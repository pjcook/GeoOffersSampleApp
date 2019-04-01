//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersWebViewCache {
    private let cache: GeoOffersCache
    private let listingCache: GeoOffersListingCache
    private let offersCache: GeoOffersOffersCache

    init(cache: GeoOffersCache, listingCache: GeoOffersListingCache, offersCache: GeoOffersOffersCache) {
        self.cache = cache
        self.listingCache = listingCache
        self.offersCache = offersCache
    }

    func buildCouponRequestJson(scheduleID: Int) -> String {
        guard let listing = cache.cacheData.listing else { return "{}" }
        var possibleOffer: GeoOffersOffer?
        for campaign in listing.campaigns.values {
            if campaign.offer.scheduleId == scheduleID {
                possibleOffer = campaign.offer
                break
            }
        }
        guard let offer = possibleOffer else { return "{}" }
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(offer)
            let json = String(data: jsonData, encoding: .utf8)
            return json ?? "{}"
        } catch {
            geoOffersLog("\(error)")
            return "{}"
        }
    }

    func buildListingRequestJson() -> String {
        let timestamp = Date().unixTimeIntervalSince1970
        guard let listing = updateCampaignTimestamps(timestamp: timestamp) else { return "{}" }

        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(listing)
            let json = String(data: jsonData, encoding: .utf8)
            return json ?? "{}"
        } catch {
            geoOffersLog("\(error)")
            return "{}"
        }
    }

    func buildAlreadyDeliveredOfferJson() -> String {
        let scheduleIds = deliveredScheduleIDs()
        var items = [String]()
        for id in scheduleIds {
            items.append("\"\(id)\":true")
        }
        let itemsString = items.joined(separator: ", ")
        return itemsString
    }

    func buildAlreadyDeliveredOfferIdTimestampJson() -> String {
        let scheduleIds = deliveredScheduleIDs()
        var items = [String]()
        for id in scheduleIds {
            if let campaign = listingCache.campaign(by: id) {
                let timestamp = campaign.offer.deliveredToAppTimestampSeconds ?? Date().unixTimeIntervalSince1970
                items.append("\"\(id)\":\(timestamp)")
            }
        }
        let itemsString = items.joined(separator: ", ")
        return itemsString
    }
}

extension GeoOffersWebViewCache {
    private func updateCampaignTimestamps(timestamp: Double) -> GeoOffersListing? {
        guard var listing = cache.cacheData.listing else { return nil }
        var hashes = [String]()
        let campaigns = listing.campaigns
        for campaign in campaigns.values {
            if campaign.offer.countdownToExpiryStartedTimestampMsOrNull == nil {
                var updatableCampaign = campaign
                updatableCampaign.offer.countdownToExpiryStartedTimestampMsOrNull = timestamp
                listing.campaigns[String(updatableCampaign.campaignId)] = updatableCampaign
                if let hash = updatableCampaign.offer.clientCouponHash {
                    hashes.append(hash)
                }
            }
        }
        
        if hashes.count > 0 {
            cache.cacheData.listing = listing
            cache.cacheUpdated()
        }
        return listing
    }

    private func deliveredScheduleIDs() -> Set<Int> {
        let offers = offersCache.offers()
        var scheduleIds: Set<Int> = []
        for offer in offers {
            scheduleIds.insert(offer.scheduleID)
        }
        return scheduleIds
    }
}
