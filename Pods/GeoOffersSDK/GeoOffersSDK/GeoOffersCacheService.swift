//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import Foundation

struct GeoOffersPendingOffer: Codable {
    let scheduleID: Int
    let scheduleDeviceID: String
    let notificationDwellDelay: TimeInterval
    let createdDate: Date
    var key: String {
        return "\(scheduleID)_\(scheduleDeviceID)"
    }

    static func generateKey(scheduleID: Int, scheduleDeviceID: String) -> String {
        return "\(scheduleID)_\(scheduleDeviceID)"
    }
}

protocol GeoOffersCacheService {
    func replaceCache(_ geoFenceData: GeoOffersListing)
    func updateCache(pushData: GeoOffersPushNotificationDataUpdate)
    func fencesNear(latitude: Double, longitude: Double, maximumNumberOfRegionsToReturn: Int, completionHandler: @escaping ([GeoOffersGeoFence]) -> Void)
    func schedules(for scheduleID: Int, scheduleDeviceID: String) -> [GeoOffersSchedule]
    func deliveredSchedule(for scheduleID: Int, scheduleDeviceID: String) -> Bool
    func clearCache()
    func region(with identifier: String) -> [GeoOffersGeoFence]
    func addPendingOffer(scheduleID: Int, scheduleDeviceID: String, notificationDwellDelayMs: Double)
    func removePendingOffer(identifier: String)
    func refreshPendingOffers()
    func hasPendingOffers() -> Bool
    func hasOffers() -> Bool
    func pendingOffer(_ identifier: String) -> GeoOffersPendingOffer?
    func clearPendingOffers()

    func regions() -> [GeoOffersGeoFence]
    func schedules() -> [GeoOffersSchedule]
    func deliveredSchedules() -> [GeoOffersDeliveredSchedule]
    func offers() -> [GeoOffersPendingOffer]

    func add(_ message: GeoOffersPushData)
    func count(_ messageID: String) -> Int
    func messages(_ messageID: String) -> [GeoOffersPushData]
    func remove(_ messageID: String)
    func removeAllPushMessages()

    func buildListingRequestJson() -> String
    func buildCouponRequestJson(scheduleID: Int) -> String
    func buildAlreadyDeliveredOfferJson() -> String
}

class GeoOffersCacheData: Codable {
    var listing: GeoOffersListing?
    var pendingOffers: [String: GeoOffersPendingOffer] = [:]
    var offers: [String: GeoOffersPendingOffer] = [:]
    var dataUpdateMessages: [GeoOffersPushData] = []
}

private struct GeoOffersRegionDistance {
    let scheduleDeviceID: String
    let distance: Double
}

private let geoOffersCacheSaveQueue = DispatchQueue(label: "GeoOffersCacheServiceDefault.Queue")

class GeoOffersCacheServiceDefault: GeoOffersCacheService {
    private var cacheData = GeoOffersCacheData()
    private var savePath: String
    private let apiService: GeoOffersAPIService
    private let fileManager: FileManager
    private var pendingOffersTimer: Timer?
    private var saveTimer: Timer?
    private var hasPendingChanges = false

