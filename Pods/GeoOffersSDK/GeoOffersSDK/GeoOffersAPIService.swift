//  Copyright © 2019 Zappit. All rights reserved.

import Foundation

protocol GeoOffersAPIServiceProtocol {
    var backgroundSessionCompletionHandler: (() -> Void)? { get set }
    func pollForNearbyOffers(latitude: Double, longitude: Double, completionHandler: @escaping GeoOffersNetworkResponse)
    func register(pushToken: String, latitude: Double, longitude: Double, clientID: Int, completionHandler: GeoOffersNetworkResponse?)
    func update(pushToken: String, with newToken: String, completionHandler: GeoOffersNetworkResponse?)
    func delete(scheduleID: ScheduleID)
    func checkForPendingTrackingEvents()
    func countdownsStarted(hashes: [String], completionHandler: GeoOffersNetworkResponse?)
}

enum GeoOffersAPIErrors: Error {
    case failedToBuildURL
    case failedToBuildJsonForPost
}

enum GeoOffersNetworkResponseType {
    case failure(Error)
    case dataTask(Data?)
    case success
}

enum GeoOffersTaskType {
    case getOffersData
    case general
}

typealias GeoOffersNetworkResponse = ((GeoOffersNetworkResponseType) -> Void)

class GeoOffersNetworkTask {
    let id: Int
    let task: URLSessionTask
    let isDataTask: Bool
    let taskType: GeoOffersTaskType
    var completionHandler: GeoOffersNetworkResponse?

    init(id: Int, task: URLSessionTask, isDataTask: Bool, taskType: GeoOffersTaskType = .general, completionHandler: GeoOffersNetworkResponse?) {
        self.id = id
        self.task = task
        self.isDataTask = isDataTask
        self.completionHandler = completionHandler
        self.taskType = taskType
    }
}

class GeoOffersAPIService: NSObject, GeoOffersAPIServiceProtocol {
    struct HTTPMethod {
        static let get = "GET"
        static let post = "POST"
        static let put = "PUT"
    }

    struct EndPoints {
        static let nearbyOffers = "nearby-geofences"
        static let registerPushToken = "fcm-registration"
        static let updatePushToken = "change-push-token"
        static let deleteOfferFromUser = "delete-offer-from-end-user-listing"
        static let tracking = "geo-offer-events"
        static let countdownStarted = "coupons/countdowns-started"
    }

    private var activeTasks: [Int: GeoOffersNetworkTask] = [:]
    private let configuration: GeoOffersInternalConfiguration
    private var session: URLSession?
    private var trackingCache: GeoOffersTrackingCache

    public var backgroundSessionCompletionHandler: (() -> Void)?

