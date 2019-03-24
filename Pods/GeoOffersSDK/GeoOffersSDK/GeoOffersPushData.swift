//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

extension Double {
    static let oneDaySeconds: Double = 60 * 60 * 24
}

struct GeoOffersPushData: Codable {
    let message: String
    let totalParts: Int
    let scheduleID: Int
    let messageIndex: Int
    let messageID: String
    let timestamp: Double
    
    init(message: String, totalParts: Int, scheduleID: Int, messageIndex: Int, messageID: String, timestamp: Double) {
        self.message = message
        self.totalParts = totalParts
        self.scheduleID = scheduleID
        self.messageIndex = messageIndex
        self.messageID = messageID
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case message = "geoRewardsPushMessageJson"
        case totalParts = "splitMessageTotalPortionsCount"
        case scheduleID = "offerScheduleId"
        case messageIndex = "splitMessagePortionIndex"
        case messageID = "splitMessageId"
        case timestamp = "splitOrSingleMessageInitiatedTimestampMs"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        message = try values.decode(String.self, forKey: .message)
        messageID = try values.decode(String.self, forKey: .messageID)
        totalParts = try values.geoValueFromString(.totalParts)
        scheduleID = try values.geoValueFromString(.scheduleID)
        messageIndex = try values.geoValueFromString(.messageIndex)
        timestamp = try values.geoValueFromString(.timestamp)
    }

    var isOutOfDate: Bool {
        return abs((Date().timeIntervalSince1970 * 1000) - timestamp) > Double.oneDaySeconds
    }
}

struct GeoOffersPushNotificationDataUpdate: Codable {
    let type: String
    let scheduleID: Int
    let campaign: GeoOffersCampaign?
    let regions: [GeoOffersGeoFence]
    let schedule: GeoOffersSchedule

    enum CodingKeys: String, CodingKey {
        case type
        case campaign
        case scheduleID = "scheduleId"
        case regions = "geofences"
        case schedule = "offerRun"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        regions = values.geoDecode([GeoOffersGeoFence].self, forKey: .regions) ?? []
        type = try values.decode(String.self, forKey: .type)
        scheduleID = try values.decode(Int.self, forKey: .scheduleID)
        campaign = try values.decodeIfPresent(GeoOffersCampaign.self, forKey: .campaign)
        schedule = try values.decode(GeoOffersSchedule.self, forKey: .schedule)
    }
}
