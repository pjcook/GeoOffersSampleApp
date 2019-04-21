//  Copyright © 2019 Software101. All rights reserved.

import Foundation

protocol CacheStorage {
    associatedtype CacheData: Codable
    var cacheData: CacheData? { get set }
    func save()
    func cacheUpdated()
}

protocol Cache {
    associatedtype CacheData: Codable
    var cacheData: CacheData { get }
    func clearCache()
    func cacheUpdated()
    func save()
}

