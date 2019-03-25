//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation

/*
 Using the current location
 Check each Campaign
 • Ignore if already Delivered
 • Must have a valid schedule
 • Check if currently in a campaign region
 • If above valid process notification details
 */
class GeoOffersDataProcessor {
    private let offersCache: GeoOffersOffersCache
    private let listingCache: GeoOffersListingCache
    private let notificationService: GeoOffersNotificationServiceProtocol
    private let apiService: GeoOffersAPIServiceProtocol
    
    init(
        offersCache: GeoOffersOffersCache,
        listingCache: GeoOffersListingCache,
        notificationService: GeoOffersNotificationServiceProtocol,
        apiService: GeoOffersAPIServiceProtocol
        ) {
        self.offersCache = offersCache
        self.listingCache = listingCache
        self.notificationService = notificationService
        self.apiService = apiService
    }
    
    // Process campaigns and return regions that need monitoring
    func processListing(at coordinates: CLLocationCoordinate2D) -> [GeoOffersGeoFence] {
        guard let listing = listingCache.listing() else { return [] }

        let now = Date()
        var regionsToReturn = [GeoOffersGeoFence]()

        for campaign in listing.campaigns {
            let campaignId = campaign.value.campaignId
            guard
                let scheduleId = campaign.value.offer.scheduleId,
                let deviceUid = campaign.value.offer.deviceUid,
                !isAlreadyDelivered(in: listing, by: scheduleId, and: deviceUid),
                let schedule = findSchedule(in: listing, by: scheduleId, and: campaignId),
                schedule.isValid(for: now)
            else { continue }
            let regions = findRegions(in: listing, by: String(scheduleId), and: deviceUid)
            for region in regions {
                guard process(region: region, at: coordinates) else { continue }
                regionsToReturn.append(region)
            }
        }
        
        return regionsToReturn
    }
    
    // return whether to monitor or not
    private func process(region: GeoOffersGeoFence, at coordinates: CLLocationCoordinate2D) -> Bool {
        let circularRegion = CLCircularRegion(center: region.coordinate, radius: region.radiusKm * 1000, identifier: region.scheduleDeviceID)
        let isInRegion = circularRegion.contains(coordinates)
        guard isInRegion else { return true }
        
        let dwellDelayMs = region.notificationDwellDelayMs
        
        offersCache.addPendingOffer(scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID, latitude: region.latitude, longitude: region.longitude, notificationDwellDelayMs: dwellDelayMs)
        
        trackEntry(region: region)
        sendNotification(region: region)

        return dwellDelayMs > 0
    }
    
    private func trackEntry(region: GeoOffersGeoFence) {
        let event = GeoOffersTrackingEvent.event(with: .geoFenceEntry, region: region)
        apiService.track(event: event)
    }
    
    private func sendNotification(region: GeoOffersGeoFence) {
        guard !region.doesNotNotify else { return }
        
        let identifier = GeoOffersPendingOffer.generateKey(scheduleID: region.scheduleID, scheduleDeviceID: region.scheduleDeviceID)
        notificationService.sendNotification(title: region.notificationTitle, subtitle: region.notificationMessage, delayMs: region.notificationDwellDelayMs, identifier: identifier, isSilent: region.notifiesSilently)
    }
    
    private func isAlreadyDelivered(in listing: GeoOffersListing, by scheduleId: Int, and deviceUid: String) -> Bool {
        let alreadyDelivered = listing.deliveredSchedules.contains { $0.scheduleID == scheduleId && $0.scheduleDeviceID == deviceUid }
        guard !alreadyDelivered else { return true }
        return offersCache.offers().contains { $0.scheduleID == scheduleId && $0.scheduleDeviceID == deviceUid }
    }
    
    private func findSchedule(in listing: GeoOffersListing, by scheduleId: Int, and campaignId: Int) -> GeoOffersSchedule? {
        return listing.schedules.first { $0.scheduleID == scheduleId && $0.campaignID == campaignId }
    }
    
    private func findRegions(in listing: GeoOffersListing, by scheduleId: String, and deviceUid: String?) -> [GeoOffersGeoFence] {
        guard let regions = listing.regions[scheduleId] else { return [] }
        return regions.compactMap { $0.scheduleDeviceID == deviceUid ? $0 : nil }
    }
}
