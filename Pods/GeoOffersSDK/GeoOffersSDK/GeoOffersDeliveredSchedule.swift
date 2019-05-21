//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersDeliveredSchedule: Codable {
    let scheduleID: ScheduleID
    let scheduleDeviceID: String

    enum CodingKeys: String, CodingKey {
        case scheduleID = "rewardScheduleId"
        case scheduleDeviceID = "deviceUid"
    }
}
