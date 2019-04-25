//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import GeoOffersSDK
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var pushToken: UILabel!
    @IBOutlet private var locationInfo: UILabel!
    @IBOutlet private var versionNumber: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else { return }
        versionNumber.text = "Version: \(version) (\(build))"
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
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

    @IBAction private func toggleLocationInfo() {
        let location = GeoOffersWrapper.shared.lastLocation
        var locationString = "No Location"
        if let location = location {
            locationString = "lat:\(location.latitude), lng:\(location.longitude)"
            UIPasteboard.general.string = locationString
        }
        locationInfo.text = locationString
        locationInfo.isHidden = !locationInfo.isHidden
    }
}

extension ViewController: GeoOffersSDKServiceDelegate {
    func hasAvailableOffers() {
        presentOffers()
    }
}
