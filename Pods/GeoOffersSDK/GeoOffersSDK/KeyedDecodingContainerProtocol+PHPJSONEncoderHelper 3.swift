//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

enum GeoOffersCodableError: Error {
    case failedToParseData
}

extension KeyedDecodingContainerProtocol {
    func geoDecode<T>(_: T.Type, forKey: Self.Key) -> T? where T: Decodable {
        if let obj = try? decode(T.self, forKey: forKey) {
            return obj
        }
        return nil
    }

    func geoValueFromString<T>(_ key: Self.Key) throws -> T where T: Decodable {
        let stringValue = (try? decode(String.self, forKey: key)) ?? ""
        if !stringValue.isEmpty {
            if Int.self == T.self, let value = Int(stringValue) {
                return value as! T
            } else if Double.self == T.self, let value = Double(stringValue) {
                return value as! T
            }
            throw GeoOffersCodableError.failedToParseData
        } else {
            return try decode(T.self, forKey: key)
        }
    }
}
