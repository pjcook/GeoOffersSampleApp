//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import GeoOffersSDK

class ViewController: UIViewController {
    @IBOutlet private var pushToken: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showNotifications", let vc = segue.destination as? NotificationsViewController {
            vc.notifications = GeoOffersNotificationLogger.shared.allMessages()
        }
    }

    @IBAction private func requestLocationPermissions() {
        GeoOffersWrapper.shared.geoOffers.requestLocationPermissions()
    }
    
    @IBAction private func requestNotificationPermissions() {
        GeoOffersWrapper.shared.geoOffers.requestPushNotificationPermissions()
    }
    
    @IBAction fileprivate func presentOffers() {
        let viewController = GeoOffersWrapper.shared.geoOffers.buildOfferListViewController()
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    @IBAction private func togglePushToken() {
        let token = GeoOffersWrapper.shared.pushToken
        pushToken.text = token ?? "No Token"
        pushToken.isHidden = !pushToken.isHidden
        if let token = token {
            UIPasteboard.general.string = token
        }
    }
}

extension ViewController: GeoOffersSDKServiceDelegate {
    func hasAvailableOffers() {
        presentOffers()
    }
}

