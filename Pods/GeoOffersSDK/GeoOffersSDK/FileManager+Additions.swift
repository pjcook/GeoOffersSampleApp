//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

enum FileManagerError: Error {
    case missingDocumentDirectory
    case failedToCreateDirectory
}

public extension FileManager {
    func documentPath(for filename: String) throws -> String {
        guard let path = urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileManagerError.missingDocumentDirectory
        }

        if !fileExists(atPath: path.path) {
            do {
                try createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw FileManagerError.failedToCreateDirectory
            }
        }

        return path.appendingPathComponent(filename).path
    }
}
