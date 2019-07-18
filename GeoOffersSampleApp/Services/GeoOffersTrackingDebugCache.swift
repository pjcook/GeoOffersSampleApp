//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

typealias ScheduleID = Int

enum GeoOffersTrackingEventType: String, Codable {
    case geoFenceEntry = "GeofenceEntry"
    case geoFenceExit = "GeofenceExit"
    case offerDelivered = "Delivered"
    case regionDwellTime = "GeofenceDwell"
    case polledForNearbyOffers = "PolledForNearbyOffers"
    case couponOpened = "CouponOpened"

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
    let clientCouponHash: String?

    enum CodingKeys: String, CodingKey {
        case type
        case timestamp = "timestampMs"
        case scheduleDeviceID = "deviceUid"
        case scheduleID = "rewardScheduleId"
        case latitude = "userLatitude"
        case longitude = "userLongitude"
        case clientCouponHash = "clientCouponHashIfApplicable"
    }
}

class GeoOffersTrackingDebugCache {
    var cacheData: [GeoOffersTrackingEvent] = []
    let savePath: String
    private let fileManager = FileManager.default

    init() {
        savePath = try! fileManager.documentPath(for: "GeoOffersTrackingDebugCache.data")
        print(savePath)
    }

    func load() -> [GeoOffersTrackingEvent] {
        guard fileManager.fileExists(atPath: savePath) else { return [] }
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: savePath))
            let jsonDecoder = JSONDecoder()
            let cacheData = try jsonDecoder.decode([GeoOffersTrackingEvent].self, from: jsonData)
            return cacheData
        } catch {
            print("DiskCache.load().Failed to load \(savePath): \(error)")
        }
        return []
    }
}
