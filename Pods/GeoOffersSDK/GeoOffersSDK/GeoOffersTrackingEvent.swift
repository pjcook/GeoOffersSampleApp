//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

enum GeoOffersTrackingEventType: String, Codable {
    case geoFenceEntry = "GeofenceEntry"
    case offerDelivered = "Delivered"
    case regionDwellTime = "GeofenceDwell"
}

struct GeoOffersTrackingEvent: Codable {
    let type: GeoOffersTrackingEventType
    let timestamp: Double
    let scheduleDeviceID: String
    let scheduleID: Int
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case type
        case timestamp = "timestampMs"
        case scheduleDeviceID = "deviceUid"
        case scheduleID = "rewardScheduleId"
        case latitude = "userLatitude"
        case longitude = "userLongitude"
    }
}

extension GeoOffersTrackingEvent {
    static func event(with type: GeoOffersTrackingEventType, region: GeoOffersGeoFence) -> GeoOffersTrackingEvent {
        return event(with: type, scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID, latitude: region.latitude, longitude: region.longitude)
    }

    static func event(with type: GeoOffersTrackingEventType, scheduleID: Int, scheduleDeviceID: String, latitude: Double, longitude: Double) -> GeoOffersTrackingEvent {
        let event = GeoOffersTrackingEvent(type: type, timestamp: Date().unixTimeIntervalSince1970, scheduleDeviceID: scheduleDeviceID, scheduleID: scheduleID, latitude: latitude, longitude: longitude)
        return event
    }
}

struct GeoOffersTrackingWrapper: Codable {
    let deviceID: String
    let timezone: String
    let events: [GeoOffersTrackingEvent]

    enum CodingKeys: String, CodingKey {
        case deviceID = "endUserUid"
        case timezone = "endUserTimezone"
        case events
    }
}
