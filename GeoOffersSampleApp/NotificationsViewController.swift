//  Copyright © 2019 Zappit. All rights reserved.

import UIKit

class NotificationsViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    var notifications: [GeoOffersNotificationMessage] = [] {
        didSet {
            if tableView != nil {
                tableView.reloadData()
            }
        }
    }
    
    @IBAction func deleteAll() {
        GeoOffersNotificationLogger.shared
        .clearCache()
        notifications = []
        tableView.reloadData()
    }
}

extension NotificationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let notification = notifications[indexPath.row]
        guard let notificationMessage = notification.messageString else { return }
        UIPasteboard.general.string = notificationMessage
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { [weak self] (action, indexPath) in
            guard let self = self else { return }
            let notification = self.notifications[indexPath.row]
            self.notifications.remove(at: indexPath.row)
            tableView.reloadData()
            GeoOffersNotificationLogger.shared.remove(notification.id)
        }
        
        return [delete]
    }
}

extension NotificationsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let notification = notifications[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationSummaryCell", for: indexPath) as! NotificationSummaryCell
        cell.configure(notification)
        return cell
    }
}
