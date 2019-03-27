//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import UIKit
import UserNotifications

public protocol GeoOffersSDKServiceDelegate: class {
    func hasAvailableOffers()
}

public protocol GeoOffersSDKServiceProtocol {
    var delegate: GeoOffersSDKServiceDelegate? { get set }
    var offersUpdatedDelegate: GeoOffersOffersCacheDelegate? { get set }
    func requestLocationPermissions()
    func applicationDidBecomeActive(_ application: UIApplication)
    func buildOfferListViewController() -> UIViewController
    func requestPushNotificationPermissions()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?)
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?)
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
    func refreshOfferListViewController(_ viewController: UIViewController)
}

private var isRunningTests: Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

public class GeoOffersSDKService: GeoOffersSDKServiceProtocol {
    private let maxNumberOfRegionsThatCanBeMonitoredPerApp = 20
    private var configuration: GeoOffersSDKConfiguration
    private let notificationService: GeoOffersNotificationServiceProtocol
    fileprivate let locationService: GeoOffersLocationService
    fileprivate var apiService: GeoOffersAPIServiceProtocol
    private let presentationService: GeoOffersPresenterProtocol
    private let dataParser: GeoOffersDataParser
    private var firebaseWrapper: GeoOffersFirebaseWrapperProtocol
    private let offersCache: GeoOffersOffersCache
    private let notificationCache: GeoOffersNotificationCache
    private let fencesCache: GeoOffersGeoFencesCache
    private let listingCache: GeoOffersListingCache
    private let dataProcessor: GeoOffersDataProcessor

    public weak var delegate: GeoOffersSDKServiceDelegate?
    public weak var offersUpdatedDelegate: GeoOffersOffersCacheDelegate?

    public init(
        configuration: GeoOffersConfigurationProtocol,
        userNotificationCenter: GeoOffersUserNotificationCenter = UNUserNotificationCenter.current()
    ) {
        let lastKnownLocation = GeoOffersSDKUserDefaults.shared.lastKnownLocation
        self.configuration = configuration as! GeoOffersSDKConfiguration
        notificationService = GeoOffersNotificationService(notificationCenter: userNotificationCenter)
        locationService = GeoOffersLocationService(latestLocation: lastKnownLocation)
        apiService = GeoOffersAPIService(configuration: self.configuration)
        let cache = GeoOffersCache()
        fencesCache = GeoOffersGeoFencesCache(cache: cache)
        offersCache = GeoOffersOffersCache(cache: cache, fencesCache: fencesCache, apiService: apiService)
        notificationCache = GeoOffersNotificationCache(cache: cache)
        listingCache = GeoOffersListingCache(cache: cache)

        dataParser = GeoOffersDataParser()
        presentationService = GeoOffersPresenter(configuration: self.configuration, locationService: locationService, cacheService: GeoOffersWebViewCache(cache: cache, listingCache: listingCache, offersCache: offersCache), dataParser: dataParser)
        firebaseWrapper = isRunningTests ? GeoOffersFirebaseWrapperEmpty() : GeoOffersFirebaseWrapper(configuration: self.configuration)
        dataProcessor = GeoOffersDataProcessor(
            offersCache: offersCache,
            listingCache: listingCache,
            notificationService: notificationService,
            apiService: apiService
        )

        offersCache.delegate = self
        listingCache.delegate = self
        firebaseWrapper.delegate = self
        locationService.delegate = self
        presentationService.viewControllerDelegate = self
    }

    init(
        configuration: GeoOffersSDKConfiguration,
        notificationService: GeoOffersNotificationServiceProtocol,
        locationService: GeoOffersLocationService,
        apiService: GeoOffersAPIServiceProtocol,
        presentationService: GeoOffersPresenterProtocol,
        dataParser: GeoOffersDataParser,
        firebaseWrapper: GeoOffersFirebaseWrapperProtocol,
        fencesCache: GeoOffersGeoFencesCache,
        offersCache: GeoOffersOffersCache,
        notificationCache: GeoOffersNotificationCache,
        listingCache: GeoOffersListingCache,
        dataProcessor: GeoOffersDataProcessor
    ) {
        self.configuration = configuration
        self.notificationService = notificationService
        self.locationService = locationService
        self.apiService = apiService
        self.presentationService = presentationService
        self.dataParser = dataParser
        self.firebaseWrapper = firebaseWrapper
        self.dataProcessor = dataProcessor

        self.fencesCache = fencesCache
        self.offersCache = offersCache
        self.notificationCache = notificationCache
        self.listingCache = listingCache

        self.firebaseWrapper.delegate = self
        self.locationService.delegate = self
        self.presentationService.viewControllerDelegate = self
    }

    public func requestPushNotificationPermissions() {
        notificationService.requestNotificationPermissions()
    }

