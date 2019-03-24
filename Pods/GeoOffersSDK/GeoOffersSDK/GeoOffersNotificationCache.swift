//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersNotificationCache {
    private var cache: GeoOffersCache
    
    init(cache: GeoOffersCache) {
        self.cache = cache
    }
    
    func add(_ message: GeoOffersPushData) {
        cache.cacheData.dataUpdateMessages.append(message)
        cache.cacheUpdated()
    }
    
    func count(_ messageID: String) -> Int {
        return messages(messageID).count
    }
    
    func messages(_ messageID: String) -> [GeoOffersPushData] {
        return cache.cacheData.dataUpdateMessages.filter { $0.messageID == messageID }
    }
    
    func remove(_ messageID: String) {
        cache.cacheData.dataUpdateMessages.removeAll(where: { $0.messageID == messageID })
        cache.cacheUpdated()
    }
    
    func removeAllPushMessages() {
        cache.cacheData.dataUpdateMessages.removeAll()
        cache.cacheUpdated()
    }
    
    func updateCache(pushData: GeoOffersPushNotificationDataUpdate) {
        guard var listing = cache.cacheData.listing else { return }
        
        // Update regions
        var updatedRegions = listing.regions
        for region in pushData.regions {
            if var regionsByScheduleID = updatedRegions[String(region.scheduleID)] {
                regionsByScheduleID.removeAll(where: { $0.scheduleDeviceID == region.scheduleDeviceID })
                regionsByScheduleID.append(region)
            } else {
                updatedRegions[String(region.scheduleID)] = [region]
            }
        }
        listing.regions = updatedRegions
        
        // Update schedules
        var updatedSchedules = listing.schedules
        let schedule = pushData.schedule
        updatedSchedules.removeAll(where: { $0.scheduleID == schedule.scheduleID && $0.campaignID == schedule.campaignID
        })
        updatedSchedules.append(schedule)
        listing.schedules = updatedSchedules
        
        // Update campaign
        if let campaign = pushData.campaign {
            listing.campaigns[String(campaign.campaignId)] = campaign
        }
        
        // Update cache
        cache.cacheData.listing = listing
        cache.cacheUpdated()
    }
}
