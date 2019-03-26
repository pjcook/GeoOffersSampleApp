//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersPendingOffer: Codable {
    let scheduleID: Int
    let scheduleDeviceID: String
    let latitude: Double
    let longitude: Double
    let notificationDwellDelay: TimeInterval
    let createdDate: Date
    var key: String {
        return GeoOffersPendingOffer.generateKey(scheduleID: scheduleID, scheduleDeviceID: scheduleDeviceID)
    }

    static func generateKey(scheduleID: Int, scheduleDeviceID: String) -> String {
        return "\(scheduleID)_\(scheduleDeviceID)"
    }
}