    init(fileManager: FileManager = FileManager.default, apiService: GeoOffersAPIService, skipLoad: Bool = false, savePeriodSeconds: TimeInterval = 30) {
        self.apiService = apiService
        self.fileManager = fileManager
        do {
            savePath = try fileManager.documentPath(for: "GeoOffersCache.data")
        } catch {
            geoOffersLog("\(error)")
            savePath = ""
        }

        if !skipLoad {
            load()

            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
                self.save()
            }

            let saveTimer = Timer.scheduledTimer(withTimeInterval: savePeriodSeconds, repeats: true) { _ in
                guard self.hasPendingChanges else { return }
                self.save()
            }
            self.saveTimer = saveTimer
        }
    }

    deinit {
        pendingOffersTimer?.invalidate()
        saveTimer?.invalidate()
        nonQueuedSave()
    }

    private func startPendingOffersTimer() {
        pendingOffersTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
            self.queueRefreshPendingOffers()
        }
        pendingOffersTimer = timer
    }

    func forcePendingChanges() {
        hasPendingChanges = true
    }

    func buildCouponRequestJson(scheduleID: Int) -> String {
        guard let listing = cacheData.listing else { return "{}" }
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

    private func updateCampaignTimestamps(timestamp: Double) {
        guard var listing = cacheData.listing else { return }
        var hashes = [String]()
        geoOffersCacheSaveQueue.sync {
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
                self.cacheData.listing = listing
            }
        }
    }

    func buildListingRequestJson() -> String {
        guard var listing = cacheData.listing else { return "{}" }
        let campaigns = listing.campaigns
        let timestamp = Date().timeIntervalSinceReferenceDate * 1000
        var needsUpdate = false
        for campaign in campaigns.values {
            if campaign.offer.countdownToExpiryStartedTimestampMsOrNull == nil {
                var updatableCampaign = campaign
                updatableCampaign.offer.countdownToExpiryStartedTimestampMsOrNull = timestamp
                listing.campaigns[String(updatableCampaign.campaignId)] = updatableCampaign
                needsUpdate = true
            }
        }

        if needsUpdate {
            updateCampaignTimestamps(timestamp: timestamp)
        }

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
        let schedules = deliveredSchedules()
        var items = [String]()
        for schedule in schedules {
            items.append("\"\(schedule.scheduleID)\":true")
        }
        let itemsString = items.joined(separator: ", ")
        return itemsString
    }

    func add(_ message: GeoOffersPushData) {
        cacheData.dataUpdateMessages.append(message)
        hasPendingChanges = true
    }

    func count(_ messageID: String) -> Int {
        return messages(messageID).count
    }

    func messages(_ messageID: String) -> [GeoOffersPushData] {
        return cacheData.dataUpdateMessages.filter { $0.messageID == messageID }
    }

    func remove(_ messageID: String) {
        cacheData.dataUpdateMessages.removeAll(where: { $0.messageID == messageID })
        hasPendingChanges = true
    }

    func removeAllPushMessages() {
        cacheData.dataUpdateMessages.removeAll()
        hasPendingChanges = true
    }

    func listing() -> GeoOffersListing? {
        return cacheData.listing
    }

    func regions() -> [GeoOffersGeoFence] {
        guard let listing = cacheData.listing else { return [] }
        let regions = listing.regions.reduce([]) { result, keyValuePair in
            result + keyValuePair.value
        }
        return regions
    }

    func schedules() -> [GeoOffersSchedule] {
        guard let listing = cacheData.listing else { return [] }
        return listing.schedules
    }

    func deliveredSchedules() -> [GeoOffersDeliveredSchedule] {
        guard let listing = cacheData.listing else { return [] }
        return listing.deliveredSchedules
    }

    func offers() -> [GeoOffersPendingOffer] {
        let offers = cacheData.offers.reduce([]) { result, keyValuePair in
            result + [keyValuePair.value]
        }
        return offers
    }

    func clearCache() {
        cacheData = GeoOffersCacheData()
        hasPendingChanges = true
    }

    func region(with identifier: String) -> [GeoOffersGeoFence] {
        let regions = self.regions()
        return regions.filter { $0.scheduleDeviceID == identifier }
    }

    func replaceCache(_ geoFenceData: GeoOffersListing) {
        cacheData.listing = geoFenceData
        hasPendingChanges = true
    }

    func updateCache(pushData: GeoOffersPushNotificationDataUpdate) {
        guard var listing = cacheData.listing else { return }
        geoOffersCacheSaveQueue.sync {
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
            self.cacheData.listing = listing
            self.hasPendingChanges = true
        }
    }

    func fencesNear(
        latitude: Double,
        longitude: Double,
        maximumNumberOfRegionsToReturn: Int = 20,
        completionHandler: @escaping ([GeoOffersGeoFence]) -> Void
    ) {
        guard let listing = cacheData.listing else {
            completionHandler([])
            return
        }
        geoOffersCacheSaveQueue.sync {
            let cachedRegions = listing.regions.reduce([]) { result, keyValuePair in
                result + keyValuePair.value
            }
            guard cachedRegions.count > maximumNumberOfRegionsToReturn else {
                let regions = cachedRegions.map { $0 }
                DispatchQueue.main.async {
                    completionHandler(regions)
                }
                return
            }
            var regionDistances = [GeoOffersRegionDistance]()
            let currentLocation = CLLocation(latitude: latitude, longitude: longitude)
            for region in cachedRegions {
                let regionLocation = CLLocation(latitude: region.latitude, longitude: region.longitude)
                let distance = currentLocation.distance(from: regionLocation)
                let regionDistance = GeoOffersRegionDistance(scheduleDeviceID: region.scheduleDeviceID, distance: distance)
                regionDistances.append(regionDistance)
            }

            let sortedRegions = regionDistances.sorted { a, b -> Bool in
                a.distance < b.distance
            }

            var regions = [GeoOffersGeoFence]()

            for regionDistance in sortedRegions {
                guard regions.count < maximumNumberOfRegionsToReturn else { break }
                if let region = cachedRegions.first(where: { $0.scheduleDeviceID == regionDistance.scheduleDeviceID }) {
                    regions.append(region)
                }
            }

            DispatchQueue.main.async {
                completionHandler(regions)
            }
        }
    }

    func schedules(for scheduleID: Int, scheduleDeviceID: String) -> [GeoOffersSchedule] {
        guard let listing = cacheData.listing else { return [] }
        var schedules = [GeoOffersSchedule]()
        let cachedSchedules = listing.schedules
        for schedule in cachedSchedules {
            if schedule.scheduleID == scheduleID,
                deliveredSchedule(for: scheduleID, scheduleDeviceID: scheduleDeviceID) == false {
                schedules.append(schedule)
            }
        }

        return schedules
    }

    func deliveredSchedule(for scheduleID: Int, scheduleDeviceID: String) -> Bool {
        guard let listing = cacheData.listing else { return false }
        let deliveredSchedules = listing.deliveredSchedules

        for schedule in deliveredSchedules {
            if schedule.scheduleID == scheduleID, schedule.scheduleDeviceID == scheduleDeviceID {
                return true
            }
        }

        return false
    }

    func addPendingOffer(scheduleID: Int, scheduleDeviceID: String, notificationDwellDelayMs: Double) {
        let key = GeoOffersPendingOffer.generateKey(scheduleID: scheduleID, scheduleDeviceID: scheduleDeviceID)
        let offer = GeoOffersPendingOffer(scheduleID: scheduleID, scheduleDeviceID: scheduleDeviceID, notificationDwellDelay: notificationDwellDelayMs / 1000, createdDate: Date())
        if notificationDwellDelayMs <= 0 {
            cacheData.offers[key] = offer
            if let event = buildOfferDeliveredEvent(offer) {
                apiService.track(events: [event])
            }
        } else {
            cacheData.pendingOffers[key] = offer
        }
        hasPendingChanges = true
        schedulePendingOfferTimeIfRequired()
    }

    func removePendingOffer(identifier: String) {
        cacheData.pendingOffers.removeValue(forKey: identifier)
        hasPendingChanges = true
    }

    private var refreshPendingOffersInProgress = false
    private func queueRefreshPendingOffers() {
        guard !refreshPendingOffersInProgress else { return }
        refreshPendingOffersInProgress = true
        geoOffersCacheSaveQueue.async {
            self.refreshPendingOffers()
        }
    }

    private func schedulePendingOfferTimeIfRequired() {
        if !cacheData.pendingOffers.isEmpty {
            startPendingOffersTimer()
        }
    }

    func refreshPendingOffers() {
        var newOffers = [GeoOffersPendingOffer]()
        let pendingOffers = cacheData.pendingOffers.values
        for offer in pendingOffers {
            if abs(offer.createdDate.timeIntervalSinceNow) >= offer.notificationDwellDelay {
                newOffers.append(offer)
            }
        }

        guard !newOffers.isEmpty else { return }
        var events = [GeoOffersTrackingEvent]()
        for offer in newOffers {
            let key = GeoOffersPendingOffer.generateKey(scheduleID: offer.scheduleID, scheduleDeviceID: offer.scheduleDeviceID)
            cacheData.pendingOffers.removeValue(forKey: key)
            cacheData.offers[key] = offer
            if let event = buildOfferDeliveredEvent(offer) {
                events.append(event)
            }
        }
        if !events.isEmpty {
            apiService.track(events: events)
            hasPendingChanges = true
        }
        refreshPendingOffersInProgress = false
        schedulePendingOfferTimeIfRequired()
    }

    private func buildOfferDeliveredEvent(_ offer: GeoOffersPendingOffer) -> GeoOffersTrackingEvent? {
        let regions = region(with: offer.scheduleDeviceID)
        guard let region = regions.first else { return nil }
        let event = GeoOffersTrackingEvent.event(with: .offerDelivered, region: region)
        return event
    }

    func hasPendingOffers() -> Bool {
        return !cacheData.pendingOffers.isEmpty
    }

    func hasOffers() -> Bool {
        return !cacheData.offers.isEmpty
    }

    func pendingOffer(_ identifier: String) -> GeoOffersPendingOffer? {
        return cacheData.pendingOffers.first(where: { $0.value.key == identifier })?.value
    }

    func clearPendingOffers() {
        cacheData.pendingOffers.removeAll()
        hasPendingChanges = true
    }

    private func load() {
        guard fileManager.fileExists(atPath: savePath) else { return }
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: savePath))
            let jsonDecoder = JSONDecoder()
            let cacheData = try jsonDecoder.decode(GeoOffersCacheData.self, from: jsonData)
            self.cacheData = cacheData
            geoOffersLog("GeoOffersCacheService.load().loaded")
        } catch {
            geoOffersLog("GeoOffersCacheService.load().Failed to load GeoOffersCacheData: \(error)")
        }
    }

    func save() {
        hasPendingChanges = false
        geoOffersCacheSaveQueue.sync {
            self.nonQueuedSave()
        }
    }

    private func nonQueuedSave() {
        let cache = cacheData
        let savePath = self.savePath
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(cache)
            try jsonData.write(to: URL(fileURLWithPath: savePath))
            geoOffersLog("GeoOffersCacheService.save().saved")
        } catch {
            geoOffersLog("GeoOffersCacheService.save().Failed to save GeoOffersCacheData: \(error)")
        }
    }
}

enum FileManagerError: Error {
    case missingDocumentDirectory
    case failedToCreateDirectory
}

public extension FileManager {
    func documentPath(for filename: String) throws -> String {
        guard let path = urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileManagerError.missingDocumentDirectory
        }

        if !fileExists(atPath: path.path) {
            do {
                try createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw FileManagerError.failedToCreateDirectory
            }
        }

        return path.appendingPathComponent(filename).path
    }
}
