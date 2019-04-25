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
    private var configuration: GeoOffersSDKConfiguration
    private let notificationService: GeoOffersNotificationServiceProtocol
    fileprivate let locationService: GeoOffersLocationService
    fileprivate var apiService: GeoOffersAPIServiceProtocol
    private let presentationService: GeoOffersPresenterProtocol
    private let dataParser: GeoOffersPushNotificationProcessor
    private var firebaseWrapper: GeoOffersFirebaseWrapperProtocol
    private let offersCache: GeoOffersOffersCache
    private let notificationCache: GeoOffersPushNotificationCache
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
        locationService = GeoOffersLocationService(latestLocation: lastKnownLocation, configuration: configuration)
        let cache = GeoOffersCache(storage: GeoOffersDiskCacheStorage())
        let trackingCache = GeoOffersTrackingCache(cache: cache)
        let sendNotificationCache = GeoOffersSendNotificationCache(cache: cache)
        let enteredRegionCache = GeoOffersEnteredRegionCache(cache: cache)
        notificationCache = GeoOffersPushNotificationCache(cache: cache)
        offersCache = GeoOffersOffersCache(cache: cache)
        listingCache = GeoOffersListingCache(cache: cache, offersCache: offersCache)
        apiService = GeoOffersAPIService(configuration: self.configuration, trackingCache: trackingCache)

        dataParser = GeoOffersPushNotificationProcessor(notificationCache: notificationCache, listingCache: listingCache)
        presentationService = GeoOffersPresenter(configuration: self.configuration, locationService: locationService, cacheService: GeoOffersWebViewCache(cache: cache, listingCache: listingCache, offersCache: offersCache))
        firebaseWrapper = isRunningTests ? GeoOffersFirebaseWrapperEmpty() : GeoOffersFirebaseWrapper(configuration: self.configuration)
        dataProcessor = GeoOffersDataProcessor(
            offersCache: offersCache,
            listingCache: listingCache,
            sendNotificationCache: sendNotificationCache,
            enteredRegionCache: enteredRegionCache,
            notificationService: notificationService,
            apiService: apiService,
            trackingCache: trackingCache
        )

        dataParser.delegate = self
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
        dataParser: GeoOffersPushNotificationProcessor,
        firebaseWrapper: GeoOffersFirebaseWrapperProtocol,
        offersCache: GeoOffersOffersCache,
        notificationCache: GeoOffersPushNotificationCache,
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

        self.offersCache = offersCache
        self.notificationCache = notificationCache
        self.listingCache = listingCache

        dataParser.delegate = self
        self.firebaseWrapper.delegate = self
        self.locationService.delegate = self
        self.presentationService.viewControllerDelegate = self
    }

    public func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        firebaseWrapper.applicationDidFinishLaunching()
        guard
            let notificationOptions = launchOptions?[.remoteNotification],
            let notification = notificationOptions as? [String: AnyObject],
            notification["aps"] != nil,
            dataParser.shouldProcessRemoteNotification(notification) else { return }
        _ = dataParser.handleNotification(notification)
    }

    public func application(_: UIApplication, handleEventsForBackgroundURLSession _: String, completionHandler: @escaping () -> Void) {
        apiService.backgroundSessionCompletionHandler = completionHandler
    }

    public func requestPushNotificationPermissions() {
        notificationService.requestNotificationPermissions()
    }

    public func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        guard let notification = userInfo as? [String: AnyObject],
            dataParser.shouldProcessRemoteNotification(notification) else {
            completionHandler?(.failed)
            return
        }
        let success = dataParser.handleNotification(notification)
        completionHandler?(success ? .newData : .failed)
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

    public func requestLocationPermissions() {
        locationService.requestPermissions()
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {
        notificationService.applicationDidBecomeActive(application)
        locationService.startMonitoringSignificantLocationChanges()
        retrieveNearbyGeoFences()
        processListingData()
        registerPendingPushToken()
        notificationCache.cleanUpMessages()
    }

    public func buildOfferListViewController() -> UIViewController {
        return presentationService.buildOfferListViewController(service: self)
    }

    public func refreshOfferListViewController(_ viewController: UIViewController) {
        guard let vc = viewController as? GeoOffersViewController else { return }
        presentationService.refreshOfferListViewController(vc)
    }

    public func debugRegionLocations() -> [GeoOffersDebugRegion] {
        let regions = listingCache.listing()?.regions.reduce([]) { $0 + $1.value } ?? []
        return regions.map { GeoOffersDebugRegion(region: $0) }
    }
}

extension GeoOffersSDKService: GeoOffersPushNotificationProcessorDelegate {
    private func updateLastRefreshTime(location: CLLocationCoordinate2D) {
        GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval = Date().timeIntervalSince1970
        GeoOffersSDKUserDefaults.shared.lastRefreshLocation = location
    }

    internal func processListingData() {
        guard let location = locationService.latestLocation else { return }
        dataProcessor.process(at: location)

        guard let regionsToBeMonitored = dataProcessor.regionsToBeMonitored(at: location) else {
            locationService.stopMonitoringAllRegions()
            return
        }
        locationService.monitor(regions: regionsToBeMonitored)
    }

    private func processListingData(for location: CLLocationCoordinate2D) {
        dataProcessor.process(at: location)
    }
}

extension GeoOffersSDKService: GeoOffersLocationServiceDelegate {
    func userDidMoveSignificantDistance() {
        GeoOffersSDKUserDefaults.shared.lastKnownLocation = locationService.latestLocation
        retrieveNearbyGeoFences()
        processListingData()
    }

    func didUpdateLocations(_ locations: [CLLocation]) {
        for location in locations {
            processListingData(for: location.coordinate)
        }
    }

    func didEnterRegion(_: String) {
        retrieveNearbyGeoFences()
        processListingData()
    }

    func didExitRegion(_: String) {
        retrieveNearbyGeoFences()
        processListingData()
    }
}

extension GeoOffersSDKService: GeoOffersFirebaseWrapperDelegate {
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

    func handleFirebaseNotification(notification: [String: AnyObject]) {
        _ = dataParser.handleNotification(notification)
    }

    func fcmTokenUpdated() {
        registerPendingPushToken()
    }
}

extension GeoOffersSDKService: GeoOffersViewControllerDelegate {
    func deleteOffer(scheduleID: ScheduleID) {
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
        // offersUpdatedDelegate?.offersUpdated()
        // updates too frequently
    }
}

// MARK: - Process data

extension GeoOffersSDKService {
    private func shouldPollNearbyGeoFences(location: CLLocationCoordinate2D) -> Bool {
        let lastRefreshTimeInterval = GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval
        guard
            let lastRefreshLocation = GeoOffersSDKUserDefaults.shared.lastRefreshLocation
        else {
            return true
        }
        let minimumWaitTimePassed = abs(Date(timeIntervalSince1970: lastRefreshTimeInterval).timeIntervalSinceNow) >= configuration.minimumRefreshWaitTime
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let refreshLocation = CLLocation(latitude: lastRefreshLocation.latitude, longitude: lastRefreshLocation.longitude)
        let movedMinimumDistance = currentLocation.distance(from: refreshLocation) >= listingCache.minimumMovementDistance
        return minimumWaitTimePassed || movedMinimumDistance
    }

    private func retrieveNearbyGeoFences() {
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
}
