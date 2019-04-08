//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersTrackingCache {
    private var cache: GeoOffersCache

    init(cache: GeoOffersCache) {
        self.cache = cache
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
