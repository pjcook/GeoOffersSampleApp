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
        tracking = (cacheData.cacheData ?? []).reversed()
        tableView.reloadData()
    }
    
    @IBAction private func refreshAction() {
        reloadData()
    }
    
    @IBAction private func shareData(_ sender: UIBarButtonItem) {
        var data: Data?
        do {
            data = try JSONEncoder().encode(tracking)
        } catch {
            print(error)
        }
        
        guard let strongData = data, let shareData = String(data: strongData, encoding: .utf8) else { return }
        let shareContent: [Any] = [shareData as Any]
        let activityViewController = UIActivityViewController(activityItems: shareContent, applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = sender
        present(activityViewController, animated: true, completion: nil)
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
