//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public protocol GeoOffersNotificationServiceProtocol {
    func requestNotificationPermissions()
    func applicationDidBecomeActive(_ application: UIApplication)
    func sendNotification(title: String, subtitle: String, delaySeconds: Double, identifier: String, isSilent: Bool)
}
