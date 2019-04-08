//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersCacheItem: Codable {
    let region: GeoOffersGeoFence
    let createdDate: Date

    init(region: GeoOffersGeoFence) {
        self.region = region
        createdDate = Date()
    }
}
