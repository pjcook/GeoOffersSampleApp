//  Copyright © 2019 Software101. All rights reserved.

import UIKit

private let diskCacheSaveQueue = DispatchQueue(label: "DiskCache.queue")
class DiskCache<CacheData: Codable>: CacheStorage {
    var cacheData: CacheData
    
    private let savePath: String
    private let fileManager: FileManager
    private var saveTimer: Timer?
    private(set) var hasPendingChanges = false
    private let emptyData: CacheData

    init(filename: String, fileManager: FileManager = FileManager.default, savePeriodSeconds: TimeInterval = 30, emptyData: CacheData) {
        self.fileManager = fileManager
        self.emptyData = emptyData
        cacheData = emptyData
        savePath = try! fileManager.documentPath(for: filename)
        load()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.nonQueuedSave(self.cacheData)
        }

        setupSaveTimer(savePeriodSeconds: savePeriodSeconds)
    }

    deinit {
        saveTimer?.invalidate()
        nonQueuedSave(cacheData)
    }

    func save() {
        diskCacheSaveQueue.sync {
            self.nonQueuedSave(cacheData)
        }
    }
    
    func cacheUpdated() {
        hasPendingChanges = true
    }
}

extension DiskCache {
    private func setupSaveTimer(savePeriodSeconds: TimeInterval) {
        let saveTimer = Timer.scheduledTimer(withTimeInterval: savePeriodSeconds, repeats: true) { _ in
            self.save()
        }
        self.saveTimer = saveTimer
    }

    private func load() {
        geoOffersLog("DiskCache.load:\(savePath)")
        guard fileManager.fileExists(atPath: savePath) else { return }
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: savePath))
            let jsonDecoder = JSONDecoder()
            let cacheData = try jsonDecoder.decode(CacheData.self, from: jsonData)
            self.cacheData = cacheData
        } catch {
            print("DiskCache.load().Failed to load \(savePath): \(error)")
        }
    }

    private func nonQueuedSave(_ data: CacheData) {
        let savePath = self.savePath
        do {
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(data)
            try jsonData.write(to: URL(fileURLWithPath: savePath))
        } catch {
            print("DiskCache.save().Failed to save \(savePath): \(error)")
        }
    }
}
