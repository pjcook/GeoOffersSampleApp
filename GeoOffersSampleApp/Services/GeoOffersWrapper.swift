//  Copyright © 2019 Zappit. All rights reserved.

import Foundation
import GeoOffersSDK

class GeoOffersWrapper {
    static let shared = GeoOffersWrapper()
    
    var geoOffers: GeoOffersSDKService = {
        let registrationCode = ""
        let authToken = ""
        let configuration = GeoOffersSDKConfiguration(registrationCode: registrationCode, authToken: authToken, testing: true)
        let geoOffers = GeoOffersSDKServiceDefault(configuration: configuration)
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
