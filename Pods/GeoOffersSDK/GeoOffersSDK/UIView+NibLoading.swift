//  Copyright © 2019 Software101. All rights reserved.

import UIKit

extension UIView {
    func xibSetup() {
        let className = NSStringFromClass(type(of: self))
        guard let nibName = className.components(separatedBy: ".").last else {
            assertionFailure("Could not find nibName for class \(className)")
            return
        }
        let bundle = Bundle(for: type(of: self))
        xibSetup(nibName: nibName, bundle: bundle)
    }

    func xibSetup(nibName: String, bundle: Bundle) {
        backgroundColor = .clear
        let view = loadViewFromNib(nibName: nibName, bundle: bundle)
        if frame == CGRect.zero {
            bounds = view.frame
        } else {
            view.frame = bounds
        }
        view.autoresizingMask = UIView.AutoresizingMask.flexibleWidth.union(.flexibleHeight)
        addSubview(view)
    }

    func loadViewFromNib(nibName: String, bundle: Bundle) -> UIView {
        let nib = UINib(nibName: nibName, bundle: bundle)
        let objects = nib.instantiate(withOwner: self, options: nil)

        // Find first object that is a view (there may be other objects, such as gesture recognizers)
        let views = objects.compactMap { $0 as? UIView }
        guard let view = views.first else {
            assertionFailure("No view found in nib \(nibName)")
            return UIView()
        }
        return view
    }
}
