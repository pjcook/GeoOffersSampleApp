//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersGeoFence: Codable {
    let logoImageUrl: String
    let scheduleID: Int
    let scheduleDeviceID: String
    let latitude: Double
    let longitude: Double
    let radiusKm: Double
    let notificationTitle: String
    let notificationMessage: String
    let notificationDwellDelayMs: Double
    let notificationDeliveryDelayMs: Double
    let doesNotNotify: Bool
    let notifiesSilently: Bool

    enum CodingKeys: String, CodingKey {
        case logoImageUrl
        case scheduleID = "scheduleId"
        case scheduleDeviceID = "deviceUid"
        case latitude = "lat"
        case longitude = "lng"
        case radiusKm
        case notificationTitle = "customEntryNotificationTitle"
        case notificationMessage = "customEntryNotificationMessage"
        case notificationDwellDelayMs = "loiteringDelayMs"
        case notificationDeliveryDelayMs = "deliveryDelayMs"
        case doesNotNotify
        case notifiesSilently
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        logoImageUrl = try values.decode(String.self, forKey: .logoImageUrl)
        if let scheduleIDString = try? values.decode(String.self, forKey: .scheduleID),
            let scheduleIDInt = Int(scheduleIDString) {
            scheduleID = scheduleIDInt
        } else {
            scheduleID = try values.decode(Int.self, forKey: .scheduleID)
        }
        scheduleDeviceID = try values.decode(String.self, forKey: .scheduleDeviceID)
        if let latitudeString = try? values.decode(String.self, forKey: .latitude),
            let latitudeDouble = Double(latitudeString) {
            latitude = latitudeDouble
        } else {
            latitude = Double(try values.decode(Double.self, forKey: .latitude))
        }
        if let longitudeString = try? values.decode(String.self, forKey: .longitude),
            let longitudeDouble = Double(longitudeString) {
            longitude = longitudeDouble
        } else {
            longitude = Double(try values.decode(Double.self, forKey: .longitude))
        }
        if let radiusKmString = try? values.decode(String.self, forKey: .radiusKm) {
            radiusKm = Double(radiusKmString) ?? 1
        } else {
            radiusKm = try values.decode(Double.self, forKey: .radiusKm)
        }
        notificationTitle = try values.decodeIfPresent(String.self, forKey: .notificationTitle) ?? ""
        notificationMessage = try values.decodeIfPresent(String.self, forKey: .notificationMessage) ?? ""
        if let delayString = try? values.decode(String.self, forKey: .notificationDeliveryDelayMs) {
            notificationDeliveryDelayMs = Double(delayString) ?? 0
        } else {
            notificationDeliveryDelayMs = try values.decodeIfPresent(Double.self, forKey: .notificationDeliveryDelayMs) ?? 0
        }
        if let delayString = try? values.decode(String.self, forKey: .notificationDwellDelayMs) {
            notificationDwellDelayMs = Double(delayString) ?? 0
        } else {
            notificationDwellDelayMs = try values.decodeIfPresent(Double.self, forKey: .notificationDwellDelayMs) ?? 0
        }
        doesNotNotify = try values.decode(Bool.self, forKey: .doesNotNotify)
        notifiesSilently = try values.decode(Bool.self, forKey: .notifiesSilently)
    }
}
