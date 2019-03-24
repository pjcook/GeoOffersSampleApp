//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import WebKit

protocol GeoOffersPresenter: class {
    func buildOfferListViewController() -> UIViewController
    func buildCouponViewController(scheduleID: Int) -> UIViewController
    var viewControllerDelegate: GeoOffersViewControllerDelegate? { get set }
}

class GeoOffersPresenterDefault: GeoOffersPresenter {
    private let configuration: GeoOffersSDKConfiguration
    private let locationService: GeoOffersLocationService
    private let cacheService: GeoOffersWebViewCache
    private let dataParser: GeoOffersDataParser
    weak var viewControllerDelegate: GeoOffersViewControllerDelegate?

    init(
        configuration: GeoOffersSDKConfiguration,
        locationService: GeoOffersLocationService,
        cacheService: GeoOffersWebViewCache,
        dataParser: GeoOffersDataParser
    ) {
        self.configuration = configuration
        self.locationService = locationService
        self.cacheService = cacheService
        self.dataParser = dataParser
    }

    private func offersURL() -> URL? {
        let baseURL = Bundle(for: GeoOffersPresenterDefault.self).url(forResource: "offerslist", withExtension: "html")
        return baseURL
    }

    private func couponURL() -> URL? {
        let baseURL = Bundle(for: GeoOffersPresenterDefault.self).url(forResource: "coupon", withExtension: "html")
        return baseURL
    }

    func buildOfferListViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "GeoOffersSDK", bundle: Bundle(for: GeoOffersPresenterDefault.self))
        guard let url = offersURL(),
            let vc = storyboard.instantiateInitialViewController() as? GeoOffersViewController
        else {
            geoOffersLog("Failed to buildOfferListViewController")
            return UIViewController()
        }
        let jsonData = cacheService.buildListingRequestJson()
        vc.presenter = self
        vc.delegate = viewControllerDelegate

        guard jsonData != "{}" else {
            vc.noOffers()
            return vc
        }
        
        let queryString = dataParser.buildOfferListQuerystring(configuration: configuration, locationService: locationService)
        let alreadyDeliveredOfferData = cacheService.buildAlreadyDeliveredOfferJson()
        let javascript = dataParser.buildJavascriptForWebView(listingData: jsonData, couponData: "", authToken: configuration.authToken, tabBackgroundColor: configuration.selectedCategoryTabBackgroundColor, alreadyDeliveredOfferData: alreadyDeliveredOfferData)
        vc.loadRequest(url: url, javascript: javascript, querystring: queryString)
        return vc
    }

    func buildCouponViewController(scheduleID: Int) -> UIViewController {
        let storyboard = UIStoryboard(name: "GeoOffersSDK", bundle: Bundle(for: GeoOffersPresenterDefault.self))
        guard let url = couponURL(),
            let vc = storyboard.instantiateInitialViewController() as? GeoOffersViewController
        else {
            geoOffersLog("Failed to buildOfferListViewController")
            return UIViewController()
        }
        let jsonData = cacheService.buildCouponRequestJson(scheduleID: scheduleID)
        vc.presenter = self
        vc.delegate = viewControllerDelegate
        let javascript = dataParser.buildJavascriptForWebView(listingData: "", couponData: jsonData, authToken: configuration.authToken, tabBackgroundColor: configuration.selectedCategoryTabBackgroundColor, alreadyDeliveredOfferData: "")
        let queryString = dataParser.buildCouponQuerystring(configuration: configuration, locationService: locationService)
        vc.loadRequest(url: url, javascript: javascript, querystring: queryString)
        return vc
    }
}
