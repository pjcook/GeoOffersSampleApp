//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation

protocol GeoOffersLocationServiceDelegate: class {
    func userDidMoveSignificantDistance()
    func didUpdateLocations(_ locations: [CLLocation])
    func didEnterRegion(_ identifier: String)
    func didExitRegion(_ identifier: String)
}

protocol GeoOffersLocationManager: class {
    var location: CLLocation? { get }
    var activityType: CLActivityType { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var delegate: CLLocationManagerDelegate? { get set }
    var monitoredRegions: Set<CLRegion> { get }
    var maximumRegionMonitoringDistance: CLLocationDistance { get }
    var hasLocationPermission: Bool { get }
    var canMonitorForRegions: Bool { get }
    var allowsBackgroundLocationUpdates: Bool { get set }
    
    func startUpdatingLocation()
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
    private let configuration: GeoOffersConfigurationProtocol
    private let maxNumberOfRegionsThatCanBeMonitoredPerApp = 20

    weak var delegate: GeoOffersLocationServiceDelegate?

    init(latestLocation: CLLocationCoordinate2D?, locationManager: GeoOffersLocationManager = CLLocationManager(), configuration: GeoOffersConfigurationProtocol) {
        self.configuration = configuration
        self.locationManager = locationManager
        super.init()
        self.latestLocation = latestLocation ?? locationManager.location?.coordinate
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
        guard locationManager.hasLocationPermission else { return }
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .other
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = configuration.minimumRefreshDistance
        locationManager.startUpdatingLocation()
    }

    var monitoredRegions: Set<CLRegion> {
        return locationManager.monitoredRegions
    }

    func monitor(regions: [GeoOffersGeoFence]) {
        guard latestLocation != nil, !regions.isEmpty else { return }
        let previouslyMonitoredRegions = monitoredRegions
        stopMonitoringAllRegions()
        
        let regionsToTrack = filterAndReduceCrossedRegions(regions)

        for region in regionsToTrack {
            let key = region.key
            let ignoreIfInside = previouslyMonitoredRegions.contains(where: { $0.identifier == key })
            monitor(center: region.coordinate, radiusMeters: Double(region.radiusMeters), identifier: key, ignoreIfInside: ignoreIfInside)
        }
    }
    
    func filterAndReduceCrossedRegions(_ regions: [GeoOffersGeoFence]) -> [GeoOffersGeoFence] {
        guard let location = latestLocation, !regions.isEmpty else { return [] }
        var regionsToTrack = [GeoOffersGeoFence]()
        
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let sortedRegions = regions.sorted { (f1, f2) -> Bool in
            f1.location.distance(from: currentLocation) < f2.location.distance(from: currentLocation)
        }
        
        for region in sortedRegions {
            guard regionsToTrack.count < maxNumberOfRegionsThatCanBeMonitoredPerApp else { break }
            
            if regionsToTrack.isEmpty {
                regionsToTrack.append(region)
                continue
            }
            
            var trackRegion = true
            for trackedRegion in regionsToTrack {
                if CLCircularRegion(center: trackedRegion.coordinate, radius: trackedRegion.radiusMeters, identifier: "dummy").contains(region.coordinate) {
                    trackRegion = false
                    break
                }
            }
            
            if trackRegion {
                regionsToTrack.append(region)
            }
        }
        
        return regionsToTrack
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
        delegate?.didUpdateLocations(locations)
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
