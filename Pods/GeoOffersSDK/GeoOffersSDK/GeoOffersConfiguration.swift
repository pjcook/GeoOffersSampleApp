//  Copyright © 2019 Zappit. All rights reserved.

import AdSupport
import CoreLocation
import Foundation

public protocol GeoOffersConfigurationProtocol {
    var registrationCode: String { get }
    var authToken: String { get }
    var deviceID: String { get }
    var selectedCategoryTabBackgroundColor: String { get }
    var timezone: String { get }
    var minimumRefreshWaitTime: Double { get }
    var minimumRefreshDistance: Double { get }
    var mainAppUsesFirebase: Bool { get }
    func refresh()
}

protocol GeoOffersInternalConfiguration {
    var apiURL: String { get }
    var clientID: Int? { get set }
    var pushToken: String? { get set }
    var pendingPushTokenRegistration: String? { get set }
}

typealias GeoOffersSDKConfiguration = GeoOffersConfigurationProtocol & GeoOffersInternalConfiguration

public class GeoOffersConfiguration: GeoOffersConfigurationProtocol, GeoOffersInternalConfiguration {
    public let registrationCode: String
    public let authToken: String
    public private(set) var deviceID: String
    internal let apiURL: String
    public let selectedCategoryTabBackgroundColor: String
    public let minimumRefreshWaitTime: Double // seconds
    public let minimumRefreshDistance: Double // meters
    public let mainAppUsesFirebase: Bool

    public var timezone: String {
        return TimeZone.current.identifier
    }

    internal var clientID: Int? {
        get {
            return GeoOffersSDKUserDefaults.shared.clientID
        }
        set {
            GeoOffersSDKUserDefaults.shared.clientID = newValue
        }
    }

    internal var pushToken: String? {
        get {
            return GeoOffersSDKUserDefaults.shared.pushToken
        }
        set {
            GeoOffersSDKUserDefaults.shared.pushToken = newValue
        }
    }

    internal var pendingPushTokenRegistration: String? {
        get {
            return GeoOffersSDKUserDefaults.shared.pendingPushTokenRegistration
        }
        set {
            GeoOffersSDKUserDefaults.shared.pendingPushTokenRegistration = newValue
        }
    }

    public func refresh() {
        deviceID = GeoOffersSDKUserDefaults.shared.deviceID
    }

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
        deviceID = GeoOffersSDKUserDefaults.shared.deviceID
        apiURL = testing ? "https://app-stg.zappitrewards.com/api" : "https://app.zappitrewards.com/api"
        self.selectedCategoryTabBackgroundColor = selectedCategoryTabBackgroundColor
        self.minimumRefreshWaitTime = minimumRefreshWaitTime
        self.mainAppUsesFirebase = mainAppUsesFirebase
        minimumRefreshDistance = minimumDistance
    }
}

class GeoOffersSDKUserDefaults {
    static var shared = GeoOffersSDKUserDefaults()

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

    var deviceID: String {
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

    var lastKnownLocation: CLLocationCoordinate2D? {
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

    var lastRefreshTimeInterval: TimeInterval {
        get {
            return defaults.double(forKey: Keys.lastRefreshTimeInterval.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Keys.lastRefreshTimeInterval.rawValue)
            defaults.synchronize()
        }
    }

    var lastRefreshLocation: CLLocationCoordinate2D? {
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
