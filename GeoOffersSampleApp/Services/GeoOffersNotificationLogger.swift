//  Copyright © 2019 Zappit. All rights reserved.

import Foundation
import UserNotifications

private let GeoOffersNotificationLoggerQueue = DispatchQueue(label: "GeoOffersNotificationLogger.Queue")

let notificationSummaryCellDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

class GeoOffersNotificationMessage {
    let id: String
    let message: [String: AnyObject]
    let createdAt: TimeInterval
    
    lazy var messageString: String? = {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)
        } catch {
            print(error)
        }
        return nil
    }()
    
    lazy var formattedDate: String = {
        return notificationSummaryCellDateFormatter.string(from: Date(timeIntervalSinceReferenceDate: createdAt))
    }()
    
    init(message: [String: AnyObject]) {
        id = UUID().uuidString
        createdAt = Date().timeIntervalSinceReferenceDate
        self.message = message
    }
    
    init(with dictionary: [String: AnyObject]) {
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.createdAt = dictionary["createdAt"] as! TimeInterval
        self.message = dictionary["message"] as! [String: AnyObject]
    }
    
    func toDictionary() -> [String: AnyObject] {
        let dictionary: [String: AnyObject] = [
            "id": id as AnyObject,
            "createdAt": createdAt as AnyObject,
            "message": message as AnyObject
        ]
        return dictionary
    }
}

class GeoOffersNotificationLogger {
    static let shared = GeoOffersNotificationLogger()
    
    private let maxMessagesToCache = 100
    private var notifications: [GeoOffersNotificationMessage] = []
    
    func clearCache() {
        GeoOffersNotificationLoggerQueue.sync {
            self.notifications = []
        }
        save()
    }
    
    func remove(_ id: String) {
        GeoOffersNotificationLoggerQueue.sync {
            self.notifications.removeAll(where: { $0.id == id })
        }
        save()
    }
    
    func allMessages() -> [GeoOffersNotificationMessage] {
        return notifications
    }
    
    func log(_ notification: [String: AnyObject]) {
        let message = GeoOffersNotificationMessage(message: notification)
        GeoOffersNotificationLoggerQueue.sync {
            self.notifications.append(message)
            while self.notifications.count > self.maxMessagesToCache {
                _ = self.notifications.removeFirst()
            }
        }
        save()
    }
    
    private lazy var savePath: String? = {
        let fileManager = FileManager.default
        do {
            let path = try fileManager.documentPath(for: "GeoOffersNotificationLogger.data")
            return path
        } catch {
            print(error)
        }
        return nil
    }()
    
    init() {
        load()
    }
    
    private func load() {
        guard let savePath = savePath, FileManager.default.fileExists(atPath: savePath) else { return }
        GeoOffersNotificationLoggerQueue.sync {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: savePath))
                guard let cachedData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: AnyObject]] else { return }
                var notifications: [GeoOffersNotificationMessage] = []
                for dict in cachedData {
                    notifications.append(GeoOffersNotificationMessage(with: dict))
                }
                self.notifications = notifications
                print("GeoOffersNotificationLogger.load().loaded")
            } catch {
                print("GeoOffersNotificationLogger.load().Failed to load CachedNotificationData: \(error)")
            }
        }
    }
    
    private func save() {
        guard let savePath = savePath else { return }
        let cache = notifications
        GeoOffersNotificationLoggerQueue.sync {
            let url = URL(fileURLWithPath: savePath)
            do {
                var array: [[String: AnyObject]] = []
                for item in cache {
                    array.append(item.toDictionary())
                }
                
                let data = try JSONSerialization.data(withJSONObject: array, options: [])
                try data.write(to: url)
                print("GeoOffersNotificationLogger.save().saved")
            } catch {
                print(error)
            }
        }
    }
}