    public init(configuration: GeoOffersInternalConfiguration, session: URLSession? = nil, trackingCache: GeoOffersTrackingCache) {
        self.trackingCache = trackingCache
        self.configuration = configuration
        super.init()
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.background(withIdentifier: "GeoOffersSDK.background.urlsession")
            configuration.waitsForConnectivity = true
            configuration.networkServiceType = .background
            self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        }
    }

    private func startTask(task: GeoOffersNetworkTask) {
        activeTasks[task.id] = task
        task.task.resume()
    }

    private func taskFinished(task: GeoOffersNetworkTask) {
        activeTasks.removeValue(forKey: task.id)
    }

    private func cancelTasks(of taskType: GeoOffersTaskType) {
        activeTasks.forEach {
            if $0.value.taskType == taskType {
                $0.value.task.cancel()
                activeTasks.removeValue(forKey: $0.key)
            }
        }
    }
    
    private var pollingForNearbyOffers = false
    private var pendingPollForNearbyOffers: (() -> Void)?

    public func pollForNearbyOffers(latitude: Double, longitude: Double, completionHandler: @escaping GeoOffersNetworkResponse) {
        guard let url = URL(string: configuration.apiURL)?
            .appendingPathComponent(EndPoints.nearbyOffers)
            .appendingPathComponent(configuration.registrationCode)
            .appendingPathComponent(String(latitude))
            .appendingPathComponent(String(longitude))
            .appendingPathComponent(configuration.deviceID)
        else {
            completionHandler(.failure(GeoOffersAPIErrors.failedToBuildURL))
            return
        }

        let request = generateRequest(url: url, method: HTTPMethod.get)
        guard let downloadTask = session?.downloadTask(with: request) else { return }
        
        pendingPollForNearbyOffers = {
            self.pollingForNearbyOffers = true
            self.trackingCache.add(GeoOffersTrackingEvent(type: .polledForNearbyOffers, timestamp: Date().unixTimeIntervalSince1970, scheduleDeviceID: "", scheduleID: 0, latitude: latitude, longitude: longitude))
            let task = GeoOffersNetworkTask(id: downloadTask.taskIdentifier, task: downloadTask, isDataTask: true, taskType: .getOffersData, completionHandler: { response in
                DispatchQueue.main.async {
                    completionHandler(response)
                    self.pollingForNearbyOffers = false
                    self.executePendingPollingTask()
                }
            })
            self.startTask(task: task)
        }
        
        guard !pollingForNearbyOffers else { return }
        
        executePendingPollingTask()
    }
    
    private func executePendingPollingTask() {
        guard let pendingTask = pendingPollForNearbyOffers else { return }
        pendingPollForNearbyOffers = nil
        pendingTask()
    }

    public func countdownsStarted(hashes: [String], completionHandler: GeoOffersNetworkResponse?) {
        guard let url = URL(string: configuration.apiURL)?
            .appendingPathComponent(EndPoints.countdownStarted)
        else {
            completionHandler?(.failure(GeoOffersAPIErrors.failedToBuildURL))
            return
        }

        var request = generateRequest(url: url, method: HTTPMethod.post)

        let data = GeoOffersCountdownsStarted(timezone: configuration.timezone, timestamp: Date().unixTimeIntervalSince1970, hashes: hashes)
        guard let jsonData = encode(data) else {
            completionHandler?(.failure(GeoOffersAPIErrors.failedToBuildJsonForPost))
            return
        }
        request.httpBody = jsonData

        guard let dataTask = session?.dataTask(with: request) else { return }
        let task = GeoOffersNetworkTask(id: dataTask.taskIdentifier, task: dataTask, isDataTask: true, completionHandler: completionHandler)
        startTask(task: task)
    }

    public func register(pushToken: String, latitude: Double, longitude: Double, clientID: Int, completionHandler: GeoOffersNetworkResponse?) {
        guard let url = URL(string: configuration.apiURL)?
            .appendingPathComponent(EndPoints.registerPushToken)
        else {
            completionHandler?(.failure(GeoOffersAPIErrors.failedToBuildURL))
            return
        }

        var request = generateRequest(url: url, method: HTTPMethod.post)

        let data = GeoOffersPushRegistration(pushToken: pushToken, clientID: clientID, deviceID: configuration.deviceID, latitude: latitude, longitude: longitude)
        guard let jsonData = encode(data) else {
            completionHandler?(.failure(GeoOffersAPIErrors.failedToBuildJsonForPost))
            return
        }
        request.httpBody = jsonData

        guard let dataTask = session?.dataTask(with: request) else { return }
        let task = GeoOffersNetworkTask(id: dataTask.taskIdentifier, task: dataTask, isDataTask: true, completionHandler: completionHandler)
        startTask(task: task)
    }

    public func update(pushToken: String, with newToken: String, completionHandler: GeoOffersNetworkResponse?) {
        guard let url = URL(string: configuration.apiURL)?
            .appendingPathComponent(EndPoints.updatePushToken)
        else {
            completionHandler?(.failure(GeoOffersAPIErrors.failedToBuildURL))
            return
        }

        var request = generateRequest(url: url, method: HTTPMethod.post)
        cancelTasks(of: .getOffersData)
        let tokenData = GeoOffersChangePushToken(oldToken: pushToken, newToken: newToken)
        guard let jsonData = encode(tokenData) else {
            completionHandler?(.failure(GeoOffersAPIErrors.failedToBuildJsonForPost))
            return
        }
        request.httpBody = jsonData

        guard let dataTask = session?.dataTask(with: request) else { return }
        let task = GeoOffersNetworkTask(id: dataTask.taskIdentifier, task: dataTask, isDataTask: true, completionHandler: completionHandler)
        startTask(task: task)
    }

    public func delete(scheduleID: ScheduleID) {
        guard let url = URL(string: configuration.apiURL)?
            .appendingPathComponent(EndPoints.deleteOfferFromUser)
        else { return }

        var request = generateRequest(url: url, method: HTTPMethod.post)

        let deleteSchedule = GeoOffersDeleteSchedule(scheduleID: scheduleID, deviceID: configuration.deviceID)
        guard let jsonData = encode(deleteSchedule) else { return }
        request.httpBody = jsonData

        guard let dataTask = session?.dataTask(with: request) else { return }
        let task = GeoOffersNetworkTask(id: dataTask.taskIdentifier, task: dataTask, isDataTask: true, completionHandler: nil)
        startTask(task: task)
    }

    private var trackingRequestInProgress = false
    private func track(events: [GeoOffersTrackingEvent]) {
        guard !trackingRequestInProgress, let url = URL(string: configuration.apiURL)?
            .appendingPathComponent(EndPoints.tracking)
        else { return }
        trackingRequestInProgress = true
        var request = generateRequest(url: url, method: HTTPMethod.post)

        let trackingWrapper = GeoOffersTrackingWrapper(deviceID: configuration.deviceID, timezone: configuration.timezone, events: events)
        guard let jsonData = encode(trackingWrapper) else { return }
        request.httpBody = jsonData

        guard let dataTask = session?.dataTask(with: request) else { return }
        let task = GeoOffersNetworkTask(id: dataTask.taskIdentifier, task: dataTask, isDataTask: true) { response in
            DispatchQueue.main.async {
                self.trackingRequestInProgress = false
                switch response {
                case .failure:
                    self.trackingCache.add(events)
                default:
                    self.checkForPendingTrackingEvents()
                }
            }
        }
        startTask(task: task)
    }

    public func checkForPendingTrackingEvents() {
        guard !trackingRequestInProgress, trackingCache.hasCachedEvents() else { return }
        let pendingEvents = trackingCache.popCachedEvents()
        guard !pendingEvents.isEmpty else { return }
        track(events: pendingEvents)
    }

    private func encode<T>(_ object: T) -> Data? where T: Encodable {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(object)
            return jsonData
        } catch {
            geoOffersLog("\(error)")
        }
        return nil
    }

    private func generateRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request = addAuthorizationHeader(request: request)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("br, gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        return request
    }

    private func addAuthorizationHeader(request: URLRequest) -> URLRequest {
        var request = request

        let authToken = ":" + configuration.authToken
        if let authData = authToken.data(using: .utf8) {
            let base64AuthString = authData.base64EncodedString()
            request.setValue("Basic \(base64AuthString)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

extension GeoOffersAPIService: URLSessionDownloadDelegate {
    public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        guard let activeTask = activeTasks[downloadTask.taskIdentifier] else { return }
        if let error = downloadTask.error {
            activeTask.completionHandler?(.failure(error))
        } else if activeTask.isDataTask {
            var data: Data?
            do {
                data = try Data(contentsOf: location)
            } catch {}
            activeTask.completionHandler?(.dataTask(data))
        } else {
            activeTask.completionHandler?(.success)
        }
        taskFinished(task: activeTask)
    }
}

extension GeoOffersAPIService: URLSessionTaskDelegate {
    public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let activeTask = activeTasks[task.taskIdentifier] else { return }
        if let error = error {
            activeTask.completionHandler?(.failure(error))
        } else {
            activeTask.completionHandler?(.success)
        }
        taskFinished(task: activeTask)
    }
}

extension GeoOffersAPIService: URLSessionDelegate {
    public func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
        guard let completionHandler = backgroundSessionCompletionHandler else { return }
        DispatchQueue.main.async {
            completionHandler()
        }
    }
}
