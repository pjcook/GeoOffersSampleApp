//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation

private let geoOffersDataProcessorQueue = DispatchQueue(label: "GeoOffersDataProcessor.Queue")

class GeoOffersDataProcessor {
    private let offersCache: GeoOffersOffersCache
    private let listingCache: GeoOffersListingCache
    private let sendNotificationCache: GeoOffersSendNotificationCache
    private let enteredRegionCache: GeoOffersEnteredRegionCache
    private let notificationService: GeoOffersNotificationServiceProtocol
    private let apiService: GeoOffersAPIServiceProtocol
    private let trackingCache: GeoOffersTrackingCache

    init(
        offersCache: GeoOffersOffersCache,
        listingCache: GeoOffersListingCache,
        sendNotificationCache: GeoOffersSendNotificationCache,
        enteredRegionCache: GeoOffersEnteredRegionCache,
        notificationService: GeoOffersNotificationServiceProtocol,
        apiService: GeoOffersAPIServiceProtocol,
        trackingCache: GeoOffersTrackingCache
    ) {
        self.offersCache = offersCache
        self.listingCache = listingCache
        self.sendNotificationCache = sendNotificationCache
        self.enteredRegionCache = enteredRegionCache
        self.notificationService = notificationService
        self.apiService = apiService
        self.trackingCache = trackingCache
    }

    func process(at currentLocation: CLLocationCoordinate2D) {
        geoOffersDataProcessorQueue.sync {
            checkPendingOffersToSeeIfDwellTimeExpired(at: currentLocation)
            checkPendingNotificationsToSeeIfDelayTimeExpired(at: currentLocation)
            processEnteredRegionState(at: currentLocation)
            processRegionEntries(at: currentLocation)
            cleanUpEnteredRegions()
        }
    }

    func regionsToBeMonitored(at _: CLLocationCoordinate2D) -> [GeoOffersGeoFence]? {
        return listingCache.listing()?.regions.reduce([]) { $0 + $1.value }
    }

    private func cleanUpEnteredRegions() {
        let enteredRegionScheduleIDs = enteredRegionCache.all().map { $0.region.scheduleID }
        let listingRegions: [GeoOffersGeoFence]? = listingCache.listing()?.regions.reduce([]) { $0 + $1.value }
        guard let regions = listingRegions else { return }
        var listingRegionScheduleIDs: [ScheduleID: Int] = [:]
        regions.forEach { listingRegionScheduleIDs[$0.scheduleID] = 1 }
        for scheduleID in enteredRegionScheduleIDs {
            if listingRegionScheduleIDs[scheduleID] != 1 {
                enteredRegionCache.remove(scheduleID)
            }
        }
    }

    private func processRegionEntries(at location: CLLocationCoordinate2D) {
        let regions = listingCache.regions(at: location)
        let now = Date()
        regions.forEach {
            guard
                !enteredRegionCache.exists($0.scheduleID),
                listingCache.hasValidSchedule(by: $0.scheduleID, date: now)
            else { return }
            track(GeoOffersTrackingEvent.event(with: .geoFenceEntry, region: $0, location: location))
            enteredRegionCache.add($0)
            processRegionForDwellTime($0, location: location)
        }
    }

    private func track(_ event: GeoOffersTrackingEvent) {
        trackingCache.add(event)
        apiService.checkForPendingTrackingEvents()
    }

    private func processRegionForDwellTime(_ region: GeoOffersGeoFence, location: CLLocationCoordinate2D) {
        guard !offersCache.hasOfferAlready(region.scheduleID) else { return }
        if region.notificationDwellDelaySeconds > 0 {
            offersCache.addPendingOffer(region)
        } else {
            checkAndSendNotification(region, location: location)
        }
    }

    private func processEnteredRegionState(at location: CLLocationCoordinate2D) {
        let regionsIDs = listingCache.regions(at: location).map { $0.scheduleID }
        let enteredRegions = enteredRegionCache.all()
        enteredRegions.forEach {
            if !regionsIDs.contains($0.region.scheduleID) {
                enteredRegionCache.remove($0.region.scheduleID)
                track(GeoOffersTrackingEvent.event(with: .geoFenceExit, region: $0.region, location: location))
            }
        }
    }

    private func checkPendingNotificationsToSeeIfDelayTimeExpired(at location: CLLocationCoordinate2D) {
        let pendingNotifications = sendNotificationCache.pendingNotifications()
        pendingNotifications.forEach {
            if abs($0.createdDate.timeIntervalSinceNow) > $0.region.notificationDeliveryDelaySeconds {
                sendNotificationCache.remove($0.region.scheduleID)
                sendNotification($0.region, location: location)
            }
        }
    }

    private func checkPendingOffersToSeeIfDwellTimeExpired(at location: CLLocationCoordinate2D) {
        let pendingOffers = offersCache.pendingOffers()
        pendingOffers.forEach {
            if abs($0.createdDate.timeIntervalSinceNow) > $0.region.notificationDwellDelaySeconds {
                track(GeoOffersTrackingEvent.event(with: .regionDwellTime, region: $0.region, location: location))
                checkAndSendNotification($0.region, location: location)
            }
        }
    }

    private func checkAndSendNotification(_ region: GeoOffersGeoFence, location: CLLocationCoordinate2D) {
        if region.notificationDeliveryDelaySeconds > 0 {
            sendNotificationCache.add(region)
        } else {
            sendNotification(region, location: location)
        }
    }

    private func sendNotification(_ region: GeoOffersGeoFence, location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.notificationService.sendNotification(title: region.notificationTitle, subtitle: region.notificationMessage, delaySeconds: region.notificationDeliveryDelaySeconds, identifier: region.key, isSilent: region.notifiesSilently)
        }

        offersCache.addOffer(region.scheduleID)
        track(GeoOffersTrackingEvent.event(with: .offerDelivered, region: region, location: location))
    }
}
