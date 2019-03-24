//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersListingCache {
    private var cache: GeoOffersCache
    
    init(cache: GeoOffersCache) {
        self.cache = cache
    }
    
    func deliveredSchedules() -> [GeoOffersDeliveredSchedule] {
        guard let listing = cache.cacheData.listing else { return [] }
        return listing.deliveredSchedules
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
    
    func schedules() -> [GeoOffersSchedule] {
        guard let listing = cache.cacheData.listing else { return [] }
        return listing.schedules
    }
    
    func replaceCache(_ geoFenceData: GeoOffersListing) {
        cache.cacheData.listing = geoFenceData
        cache.cacheUpdated()
    }
    
    func schedules(for scheduleID: Int, scheduleDeviceID: String) -> [GeoOffersSchedule] {
        guard let listing = cache.cacheData.listing else { return [] }
        var schedules = [GeoOffersSchedule]()
        let cachedSchedules = listing.schedules
        for schedule in cachedSchedules {
            if schedule.scheduleID == scheduleID,
                deliveredSchedule(for: scheduleID, scheduleDeviceID: scheduleDeviceID) == false {
                schedules.append(schedule)
            }
        }
        
        return schedules
    }
    
    func deliveredSchedule(for scheduleID: Int, scheduleDeviceID: String) -> Bool {
        guard let listing = cache.cacheData.listing else { return false }
        let deliveredSchedules = listing.deliveredSchedules
        
        for schedule in deliveredSchedules {
            if schedule.scheduleID == scheduleID, schedule.scheduleDeviceID == scheduleDeviceID {
                return true
            }
        }
        
        return false
    }
}
