//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation

class GeoOffersDataProcessor {
    private let offersCache: GeoOffersOffersCache
    private let listingCache: GeoOffersListingCache
    private let regionCache: GeoOffersRegionCache
    private let notificationService: GeoOffersNotificationServiceProtocol
    private let apiService: GeoOffersAPIServiceProtocol

    init(
        offersCache: GeoOffersOffersCache,
        listingCache: GeoOffersListingCache,
        regionCache: GeoOffersRegionCache,
        notificationService: GeoOffersNotificationServiceProtocol,
        apiService: GeoOffersAPIServiceProtocol
    ) {
        self.offersCache = offersCache
        self.listingCache = listingCache
        self.regionCache = regionCache
        self.notificationService = notificationService
        self.apiService = apiService
    }
    
    // Process listing at location
   func process(at currentLocation: CLLocationCoordinate2D) -> [GeoOffersGeoFence] {
        let regions = listingCache.regions(at: currentLocation)
        
        processEnterExitRegion(regions)
        
        let now = Date()
        let regionsWithValidSchedule = regions.compactMap { listingCache.hasValidSchedule(by: $0.scheduleID, date: now) ? $0 : nil }
        
        let nonDeliveredRegions = offersCache.filterPendingOrOffered(from: regionsWithValidSchedule)
        nonDeliveredRegions.forEach {
            sendNotification(region: $0)
            offersCache.addPendingOffer(region: $0)
        }
        
        let dwelledRegions = regionCache.all().compactMap { abs($0.enterRegion.timeIntervalSinceNow) > $0.region.notificationDwellDelaySeconds ? $0 : nil }
        dwelledRegions.forEach {
            sendNotification(region: $0.region)
            offersCache.addPendingOffer(region: $0.region)
            regionCache.remove($0.region)
        }
        
        return listingCache.regions(notAt: currentLocation)
    }
    
    private func processEnterExitRegion(_ regions: [GeoOffersGeoFence]) {
        let regionsToEnter = regions.compactMap { regionCache.exists($0) == nil ? $0 : nil }

        let regionsToExit = regionCache.all().compactMap { current in
            regions.first(where: { $0.key == current.region.key }) == nil ? current : nil
        }

        notifyEnterRegions(regionsToEnter)
        notifyExitRegions(regionsToExit)
    }
    
    private func notifyEnterRegions(_ regions: [GeoOffersGeoFence]) {
        for region in regions {
            trackEntry(region: region)
            regionCache.add(region)
        }
    }
    
    private func notifyExitRegions(_ regions: [GeoOffersRegionCacheItem]) {
        for region in regions {
            trackExit(region: region.region)
            regionCache.remove(region.region)
            if let pendingOffer = offersCache.pendingoffer(identifier: region.region.key) {
                if abs(pendingOffer.createdDate.timeIntervalSinceNow) > pendingOffer.notificationDwellDelay {
                    offersCache.promotePendingOffer(identifier: region.region.key)
                    sendNotification(region: region.region)
                    offersCache.addPendingOffer(region: region.region)
                }
            offersCache.removePendingOffer(identifier: region.region.key)
            }
        }
    }
    
    private func trackEntry(region: GeoOffersGeoFence) {
        let event = GeoOffersTrackingEvent.event(with: .geoFenceEntry, region: region)
        apiService.track(event: event)
    }
    
    private func trackExit(region: GeoOffersGeoFence) {
        let event = GeoOffersTrackingEvent.event(with: .regionDwellTime, region: region)
        apiService.track(event: event)
        notificationService.removeNotification(with: region.key)
    }

    private func sendNotification(region: GeoOffersGeoFence) {
        guard !region.doesNotNotify else { return }
        
        notificationService.sendNotification(title: region.notificationTitle, subtitle: region.notificationMessage, delaySeconds: region.notificationDeliveryDelaySeconds, identifier: region.key, isSilent: region.notifiesSilently)
    }
}
