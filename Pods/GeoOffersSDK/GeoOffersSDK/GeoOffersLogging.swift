//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

public func geoOffersLog(_ message: String) {
    #if DEBUG
        print(message)
    #endif
}
