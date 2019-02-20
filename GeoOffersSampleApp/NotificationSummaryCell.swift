//  Copyright © 2019 Zappit. All rights reserved.

import UIKit

class NotificationSummaryCell: UITableViewCell {
    @IBOutlet private var createdAt: UILabel!
    @IBOutlet private var summary: UILabel!

    override func prepareForReuse() {
        createdAt.text = nil
        summary.text = nil
    }

    func configure(_ notification: GeoOffersNotificationMessage) {
        createdAt.text = notification.formattedDate
        summary.text = notification.messageString
    }
}
