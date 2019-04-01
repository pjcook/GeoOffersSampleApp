//  Copyright © 2019 Zappit. All rights reserved.

import Foundation
import UserNotifications

public protocol GeoOffersUserNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void)
}

extension UNUserNotificationCenter: GeoOffersUserNotificationCenter {}

protocol GeoOffersNotificationServiceProtocol {
    func requestNotificationPermissions()
    func applicationDidBecomeActive(_ application: UIApplication)
    func sendNotification(title: String, subtitle: String, delaySeconds: Double, identifier: String, isSilent: Bool)
    func removeNotification(with identifier: String)
}

class GeoOffersNotificationService: GeoOffersNotificationServiceProtocol {
    private var notificationCenter: GeoOffersUserNotificationCenter
    private let toastManager: GeoOffersNotificationToastManager

    init(
        notificationCenter: GeoOffersUserNotificationCenter = UNUserNotificationCenter.current(),
         toastManager: GeoOffersNotificationToastManager = GeoOffersNotificationToastManager()
    ) {
        self.notificationCenter = notificationCenter
        self.toastManager = toastManager
    }

    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.badge, .sound, .alert]) { success, error in
            if let error = error {
                geoOffersLog("GeoOffersSDK.failedToRequestNotificationPermissions Error: \(error)")
            }
            if success {
                self.registerForPushNotifications()
            }
        }
    }

    func applicationDidBecomeActive(_: UIApplication) {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        registerOnLaunch()
    }

    /*
     This method will schedule a location notification if the application is not active
     */
    func sendNotification(title: String, subtitle: String, delaySeconds: Double, identifier: String, isSilent: Bool) {
        guard !title.isEmpty else { return }
        #if targetEnvironment(simulator)
        #else
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    self.sendNotification(title: title, subtitle: subtitle, delaySeconds: delaySeconds, identifier: identifier, isSilent: isSilent)
                }
                return
            }
        
            guard UIApplication.shared.applicationState != .active else {
                toastManager.presentToast(title: title, subtitle: subtitle, delay: delaySeconds)
                return
            }
        #endif

        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = title
        notificationContent.subtitle = subtitle
        notificationContent.sound = isSilent ? nil : UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error = error {
                geoOffersLog("GeoOffersSDK.failedToSendNotification Error: \(error)")
            }
        }
    }

    func removeNotification(with identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

extension GeoOffersNotificationService {
    private func registerForPushNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    private func registerOnLaunch() {
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            self.registerForPushNotifications()
        }
    }
}
