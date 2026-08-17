import Foundation
import Combine
import UserNotifications

enum PushError: LocalizedError {
    case permissionDenied
    case tokenRegistrationFailed
    case payloadTooLarge
    case invalidTopic

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Push notification permission was denied."
        case .tokenRegistrationFailed: return "Failed to register push token."
        case .payloadTooLarge: return "Push notification payload exceeds size limit."
        case .invalidTopic: return "Invalid push topic."
        }
    }
}

@MainActor
final class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: Data?
    @Published private(set) var lastNotificationDate: Date?
    @Published private(set) var notificationHistory: [NotificationRecord] = []
    @Published private(set) var pendingNotifications: [UNNotificationRequest] = []

    private let notificationCenter = UNUserNotificationCenter.current()
    private var tokenUpdateTask: Task<Void, Never>?
    private let storage = DatabaseManager.shared
    private let maxHistorySize = 500

    struct NotificationRecord: Identifiable, Codable {
        let id = UUID()
        let title: String
        let body: String
        let category: String
        let receivedAt: Date
        let userInfo: [String: String]
        let isRead: Bool
    }

    private init() {
        registerForNotifications()
        setupNotificationCenterDelegate()
    }

    func requestAuthorization(options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert]) async throws -> UNAuthorizationStatus {
        let status = try await notificationCenter.requestAuthorization(options: options)
        authorizationStatus = status
        return status
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleTokenUpdate(_ data: Data) {
        deviceToken = data
        let tokenString = data.map { String(format: "%02.2hhx", $0) }.joined()
        Task.detached(priority: .background) {
            do {
                let payload = ["token": tokenString, "platform": "ios", "bundle_id": Bundle.main.bundleIdentifier ?? ""]
                _ = try await APIClientManager.shared.send(APIRequest(endpoint: "https://api.systemflye.app/v1/push/token", method: .post, headers: [:], body: payload, queryItems: nil))
            } catch {
                print("Failed to register push token: \\(error)")
            }
        }
    }

    func scheduleLocalNotification(title: String, body: String, category: String, userInfo: [String: String] = [:], trigger: UNNotificationTrigger? = nil, sound: UNNotificationSound = .default) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.userInfo = userInfo
        content.sound = sound
        content.threadID = category
        content.summaryArgument = category

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await notificationCenter.add(request)
        pendingNotifications.append(request)
        recordNotification(title: title, body: body, category: category, userInfo: userInfo)
    }

    func scheduleRecurringNotification(title: String, body: String, category: String, interval: TimeInterval, repeats: Bool = true) async throws {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, interval), repeats: repeats)
        try await scheduleLocalNotification(title: title, body: body, category: category, trigger: trigger)
    }

    func cancelPendingNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        pendingNotifications.removeAll { identifiers.contains($0.identifier) }
    }

    func cancelAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        pendingNotifications.removeAll()
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        notificationCenter.setNotificationCategories(categories)
    }

    func notificationCategories() async -> Set<UNNotificationCategory> {
        return await notificationCenter.notificationCategories()
    }

    func markAllAsRead() {
        for i in notificationHistory.indices { notificationHistory[i].isRead = true }
    }

    func deleteHistoryOlderThan(_ date: Date) {
        notificationHistory.removeAll { $0.receivedAt < date }
    }

    private func registerForNotifications() {
        Task { @MainActor in
            let status = try? await requestAuthorization()
            authorizationStatus = status ?? .denied
        }
    }

    private func setupNotificationCenterDelegate() {
        notificationCenter.delegate = self
    }

    private func recordNotification(title: String, body: String, category: String, userInfo: [String: String]) {
        let record = NotificationRecord(title: title, body: body, category: category, receivedAt: Date(), userInfo: userInfo, isRead: false)
        notificationHistory.insert(record, at: 0)
        if notificationHistory.count > maxHistorySize { notificationHistory.removeLast() }
        lastNotificationDate = record.receivedAt
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        lastNotificationDate = Date()
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        lastNotificationDate = Date()
        let userInfo = response.notification.request.content.userInfo
        handleNotificationAction(userInfo: userInfo, actionIdentifier: response.actionIdentifier)
    }

    private func handleNotificationAction(userInfo: [AnyHashable: Any], actionIdentifier: String) {
        if let pair = userInfo["pair"] as? String, actionIdentifier == "VIEW_SIGNAL" {
            AdvancedStore.shared.selectedPair = pair
        }
    }
}
