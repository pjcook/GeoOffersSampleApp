//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersDeliveredSchedule: Codable {
    let scheduleID: Int
    let scheduleDeviceID: String

    enum CodingKeys: String, CodingKey {
        case scheduleID = "rewardScheduleId"
        case scheduleDeviceID = "deviceUid"
    }
}
