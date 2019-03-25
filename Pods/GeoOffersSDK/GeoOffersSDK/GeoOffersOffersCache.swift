//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public protocol GeoOffersOffersCacheDelegate: class {
    func offersUpdated()
}

class GeoOffersOffersCache {
    private var pendingOffersTimer: Timer?
    private var cache: GeoOffersCache
    private let apiService: GeoOffersAPIService
    private var fencesCache: GeoOffersGeoFencesCache
    
    weak var delegate: GeoOffersOffersCacheDelegate?
    
    init(
        cache: GeoOffersCache,
        fencesCache: GeoOffersGeoFencesCache,
        apiService: GeoOffersAPIService
        ) {
        self.cache = cache
        self.fencesCache = fencesCache
        self.apiService = apiService
    }
    
    deinit {
        pendingOffersTimer?.invalidate()
    }
    
    func offers() -> [GeoOffersPendingOffer] {
        let offers = cache.cacheData.offers.reduce([]) { result, keyValuePair in
            result + [keyValuePair.value]
        }
        return offers
    }
    
    func addPendingOffer(
        scheduleID: Int,
        scheduleDeviceID: String,
        latitude: Double,
        longitude: Double,
        notificationDwellDelayMs: Double
        ) {
        let key = GeoOffersPendingOffer.generateKey(scheduleID: scheduleID, scheduleDeviceID: scheduleDeviceID)
        guard cache.cacheData.pendingOffers[key] == nil, cache.cacheData.offers[key] == nil else { return }
        let offer = GeoOffersPendingOffer(scheduleID: scheduleID, scheduleDeviceID: scheduleDeviceID, latitude: latitude, longitude: longitude, notificationDwellDelay: notificationDwellDelayMs / 1000, createdDate: Date())
        if notificationDwellDelayMs <= 0 {
            cache.cacheData.offers[key] = offer
            if let event = buildOfferDeliveredEvent(offer) {
                apiService.track(events: [event])
            }
            delegate?.offersUpdated()
        } else {
            cache.cacheData.pendingOffers[key] = offer
        }
        cache.cacheUpdated()
        schedulePendingOfferTimeIfRequired()
    }
    
    func removePendingOffer(identifier: String) {
        cache.cacheData.pendingOffers.removeValue(forKey: identifier)
        cache.cacheUpdated()
    }
    
    func hasPendingOffers() -> Bool {
        return !cache.cacheData.pendingOffers.isEmpty
    }
    
    func hasOffers() -> Bool {
        return !cache.cacheData.offers.isEmpty
    }
    
    func pendingOffer(_ identifier: String) -> GeoOffersPendingOffer? {
        return cache.cacheData.pendingOffers.first(where: { $0.value.key == identifier })?.value
    }
    
    func clearPendingOffers() {
        cache.cacheData.pendingOffers.removeAll()
        cache.cacheUpdated()
    }
    
    private func buildOfferDeliveredEvent(_ offer: GeoOffersPendingOffer) -> GeoOffersTrackingEvent? {
        let event = GeoOffersTrackingEvent.event(with: .offerDelivered, scheduleID: offer.scheduleID, scheduleDeviceID: offer.scheduleDeviceID, latitude: offer.latitude, longitude: offer.longitude)
        return event
    }
    
    private func startPendingOffersTimer() {
        pendingOffersTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.queueRefreshPendingOffers()
        }
        pendingOffersTimer = timer
    }
    
    private var refreshPendingOffersInProgress = false
    private func queueRefreshPendingOffers() {
        guard !refreshPendingOffersInProgress else { return }
        refreshPendingOffersInProgress = true
        self.refreshPendingOffers()
    }
    
    private func schedulePendingOfferTimeIfRequired() {
        if !cache.cacheData.pendingOffers.isEmpty {
            startPendingOffersTimer()
        }
    }
    
    func refreshPendingOffers() {
        var newOffers = [GeoOffersPendingOffer]()
        let pendingOffers = cache.cacheData.pendingOffers.values
        for offer in pendingOffers {
            if abs(offer.createdDate.timeIntervalSinceNow) >= offer.notificationDwellDelay {
                newOffers.append(offer)
            }
        }
        
        guard !newOffers.isEmpty else { return }
        var events = [GeoOffersTrackingEvent]()
        for offer in newOffers {
            let key = GeoOffersPendingOffer.generateKey(scheduleID: offer.scheduleID, scheduleDeviceID: offer.scheduleDeviceID)
            cache.cacheData.pendingOffers.removeValue(forKey: key)
            cache.cacheData.offers[key] = offer
            if let event = buildOfferDeliveredEvent(offer) {
                events.append(event)
            }
        }
        if !events.isEmpty {
            apiService.track(events: events)
            cache.cacheUpdated()
            delegate?.offersUpdated()
        }
        refreshPendingOffersInProgress = false
        schedulePendingOfferTimeIfRequired()
    }
}
