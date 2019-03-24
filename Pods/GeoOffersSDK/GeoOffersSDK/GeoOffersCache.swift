//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

class GeoOffersCacheData: Codable {
    var listing: GeoOffersListing?
    var pendingOffers: [String: GeoOffersPendingOffer] = [:]
    var offers: [String: GeoOffersPendingOffer] = [:]
    var dataUpdateMessages: [GeoOffersPushData] = []
}

private let geoOffersCacheSaveQueue = DispatchQueue(label: "GeoOffersCacheServiceDefault.Queue")

class GeoOffersCache {
    private(set) var cacheData = GeoOffersCacheData()
    private lazy var savePath: String = {
        do {
            return try fileManager.documentPath(for: "GeoOffersCache.data")
        } catch {
            geoOffersLog("\(error)")
            return ""
        }
    }()
    private let fileManager: FileManager
    private var saveTimer: Timer?
    private var hasPendingChanges = false
    private let shouldCacheToDisk: Bool
    
    init(
        fileManager: FileManager = FileManager.default,
        savePeriodSeconds: TimeInterval = 30,
        shouldCacheToDisk: Bool = true
    ) {
        self.fileManager = fileManager
        self.shouldCacheToDisk = shouldCacheToDisk
        load()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.save()
        }
        
        setupSaveTimer(savePeriodSeconds: savePeriodSeconds)
    }
    
    func clearCache() {
        cacheData = GeoOffersCacheData()
        cacheUpdated()
    }
    
    func cacheUpdated() {
        hasPendingChanges = true
    }
    
    private func setupSaveTimer(savePeriodSeconds: TimeInterval) {
        guard shouldCacheToDisk else { return }
        let saveTimer = Timer.scheduledTimer(withTimeInterval: savePeriodSeconds, repeats: true) { _ in
            guard self.hasPendingChanges else { return }
            self.save()
        }
        self.saveTimer = saveTimer
    }
    
    deinit {
        saveTimer?.invalidate()
        nonQueuedSave()
    }
    
    private func load() {
        guard shouldCacheToDisk, fileManager.fileExists(atPath: savePath) else { return }
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
        guard shouldCacheToDisk else { return }
        hasPendingChanges = false
        geoOffersCacheSaveQueue.sync {
            self.nonQueuedSave()
        }
    }
    
    private func nonQueuedSave() {
        guard shouldCacheToDisk else { return }
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
