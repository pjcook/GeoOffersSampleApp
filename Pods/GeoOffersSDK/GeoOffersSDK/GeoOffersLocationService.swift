//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import Foundation

protocol GeoOffersLocationServiceDelegate: class {
    func userDidMoveSignificantDistance()
    func didEnterRegion(_ identifier: String)
    func didExitRegion(_ identifier: String)
}

protocol GeoOffersLocationManager {
    var delegate: CLLocationManagerDelegate? { get set }
    var monitoredRegions: Set<CLRegion> { get }
    var maximumRegionMonitoringDistance: CLLocationDistance { get }
    var hasLocationPermission: Bool { get }
    var canMonitorForRegions: Bool { get }
    var allowsBackgroundLocationUpdates: Bool { get set }

    func requestAlwaysAuthorization()
    func startMonitoringSignificantLocationChanges()
    func startMonitoring(for region: CLRegion)
    func stopMonitoring(for region: CLRegion)
}

extension CLLocationManager: GeoOffersLocationManager {
    var hasLocationPermission: Bool {
        return [.authorizedAlways, .authorizedWhenInUse].contains(CLLocationManager.authorizationStatus())
    }

    var canMonitorForRegions: Bool {
        return CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    }
}

class GeoOffersLocationService: NSObject {
    private var locationManager: GeoOffersLocationManager
    private(set) var latestLocation: CLLocationCoordinate2D?

    weak var delegate: GeoOffersLocationServiceDelegate?

    init(latestLocation: CLLocationCoordinate2D?, locationManager: GeoOffersLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.latestLocation = latestLocation
        self.locationManager.delegate = self
        startMonitoringSignificantLocationChanges()
    }

    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }

    func stopMonitoringAllRegions() {
        for region in monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    func startMonitoringSignificantLocationChanges() {
        guard locationManager.hasLocationPermission, locationManager.canMonitorForRegions else { return }
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startMonitoringSignificantLocationChanges()
    }

    var monitoredRegions: Set<CLRegion> {
        return locationManager.monitoredRegions
    }

    /*
     Note: A single app can only monitor up to 20 regions
     */
    func monitor(center: CLLocationCoordinate2D, radiusMeters: Double, identifier: String, ignoreIfInside: Bool) {
        guard locationManager.hasLocationPermission, locationManager.canMonitorForRegions else { return }
        let region = CLCircularRegion(center: center, radius: min(radiusMeters, locationManager.maximumRegionMonitoringDistance), identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
        if !ignoreIfInside, let latestLocation = latestLocation, region.contains(latestLocation) {
            delegate?.didEnterRegion(region.identifier)
        }
    }

    func stopMonitoringRegion(with identifier: String) {
        for region in locationManager.monitoredRegions {
            if region.identifier == identifier {
                locationManager.stopMonitoring(for: region)
            }
        }
    }
}

extension GeoOffersLocationService: CLLocationManagerDelegate {
    func locationManager(_: CLLocationManager, didChangeAuthorization _: CLAuthorizationStatus) {
        guard locationManager.hasLocationPermission else { return }
        startMonitoringSignificantLocationChanges()
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.first else { return }
        self.latestLocation = latestLocation.coordinate
        delegate?.userDidMoveSignificantDistance()
    }

    func locationManager(_: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        geoOffersLog("GeoOffersSDK.error Monitoring failed for region with identifier: \(region?.identifier ?? "") with error: \(error)")
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        geoOffersLog("GeoOffersSDK.error Location Mnaager failed with the following error: \(error)")
    }

    func locationManager(_: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        delegate?.didEnterRegion(region.identifier)
    }

    func locationManager(_: CLLocationManager, didExitRegion region: CLRegion) {
        delegate?.didExitRegion(region.identifier)
    }
}
