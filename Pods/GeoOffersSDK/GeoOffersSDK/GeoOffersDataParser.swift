//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import Foundation

class GeoOffersDataParser {
    func parseNearbyFences(jsonData: Data) -> GeoOffersListing? {
        let decoder = JSONDecoder()
        var data: GeoOffersListing?
        do {
            data = try decoder.decode(GeoOffersListing.self, from: jsonData)
        } catch {
            geoOffersLog("\(error)")
        }
        return data
    }

    func parsePushNotification(jsonData: Data) -> GeoOffersPushData? {
        let decoder = JSONDecoder()
        var data: GeoOffersPushData?
        do {
            data = try decoder.decode(GeoOffersPushData.self, from: jsonData)
        } catch {
            geoOffersLog("\(error)")
        }
        return data
    }

    func buildOfferListQuerystring(configuration: GeoOffersConfigurationProtocol, locationService: GeoOffersLocationService) -> String {
        let registrationCode = configuration.registrationCode
        var latitude = ""
        var longitude = ""
        if let location = locationService.latestLocation {
            latitude = String(location.latitude)
            longitude = String(location.longitude)
        }
        let deviceID = configuration.deviceID
        let queryString = "#\(registrationCode),\(latitude),\(longitude),\(deviceID)"
        return queryString
    }

    func buildCouponQuerystring(configuration: GeoOffersConfigurationProtocol, locationService: GeoOffersLocationService) -> String {
        var latitude = ""
        var longitude = ""
        if let location = locationService.latestLocation {
            latitude = String(location.latitude)
            longitude = String(location.longitude)
        }
        let timezone = configuration.timezone.urlEncode() ?? ""
        let queryString = "#\(latitude),\(longitude),\(timezone)"
        return queryString
    }

    func buildJavascriptForWebView(listingData: String, couponData: String, authToken: String, tabBackgroundColor: String, alreadyDeliveredOfferData: String, deliveredIdsAndTimestamps: String) -> String {
        guard let url = Bundle(for: GeoOffersDataParser.self).url(forResource: "ListingJSTemplate", withExtension: "js") else { return "" }
        do {
            let template = try String(contentsOf: url, encoding: .utf8)
            return template
                .replacingOccurrences(of: "<listingData>", with: listingData)
                .replacingOccurrences(of: "<couponData>", with: couponData)
                .replacingOccurrences(of: "<authToken>", with: authToken)
                .replacingOccurrences(of: "<tabBackgroundColor>", with: tabBackgroundColor)
                .replacingOccurrences(of: "<AlreadyDeliveredOfferData>", with: alreadyDeliveredOfferData)
                .replacingOccurrences(of: "<deliveredIdsAndTimestamps>", with: deliveredIdsAndTimestamps)
        } catch {
            geoOffersLog("\(error)")
            return ""
        }
    }
}
