//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersRegionCacheItem: Codable {
    let region: GeoOffersGeoFence
    let enterRegion: Date
}

class GeoOffersRegionCache {
    private var cache: GeoOffersCache
    
    init(cache: GeoOffersCache) {
        self.cache = cache
    }
    
    func add(_ region: GeoOffersGeoFence) {
        cache.cacheData.regionEntries[region.key] = GeoOffersRegionCacheItem(region: region, enterRegion: Date())
        cache.cacheUpdated()
    }
    
    func remove(_ region: GeoOffersGeoFence) {
        cache.cacheData.regionEntries.removeValue(forKey: region.key)
        cache.cacheUpdated()
    }
    
    func exists(_ region: GeoOffersGeoFence) -> GeoOffersRegionCacheItem? {
        return cache.cacheData.regionEntries[region.key]
    }
    
    func all() -> [GeoOffersRegionCacheItem] {
        return cache.cacheData.regionEntries.reduce([]) { $0 + [$1.value] }
    }
}
