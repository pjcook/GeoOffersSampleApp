//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

struct GeoOffersCouponResultsPage: Codable {
    let id: Int
    let titleText: String
    let titleTextSize: CGFloat
    let subtitleTextSize: CGFloat
    let itemResultTitleTextSize: CGFloat
    let resultsGridConfig: String
    let dividerLineColor: String
}

struct GeoOffersOffer: Codable {
    let clientCouponHash: String?
    let customCompanyName: String?
    let clientCompanyName: String?
    let logoImagePath: String?
    let headline: String?
    let subheadline: String?
    let promoExpiryBackgroundColor: String
    let termsAndConditionsForHtml: String?
    let couponLink: String?
    let deviceUid: String?
    let zcmBaseAddress: String?
    let errorMessageHtml: String?
    let customCouponUrl: String?
    let scheduleEndDateString: String?
    let mapsLink: String?
    let mapsLinkButtonText: String?
    let offerRedemptionMethod: String?
    let barcodeFormat: String?
    let codeToUse: String?
    let humanTypableCode: String?
    let customLinkOnCouponButtonText: String?
    let googlePayJwtOrEmpty: String?
    let shareLink: String?
    let brandName: String?
    let printedCouponExpiryMessage: String?
    let couponRedeemLink: String?

    var isNotCollected: Bool? = false
    let isTrackerOnly: Bool
    let hasHitRedeemedLimit: Bool?
    let isTermsAgreementRequired: Bool
    var didNotCreateClientCoupon: Bool? = false
    var isRedeemed: Bool? = false
    let usesCustomCouponURL: Bool?
    let isDeletedFromListingByEndUser: Bool?
    let hasRedemptionLimit: Bool?
    let hasRevealingRedemptionButton: Bool?
    let hidesWebPageCodeContentForPrintButton: Bool?
    let couponExpires: Bool?
    let hasCountdown: Bool?
    let showPrintAtHomeButton: Bool?
    let hasSaveToMobileWalletButton: Bool?
    let saveToMobileWallet: Bool?
    let allowsSharing: Bool?
    let showExpireOfferButton: Bool?
    let couponExpiresUponScheduleEnd: Bool?

    var countdownToExpiryStartedTimestampMsOrNull: Double?

    let scheduleId: Int?
    let couponDailyLimit: Int?
    let limitedCouponCountForToday: Int?
    let couponExpiryTimestampMs: TimeInterval?
    let couponTimeLeftSeconds: TimeInterval?
    let scheduleEndTimestampMs: TimeInterval?
    let deliveredToAppTimestampSeconds: TimeInterval?
    let campaignId: Int?

    let multipleStoreLogos: [MultipleStoreLogo]?

    let multipleStoreLogosHeading: String?

    let tags: [String]?
    let termsAndConditions: String?
    let couponLimitIsDailyNotTotal: Bool?
    let couponDailyLimitAppliesPerLocation: Bool?
    let couponId: Int?
    let itemResultsPage: GeoOffersCouponResultsPage
    let fontPaths: [String]
    let localTimezone: String?
    let locationId: Int?
    let error: String?
    let countdownToExpiryDurationMsOrNull: TimeInterval?
}

struct MultipleStoreLogo: Codable {
    let src: String
}
