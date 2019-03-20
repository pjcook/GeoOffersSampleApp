//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersCountdownsStarted: Codable {
    let timezone: String
    let timestamp: Double
    let hashes: [String]

    enum CodingKeys: String, CodingKey {
        case timezone = "endUserTimezone"
        case timestamp = "countdownToExpiryStartedTimestampMs"
        case hashes = "countdownToExpiryStartedOnClientCouponHashes"
    }
}

struct GeoOffersDeleteSchedule: Codable {
    let scheduleID: Int
    let deviceID: String

    enum CodingKeys: String, CodingKey {
        case scheduleID = "offerScheduleId"
        case deviceID = "endUserUid"
    }
}

struct GeoOffersChangePushToken: Codable {
    let oldToken: String
    let newToken: String

    enum CodingKeys: String, CodingKey {
        case oldToken = "oldPushToken"
        case newToken = "newPushToken"
    }
}

struct GeoOffersPushRegistration: Codable {
    let pushToken: String
    let clientID: Int
    let deviceID: String
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case pushToken
        case clientID = "clientId"
        case deviceID = "deviceUid"
        case latitude
        case longitude
    }
}

struct GeoOffersWebViewLoad: Codable {
    let regCode: String
    let deviceID: String
    let timezone: String
    let selectedCategoryTabBackgroundColor: String
    let scheduleIDs: [Int]
    let scheduleDeviceIDs: [String]
    let correspondingDeviceUidsByScheduleId: [String: [String]]
    let correspondingScheduleIdsByDeviceUid: [String: [Int]]
    let deliveredToAppTimestampSecondsByScheduleId: [String: Double]

    enum CodingKeys: String, CodingKey {
        case regCode
        case deviceID = "endUserUid"
        case timezone
        case selectedCategoryTabBackgroundColor
        case scheduleIDs = "scheduleIds"
        case scheduleDeviceIDs = "deviceUids"
        case correspondingDeviceUidsByScheduleId
        case correspondingScheduleIdsByDeviceUid
        case deliveredToAppTimestampSecondsByScheduleId
    }
}
