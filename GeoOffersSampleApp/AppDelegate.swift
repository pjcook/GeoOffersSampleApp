//  Copyright © 2019 Zappit. All rights reserved.

import GeoOffersSDK
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialise the GeoOffersSDK, simply using the Wrapper singleton for simplifying the Sample App, use your own preferred dependency injection pattern
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Sample app test code. Log push notifications for testing
        if
            let notificationOptions = launchOptions?[.remoteNotification],
            let notification = notificationOptions as? [String: AnyObject],
            notification["aps"] != nil {
            GeoOffersNotificationLogger.shared.log(notification)
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.applicationDidBecomeActive(application)
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

        GeoOffersWrapper.shared.geoOffers.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
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
        GeoOffersWrapper.shared.geoOffers.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        GeoOffersWrapper.shared.geoOffers.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: nil)
        
        // Sample app test code. Log push notifications for testing
        guard let notification = userInfo as? [String: AnyObject] else { return }
        GeoOffersNotificationLogger.shared.log(notification)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)

        // Sample app test code. Log push notifications for testing
        guard let notification = userInfo as? [String: AnyObject] else { return }
        GeoOffersNotificationLogger.shared.log(notification)
    }
}
