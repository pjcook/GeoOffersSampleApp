//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public class GeoOffersWebViewCache {
    private let cache: GeoOffersCache
    private let listingCache: GeoOffersListingCache
    private let offersCache: GeoOffersOffersCache
    public var startCountdowns: (([String]) -> Void)?

    public init(cache: GeoOffersCache, listingCache: GeoOffersListingCache, offersCache: GeoOffersOffersCache) {
        self.cache = cache
        self.listingCache = listingCache
        self.offersCache = offersCache
    }
    
    func offer(scheduleID: ScheduleID) -> GeoOffersOffer? {
        guard let listing = cache.cacheData.listing else { return nil }
        var possibleOffer: GeoOffersOffer?
        for campaign in listing.campaigns.values {
            if campaign.offer.scheduleId == scheduleID {
                possibleOffer = campaign.offer
                break
            }
        }
        return possibleOffer
    }

    func buildCouponRequestJson(offer: GeoOffersOffer?) -> String {
        guard let offer = offer else { return "{}" }
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

    public func buildListingRequestJson() -> String {
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

    public func buildAlreadyDeliveredOfferJson() -> String {
        let offers = offersCache.offers()
        var items = [String]()
        for offer in offers {
            items.append("\"\(offer.scheduleID)\":true")
        }
        let itemsString = items.joined(separator: ", ")
        return itemsString
    }

    public func buildAlreadyDeliveredOfferIdTimestampJson() -> String {
        let offers = offersCache.offers()
        var items = [String]()
        for offer in offers {
            let timestamp = offersCache.campaign(by: offer.scheduleID)?.offer.deliveredToAppTimestampSeconds ?? Date().unixTimeIntervalSince1970
            items.append("\"\(offer.scheduleID)\":\(timestamp)")
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
            if campaign.offer.countdownToExpiryStartedTimestampMsOrNull == nil, campaign.offer.countdownToExpiryDurationMsOrNull != nil {
                var updatableCampaign = campaign
                updatableCampaign.offer.countdownToExpiryStartedTimestampMsOrNull = timestamp
                listing.campaigns[String(updatableCampaign.campaignId)] = updatableCampaign
                if let hash = updatableCampaign.offer.clientCouponHash {
                    hashes.append(hash)
                }
                // update api with started timestamp
            }
        }

        if hashes.count > 0 {
            cache.cacheData.listing = listing
            cache.cacheUpdated()
            startCountdowns?(hashes)
        }
        return listing
    }
}
