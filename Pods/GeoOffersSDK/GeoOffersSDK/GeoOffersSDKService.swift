//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import UIKit
import UserNotifications

public protocol GeoOffersSDKServiceDelegate: class {
    func hasAvailableOffers()
}

public protocol GeoOffersSDKService {
    var delegate: GeoOffersSDKServiceDelegate? { get set }
    func requestLocationPermissions()
    func applicationDidBecomeActive(_ application: UIApplication)
    func buildOfferListViewController() -> UIViewController
    func requestPushNotificationPermissions()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?)
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?)
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
}

private var isRunningTests: Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

public class GeoOffersSDKServiceDefault: GeoOffersSDKService {
    private let maxNumberOfRegionsThatCanBeMonitoredPerApp = 20
    private var configuration: GeoOffersSDKConfiguration
    private let notificationService: GeoOffersNotificationService
    fileprivate let locationService: GeoOffersLocationService
    fileprivate var apiService: GeoOffersAPIService
    private let presentationService: GeoOffersPresenter
    private let dataParser: GeoOffersDataParser
    private let cacheService: GeoOffersCacheService
    private var firebaseWrapper: GeoOffersFirebaseWrapperProtocol

    public weak var delegate: GeoOffersSDKServiceDelegate?

    public init(configuration: GeoOffersConfiguration, userNotificationCenter: GeoOffersUserNotificationCenter = UNUserNotificationCenter.current()) {
        let lastKnownLocation = GeoOffersSDKUserDefaults.shared.lastKnownLocation
        self.configuration = configuration as! GeoOffersSDKConfiguration
        notificationService = GeoOffersNotificationServiceDefault(notificationCenter: userNotificationCenter)
        locationService = GeoOffersLocationService(latestLocation: lastKnownLocation)
        apiService = GeoOffersAPIServiceDefault(configuration: self.configuration)
        cacheService = GeoOffersCacheServiceDefault(apiService: apiService)
        dataParser = GeoOffersDataParser()
        presentationService = GeoOffersPresenterDefault(configuration: self.configuration, locationService: locationService, cacheService: cacheService, dataParser: dataParser)
        firebaseWrapper = isRunningTests ? GeoOffersFirebaseWrapperEmpty() : GeoOffersFirebaseWrapper(configuration: self.configuration)

        firebaseWrapper.delegate = self
        locationService.delegate = self
        presentationService.viewControllerDelegate = self
    }

    init(
        configuration: GeoOffersSDKConfiguration,
        notificationService: GeoOffersNotificationService,
        locationService: GeoOffersLocationService,
        apiService: GeoOffersAPIService,
        presentationService: GeoOffersPresenter,
        dataParser: GeoOffersDataParser,
        cacheService: GeoOffersCacheService,
        firebaseWrapper: GeoOffersFirebaseWrapperProtocol
    ) {
        self.configuration = configuration
        self.notificationService = notificationService
        self.locationService = locationService
        self.apiService = apiService
        self.presentationService = presentationService
        self.dataParser = dataParser
        self.cacheService = cacheService
        self.firebaseWrapper = firebaseWrapper

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
        return aps["content-available"] as? Int == 1
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
            cacheService.add(pushData)
            let totalMessages = cacheService.count(pushData.messageID)
            guard totalMessages == pushData.totalParts else { return false }
            let messages = cacheService.messages(pushData.messageID)
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
        cacheService.updateCache(pushData: message)
        cacheService.remove(messageID)
        refreshNearbyRegions()
        return true
    }

