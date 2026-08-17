import Foundation
import Combine

enum SyncError: LocalizedError {
    case networkUnavailable
    case taskCancelled
    case dataIntegrityError
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "Network is unavailable for sync."
        case .taskCancelled: return "Sync task was cancelled."
        case .dataIntegrityError: return "Data integrity check failed during sync."
        case .quotaExceeded: return "Sync quota exceeded."
        }
    }
}

enum SyncPriority: Int, Comparable, Codable {
    case critical = 0
    case high = 1
    case normal = 2
    case low = 3

    static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct SyncTask: Identifiable, Codable {
    let id = UUID()
    let name: String
    let priority: SyncPriority
    let payload: Data
    let createdAt: Date
    var attempts: Int = 0
    var lastAttemptAt: Date?
    var isCompleted: Bool = false
    var estimatedSize: Int64 { Int64(payload.count) }
}

@MainActor
final class BackgroundSyncScheduler: ObservableObject {
    static let shared = BackgroundSyncScheduler()
    @Published private(set) var pendingTasks: [SyncTask] = []
    @Published private(set) var activeTasks: [SyncTask] = []
    @Published private(set) var completedTasks: [SyncTask] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var totalBytesPending: Int64 = 0
    @Published private(set) var lastSyncDate: Date?

    private let maxConcurrentTasks = 3
    private let maxRetries = 3
    private let syncInterval: TimeInterval = 300
    private var syncTimer: Timer?
    private let queue = DispatchQueue(label: "sync.scheduler", qos: .utility, attributes: .concurrent)
    private let processingQueue = OperationQueue()
    private let storage = DatabaseManager.shared

    private init() {
        processingQueue.maxConcurrentOperationCount = maxConcurrentTasks
        processingQueue.qualityOfService = .utility
        loadPendingTasks()
        startPeriodicSync()
    }

    func scheduleSync(name: String, priority: SyncPriority, payload: Data) {
        let task = SyncTask(name: name, priority: priority, payload: payload, createdAt: Date())
        pendingTasks.append(task)
        totalBytesPending += task.estimatedSize
        pendingTasks.sort { $0.priority < $1.priority }
        processQueue()
    }

    func runAll() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        try await withThrowingTaskGroup { group in
            for task in pendingTasks where activeTasks.count < maxConcurrentTasks {
                group.addTask { [weak self] in
                    try await self?.execute(task) ?? ()
                }
            }
        }
        isSyncing = false
        lastSyncDate = Date()
    }

    func cancelAll() {
        processingQueue.cancelAllOperations()
        pendingTasks.removeAll()
        activeTasks.removeAll()
        totalBytesPending = 0
    }

    private func processQueue() {
        guard !isSyncing, pendingTasks.count > 0, activeTasks.count < maxConcurrentTasks else { return }
        guard let task = pendingTasks.first else { return }
        pendingTasks.removeFirst()
        activeTasks.append(task)
        processingQueue.addOperation {
            Task { @MainActor in
                do {
                    try await self.execute(task)
                } catch {
                    print("Sync task failed: \\(error)")
                }
            }
        }
    }

    private func execute(_ task: SyncTask) async throws {
        guard APIClientManager.shared.isOnline else { throw SyncError.networkUnavailable }
        do {
            let request = APIRequest(endpoint: "https://api.systemflye.app/v1/sync", method: .post, headers: ["Content-Type": "application/octet-stream"], body: nil, queryItems: nil)
            _ = try await APIClientManager.shared.upload(request, fileData: task.payload, mimeType: "application/octet-stream")
            await MainActor.run {
                task.isCompleted = true
                self.completedTasks.append(task)
                if let index = self.activeTasks.firstIndex(where: { $0.id == task.id }) {
                    self.activeTasks.remove(at: index)
                }
                self.totalBytesPending -= task.estimatedSize
                self.lastSyncDate = Date()
                self.processQueue()
            }
        } catch {
            await MainActor.run {
                task.attempts += 1
                task.lastAttemptAt = Date()
                if task.attempts >= maxRetries {
                    self.completedTasks.append(task)
                    if let index = self.activeTasks.firstIndex(where: { $0.id == task.id }) {
                        self.activeTasks.remove(at: index)
                    }
                } else {
                    self.pendingTasks.append(task)
                    self.pendingTasks.sort { $0.priority < $1.priority }
                }
                self.processQueue()
            }
            throw error
        }
    }

    private func loadPendingTasks() {
        do {
            let data = try storage.query("SELECT payload FROM sync_tasks WHERE is_completed = 0", parameters: [:]) { row in
                return row.data(at: 0) ?? Data()
            }
            for blob in data {
                let task = try JSONDecoder.flye.decode(SyncTask.self, from: blob)
                pendingTasks.append(task)
                totalBytesPending += task.estimatedSize
            }
            pendingTasks.sort { $0.priority < $1.priority }
        } catch {
            print("Failed to load pending sync tasks: \\(error)")
        }
    }

    private func startPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processQueue()
            }
        }
    }
}
