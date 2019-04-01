//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public protocol GeoOffersOffersCacheDelegate: class {
    func offersUpdated()
}

class GeoOffersOffersCache {
    private var cache: GeoOffersCache
    private let trackingCache: GeoOffersTrackingCache

    weak var delegate: GeoOffersOffersCacheDelegate?

    init(
        cache: GeoOffersCache,
        trackingCache: GeoOffersTrackingCache
    ) {
        self.cache = cache
        self.trackingCache = trackingCache
    }
    
    func appendDeliveredSchedules(_ deliveredSchedules: [GeoOffersDeliveredSchedule]) {
        let now = Date()
        for offer in deliveredSchedules {
            let key = GeoOffersPendingOffer.generateKey(scheduleID: offer.scheduleID, scheduleDeviceID: offer.scheduleDeviceID)
            if cache.cacheData.offers[key] == nil {
                let deliveredOffer = GeoOffersPendingOffer(
                    scheduleID: offer.scheduleID,
                    scheduleDeviceID: offer.scheduleDeviceID,
                    createdDate: now)
                cache.cacheData.offers[key] = deliveredOffer
            }
            cache.cacheData.pendingOffers.removeValue(forKey: key)
        }
    }
    
    func pendingoffer(identifier: String) -> GeoOffersPendingOffer? {
        return cache.cacheData.pendingOffers[identifier]
    }
    
    func promotePendingOffer(identifier: String) {
        guard let pendingOffer = cache.cacheData.pendingOffers.removeValue(forKey: identifier) else { return }
        cache.cacheData.offers[identifier] = pendingOffer
    }
    
    func filterPendingOrOffered(from regions:[GeoOffersGeoFence]) -> [GeoOffersGeoFence] {
        let notPending = regions.compactMap { cache.cacheData.pendingOffers[$0.key] == nil ? $0 : nil }
        return notPending.compactMap { cache.cacheData.offers[$0.key] == nil ? $0 : nil }
    }

    func offers() -> [GeoOffersPendingOffer] {
        let offers = cache.cacheData.offers.reduce([]) { result, keyValuePair in
            result + [keyValuePair.value]
        }
        return offers
    }

    func addPendingOffer(region: GeoOffersGeoFence) {
        let key = region.key
        guard cache.cacheData.pendingOffers[key] == nil, cache.cacheData.offers[key] == nil else { return }
        let offer = GeoOffersPendingOffer(
            scheduleID: region.scheduleID,
            scheduleDeviceID: region.scheduleDeviceID,
            latitude: region.latitude,
            longitude: region.longitude,
            notificationDwellDelay: region.notificationDwellDelaySeconds,
            createdDate: Date())
        if region.notificationDwellDelaySeconds <= 0 {
            cache.cacheData.offers[key] = offer
            if let event = buildOfferDeliveredEvent(offer) {
                trackingCache.add([event])
            }
            delegate?.offersUpdated()
        } else {
            cache.cacheData.pendingOffers[key] = offer
        }
        cache.cacheUpdated()
    }

    func removePendingOffer(identifier: String) {
        cache.cacheData.pendingOffers.removeValue(forKey: identifier)
        cache.cacheUpdated()
    }

    private func buildOfferDeliveredEvent(_ offer: GeoOffersPendingOffer) -> GeoOffersTrackingEvent? {
        let event = GeoOffersTrackingEvent.event(with: .offerDelivered, scheduleID: offer.scheduleID, scheduleDeviceID: offer.scheduleDeviceID, latitude: offer.latitude, longitude: offer.longitude)
        return event
    }
}
