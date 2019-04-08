//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation

protocol GeoOffersListingCacheDelegate: class {
    func listingUpdated()
}

class GeoOffersListingCache {
    private var cache: GeoOffersCache
    private var offersCache: GeoOffersOffersCache

    weak var delegate: GeoOffersListingCacheDelegate?

    init(cache: GeoOffersCache, offersCache: GeoOffersOffersCache) {
        self.cache = cache
        self.offersCache = offersCache
    }

    func regions(at location: CLLocationCoordinate2D) -> [GeoOffersGeoFence] {
        guard let regions = cache.cacheData.listing?.regions else { return [] }
        return regions.reduce([]) { $0 + $1.value.compactMap { $0.cirularRegion.contains(location) ? $0 : nil } }
    }

    func regionsNot(at location: CLLocationCoordinate2D) -> [GeoOffersGeoFence] {
        guard let regions = cache.cacheData.listing?.regions else { return [] }
        return regions.reduce([]) { $0 + $1.value.compactMap { $0.cirularRegion.contains(location) ? nil : $0 } }
    }

    func redeemCoupon(campaignId: Int) {
        let key = String(campaignId)
        guard var listing = cache.cacheData.listing, var campaign = listing.campaigns[key]
        else { return }
        campaign.offer.isRedeemed = true
        listing.campaigns[key] = campaign
        cache.cacheData.listing = listing
        cache.cacheUpdated()
        delegate?.listingUpdated()
    }

    func clearCache() {
        cache.clearCache()
    }

    func forcePendingChanges() {
        cache.cacheUpdated()
    }

    func listing() -> GeoOffersListing? {
        return cache.cacheData.listing
    }

    func replaceCache(_ geoFenceData: GeoOffersListing) {
        cache.cacheData.listing = geoFenceData
        offersCache.appendDeliveredSchedules(geoFenceData.deliveredSchedules)
        cache.cacheUpdated()
        delegate?.listingUpdated()
    }

    func hasValidSchedule(by scheduleID: ScheduleID, date: Date) -> Bool {
        guard let schedules = cache.cacheData.listing?.schedules else { return false }
        let schedule = schedules.first {
            $0.scheduleID == scheduleID && $0.isValid(for: date)
        }
        return schedule != nil
    }
}
