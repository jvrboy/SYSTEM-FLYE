import Foundation
import Combine

enum BatchError: LocalizedError {
    case queueFull
    case itemTooLarge
    case processorBusy
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .queueFull: return "Batch queue is full."
        case .itemTooLarge: return "Batch item exceeds maximum size."
        case .processorBusy: return "Batch processor is busy."
        case .serializationFailed: return "Failed to serialize batch item."
        }
    }
}

struct BatchItem: Identifiable, Codable {
    let id = UUID()
    let data: Data
    let priority: Int
    let createdAt: Date
    let retryCount: Int
    let tags: [String]
}

struct BatchResult: Identifiable, Codable {
    let id = UUID()
    let batchId: UUID
    let successCount: Int
    let failureCount: Int
    let processedAt: Date
    let errors: [String]
}

@MainActor
final class BatchProcessor: ObservableObject {
    static let shared = BatchProcessor()
    @Published private(set) var pendingItems: [BatchItem] = []
    @Published private(set) var processingItems: [BatchItem] = []
    @Published private(set) var completedBatches: [BatchResult] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var throughput: Double = 0.0

    private let maxBatchSize = 50
    private let maxConcurrentBatches = 3
    private let maxItemSize: Int64 = 5 * 1024 * 1024
    private var batchCounter: UUID = UUID()
    private var processingQueue = OperationQueue()
    private let storage = DatabaseManager.shared

    private init() {
        processingQueue.maxConcurrentOperationCount = maxConcurrentBatches
        processingQueue.qualityOfService = .utility
        loadPendingItems()
    }

    func enqueue(_ data: Data, priority: Int = 0, tags: [String] = []) throws {
        guard data.count <= maxItemSize else { throw BatchError.itemTooLarge }
        guard pendingItems.count < maxBatchSize * 10 else { throw BatchError.queueFull }
        let item = BatchItem(data: data, priority: priority, createdAt: Date(), retryCount: 0, tags: tags)
        pendingItems.append(item)
        processBatchIfNeeded()
    }

    func enqueueCodable<T: Codable>(_ value: T, priority: Int = 0, tags: [String] = []) throws {
        let data = try JSONEncoder.flye.encode(value)
        try enqueue(data, priority: priority, tags: tags)
    }

    func processAll() async throws -> [BatchResult] {
        guard !isProcessing else { return [] }
        isProcessing = true
        var results: [BatchResult] = []
        while !pendingItems.isEmpty {
            let result = try await processNextBatch()
            results.append(result)
        }
        isProcessing = false
        return results
    }

    func cancelAll() {
        processingQueue.cancelAllOperations()
        pendingItems.removeAll()
        processingItems.removeAll()
    }

    private func processBatchIfNeeded() {
        guard pendingItems.count >= maxBatchSize, !isProcessing else { return }
        Task { try? await processNextBatch() }
    }

    private func processNextBatch() async throws -> BatchResult {
        guard !pendingItems.isEmpty else { return BatchResult(batchId: UUID(), successCount: 0, failureCount: 0, processedAt: Date(), errors: []) }
        isProcessing = true
        defer { isProcessing = pendingItems.isEmpty }

        let batchId = UUID()
        let batchSize = min(maxBatchSize, pendingItems.count)
        let batch = Array(pendingItems.prefix(batchSize))
        pendingItems.removeFirst(batchSize)

        var successCount = 0
        var failureCount = 0
        var errors: [String] = []

        try await withThrowingTaskGroup { group in
            for item in batch {
                group.addTask { [weak self] in
                    do {
                        try await self?.processItem(item)
                        successCount += 1
                    } catch {
                        failureCount += 1
                        errors.append(error.localizedDescription)
                    }
                }
            }
        }

        let result = BatchResult(batchId: batchId, successCount: successCount, failureCount: failureCount, processedAt: Date(), errors: errors)
        completedBatches.insert(result, at: 0)
        if completedBatches.count > 200 { completedBatches.removeLast() }
        throughput = Double(successCount) / Date().timeIntervalSince(batch.first?.createdAt ?? Date())
        return result
    }

    private func processItem(_ item: BatchItem) async throws {
        let request = APIRequest(endpoint: "https://api.systemflye.app/v1/batch", method: .post, headers: ["Content-Type": "application/octet-stream"], body: nil, queryItems: nil)
        _ = try await APIClientManager.shared.upload(request, fileData: item.data, mimeType: "application/octet-stream")
    }

    private func loadPendingItems() {
        do {
            let items = try storage.query("SELECT data FROM batch_queue WHERE processed = 0 ORDER BY priority DESC, created_at ASC", parameters: [:]) { row in
                guard let data = row.data(at: 0) else { return BatchItem(data: Data(), priority: 0, createdAt: Date(), retryCount: 0, tags: []) }
                return try JSONDecoder.flye.decode(BatchItem.self, from: data)
            }
            pendingItems = items
        } catch {
            print("Failed to load pending batch items: \\(error)")
        }
    }
}
