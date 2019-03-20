//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

let geoOffersScheduleDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

struct GeoOffersSchedule: Codable {
    let scheduleID: Int
    let campaignID: Int
    let startDate: Date
    let endDate: Date
    let repeatingSchedule: GeoOffersRepeatingSchedule?

    enum CodingKeys: String, CodingKey {
        case scheduleID = "scheduleId"
        case campaignID = "campaignId"
        case startDate
        case endDate
        case repeatingSchedule
    }

    init(scheduleID: Int, campaignID: Int, startDate: Date, endDate: Date, repeatingSchedule: GeoOffersRepeatingSchedule?) {
        self.scheduleID = scheduleID
        self.campaignID = campaignID
        self.startDate = startDate
        self.endDate = endDate
        self.repeatingSchedule = repeatingSchedule
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        scheduleID = try values.decode(Int.self, forKey: .scheduleID)
        campaignID = try values.decode(Int.self, forKey: .campaignID)
        let startDateString = try values.decode(String.self, forKey: .startDate)
        startDate = geoOffersScheduleDateFormatter.date(from: startDateString)!
        let endDateString = try values.decode(String.self, forKey: .endDate)
        endDate = geoOffersScheduleDateFormatter.date(from: endDateString)!
        repeatingSchedule = try values.decodeIfPresent(GeoOffersRepeatingSchedule.self, forKey: .repeatingSchedule)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleID, forKey: .scheduleID)
        try container.encode(campaignID, forKey: .campaignID)
        let startDateString = geoOffersScheduleDateFormatter.string(from: startDate)
        try container.encode(startDateString, forKey: .startDate)
        let endDateString = geoOffersScheduleDateFormatter.string(from: endDate)
        try container.encode(endDateString, forKey: .endDate)
        try container.encode(repeatingSchedule, forKey: .repeatingSchedule)
    }

    func isValid(for date: Date) -> Bool {
        guard startDate < date, date < endDate else { return false }
        guard let repeatingSchedule = repeatingSchedule else { return true }
        return repeatingSchedule.isValid(for: date)
    }
}

enum GeoOffersRepeatingScheduleType: String, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
}

struct GeoOffersRepeatingScheduleTime: Codable {
    let hours: Int
    let minutes: Int
    let dayOfWeek: Int?
    let dayOfMonth: Int?
    let month: Int?

    enum CodingKeys: String, CodingKey {
        case hours = "hour"
        case minutes = "minute"
        case dayOfWeek
        case dayOfMonth
        case month
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hours = try values.decode(Int.self, forKey: .hours)
        minutes = try values.decode(Int.self, forKey: .minutes)
        dayOfWeek = try values.decodeIfPresent(Int.self, forKey: .dayOfWeek)
        dayOfMonth = try values.decodeIfPresent(Int.self, forKey: .dayOfMonth)
        month = try values.decodeIfPresent(Int.self, forKey: .month)
    }
}

struct GeoOffersRepeatingSchedule: Codable {
    let type: GeoOffersRepeatingScheduleType
    let start: GeoOffersRepeatingScheduleTime
    let end: GeoOffersRepeatingScheduleTime

    func isValid(for date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        guard start.hours <= hour, start.minutes == minute, end.hours >= hour, end.minutes >= minute else { return false }

        switch type {
        case .daily:
            return true
        case .weekly: // 1-7 where 1 == Monday
            let dayOfWeek = calendar.dayOfWeek(date)
            return dayOfWeek == start.dayOfWeek
        case .monthly: // 1-12 where 1 == January
            let dayOfMonth = calendar.component(.day, from: date)
            return dayOfMonth == start.dayOfMonth
        case .yearly: // 1-31 where position is day in month
            let dayOfMonth = calendar.component(.day, from: date)
            let month = calendar.component(.month, from: date)
            return month == start.month && dayOfMonth == start.dayOfMonth
        }
    }
}

extension Calendar {
    func dayOfWeek(_ date: Date) -> Int {
        var dayOfWeek = component(.weekday, from: date) + 1 - (firstWeekday + 1)
        if dayOfWeek <= 0 {
            dayOfWeek += 7
        }
        return dayOfWeek
    }
}
