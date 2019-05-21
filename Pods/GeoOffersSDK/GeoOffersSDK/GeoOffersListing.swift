//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersCampaign: Codable {
    let language: String
    let campaignId: Int
    let campaignSize: Int
    let experienceType: String
    let version: String
    let aspectRatio: CGFloat
    var offer: GeoOffersOffer
}

struct GeoOffersListing: Codable {
    let clientID: Int
    let catchmentRadius: Int
    var campaigns: [String: GeoOffersCampaign]
    var regions: [String: [GeoOffersGeoFence]]
    var schedules: [GeoOffersSchedule]
    let scheduleDeviceIDs: [String]
    let campaignID: Int
    var deliveredSchedules: [GeoOffersDeliveredSchedule]
    let timezone: String = TimeZone.current.identifier

    enum CodingKeys: String, CodingKey {
        case clientID = "clientId"
        case catchmentRadius = "catchmentRadiusKmAroundDeviceLocationSent"
        case scheduleDeviceIDs = "matchingDeviceUids"
        case campaignID = "offersNetworkCampaignId"
        case regions = "geofencesByRewardScheduleId"
        case deliveredSchedules = "scheduleIdAndDeviceUidCombinationsAlreadyDelivered"
        case schedules = "offerRuns"
        case campaigns
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        scheduleDeviceIDs = values.geoDecode([String].self, forKey: .scheduleDeviceIDs) ?? []
        regions = values.geoDecode([String: [GeoOffersGeoFence]].self, forKey: .regions) ?? [:]
        // campaigns = values.geoDecode(Dictionary<String,GeoOffersCampaign>.self, forKey: .campaigns) ?? [:]
        campaigns = try values.decode([String: GeoOffersCampaign].self, forKey: .campaigns)
        deliveredSchedules = values.geoDecode([GeoOffersDeliveredSchedule].self, forKey: .deliveredSchedules) ?? []
        schedules = values.geoDecode([GeoOffersSchedule].self, forKey: .schedules) ?? []

        clientID = try values.decode(Int.self, forKey: .clientID)
        campaignID = try values.decode(Int.self, forKey: .campaignID)
        catchmentRadius = try values.decode(Int.self, forKey: .catchmentRadius)
    }
}
