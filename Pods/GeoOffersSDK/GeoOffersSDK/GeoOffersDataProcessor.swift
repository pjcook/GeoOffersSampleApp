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

    init(
        offersCache: GeoOffersOffersCache,
        listingCache: GeoOffersListingCache,
        sendNotificationCache: GeoOffersSendNotificationCache,
        enteredRegionCache: GeoOffersEnteredRegionCache,
        notificationService: GeoOffersNotificationServiceProtocol,
        apiService: GeoOffersAPIServiceProtocol
    ) {
        self.offersCache = offersCache
        self.listingCache = listingCache
        self.sendNotificationCache = sendNotificationCache
        self.enteredRegionCache = enteredRegionCache
        self.notificationService = notificationService
        self.apiService = apiService
    }

    func process(at currentLocation: CLLocationCoordinate2D) {
        geoOffersDataProcessorQueue.sync {
            checkPendingOffersToSeeIfDwellTimeExpired()
            checkPendingNotificationsToSeeIfDelayTimeExpired()
            processEnteredRegionState(at: currentLocation)
            processRegionEntries(at: currentLocation)
        }
    }

    func regionsToBeMonitored(at _: CLLocationCoordinate2D) -> [GeoOffersGeoFence]? {
        return listingCache.listing()?.regions.reduce([]) { $0 + $1.value }
    }

    private func processRegionEntries(at location: CLLocationCoordinate2D) {
        let regions = listingCache.regions(at: location)
        let now = Date()
        regions.forEach {
            guard
                !enteredRegionCache.exists($0.scheduleID),
                listingCache.hasValidSchedule(by: $0.scheduleID, date: now)
            else { return }
            apiService.track(event: GeoOffersTrackingEvent.event(with: .geoFenceEntry, region: $0))
            enteredRegionCache.add($0)
            processRegionForDwellTime($0)
        }
    }

    private func processRegionForDwellTime(_ region: GeoOffersGeoFence) {
        guard !offersCache.hasOfferAlready(region.scheduleID) else { return }
        if region.notificationDwellDelaySeconds > 0 {
            offersCache.addPendingOffer(region)
        } else {
            checkAndSendNotification(region)
        }
    }

    private func processEnteredRegionState(at location: CLLocationCoordinate2D) {
        let regionsIDs = listingCache.regions(at: location).map { $0.scheduleID }
        let enteredRegions = enteredRegionCache.all()
        enteredRegions.forEach {
            if !regionsIDs.contains($0.region.scheduleID) {
                enteredRegionCache.remove($0.region.scheduleID)
                apiService.track(event: GeoOffersTrackingEvent.event(with: .regionDwellTime, region: $0.region))
            }
        }
    }

    private func checkPendingNotificationsToSeeIfDelayTimeExpired() {
        let pendingNotifications = sendNotificationCache.pendingNotifications()
        pendingNotifications.forEach {
            if abs($0.createdDate.timeIntervalSinceNow) > $0.region.notificationDeliveryDelaySeconds {
                sendNotificationCache.remove($0.region.scheduleID)
                sendNotification($0.region)
            }
        }
    }

    private func checkPendingOffersToSeeIfDwellTimeExpired() {
        let pendingOffers = offersCache.pendingOffers()
        pendingOffers.forEach {
            if abs($0.createdDate.timeIntervalSinceNow) > $0.region.notificationDwellDelaySeconds {
                checkAndSendNotification($0.region)
            }
        }
    }

    private func checkAndSendNotification(_ region: GeoOffersGeoFence) {
        if region.notificationDeliveryDelaySeconds > 0 {
            sendNotificationCache.add(region)
        } else {
            sendNotification(region)
        }
    }

    private func sendNotification(_ region: GeoOffersGeoFence) {
        DispatchQueue.main.async {
            self.notificationService.sendNotification(title: region.notificationTitle, subtitle: region.notificationMessage, delaySeconds: region.notificationDeliveryDelaySeconds, identifier: region.key, isSilent: region.notifiesSilently)
        }

        offersCache.addOffer(region.scheduleID)

        apiService.track(event: GeoOffersTrackingEvent.event(with: .offerDelivered, region: region))
    }
}
