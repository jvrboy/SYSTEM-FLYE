import Foundation

actor OfflineQueue {
    static let shared = OfflineQueue()
    private let fileURL: URL
    private var operations: [OfflineOperation] = []

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = base.appendingPathComponent("SYSTEMFLYE/offline-queue.json")
        operations = Self.load(from: fileURL)
    }

    func enqueue(kind: String, payload: String) {
        operations.append(OfflineOperation(id: UUID(), createdAt: Date(), kind: kind, payload: payload, attempts: 0, nextAttemptAt: Date()))
        persist()
    }

    func readyOperations(now: Date = Date()) -> [OfflineOperation] { operations.filter { $0.nextAttemptAt <= now } }

    func markSucceeded(_ id: UUID) {
        operations.removeAll { $0.id == id }
        persist()
    }

    func markFailed(_ id: UUID, now: Date = Date()) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        operations[index].attempts += 1
        operations[index].nextAttemptAt = now.addingTimeInterval(min(300, pow(2, Double(operations[index].attempts))))
        persist()
    }

    func count() -> Int { operations.count }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.flye.encode(operations)
            try data.write(to: fileURL, options: .atomic)
        } catch { }
    }

    private static func load(from url: URL) -> [OfflineOperation] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder.flye.decode([OfflineOperation].self, from: data)) ?? []
    }
}
