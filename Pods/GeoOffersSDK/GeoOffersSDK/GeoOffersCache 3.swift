//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public typealias ScheduleID = Int

class GeoOffersCacheData: Codable {
    var listing: GeoOffersListing?
    var pushNotificationSplitMessages: [GeoOffersPushData] = []
    var trackingEvents: [GeoOffersTrackingEvent] = []
    var pendingOffers: [ScheduleID: GeoOffersCacheItem] = [:]
    var offers: [ScheduleID: GeoOffersCachedOffer] = [:]
    var pendingNotifications: [ScheduleID: GeoOffersCacheItem] = [:]
    var enteredRegions: [ScheduleID: GeoOffersCacheItem] = [:]
}

public class GeoOffersCacheStorage: CacheStorage {
    var cacheData: GeoOffersCacheData?
    func save() {}
    func cacheUpdated() {}
}

public class GeoOffersDiskCacheStorage: GeoOffersCacheStorage {
    private var diskCache: DiskCache<GeoOffersCacheData>
    override var cacheData: GeoOffersCacheData? {
        didSet {
            diskCache.cacheData = cacheData ?? GeoOffersCacheData()
            diskCache.cacheUpdated()
        }
    }

    public override init() {
        diskCache = DiskCache<GeoOffersCacheData>(filename: "GeoOffersCache.data", emptyData: GeoOffersCacheData())
        super.init()
        cacheData = diskCache.cacheData
    }

    override func save() {
        diskCache.save()
    }
}

public class GeoOffersCache: Cache {
    private(set) var cacheData: GeoOffersCacheData
    private let storage: GeoOffersCacheStorage

    public init(storage: GeoOffersCacheStorage) {
        self.storage = storage
        cacheData = GeoOffersCacheData()
        guard let loadedData = storage.cacheData else { return }
        cacheData = loadedData
    }

    func save() {
        storage.save()
    }

    func clearCache() {
        cacheData = GeoOffersCacheData()
        cacheUpdated()
    }

    func cacheUpdated() {
        storage.cacheData = cacheData
        storage.save()
    }
}
