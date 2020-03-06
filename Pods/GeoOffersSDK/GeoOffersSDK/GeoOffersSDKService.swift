//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import UIKit
import UserNotifications

private var isRunningTests: Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

public class GeoOffersSDKService: GeoOffersSDKServiceProtocol {
    private var configuration: GeoOffersInternalConfiguration
    private let notificationService: GeoOffersNotificationServiceProtocol
    private let locationService: GeoOffersLocationService
    private var apiService: GeoOffersAPIServiceProtocol
    private let presentationService: GeoOffersPresenterProtocol
    private let dataParser: GeoOffersPushNotificationProcessor
    private var firebaseWrapper: GeoOffersFirebaseWrapperProtocol
    private let offersCache: GeoOffersOffersCache
    private let notificationCache: GeoOffersPushNotificationCache
    private let listingCache: GeoOffersListingCache
    private let dataProcessor: GeoOffersDataProcessor

    
    /// Use this delegate to be notified when new offers become available whilst the app is running
    public weak var delegate: GeoOffersSDKServiceDelegate?
    
    /// Used internally, to refresh the coupon list view do not override
    public weak var offersUpdatedDelegate: GeoOffersOffersCacheDelegate?
    
    /// Initialise the SDK, this should be called in the AppDelegate application didFinishLaunchingWithOptions
    /// - Parameters:
    ///   - configuration: Contains all of the configuration required to correctly use the SDK
    ///   - userNotificationCenter: Purely serves to allow UNUserNotificationCenter to be swapped out for unit testing
    public init(
        configuration: GeoOffersConfiguration,
        userNotificationCenter: GeoOffersUserNotificationCenter = UNUserNotificationCenter.current()
    ) {
        let lastKnownLocation = GeoOffersSDKUserDefaults.shared.lastKnownLocation
        self.configuration = GeoOffersInternalConfiguration(configuration: configuration)
        notificationService = GeoOffersNotificationService(notificationCenter: userNotificationCenter)
        locationService = GeoOffersLocationService(latestLocation: lastKnownLocation, configuration: self.configuration)
        let cache = GeoOffersCache(storage: GeoOffersDiskCacheStorage())
        let trackingCache = GeoOffersTrackingCache(cache: cache)
        let sendNotificationCache = GeoOffersSendNotificationCache(cache: cache)
        let enteredRegionCache = GeoOffersEnteredRegionCache(cache: cache)
        notificationCache = GeoOffersPushNotificationCache(cache: cache)
        offersCache = GeoOffersOffersCache(cache: cache)
        listingCache = GeoOffersListingCache(cache: cache, offersCache: offersCache)
        apiService = GeoOffersAPIService(configuration: self.configuration, trackingCache: trackingCache)

        dataParser = GeoOffersPushNotificationProcessor(notificationCache: notificationCache, listingCache: listingCache)
        let webViewCache = GeoOffersWebViewCache(cache: cache, listingCache: listingCache, offersCache: offersCache)
        presentationService = GeoOffersPresenter(configuration: self.configuration, locationService: locationService, cacheService: webViewCache, trackingCache: trackingCache, apiService: apiService)
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
        
        offersCache.delegate = self
        listingCache.delegate = self
        firebaseWrapper.delegate = self
        locationService.delegate = self
        presentationService.viewControllerDelegate = self
        
        webViewCache.startCountdowns = { hashes in
            self.apiService.countdownsStarted(hashes: hashes) { result in
                switch result {
                case .failure(let error):
                    geoOffersLog("\(error)")
                    
                default:
                    break
                    
                }
            }
        }
    }

    init(
        configuration: GeoOffersConfiguration,
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
        self.configuration = GeoOffersInternalConfiguration(configuration: configuration)
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

        self.firebaseWrapper.delegate = self
        self.locationService.delegate = self
        self.presentationService.viewControllerDelegate = self
    }

