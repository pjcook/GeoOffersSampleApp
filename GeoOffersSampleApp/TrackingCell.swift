//  Copyright © 2019 Zappit. All rights reserved.

import UIKit

extension GeoOffersTrackingEvent {
    var formattedDate: String {
        return notificationSummaryCellDateFormatter.string(from: Date(timeIntervalSince1970: timestamp / 1000))
    }

    var messageString: String {
        switch type {
        case .geoFenceEntry, .geoFenceExit, .offerDelivered, .regionDwellTime:
            return "\(type.rawValue): (\(scheduleID))"
        default:
            return type.rawValue
        }
    }
}

class TrackingCell: UITableViewCell {
    @IBOutlet private var createdAt: UILabel!
    @IBOutlet private var summary: UILabel!

    override func prepareForReuse() {
        createdAt.text = nil
        summary.text = nil
    }

    func configure(_ item: GeoOffersTrackingEvent) {
        createdAt.text = item.formattedDate
        summary.text = item.messageString
    }
}
