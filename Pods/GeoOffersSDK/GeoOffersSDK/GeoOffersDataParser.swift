//  Copyright © 2019 Zappit. All rights reserved.

import CoreLocation
import Foundation

enum GeoOffersNotificationType: String, Codable {
    case data = "REWARD_REMOVED_ADDED_OR_EDITED"
    case couponRedeemed = "COUPON_REDEEMED"
    case delayedDelivery = "DELAYED_DELIVERY_DUE"
}

protocol GeoOffersPushNotificationProcessorDelegate: class {
    func processListingData()
}

struct GeoOffersNotificationMessageType: Codable {
    let type: GeoOffersNotificationType
    let campaignId: Int?
}

class GeoOffersPushNotificationProcessor {
    private let notificationCache: GeoOffersPushNotificationCache
    private let listingCache: GeoOffersListingCache

    weak var delegate: GeoOffersPushNotificationProcessorDelegate?

    init(notificationCache: GeoOffersPushNotificationCache, listingCache: GeoOffersListingCache) {
        self.notificationCache = notificationCache
        self.listingCache = listingCache
    }

    func shouldProcessRemoteNotification(_ notification: [String: AnyObject]) -> Bool {
        let aps = notification["aps"] as? [String: AnyObject] ?? [:]
        return aps["content-available"] as? String == "1"
    }

    func parseNearbyFences(jsonData: Data) -> GeoOffersListing? {
        let decoder = JSONDecoder()
        var data: GeoOffersListing?
        do {
            data = try decoder.decode(GeoOffersListing.self, from: jsonData)
        } catch {
            geoOffersLog("\(error)")
        }
        return data
    }

    func handleNotification(_ notification: [String: AnyObject]) -> Bool {
        guard let messageType = processNotificationMessageType(notification) else {
            return handleDataNotification(notification)
        }

        switch messageType.type {
        case .couponRedeemed:
            if let campaignId = messageType.campaignId {
                processCouponRedeemed(campaignId: campaignId)
            }
            return true
        case .delayedDelivery:
            handleDelayedDeliveryNotification()
            return true
        case .data:
            return handleDataNotification(notification)
        }
    }

    private func processCouponRedeemed(campaignId: Int) {
        listingCache.redeemCoupon(campaignId: campaignId)
        delegate?.processListingData()
    }

    private func handleDelayedDeliveryNotification() {
        delegate?.processListingData()
    }

    private func processNotificationMessageType(_ notification: [String: AnyObject]) -> GeoOffersNotificationMessageType? {
        guard
            let messageData = notification["geoRewardsPushMessageJson"] as? String,
            let jsonData = messageData.data(using: .utf8)
        else { return nil }

        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(GeoOffersNotificationMessageType.self, from: jsonData)
            return message
        } catch {
            geoOffersLog("\(error)")
        }
        return nil
    }

    private func handleDataNotification(_ notification: [String: AnyObject]) -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: notification, options: .prettyPrinted)
            guard let parsedData = parsePushNotification(jsonData: data) else { return false }
            return processPushNotificationData(pushData: parsedData)
        } catch {
            geoOffersLog("\(error)")
        }
        return false
    }

    private func processPushNotificationData(pushData: GeoOffersPushData) -> Bool {
        if pushData.totalParts == 1 {
            guard let message = buildMessage(messages: [pushData]) else { return false }
            return processPushNotificationMessage(message: message, messageID: pushData.messageID)
        } else {
            notificationCache.add(pushData)
            let totalMessages = notificationCache.count(pushData.messageID)
            guard totalMessages == pushData.totalParts else { return false }
            let messages = notificationCache.messages(pushData.messageID)
            guard let message = buildMessage(messages: messages) else { return false }
            return processPushNotificationMessage(message: message, messageID: pushData.messageID)
        }
    }

    private func buildMessage(messages: [GeoOffersPushData]) -> GeoOffersPushNotificationDataUpdate? {
        let sorted = messages.sorted { $0.messageIndex < $1.messageIndex }
        var messageString = ""
        for message in sorted {
            messageString += message.message
        }
        guard let data = messageString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        do {
            let parsedData = try decoder.decode(GeoOffersPushNotificationDataUpdate.self, from: data)
            return parsedData
        } catch {
            geoOffersLog("\(error)")
        }
        return nil
    }

    private func processPushNotificationMessage(message: GeoOffersPushNotificationDataUpdate, messageID: String) -> Bool {
        notificationCache.updateCache(pushData: message)
        notificationCache.remove(messageID)
        delegate?.processListingData()
        return true
    }

    func parsePushNotification(jsonData: Data) -> GeoOffersPushData? {
        let decoder = JSONDecoder()
        var data: GeoOffersPushData?
        do {
            data = try decoder.decode(GeoOffersPushData.self, from: jsonData)
        } catch {
            geoOffersLog("\(error)")
        }
        return data
    }
}
