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
    
    init(scheduleID: Int, scheduleDeviceID: String, latitude: Double = 0, longitude: Double = 0, notificationDwellDelay: TimeInterval = 0, createdDate: Date) {
        self.scheduleID = scheduleID
        self.scheduleDeviceID = scheduleDeviceID
        self.latitude = latitude
        self.longitude = longitude
        self.notificationDwellDelay = notificationDwellDelay
        self.createdDate = createdDate
    }

    static func generateKey(scheduleID: Int, scheduleDeviceID: String) -> String {
        return "\(scheduleID)_\(scheduleDeviceID)"
    }
}