    public func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        firebaseWrapper.applicationDidFinishLaunching()
        guard
            let notificationOptions = launchOptions?[.remoteNotification],
            let notification = notificationOptions as? [String: AnyObject],
            notification["aps"] != nil,
            shouldProcessRemoteNotification(notification) else { return }
        _ = handleNotification(notification)
    }

    public func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        guard let notification = userInfo as? [String: AnyObject],
            shouldProcessRemoteNotification(notification) else {
            completionHandler?(.failed)
            return
        }
        let success = handleNotification(notification)
        completionHandler?(success ? .newData : .failed)
    }

    public func application(_: UIApplication, handleEventsForBackgroundURLSession _: String, completionHandler: @escaping () -> Void) {
        apiService.backgroundSessionCompletionHandler = completionHandler
    }

    private func shouldProcessRemoteNotification(_ notification: [String: AnyObject]) -> Bool {
        let aps = notification["aps"] as? [String: AnyObject] ?? [:]
        return aps["content-available"] as? String == "1"
    }

    private func handleNotification(_ notification: [String: AnyObject]) -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: notification, options: .prettyPrinted)
            guard let parsedData = self.dataParser.parsePushNotification(jsonData: data) else { return false }
            return processPushNotificationData(pushData: parsedData)
        } catch {
            geoOffersLog("\(error)")
        }
        return false
    }

    private func processPushNotificationData(pushData: GeoOffersPushData) -> Bool {
        if pushData.totalParts == 1 {
            guard let message = buildMessage(messages: [pushData]) else { return false }
            return processPushNotificationMessage(message: message, messageID: pushData.messageID)
        } else {
            notificationCache.add(pushData)
            let totalMessages = notificationCache.count(pushData.messageID)
            guard totalMessages == pushData.totalParts else { return false }
            let messages = notificationCache.messages(pushData.messageID)
            guard let message = buildMessage(messages: messages) else { return false }
            return processPushNotificationMessage(message: message, messageID: pushData.messageID)
        }
    }

    private func buildMessage(messages: [GeoOffersPushData]) -> GeoOffersPushNotificationDataUpdate? {
        let sorted = messages.sorted { $0.messageIndex < $1.messageIndex }
        var messageString = ""
        for message in sorted {
            messageString += message.message
        }
        guard let data = messageString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        do {
            let parsedData = try decoder.decode(GeoOffersPushNotificationDataUpdate.self, from: data)
            return parsedData
        } catch {
            geoOffersLog("\(error)")
        }
        return nil
    }

    private func processPushNotificationMessage(message: GeoOffersPushNotificationDataUpdate, messageID: String) -> Bool {
        notificationCache.updateCache(pushData: message)
        notificationCache.remove(messageID)
        processListingData()
        offersUpdatedDelegate?.offersUpdated()
        return true
    }

    public func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        firebaseWrapper.didRegisterForPushNotifications(deviceToken: deviceToken)
        processListingData()
    }

    public func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        processListingData()
        retrieveNearbyGeoFences()
        completionHandler?(.newData)
    }

    private func registerPendingPushToken() {
        guard
            let token = configuration.pendingPushTokenRegistration,
            let location = locationService.latestLocation,
            let clientID = configuration.clientID
        else { return }
        let currentToken = configuration.pushToken
        let completionHandler: GeoOffersNetworkResponse = { response in
            guard case .success = response else { return }
            self.configuration.pushToken = token
            self.configuration.pendingPushTokenRegistration = nil
        }

        if let currentToken = currentToken {
            apiService.update(pushToken: currentToken, with: token, completionHandler: completionHandler)
        } else {
            apiService.register(pushToken: token, latitude: location.latitude, longitude: location.longitude, clientID: clientID, completionHandler: completionHandler)
        }
    }

    public func requestLocationPermissions() {
        locationService.requestPermissions()
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {
        notificationService.applicationDidBecomeActive(application)
        locationService.startMonitoringSignificantLocationChanges()
        retrieveNearbyGeoFences()
        refreshPendingOffersCache()
        notifyOfAvailableOffers()
        registerPendingPushToken()
    }

    public func buildOfferListViewController() -> UIViewController {
        return presentationService.buildOfferListViewController(service: self)
    }

    public func refreshOfferListViewController(_ viewController: UIViewController) {
        guard let vc = viewController as? GeoOffersViewController else { return }
        presentationService.refreshOfferListViewController(vc)
    }

    private func refreshPendingOffersCache() {
        offersCache.refreshPendingOffers()
    }

    private func notifyOfAvailableOffers() {
        guard offersCache.hasOffers() else { return }
        delegate?.hasAvailableOffers()
    }

    private func shouldPollNearbyGeoFences(location: CLLocationCoordinate2D) -> Bool {
        let lastRefreshTimeInterval = GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval
        guard
            let lastRefreshLocation = GeoOffersSDKUserDefaults.shared.lastRefreshLocation
        else {
            return true
        }
        let minimumWaitTimePassed = abs(Date(timeIntervalSince1970: lastRefreshTimeInterval).timeIntervalSinceNow) > configuration.minimumRefreshWaitTime
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let refreshLocation = CLLocation(latitude: lastRefreshLocation.latitude, longitude: lastRefreshLocation.longitude)
        let movedMinimumDistance = currentLocation.distance(from: refreshLocation) >= configuration.minimumRefreshDistance
        return minimumWaitTimePassed || movedMinimumDistance
    }

    private func updateLastRefreshTime(location: CLLocationCoordinate2D) {
        GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval = Date().timeIntervalSince1970
        GeoOffersSDKUserDefaults.shared.lastRefreshLocation = location
    }

    fileprivate func retrieveNearbyGeoFences() {
        guard let location = locationService.latestLocation, shouldPollNearbyGeoFences(location: location) else { return }
        updateLastRefreshTime(location: location)
        apiService.pollForNearbyOffers(latitude: location.latitude, longitude: location.longitude) { response in
            switch response {
            case let .failure(error):
                let nsError = error as NSError
                if nsError.code == -999 {
                    // This is simply because we cancelled a previous request
                } else {
                    geoOffersLog("\(error)")
                }
                GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval = 0
            case .success:
                GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval = 0
            case let .dataTask(data):
                if let data = data {
                    self.processDownloadedData(data: data)
                }
            }
        }
    }

    internal func processDownloadedData(data: Data) {
        guard let parsedData = self.dataParser.parseNearbyFences(jsonData: data) else {
            geoOffersLog("Invalid fences data")
            return
        }
        configuration.clientID = parsedData.clientID
        listingCache.replaceCache(parsedData)
        processListingData()
        registerPendingPushToken()
    }

    fileprivate func findValidRegion(_ identifier: String) -> GeoOffersGeoFence? {
        let regions = fencesCache.region(with: identifier)
        guard !regions.isEmpty else {
            return nil
        }

        let date = Date()
        for region in regions {
            let schedules = listingCache.schedules(for: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID)
            guard !schedules.isEmpty else { continue }

            for schedule in schedules {
                if schedule.isValid(for: date) {
                    return region
                }
            }
        }

        return nil
    }

    private func processListingData() {
        if let location = locationService.latestLocation {
            let regionsToBeMonitored = dataProcessor.processListing(at: location)
            locationService.monitor(regions: regionsToBeMonitored)
        }
    }
}

