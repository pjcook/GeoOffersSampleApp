//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersEnteredRegionCache {
    private var cache: GeoOffersCache
    
    init(cache: GeoOffersCache) {
        self.cache = cache
    }
    
    func add(_ region: GeoOffersGeoFence) {
        cache.cacheData.enteredRegions[region.scheduleID] = GeoOffersCacheItem(region: region)
        cache.cacheUpdated()
    }
    
    func remove(_ scheduleID: ScheduleID) {
        cache.cacheData.enteredRegions.removeValue(forKey: scheduleID)
        cache.cacheUpdated()
    }
    
    func all() -> [GeoOffersCacheItem] {
        return cache.cacheData.enteredRegions.reduce([]) { $0 + [$1.value] }
    }
    
    func exists(_ scheduleID: ScheduleID) -> Bool {
        return cache.cacheData.enteredRegions[scheduleID] != nil
    }
}
