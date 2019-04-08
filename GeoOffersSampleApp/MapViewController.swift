//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import MapKit
import CoreLocation
import GeoOffersSDK

class MapPin: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
    
    init(region: GeoOffersDebugRegion) {
        self.coordinate = CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude)
        self.title = region.title
        self.subtitle = region.subtitle
    }
}

class MapViewController: UIViewController {
    @IBOutlet private var map: MKMapView!
    @IBOutlet private var toggle: UISwitch!
    private var locationManager = CLLocationManager()
    private var refreshTimer: Timer?
    private let service = GeoOffersWrapper.shared.geoOffers
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        map.userTrackingMode = .follow
        refreshPins()
        startTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
    }
    
    private func startTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { _ in
            self.refreshPins()
        })
    }
    
    private func refreshPins() {
        if toggle.isOn {
            refreshPinsFromTracked()
        } else {
            refreshPinsFromService()
        }
    }
    
    @IBAction private func didToggle() {
        toggle.isOn = !toggle.isOn
        refreshPins()
    }
    
    private func refreshMap(with annotations: [MKAnnotation]) {
        map.removeAnnotations(map.annotations)
        map.addAnnotations(annotations)
        title = "Pins (\(annotations.count))"
    }
    
    private func refreshPinsFromService() {
        var annotations = [MKAnnotation]()
        for region in service.debugRegionLocations() {
            let annotation = MapPin(region: region)
            annotations.append(annotation)
        }
        refreshMap(with: annotations)
    }
    
    private func refreshPinsFromTracked() {
        var annotations = [MKAnnotation]()
        for region in locationManager.monitoredRegions where region is CLCircularRegion {
            guard let region = region as? CLCircularRegion else { continue }
            let annotation = MapPin(coordinate: region.center, title: region.identifier, subtitle: "\(region.center.latitude), \(region.center.longitude), (\(region.radius))")
            annotations.append(annotation)
        }
        refreshMap(with: annotations)
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MapPin else { return nil }
        guard let view = mapView.dequeueReusableAnnotationView(withIdentifier: "pin") else {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            view.canShowCallout = true
            //view.animatesDrop = false
            view.bounds = CGRect(x: 0, y: 0, width: 38, height: 38)
            view.backgroundColor = UIColor.clear
            let pinImage = UIImage(named: "map_pin")!
            view.image = pinImage
            view.centerOffset = CGPoint(x: (view.centerOffset.x) + pinImage.size.width/2, y: (view.centerOffset.y) - pinImage.size.height/2)
            return view
        }
        return view
    }
}
