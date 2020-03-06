//  Copyright © 2019 Zappit. All rights reserved.

import AdSupport
import CoreLocation
import Foundation

public struct GeoOffersConfiguration: GeoOffersConfigurationProtocol {
    public let registrationCode: String
    public let authToken: String
    public let testing: Bool
    public let selectedCategoryTabBackgroundColor: String
    public let minimumRefreshWaitTime: Double // seconds
    public let minimumRefreshDistance: Double // meters
    public let mainAppUsesFirebase: Bool

    public init(
        registrationCode: String,
        authToken: String,
        testing: Bool = false,
        selectedCategoryTabBackgroundColor: String = "#FF0000",
        minimumRefreshWaitTime: Double = 30 * 60,
        minimumDistance: Double = 50,
        mainAppUsesFirebase: Bool = false
    ) {
        self.registrationCode = registrationCode
        self.authToken = authToken
        self.testing = testing
        self.selectedCategoryTabBackgroundColor = selectedCategoryTabBackgroundColor
        self.minimumRefreshWaitTime = minimumRefreshWaitTime
        self.mainAppUsesFirebase = mainAppUsesFirebase
        minimumRefreshDistance = minimumDistance
    }
}
