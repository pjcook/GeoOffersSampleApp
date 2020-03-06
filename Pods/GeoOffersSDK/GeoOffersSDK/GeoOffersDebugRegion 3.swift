//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public struct GeoOffersDebugRegion: Codable {
    public let latitude: Double
    public let longitude: Double
    public let title: String
    public let subtitle: String

    init(region: GeoOffersGeoFence) {
        latitude = region.coordinate.latitude
        longitude = region.coordinate.longitude
        title = "\(region.scheduleID): \(region.notificationTitle)"
        subtitle = "\(latitude), \(longitude), (\(region.radiusMeters))"
    }
}
