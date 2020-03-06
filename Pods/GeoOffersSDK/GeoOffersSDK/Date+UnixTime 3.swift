//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

extension Date {
    var unixTimeIntervalSince1970: Double {
        return timeIntervalSince1970 * 1000
    }
}
