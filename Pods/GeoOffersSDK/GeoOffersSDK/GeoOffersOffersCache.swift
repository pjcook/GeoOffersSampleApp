//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public protocol GeoOffersOffersCacheDelegate: class {
    func offersUpdated()
}

struct GeoOffersCachedOffer: Codable {
    let scheduleID: ScheduleID
    let timestamp: Double
}

public class GeoOffersOffersCache {
    private var cache: GeoOffersCache

    public weak var delegate: GeoOffersOffersCacheDelegate?

    public init(cache: GeoOffersCache) {
        self.cache = cache
    }

    func appendDeliveredSchedules(_ deliveredSchedules: [GeoOffersDeliveredSchedule]) {
        deliveredSchedules.forEach {
            cache.cacheData.pendingOffers.removeValue(forKey: $0.scheduleID)
            let timestamp = campaign(by: $0.scheduleID)?.offer.deliveredToAppTimestampSeconds ?? Date().unixTimeIntervalSince1970
            cache.cacheData.offers[$0.scheduleID] = GeoOffersCachedOffer(scheduleID: $0.scheduleID, timestamp: timestamp)
        }
        cache.cacheUpdated()
        delegate?.offersUpdated()
    }

    func pendingOffers() -> [GeoOffersCacheItem] {
        return cache.cacheData.pendingOffers.reduce([]) { $0 + [$1.value] }
    }

    func hasOfferAlready(_ scheduleID: ScheduleID) -> Bool {
        return cache.cacheData.offers[scheduleID] != nil
    }

    func addPendingOffer(_ region: GeoOffersGeoFence) {
        guard !hasOfferAlready(region.scheduleID) else { return }
        cache.cacheData.pendingOffers[region.scheduleID] = GeoOffersCacheItem(region: region)
        cache.cacheUpdated()
    }

    func addOffer(_ scheduleID: ScheduleID) {
        cache.cacheData.pendingOffers.removeValue(forKey: scheduleID)
        cache.cacheData.offers[scheduleID] = GeoOffersCachedOffer(scheduleID: scheduleID, timestamp: Date().unixTimeIntervalSince1970)
        cache.cacheUpdated()
        delegate?.offersUpdated()
    }

    func offers() -> [GeoOffersCachedOffer] {
        return cache.cacheData.offers.reduce([]) { $0 + [$1.value] }
    }

    func campaign(by scheduleID: ScheduleID) -> GeoOffersCampaign? {
        guard let listing = cache.cacheData.listing else { return nil }
        return listing.campaigns.first(where: { $1.offer.scheduleId == scheduleID })?.value
    }
}
