//  Copyright © 2019 Zappit. All rights reserved.

import GeoOffersSDK
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialise the GeoOffersSDK, simply using the Wrapper singleton for simplifying the Sample App, use your own preferred dependency injection pattern

        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.service.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Sample app test code. Log push notifications for testing
        if
            let notificationOptions = launchOptions?[.remoteNotification],
            let notification = notificationOptions as? [String: AnyObject],
            notification["aps"] != nil {
            GeoOffersNotificationLogger.shared.log(notification)
        }
        
        // Register as the UNUserNotificationCenterDelegate to support deeplinking to the coupon when the user taps the notification and the app is closed
        UNUserNotificationCenter.current().delegate = self

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.service.applicationDidBecomeActive(application)
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

        GeoOffersWrapper.shared.service.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.service.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }

    // Required if implementing Remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Start of sample app test code
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        GeoOffersWrapper.shared.pushToken = token
        // End of sample app test code

        // This part is required, the stuff above is simply for the sample app
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.service.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        GeoOffersWrapper.shared.service.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: nil)

        // Sample app test code. Log push notifications for testing
        guard let notification = userInfo as? [String: AnyObject] else { return }
        GeoOffersNotificationLogger.shared.log(notification)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.service.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)

        // Sample app test code. Log push notifications for testing
        guard let notification = userInfo as? [String: AnyObject] else { return }
        GeoOffersNotificationLogger.shared.log(notification)
    }
}

extension AppDelegate {
    private func deeplinkToCoupon(_ identifier: String, userInfo: [AnyHashable:Any]) {
        guard GeoOffersWrapper.shared.service.isGeoOffersNotification(userInfo: userInfo) else { return }
        let viewController = GeoOffersWrapper.shared.service.buildOfferListViewController()
        viewController.navigationItem.leftBarButtonItem = buildCloseButton()
        let navigationController = UINavigationController(rootViewController: viewController)
        window?.rootViewController?.present(navigationController, animated: true, completion: {
            GeoOffersWrapper.shared.service.deeplinkToCoupon(viewController, notificationIdentifier: identifier, userInfo: userInfo)
        })
    }
    
    private func buildCloseButton() -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "close"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(closeCouponModal), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        let item = UIBarButtonItem(customView: button)
        return item
    }
    
    @objc private func closeCouponModal() {
        window?.rootViewController?.dismiss(animated: true, completion: nil)
    }
}

// Required if you want to implement deeplinking to coupon when user taps notification when the app is closed
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        deeplinkToCoupon(request.identifier, userInfo: request.content.userInfo)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        deeplinkToCoupon(request.identifier, userInfo: request.content.userInfo)
    }
}
