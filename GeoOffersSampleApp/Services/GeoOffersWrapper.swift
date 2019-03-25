//  Copyright © 2019 Zappit. All rights reserved.

import Foundation
import GeoOffersSDK

class GeoOffersWrapper {
    static let shared = GeoOffersWrapper()

    var geoOffers: GeoOffersSDKService = {
        let registrationCode = "535987"
        let authToken = "963c01a5-1003-11e8-9f97-0a927e8d53d7"
        let configuration = GeoOffersConfiguration(registrationCode: registrationCode, authToken: authToken, testing: true, minimumRefreshWaitTime: 30, mainAppUsesFirebase: false)
        let geoOffers = GeoOffersSDKService(configuration: configuration)
        return geoOffers
    }()

    var pushToken: String? {
        get {
            let defaults = UserDefaults.standard
            let token = defaults.string(forKey: "SampleAppPushToken")
            return token
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "SampleAppPushToken")
        }
    }
}
