//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersPushNotificationCache {
    private var cache: GeoOffersCache
    private let deleteMessagesAfterSeconds: Double = 60 * 60 * 24 * 2

    init(cache: GeoOffersCache) {
        self.cache = cache
    }

    func add(_ message: GeoOffersPushData) {
        cache.cacheData.pushNotificationSplitMessages.append(message)
        cache.cacheUpdated()
    }

    func count(_ messageID: String) -> Int {
        return messages(messageID).count
    }

    func messages(_ messageID: String) -> [GeoOffersPushData] {
        return cache.cacheData.pushNotificationSplitMessages.filter { $0.messageID == messageID }
    }

    func remove(_ messageID: String) {
        cache.cacheData.pushNotificationSplitMessages.removeAll(where: { $0.messageID == messageID })
        cache.cacheUpdated()
    }

    func cleanUpMessages() {
        cache.cacheData.pushNotificationSplitMessages.removeAll(where: {
            abs(Date(timeIntervalSince1970: $0.timestamp).timeIntervalSinceNow) > deleteMessagesAfterSeconds
        })
        cache.cacheUpdated()
    }

    func updateCache(pushData: GeoOffersPushNotificationDataUpdate) {
        guard var listing = cache.cacheData.listing else { return }

        // Update regions
        var updatedRegions = listing.regions
        for region in pushData.regions {
            if var regionsByScheduleID = updatedRegions[String(region.scheduleID)] {
                regionsByScheduleID.removeAll(where: { $0.scheduleID == region.scheduleID && $0.scheduleDeviceID == region.scheduleDeviceID })
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
