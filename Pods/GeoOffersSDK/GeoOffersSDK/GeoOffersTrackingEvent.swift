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
        let event = GeoOffersTrackingEvent(type: type, timestamp: Date().timeIntervalSinceReferenceDate * 1000, scheduleDeviceID: region.scheduleDeviceID, scheduleID: region.scheduleID, latitude: region.latitude, longitude: region.longitude)
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