    /// Call from the AppDelegate once the SDK has been initialized
    public func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        firebaseWrapper.applicationDidFinishLaunching()
        guard
            let notificationOptions = launchOptions?[.remoteNotification],
            let notification = notificationOptions as? [String: AnyObject],
            notification["aps"] != nil,
            dataParser.shouldProcessRemoteNotification(notification) else { return }
        _ = dataParser.handleNotification(notification)
    }

    /// Call from the matching AppDelegate method
    public func application(_: UIApplication, handleEventsForBackgroundURLSession _: String, completionHandler: @escaping () -> Void) {
        apiService.backgroundSessionCompletionHandler = completionHandler
    }
    
    /// Use this method to request push notification system permissions
    public func requestPushNotificationPermissions() {
        notificationService.requestNotificationPermissions()
    }

    /// Call from the matching AppDelegate method
    public func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        guard let notification = userInfo as? [String: AnyObject],
            dataParser.shouldProcessRemoteNotification(notification) else {
            completionHandler?(.failed)
            return
        }
        let success = dataParser.handleNotification(notification)
        processListingData {
            completionHandler?(success ? .newData : .failed)
        }
    }

    /// Call from the matching AppDelegate method
    public func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        firebaseWrapper.didRegisterForPushNotifications(deviceToken: deviceToken)
        processListingData()
    }

    /// Call from the matching AppDelegate method
    public func application(_: UIApplication, performFetchWithCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        processListingData()
        retrieveNearbyGeoFences()
        completionHandler?(.newData)
    }

    // Use this method to request system location permissions
    public func requestLocationPermissions() {
        locationService.requestPermissions()
    }

    /// Call from the matching AppDelegate method
    public func applicationDidBecomeActive(_ application: UIApplication) {
        notificationService.applicationDidBecomeActive(application)
        locationService.startMonitoringSignificantLocationChanges()
        retrieveNearbyGeoFences()
        processListingData()
        registerPendingPushToken()
        notificationCache.cleanUpMessages()
        apiService.checkForPendingTrackingEvents()
    }

    /// This will create a UIViewController that contains the list of offers and coupons that the user has available. This will need to be contained in a UINavigationController to work correctly, so either push this on an existing navigation controller, or wrap it in a UINavigationController and present it
    public func buildOfferListViewController() -> UIViewController {
        return presentationService.buildOfferListViewController(service: self)
    }
    
    /// You can use this method to check whether the UNUserNotification was a GeoOffers notification or not when handling the response from a UNUserNotification for deeplinking to the Coupon or Offer
    /// - Parameter userInfo: The userInfo from UNNotification.content.userInfo
    public func isGeoOffersNotification(userInfo: [AnyHashable:Any]) -> Bool {
        guard let isValidNotification = userInfo[IsGeoOfferNotificationKey] as? Bool else { return false }
        return isValidNotification
    }
    
    /// Create a GeoOffers list view controller using the buildOfferListViewController() method, push that onto your navigation controller, or wrap it in a navigation controller and present it. Then call this method passing that view controller in here so that we can attempt to deeplink to the correct coupon or offer. If the notificationIdentifier does not match a coupon then the list page will remain visible
    /// - Parameters:
    ///   - viewController: The UIViewController from buildOfferListViewController()
    ///   - notificationIdentifier: the notification identifier from the UNNotification
    ///   - userInfo: The userInfo from the UNNotification.content.userInfo
    @discardableResult public func deeplinkToCoupon(_ viewController: UIViewController, notificationIdentifier: String, userInfo: [AnyHashable:Any]) -> Bool {
        guard
            isGeoOffersNotification(userInfo: userInfo),
            let vc = viewController as? GeoOffersViewController,
            let scheduleID = ScheduleID(notificationIdentifier)
        else { return false }
        vc.openCoupon(scheduleID: scheduleID)
        return true
    }
    
    /// Used internally by the UIViewController from buildOfferListViewController() to refresh it's content when the offers data available changes
    /// - Parameter viewController: the UIViewController from buildOfferListViewController()
    public func refreshOfferListViewController(_ viewController: UIViewController) {
        guard let vc = viewController as? GeoOffersViewController else { return }
        presentationService.refreshOfferListViewController(vc)
    }
    
    /// This allows the locations being monitored to be displayed on a MKMapView
    public func debugRegionLocations() -> [GeoOffersDebugRegion] {
        return listingCache.debugRegionLocations()
    }
}

extension GeoOffersSDKService {
    private func updateLastRefreshTime(location: CLLocationCoordinate2D) {
        GeoOffersSDKUserDefaults.shared.lastRefreshTimeInterval = Date().timeIntervalSince1970
        GeoOffersSDKUserDefaults.shared.lastRefreshLocation = location
    }

    private func processListingData(_ completionHandler: (() -> Void)? = nil) {
        guard let location = locationService.latestLocation else { return }
        dataProcessor.process(at: location, locationService: locationService, completionHandler: completionHandler)
    }

    private func processListingData(for location: CLLocationCoordinate2D, _ completionHandler: (() -> Void)? = nil) {
        dataProcessor.process(at: location, locationService: nil, completionHandler: completionHandler)
    }
}

extension GeoOffersSDKService: GeoOffersLocationServiceDelegate {
    public func userDidMoveSignificantDistance() {
        GeoOffersSDKUserDefaults.shared.lastKnownLocation = locationService.latestLocation
        retrieveNearbyGeoFences()
        processListingData()
    }

    public func didUpdateLocations(_ locations: [CLLocation]) {
        for location in locations {
            processListingData(for: location.coordinate)
        }
    }

    public func didEnterRegion(_: String) {
        retrieveNearbyGeoFences()
        processListingData()
    }

    public func didExitRegion(_: String) {
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
    public func listingUpdated() {
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
        guard let clientID = self.dataParser.parseNearbyFences(jsonData: data) else {
            geoOffersLog("Invalid fences data")
            return
        }
        configuration.clientID = clientID
        processListingData()
        registerPendingPushToken()
    }
}
