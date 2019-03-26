//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation

class GeoOffersGeoFencesCache {
    private var cache: GeoOffersCache

    init(cache: GeoOffersCache) {
        self.cache = cache
    }

    func regions() -> [GeoOffersGeoFence] {
        guard let listing = cache.cacheData.listing else { return [] }
        let regions = listing.regions.reduce([]) { result, keyValuePair in
            result + keyValuePair.value
        }
        return regions
    }

    func region(with identifier: String) -> [GeoOffersGeoFence] {
        let regions = self.regions()
        return regions.filter { GeoOffersPendingOffer.generateKey(scheduleID: $0.scheduleID, scheduleDeviceID: $0.scheduleDeviceID) == identifier }
    }

    func fencesNear(latitude: Double, longitude: Double) -> [GeoOffersGeoFence] {
        guard let listing = cache.cacheData.listing else { return [] }
        let cachedRegions = listing.regions.reduce([]) { result, keyValuePair in
            result + keyValuePair.value
        }
        let currentLocation = CLLocation(latitude: latitude, longitude: longitude)

        let sortedRegions = cachedRegions.sorted { a, b -> Bool in
            a.location.distance(from: currentLocation) < b.location.distance(from: currentLocation)
        }

        return sortedRegions
    }
}
