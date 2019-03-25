//  Copyright © 2019 Zappit. All rights reserved.

import FirebaseCore
import FirebaseMessaging
import Foundation

protocol GeoOffersFirebaseWrapperDelegate: class {
    func handleFirebaseNotification(notification: [String: AnyObject])
    func fcmTokenUpdated()
}

protocol GeoOffersFirebaseWrapperProtocol {
    var delegate: GeoOffersFirebaseWrapperDelegate? { get set }
    func applicationDidFinishLaunching()
    func didRegisterForPushNotifications(deviceToken: Data)
    func appDidReceiveMessage(userInfo: [AnyHashable: Any])
}

class GeoOffersFirebaseWrapperEmpty: GeoOffersFirebaseWrapperProtocol {
    var delegate: GeoOffersFirebaseWrapperDelegate?
    func applicationDidFinishLaunching() {}
    func didRegisterForPushNotifications(deviceToken _: Data) {}
    func appDidReceiveMessage(userInfo _: [AnyHashable: Any]) {}
}

class GeoOffersFirebaseWrapper: NSObject, GeoOffersFirebaseWrapperProtocol {
    private var configuration: GeoOffersSDKConfiguration
    weak var delegate: GeoOffersFirebaseWrapperDelegate?

    init(configuration: GeoOffersSDKConfiguration) {
        self.configuration = configuration
    }

    func applicationDidFinishLaunching() {
        guard
            let path = Bundle(for: GeoOffersFirebaseWrapper.self).path(forResource: "GeoOffersSDK-GoogleService-Info", ofType: "geoconfig"),
            let options = FirebaseOptions(contentsOfFile: path)
        else { return }

        if configuration.mainAppUsesFirebase {
            FirebaseApp.configure(name: "GeoOffersSDK", options: options)
        } else {
            FirebaseApp.configure(options: options)
        }

        Messaging.messaging().delegate = self
        Messaging.messaging().shouldEstablishDirectChannel = true
        printTokens()
    }

    private func printTokens() {
        if let deviceToken = Messaging.messaging().apnsToken {
            let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
            let token = tokenParts.joined()
            geoOffersLog("APNSToken:\(token)")
        }

        if let fcmToken = Messaging.messaging().fcmToken {
            geoOffersLog("FCMToken:\(fcmToken)")
        }
    }

    func didRegisterForPushNotifications(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        printTokens()
    }

    func appDidReceiveMessage(userInfo: [AnyHashable: Any]) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
    }
}

extension GeoOffersFirebaseWrapper: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String) {
        printTokens()
        guard configuration.pushToken != fcmToken else { return }
        configuration.pendingPushTokenRegistration = fcmToken
        configuration.refresh()
        delegate?.fcmTokenUpdated()
    }

    func messaging(_: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        geoOffersLog("\(remoteMessage.appData)")
        guard let notification = remoteMessage.appData as? [String: AnyObject] else { return }
        delegate?.handleFirebaseNotification(notification: notification)
    }
}
