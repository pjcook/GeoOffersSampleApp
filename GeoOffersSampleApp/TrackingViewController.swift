//  Copyright © 2019 Zappit. All rights reserved.

import UIKit

class TrackingViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    
    private var tracking: [GeoOffersTrackingEvent] = []
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    private func reloadData() {
        let cacheData = GeoOffersTrackingDebugCache(filename: "GeoOffersTrackingDebugCache.data")
        tracking = cacheData.cacheData ?? []
        tableView.reloadData()
    }
    
    @IBAction private func refreshAction() {
        reloadData()
    }
}

extension TrackingViewController: UITableViewDelegate {}

extension TrackingViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return tracking.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = tracking[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackingCell", for: indexPath) as! TrackingCell
        cell.configure(item)
        return cell
    }
}
