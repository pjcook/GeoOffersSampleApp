//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import GeoOffersSDK

class ViewController: UIViewController {
    @IBOutlet private var pushToken: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction private func requestLocationPermissions() {
        GeoOffersWrapper.shared.geoOffers.requestLocationPermissions()
    }
    
    @IBAction private func requestNotificationPermissions() {
        GeoOffersWrapper.shared.geoOffers.requestPushNotificationPermissions()
    }
    
    @IBAction fileprivate func presentOffers() {
        GeoOffersWrapper.shared.geoOffers.presentOfferScreen(in: self)
    }
    
    @IBAction private func togglePushToken() {
        pushToken.text = GeoOffersWrapper.shared.pushToken ?? "No Token"
        pushToken.isHidden = !pushToken.isHidden
        UIPasteboard.general.string = GeoOffersWrapper.shared.pushToken
    }
}

extension ViewController: GeoOffersSDKServiceDelegate {
    func hasAvailableOffers() {
        presentOffers()
    }
}

