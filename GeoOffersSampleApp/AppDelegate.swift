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

        // Log push notifications for testing
        if
            let notificationOptions = launchOptions?[.remoteNotification],
            let notification = notificationOptions as? [String: AnyObject],
            notification["aps"] != nil {
            GeoOffersNotificationLogger.shared.log(notification)
        }

        return true
    }

    func applicationWillResignActive(_: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.applicationDidBecomeActive(application)
    }

    func applicationWillTerminate(_: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

        GeoOffersWrapper.shared.geoOffers.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    // Required if implementing Remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        GeoOffersWrapper.shared.pushToken = token

        // This part is required, the stuff above is simply for the sample app
        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you want to handle the "completionHandler" then pass nil to the geoOffers function completionHandler

        // Call the matching method on the GeoOffersSDK instance
        GeoOffersWrapper.shared.geoOffers.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)

        // Log push notifications for testing
        guard let notification = userInfo as? [String: AnyObject] else { return }
        GeoOffersNotificationLogger.shared.log(notification)
    }
}
