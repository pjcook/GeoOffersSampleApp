//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import GeoOffersSDK

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction private func requestLocationPermissions() {
        GeoOffersWrapper.shared.geoOffers.requestLocationPermissions()
    }
    
    @IBAction fileprivate func presentOffers() {
        GeoOffersWrapper.shared.geoOffers.presentOfferScreen(in: self)
    }
}

extension ViewController: GeoOffersSDKServiceDelegate {
    func hasAvailableOffers() {
        presentOffers()
    }
}

