//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

extension String {
    public func urlEncode() -> String? {
        var allowedQueryParamAndKey = NSCharacterSet.urlQueryAllowed

        allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
        return addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey)
    }
}
