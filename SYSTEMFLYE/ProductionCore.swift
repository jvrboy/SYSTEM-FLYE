import Foundation
import SwiftUI

struct FlyeEnvelope<T: Codable>: Codable where T: Codable {
    let schemaVersion: Int
    let updatedAt: Date
    let payload: T
}

struct LocalWorkspaceSnapshot: Codable {
    var selectedWorkspace = "Command"
    var selectedPair = "EUR/USD"
    var runCount = 0
    var neuralEpoch = 0
    var signalBias = 0.67
    var isLive = true
}

struct AuditEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let category: String
    let action: String
    let detail: String
    let severity: Severity

    enum Severity: String, Codable { case info, warning, critical }
}

struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let kind: String
    let payload: String
    var attempts: Int
    var nextAttemptAt: Date
}

enum LocalStoreError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case atomicWriteFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "The workspace could not be encoded."
        case .decodingFailed: "The saved workspace could not be decoded."
        case .atomicWriteFailed: "The workspace could not be written safely."
        }
    }
}

actor LocalRepository {
    static let shared = LocalRepository()
    private let fileManager = FileManager.default
    private let directoryName = "SYSTEMFLYE"
    private let schemaVersion = 2
    private let backupSuffix = ".backup"

    private var directoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private func fileURL(_ name: String) -> URL { directoryURL.appendingPathComponent(name) }

    func loadSnapshot() throws -> LocalWorkspaceSnapshot {
        let url = fileURL("workspace.json")
        guard fileManager.fileExists(atPath: url.path) else { return LocalWorkspaceSnapshot() }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder.flye.decode(FlyeEnvelope<LocalWorkspaceSnapshot>.self, from: data)
            return migrate(envelope).payload
        } catch {
            throw LocalStoreError.decodingFailed
        }
    }

    func saveSnapshot(_ snapshot: LocalWorkspaceSnapshot) throws {
        try ensureDirectory()
        do {
            let envelope = FlyeEnvelope(schemaVersion: schemaVersion, updatedAt: Date(), payload: snapshot)
            let data = try JSONEncoder.flye.encode(envelope)
            let destination = fileURL("workspace.json")
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: fileURL("workspace.json\(backupSuffix)"))
                try? fileManager.copyItem(at: destination, to: fileURL("workspace.json\(backupSuffix)"))
            }
            try data.write(to: destination, options: .atomic)
        } catch { throw LocalStoreError.atomicWriteFailed }
    }

    private func migrate(_ envelope: FlyeEnvelope<LocalWorkspaceSnapshot>) -> FlyeEnvelope<LocalWorkspaceSnapshot> {
        guard envelope.schemaVersion < schemaVersion else { return envelope }
        return FlyeEnvelope(schemaVersion: schemaVersion, updatedAt: envelope.updatedAt, payload: envelope.payload)
    }

    func appendAudit(_ event: AuditEvent) throws {
        try ensureDirectory()
        var events = (try? loadAudit()) ?? []
        events.insert(event, at: 0)
        let data = try JSONEncoder.flye.encode(events.prefix(300))
        try data.write(to: fileURL("audit.json"), options: .atomic)
    }

    func loadAudit() throws -> [AuditEvent] {
        let url = fileURL("audit.json")
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder.flye.decode([AuditEvent].self, from: Data(contentsOf: url))
    }

    func exportDiagnostics() throws -> URL {
        try ensureDirectory()
        let report = try JSONEncoder.flye.encode((try? loadAudit()) ?? [])
        let url = directoryURL.appendingPathComponent("diagnostics-\(Int(Date().timeIntervalSince1970)).json")
        try report.write(to: url, options: .atomic)
        return url
    }

    func reset() throws {
        for name in ["workspace.json", "audit.json"] {
            let url = fileURL(name)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}

@MainActor
final class ProductionStore: ObservableObject {
    @Published private(set) var snapshot = LocalWorkspaceSnapshot()
    @Published private(set) var auditEvents: [AuditEvent] = []
    @Published private(set) var isRestoring = true
    @Published var lastError: String?
    @Published var pendingOperations = 0

    private let repository = LocalRepository.shared

    func restore() async {
        do {
            snapshot = try await repository.loadSnapshot()
            auditEvents = try await repository.loadAudit()
        } catch { lastError = error.localizedDescription }
        isRestoring = false
    }

    func update(_ mutate: (inout LocalWorkspaceSnapshot) -> Void, action: String, detail: String = "") {
        mutate(&snapshot)
        persist(action: action, detail: detail)
    }

    func record(_ action: String, category: String = "system", detail: String = "", severity: AuditEvent.Severity = .info) {
        let event = AuditEvent(id: UUID(), timestamp: Date(), category: category, action: action, detail: detail, severity: severity)
        auditEvents.insert(event, at: 0)
        Task {
            try? await repository.appendAudit(event)
        }
    }

    func persist(action: String, detail: String) {
        record(action, detail: detail)
        let value = snapshot
        Task {
            do { try await repository.saveSnapshot(value) }
            catch { await MainActor.run { self.lastError = error.localizedDescription } }
        }
    }

    func exportDiagnostics() {
        Task {
            do { _ = try await repository.exportDiagnostics() }
            catch { await MainActor.run { self.lastError = error.localizedDescription } }
        }
    }

    func resetLocalData() {
        snapshot = LocalWorkspaceSnapshot()
        auditEvents = []
        Task {
            do { try await repository.reset() }
            catch { await MainActor.run { self.lastError = error.localizedDescription } }
        }
    }
}

extension JSONEncoder {
    static let flye: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let flye: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct ProductionStatusCard: View {
    @EnvironmentObject private var production: ProductionStore
    @State private var showingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("LOCAL RUNTIME", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(FlyeTheme.accent)
                Spacer()
                Circle().fill(FlyeTheme.positive).frame(width: 7, height: 7)
                Text("HARDENED").font(.caption2.weight(.bold)).foregroundStyle(FlyeTheme.positive)
            }
            HStack(spacing: 10) {
                status("PERSISTENCE", "ATOMIC")
                status("AUDIT LOG", "\(production.auditEvents.count)")
                status("QUEUE", "\(production.pendingOperations)")
            }
            HStack {
                Button("Export diagnostics", systemImage: "square.and.arrow.up") { production.exportDiagnostics() }
                Spacer()
                Button("Reset local data", role: .destructive) { showingReset = true }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(16)
        .background(FlyeTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Reset local SYSTEM FLYE data?", isPresented: $showingReset) {
            Button("Reset", role: .destructive) { production.resetLocalData() }
        }
    }

    private func status(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(FlyeTheme.muted)
            Text(value).font(.caption.weight(.bold).monospaced())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
