//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersTrackingCache {
    private var cache: GeoOffersCache
    private var debugCache: GeoOffersTrackingDebugCache?

    init(cache: GeoOffersCache) {
        self.cache = cache
//        #if DEBUG
        self.debugCache = GeoOffersTrackingDebugCache(filename: "GeoOffersTrackingDebugCache.data", emptyData: [GeoOffersTrackingEvent]())
//        #endif
    }

    func add(_ event: GeoOffersTrackingEvent) {
        debugCache?.add([event])
        guard event.type.shouldSendToServer else { return }
        cache.cacheData.trackingEvents.append(event)
        cache.cacheUpdated()
    }
    
    func add(_ events: [GeoOffersTrackingEvent]) {
        cache.cacheData.trackingEvents += events
        cache.cacheUpdated()
    }

    func hasCachedEvents() -> Bool {
        return !cache.cacheData.trackingEvents.isEmpty
    }

    func popCachedEvents(n: Int = 50) -> [GeoOffersTrackingEvent] {
        var events = [GeoOffersTrackingEvent]()

        while events.count < min(n, cache.cacheData.trackingEvents.count) {
            events.append(cache.cacheData.trackingEvents.removeFirst())
        }
        cache.cacheUpdated()
        return events
    }
}

class GeoOffersTrackingDebugCache: DiskCache<[GeoOffersTrackingEvent]> {
    private let cacheLimit = 5000
    
    func add(_ events: [GeoOffersTrackingEvent]) {
        defer {
            limitCacheSize()
        }
        
        cacheData += events
        self.cacheData = cacheData
        cacheUpdated()
    }
    
    private func limitCacheSize() {
        guard cacheData.count > cacheLimit else { return }
        self.cacheData = Array(cacheData.reversed()[0..<cacheLimit]).reversed()
    }
}
