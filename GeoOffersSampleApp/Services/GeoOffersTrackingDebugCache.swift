//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

typealias ScheduleID = Int

enum GeoOffersTrackingEventType: String, Codable {
    case geoFenceEntry = "GeofenceEntry"
    case geoFenceExit = "GeofenceExit"
    case offerDelivered = "Delivered"
    case regionDwellTime = "GeofenceDwell"
    case polledForNearbyOffers = "PolledForNearbyOffers"
    
    var shouldSendToServer: Bool {
        switch self {
        case .geoFenceEntry, .offerDelivered: return true
        default: return false
        }
    }
}

struct GeoOffersTrackingEvent: Codable {
    let type: GeoOffersTrackingEventType
    let timestamp: Double
    let scheduleDeviceID: String
    let scheduleID: ScheduleID
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

class GeoOffersTrackingDebugCache: DiskCache<[GeoOffersTrackingEvent]> {
    override init(filename: String, fileManager: FileManager = FileManager.default, savePeriodSeconds: TimeInterval = 30) {
        super.init(filename: filename, fileManager: fileManager, savePeriodSeconds: savePeriodSeconds)
        print(savePath)
    }
}
