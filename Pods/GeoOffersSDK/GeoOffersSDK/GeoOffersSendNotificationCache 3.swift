//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public class GeoOffersSendNotificationCache {
    private var cache: GeoOffersCache

    public init(cache: GeoOffersCache) {
        self.cache = cache
    }

    func add(_ region: GeoOffersGeoFence) {
        cache.cacheData.pendingNotifications[region.scheduleID] = GeoOffersCacheItem(region: region)
        cache.cacheUpdated()
    }

    func remove(_ scheduleID: ScheduleID) {
        cache.cacheData.pendingNotifications.removeValue(forKey: scheduleID)
        cache.cacheUpdated()
    }

    func pendingNotifications() -> [GeoOffersCacheItem] {
        return cache.cacheData.pendingNotifications.reduce([]) { $0 + [$1.value] }
    }
}
