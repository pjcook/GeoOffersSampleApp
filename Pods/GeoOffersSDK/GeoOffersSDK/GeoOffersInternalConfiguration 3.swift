//  Copyright © 2019 Zappit. All rights reserved.

import AdSupport
import CoreLocation
import Foundation

public protocol GeoOffersConfigurationProtocol {
    var registrationCode: String { get }
    var authToken: String { get }
    var selectedCategoryTabBackgroundColor: String { get }
    var testing: Bool { get }
    var minimumRefreshWaitTime: Double { get }
    var minimumRefreshDistance: Double { get }
    var mainAppUsesFirebase: Bool { get }
}

class GeoOffersInternalConfiguration {
    let configuration: GeoOffersConfigurationProtocol
    private(set) var deviceID: String
    var apiURL: String {
        return configuration.testing ? "https://app-stg.zappitrewards.com/api" : "https://app.zappitrewards.com/api"
    }

    var timezone: String {
        return TimeZone.current.identifier
    }

    var clientID: Int? {
        get {
            return GeoOffersSDKUserDefaults.shared.clientID
        }
        set {
            GeoOffersSDKUserDefaults.shared.clientID = newValue
        }
    }

    var pushToken: String? {
        get {
            return GeoOffersSDKUserDefaults.shared.pushToken
        }
        set {
            GeoOffersSDKUserDefaults.shared.pushToken = newValue
        }
    }

    var pendingPushTokenRegistration: String? {
        get {
            return GeoOffersSDKUserDefaults.shared.pendingPushTokenRegistration
        }
        set {
            GeoOffersSDKUserDefaults.shared.pendingPushTokenRegistration = newValue
        }
    }

    func refresh() {
        deviceID = GeoOffersSDKUserDefaults.shared.deviceID
    }

    init(configuration: GeoOffersConfigurationProtocol) {
        self.configuration = configuration
        deviceID = GeoOffersSDKUserDefaults.shared.deviceID
    }
}

extension GeoOffersInternalConfiguration: GeoOffersConfigurationProtocol {
    var registrationCode: String { return configuration.registrationCode }
    var authToken: String { return configuration.authToken }
    var selectedCategoryTabBackgroundColor: String { return configuration.selectedCategoryTabBackgroundColor }
    var testing: Bool { return configuration.testing }
    var minimumRefreshWaitTime: Double { return configuration.minimumRefreshWaitTime }
    var minimumRefreshDistance: Double { return configuration.minimumRefreshDistance }
    var mainAppUsesFirebase: Bool { return configuration.mainAppUsesFirebase }
}

public class GeoOffersSDKUserDefaults {
    public static var shared = GeoOffersSDKUserDefaults()

    private enum Keys: String {
        case deviceID = "GeoOffers_DeviceID"
        case latitude = "GeoOffers_Latitude"
        case longitude = "GeoOffers_Longitude"
        case clientID = "GeoOffers_ClientID"
        case pushToken = "GeoOffers_PushToken"
        case pendingPushTokenRegistration = "GeoOffers_PendingPushTokenRegistration"
        case lastRefreshLatitude = "GeoOffers_LastRefreshLatitude"
        case lastRefreshLongitude = "GeoOffers_LastRefreshLongitude"
        case lastRefreshTimeInterval = "GeoOffers_LastRefreshTimeInterval"
    }

    private var defaults: UserDefaults {
        return UserDefaults.standard
    }

    var clientID: Int? {
        get {
            let clientID = defaults.integer(forKey: Keys.clientID.rawValue)
            return clientID <= 0 ? nil : clientID
        }
        set {
            defaults.set(newValue, forKey: Keys.clientID.rawValue)
        }
    }

    var pushToken: String? {
        get {
            return defaults.string(forKey: Keys.pushToken.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Keys.pushToken.rawValue)
        }
    }

    var pendingPushTokenRegistration: String? {
        get {
            return defaults.string(forKey: Keys.pendingPushTokenRegistration.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Keys.pendingPushTokenRegistration.rawValue)
        }
    }

    public var deviceID: String {
        get {
            guard let deviceID = defaults.object(forKey: Keys.deviceID.rawValue) as? String, !deviceID.isEmpty else {
                let deviceID = ASIdentifierManager.shared().isAdvertisingTrackingEnabled ?
                    ASIdentifierManager.shared().advertisingIdentifier.uuidString
                    : UUID().uuidString
                defaults.set(deviceID, forKey: Keys.deviceID.rawValue)
                defaults.synchronize()
                return deviceID
            }
            return deviceID
        }
        set {
            defaults.set(newValue, forKey: Keys.deviceID.rawValue)
            defaults.synchronize()
        }
    }

    public var lastKnownLocation: CLLocationCoordinate2D? {
        get {
            let latitude = defaults.double(forKey: Keys.latitude.rawValue)
            let longitude = defaults.double(forKey: Keys.longitude.rawValue)
            guard latitude != 0, longitude != 0 else { return nil }
            let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return location
        }
        set {
            defaults.set(newValue?.latitude, forKey: Keys.latitude.rawValue)
            defaults.set(newValue?.longitude, forKey: Keys.longitude.rawValue)
            defaults.synchronize()
        }
    }

    public var lastRefreshTimeInterval: TimeInterval {
        get {
            return defaults.double(forKey: Keys.lastRefreshTimeInterval.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Keys.lastRefreshTimeInterval.rawValue)
            defaults.synchronize()
        }
    }

    public var lastRefreshLocation: CLLocationCoordinate2D? {
        get {
            let latitude = defaults.double(forKey: Keys.lastRefreshLatitude.rawValue)
            let longitude = defaults.double(forKey: Keys.lastRefreshLongitude.rawValue)
            guard latitude != 0, longitude != 0 else { return nil }
            let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return location
        }
        set {
            defaults.set(newValue?.latitude, forKey: Keys.lastRefreshLatitude.rawValue)
            defaults.set(newValue?.longitude, forKey: Keys.lastRefreshLongitude.rawValue)
            defaults.synchronize()
        }
    }
}
