//  Copyright © 2019 Zappit. All rights reserved.

import UIKit
import WebKit

protocol GeoOffersViewControllerDelegate: class {
    func deleteOffer(scheduleID: Int)
}

class GeoOffersViewController: UIViewController {
    private var webView: WKWebView!
    private(set) var pageLoaded = false
    private(set) var pendingURL: URL?
    private(set) var pendingQuerystring: String?
    private(set) var pendingScriptForStart: WKUserScript?
    private var contentController = WKUserContentController()
    weak var presenter: GeoOffersPresenter?
    weak var delegate: GeoOffersViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.navigationDelegate = self
        webView.contentMode = .scaleAspectFit

        view.addSubview(webView)

        let layoutGuide = view.safeAreaLayoutGuide

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true
        self.webView = webView

        contentController.add(self, name: "openCoupon")
        contentController.add(self, name: "deleteOffer")

        pageLoaded = true
        guard let url = pendingURL else { return }
        load(url)
    }

    private func load(_ url: URL) {
        if let script = pendingScriptForStart {
            contentController.addUserScript(script)
        }
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        } else {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        pendingURL = nil
    }

    @IBAction private func close() {
        dismiss(animated: true, completion: nil)
    }

    func loadRequest(url: URL, javascript: String?, querystring: String?) {
        pendingQuerystring = querystring
        var script: WKUserScript?
        if let javascript = javascript {
            script = WKUserScript(source: javascript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        }

        if pageLoaded {
            load(url)
        } else {
            pendingScriptForStart = script
            pendingURL = url
        }
    }

    fileprivate func openCoupon(scheduleID: Int) {
        guard let vc = presenter?.buildCouponViewController(scheduleID: scheduleID) else { return }
        navigationController?.pushViewController(vc, animated: true)
    }

    fileprivate func deleteOffer(scheduleID: Int) {
        delegate?.deleteOffer(scheduleID: scheduleID)
    }
}

extension GeoOffersViewController: WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "openCoupon",
            let scheduleIDString = message.body as? String,
            let scheduleID = Int(scheduleIDString) {
            openCoupon(scheduleID: scheduleID)
        } else if message.name == "openCoupon",
            let scheduleID = message.body as? Int {
            openCoupon(scheduleID: scheduleID)
        } else if message.name == "deleteOffer",
            let scheduleIDString = message.body as? String,
            let scheduleID = Int(scheduleIDString) {
            deleteOffer(scheduleID: scheduleID)
        } else if message.name == "deleteOffer",
            let scheduleID = message.body as? Int {
            deleteOffer(scheduleID: scheduleID)
        } else {
            geoOffersLog("\(message.body)")
        }
    }
}

extension GeoOffersViewController: WKNavigationDelegate {
    // func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {}

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let pendingQuerystring = pendingQuerystring else { return }
        let javascript = "window.location.href = '\(pendingQuerystring)';"
        webView.evaluateJavaScript(javascript, completionHandler: nil)
        self.pendingQuerystring = nil
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        geoOffersLog("\(error)")
    }
}
