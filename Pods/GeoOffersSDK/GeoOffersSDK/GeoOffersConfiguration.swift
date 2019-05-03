//  Copyright © 2019 Zappit. All rights reserved.

import AdSupport
import CoreLocation
import Foundation
import GeoOffersPrivateSDK

public struct GeoOffersConfig {
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
        minimumRefreshWaitTime: Double = 30,
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

extension GeoOffersConfig {
    func internalConfiguration() -> GeoOffersSDKConfiguration {
        return GeoOffersConfiguration(
            registrationCode: registrationCode,
            authToken: authToken,
            testing: testing,
            selectedCategoryTabBackgroundColor: selectedCategoryTabBackgroundColor,
            minimumRefreshWaitTime: minimumRefreshWaitTime,
            minimumDistance: minimumRefreshDistance,
            mainAppUsesFirebase: mainAppUsesFirebase
        )
    }
}