extension GeoOffersSDKService: GeoOffersLocationServiceDelegate {
    func userDidMoveSignificantDistance() {
        GeoOffersSDKUserDefaults.shared.lastKnownLocation = locationService.latestLocation
        retrieveNearbyGeoFences()
        processListingData()
    }

    private func removeAnyExistingPendingNotification(_ identifier: String) {
        notificationService.removeNotification(with: identifier)
        offersCache.removePendingOffer(identifier: identifier)
    }

    func didEnterRegion(_ identifier: String) {
        retrieveNearbyGeoFences()
        processListingData()
        guard let region = findValidRegion(identifier) else { return }
        offersCache.addPendingOffer(scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID, latitude: region.latitude, longitude: region.longitude, notificationDwellDelayMs: region.notificationDwellDelayMs)
    }

    func didExitRegion(_ identifier: String) {
        retrieveNearbyGeoFences()
        if let pendingOffer = offersCache.pendingOffer(identifier) {
            let event = GeoOffersTrackingEvent.event(with: .regionDwellTime, scheduleID: pendingOffer.scheduleID, scheduleDeviceID: pendingOffer.scheduleDeviceID, latitude: pendingOffer.latitude, longitude: pendingOffer.longitude)
            apiService.track(event: event)
        }
        removeAnyExistingPendingNotification(identifier)
    }
}

extension GeoOffersSDKService: GeoOffersFirebaseWrapperDelegate {
    func handleFirebaseNotification(notification: [String: AnyObject]) {
        _ = handleNotification(notification)
    }

    func fcmTokenUpdated() {
        registerPendingPushToken()
    }
}

extension GeoOffersSDKService: GeoOffersViewControllerDelegate {
    func deleteOffer(scheduleID: Int) {
        apiService.delete(scheduleID: scheduleID)
    }
}

extension GeoOffersSDKService: GeoOffersOffersCacheDelegate {
    public func offersUpdated() {
        offersUpdatedDelegate?.offersUpdated()
    }
}

extension GeoOffersSDKService: GeoOffersListingCacheDelegate {
    func listingUpdated() {
        offersUpdatedDelegate?.offersUpdated()
    }
}
