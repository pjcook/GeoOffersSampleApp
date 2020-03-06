//  Copyright © 2019 Zappit. All rights reserved.

import UIKit

struct GeoOffersNotificationToastViewData {
    let title: String
    let message: String
}

protocol GeoOffersNotificationToastDelegate: class {
    func finishedDisplay()
}

class GeoOffersNotificationToast: UIView {
    @IBOutlet private var container: UIView!
    @IBOutlet private var title: UILabel!
    @IBOutlet private var message: UILabel!
    @IBOutlet private var widthConstraint: NSLayoutConstraint!

    weak var delegate: GeoOffersNotificationToastDelegate?

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .clear
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
    }

    func configure(viewData: GeoOffersNotificationToastViewData) {
        title.text = viewData.title
        message.text = viewData.message
    }

    func present(in window: UIWindow, delay: TimeInterval) {
        let padding: CGFloat = 16
        let doublePadding = padding * 2
        let width = window.frame.width - doublePadding
        widthConstraint.constant = width
        window.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false

        transform = CGAffineTransform(translationX: 0, y: -(frame.height + frame.origin.y))
        UIView.animate(withDuration: 0.4, delay: delay, options: .curveEaseIn, animations: {
            self.transform = CGAffineTransform.identity
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 5, options: .curveEaseOut, animations: {
                self.transform = CGAffineTransform(translationX: 0, y: -(self.frame.height + self.frame.origin.y))
            }, completion: { _ in
                self.delegate?.finishedDisplay()
                self.removeFromSuperview()
            })
        }
    }
}

class GeoOffersNotificationToastManager {
    private var pendingToasts: [GeoOffersNotificationToast] = []
    private var presentingToast = false

    func presentToast(title: String, subtitle: String, delay _: TimeInterval) {
        guard UIApplication.shared.keyWindow != nil else { return }

        let view = GeoOffersNotificationToast()
        view.xibSetup()
        let viewData = GeoOffersNotificationToastViewData(title: title, message: subtitle)
        view.configure(viewData: viewData)

        pendingToasts.append(view)
        processNextToast()
    }

    private func processNextToast() {
        guard !presentingToast, let window = UIApplication.shared.keyWindow, !pendingToasts.isEmpty else { return }
        presentingToast = true
        let view = pendingToasts.removeFirst()
        view.delegate = self
        view.present(in: window, delay: 0)
    }
}

extension GeoOffersNotificationToastManager: GeoOffersNotificationToastDelegate {
    func finishedDisplay() {
        presentingToast = false
        processNextToast()
    }
}
