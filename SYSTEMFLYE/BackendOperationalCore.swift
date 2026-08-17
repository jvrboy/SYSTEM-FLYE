import Foundation
import Combine

// MARK: - Production Backend Contracts

enum BackendRuntimeState: String, Codable, CaseIterable {
    case initializing = "INITIALIZING"
    case ready = "READY"
    case degraded = "DEGRADED"
    case offline = "OFFLINE"
}

struct BackendEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let category: String
    let message: String
    let severity: Severity

    enum Severity: String, Codable {
        case info, warning, error
    }
}

struct BackendConfiguration: Codable, Equatable {
    var requestTimeout: TimeInterval = 20
    var maxRetries = 3
    var syncInterval: TimeInterval = 30
    var offlineMode = false
    var telemetryEnabled = true
}

@MainActor
final class OperationalBackendStore: ObservableObject {
    static let shared = OperationalBackendStore()

    @Published private(set) var runtimeState: BackendRuntimeState = .initializing
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var queueCount = 0
    @Published private(set) var events: [BackendEvent] = []
    @Published private(set) var requestCount = 0
    @Published private(set) var failedRequestCount = 0
    @Published var configuration = BackendConfiguration()
    @Published var isRefreshing = false

    private let queue = OfflineQueue.shared
    private var refreshTask: Task<Void, Never>?
    private var hasStarted = false

    init() {}

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        runtimeState = .initializing
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.configuration.syncInterval))
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        hasStarted = false
        appendEvent(category: "lifecycle", message: "Background synchronization stopped", severity: .info)
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        queueCount = await queue.count()
        lastRefresh = Date()

        if configuration.offlineMode {
            runtimeState = .offline
            appendEvent(category: "health", message: "Offline mode is active; local queue remains available", severity: .warning)
            return
        }

        await BackendServiceManager.shared.performHealthChecks()
        let serviceHealth = BackendServiceManager.shared.overallHealth
        runtimeState = serviceHealth == .healthy ? .ready : .degraded
        appendEvent(category: "health", message: "Backend health refreshed: \(runtimeState.rawValue)", severity: runtimeState == .ready ? .info : .warning)
    }

    func recordRequest(success: Bool, endpoint: String) {
        requestCount += 1
        if !success { failedRequestCount += 1 }
        appendEvent(category: "request", message: "\(success ? "Completed" : "Failed") \(endpoint)", severity: success ? .info : .error)
    }

    func enqueue(kind: String, payload: String) async {
        await queue.enqueue(kind: kind, payload: payload)
        queueCount = await queue.count()
        appendEvent(category: "queue", message: "Queued offline operation: \(kind)", severity: .warning)
    }

    func clearEvents() {
        events.removeAll()
    }

    private func appendEvent(category: String, message: String, severity: BackendEvent.Severity) {
        events.insert(BackendEvent(id: UUID(), timestamp: Date(), category: category, message: message, severity: severity), at: 0)
        if events.count > 100 { events.removeLast() }
    }
}

extension BackendRuntimeState {
    var tint: String {
        switch self {
        case .initializing: return "orange"
        case .ready: return "green"
        case .degraded: return "yellow"
        case .offline: return "gray"
        }
    }
}
