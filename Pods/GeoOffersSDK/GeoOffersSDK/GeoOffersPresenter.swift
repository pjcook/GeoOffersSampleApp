//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import WebKit

protocol GeoOffersPresenterProtocol: class {
    func buildOfferListViewController(service: GeoOffersSDKServiceProtocol?) -> UIViewController
    func refreshOfferListViewController(_ viewController: GeoOffersViewController)
    func buildCouponViewController(scheduleID: Int) -> UIViewController
    var viewControllerDelegate: GeoOffersViewControllerDelegate? { get set }
}

class GeoOffersPresenter: GeoOffersPresenterProtocol {
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
        let baseURL = Bundle(for: GeoOffersPresenter.self).url(forResource: "offerslist", withExtension: "html")
        return baseURL
    }

    private func couponURL() -> URL? {
        let baseURL = Bundle(for: GeoOffersPresenter.self).url(forResource: "coupon", withExtension: "html")
        return baseURL
    }

    func buildOfferListViewController(service: GeoOffersSDKServiceProtocol?) -> UIViewController {
        let storyboard = UIStoryboard(name: "GeoOffersSDK", bundle: Bundle(for: GeoOffersPresenter.self))
        guard let vc = storyboard.instantiateInitialViewController() as? GeoOffersViewController
        else {
            geoOffersLog("Failed to buildOfferListViewController")
            return UIViewController()
        }

        vc.presenter = self
        vc.delegate = viewControllerDelegate
        vc.service = service
        
        if var service = service {
            service.offersUpdatedDelegate = vc
        }
        
        refreshOfferListViewController(vc)
        return vc
    }
    
    func refreshOfferListViewController(_ viewController: GeoOffersViewController) {
        guard let url = offersURL() else { return }
        let jsonData = cacheService.buildListingRequestJson()
        guard jsonData != "{}" else {
            viewController.noOffers()
            return
        }
        
        let queryString = dataParser.buildOfferListQuerystring(configuration: configuration, locationService: locationService)
        let alreadyDeliveredOfferData = cacheService.buildAlreadyDeliveredOfferJson()
        let javascript = dataParser.buildJavascriptForWebView(listingData: jsonData, couponData: "", authToken: configuration.authToken, tabBackgroundColor: configuration.selectedCategoryTabBackgroundColor, alreadyDeliveredOfferData: alreadyDeliveredOfferData)
        viewController.loadRequest(url: url, javascript: javascript, querystring: queryString)
    }

    func buildCouponViewController(scheduleID: Int) -> UIViewController {
        let storyboard = UIStoryboard(name: "GeoOffersSDK", bundle: Bundle(for: GeoOffersPresenter.self))
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
