//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public protocol GeoOffersSDKServiceDelegate: class {
    func hasAvailableOffers()
}

public protocol GeoOffersSDKServiceProtocol {
    var delegate: GeoOffersSDKServiceDelegate? { get set }
    var offersUpdatedDelegate: GeoOffersOffersCacheDelegate? { get set }
    func requestLocationPermissions()
    func applicationDidBecomeActive(_ application: UIApplication)
    func buildOfferListViewController() -> UIViewController
    func isGeoOffersNotification(userInfo: [AnyHashable:Any]) -> Bool
    @discardableResult func deeplinkToCoupon(_ viewController: UIViewController, notificationIdentifier: String, userInfo: [AnyHashable:Any]) -> Bool
    func requestPushNotificationPermissions()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?)
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?)
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void)
    func refreshOfferListViewController(_ viewController: UIViewController)
}