    public func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        firebaseWrapper.didRegisterForPushNotifications(deviceToken: deviceToken)
    }

    public func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        refreshNearbyRegions()
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
        notifyOfPendingOffers()
        registerPendingPushToken()
    }

    public func buildOfferListViewController() -> UIViewController {
        return presentationService.buildOfferListViewController()
    }

    private func refreshPendingOffersCache() {
        cacheService.refreshPendingOffers()
    }

    private func notifyOfPendingOffers() {
        guard cacheService.hasPendingOffers() else { return }
        delegate?.hasAvailableOffers()
    }

    private func shouldPollNearbyGeoFences(location: CLLocationCoordinate2D) -> Bool {
        let lastRefreshTimeInterval = GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval
        guard
            let lastRefreshLocation = GeoOffersSDKUserDefaults.shared.lastRefreshLocation
        else {
            return true
        }
        let minimumWaitTimePassed = abs(Date(timeIntervalSinceReferenceDate: lastRefreshTimeInterval).timeIntervalSinceNow) > configuration.minimumRefreshWaitTime
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let refreshLocation = CLLocation(latitude: lastRefreshLocation.latitude, longitude: lastRefreshLocation.longitude)
        let movedMinimumDistance = currentLocation.distance(from: refreshLocation) >= configuration.minimumRefreshDistance
        return minimumWaitTimePassed || movedMinimumDistance
    }

    private func updateLastRefreshTime(location: CLLocationCoordinate2D) {
        GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval = Date().timeIntervalSinceReferenceDate
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
        cacheService.replaceCache(parsedData)
        refreshNearbyRegions()
        registerPendingPushToken()
    }

    fileprivate func findValidRegion(_ identifier: String) -> GeoOffersGeoFence? {
        let regions = cacheService.region(with: identifier)
        guard !regions.isEmpty else {
            return nil
        }

        let date = Date()
        for region in regions {
            let schedules = cacheService.schedules(for: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID)
            guard !schedules.isEmpty else { continue }

            for schedule in schedules {
                if schedule.isValid(for: date) {
                    return region
                }
            }
        }

        return nil
    }

    private func refreshNearbyRegions() {
        guard let location = locationService.latestLocation else { return }
        cacheService.fencesNear(latitude: location.latitude, longitude: location.longitude, maximumNumberOfRegionsToReturn: maxNumberOfRegionsThatCanBeMonitoredPerApp) { regions in
            guard regions.count > 0 else { return }
            let previouslyMonitoredRegions = self.locationService.monitoredRegions
            self.locationService.stopMonitoringAllRegions()
            for region in regions {
                let regionLocation = CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude)
                let ignoreIfInside = previouslyMonitoredRegions.contains(where: { $0.identifier == region.scheduleDeviceID })
                self.locationService.monitor(center: regionLocation, radiusMeters: Double(region.radiusKm * 1000), identifier: region.scheduleDeviceID, ignoreIfInside: ignoreIfInside)
            }
        }
    }
}

extension GeoOffersSDKServiceDefault: GeoOffersLocationServiceDelegate {
    func userDidMoveSignificantDistance() {
        GeoOffersSDKUserDefaults.shared.lastKnownLocation = locationService.latestLocation
        retrieveNearbyGeoFences()
        refreshNearbyRegions()
    }

    private func removeAnyExistingPendingNotification(_ identifier: String) {
        notificationService.removeNotification(with: identifier)
        cacheService.removePendingOffer(identifier: identifier)
    }

    func didEnterRegion(_ identifier: String) {
        retrieveNearbyGeoFences()
        removeAnyExistingPendingNotification(identifier)
        guard let region = findValidRegion(identifier) else { return }
        if !region.doesNotNotify {
            let identifier = GeoOffersPendingOffer.generateKey(scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID)
            notificationService.sendNotification(title: region.notificationTitle, subtitle: region.notificationMessage, delayMs: region.notificationDwellDelayMs, identifier: identifier, isSilent: region.notifiesSilently)
            cacheService.addPendingOffer(scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID, notificationDwellDelayMs: region.notificationDwellDelayMs)
        } else {
            cacheService.addPendingOffer(scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID, notificationDwellDelayMs: region.notificationDwellDelayMs)
        }
        let event = GeoOffersTrackingEvent.event(with: .geoFenceEntry, region: region)
        apiService.track(event: event)
    }

    func didExitRegion(_ identifier: String) {
        if cacheService.pendingOffer(identifier) != nil, let region = findValidRegion(identifier) {
            let event = GeoOffersTrackingEvent.event(with: .regionDwellTime, region: region)
            apiService.track(event: event)
        }
        removeAnyExistingPendingNotification(identifier)
    }
}

extension GeoOffersSDKServiceDefault: GeoOffersFirebaseWrapperDelegate {
    func handleFirebaseNotification(notification: [String: AnyObject]) {
        _ = handleNotification(notification)
    }

    func fcmTokenUpdated() {
        registerPendingPushToken()
    }
}

extension GeoOffersSDKServiceDefault: GeoOffersViewControllerDelegate {
    func deleteOffer(scheduleID: Int) {
        apiService.delete(scheduleID: scheduleID)
    }
}
