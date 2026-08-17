import Foundation
import Combine
import CloudKit

enum CloudSyncError: LocalizedError {
    case accountNotAvailable
    case permissionDenied
    case quotaExceeded
    case conflictResolutionFailed
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable: return "iCloud account is not available."
        case .permissionDenied: return "iCloud permission was denied."
        case .quotaExceeded: return "iCloud quota exceeded."
        case .conflictResolutionFailed: return "Failed to resolve sync conflict."
        case .networkUnavailable: return "Network unavailable for sync."
        }
    }
}

enum SyncConflictResolution: String, Codable {
    case latestWins = "LATEST_WINS"
    case localWins = "LOCAL_WINS"
    case remoteWins = "REMOTE_WINS"
    case merge = "MERGE"
}

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChanges = 0
    @Published private(set) var syncConflicts: [SyncConflict] = []
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    private let container = CKContainer(identifier: "iCloud.com.jvrboy.systemflye")
    private let privateDatabase: CKDatabase
    private let resolutionStrategy: SyncConflictResolution = .latestWins
    private var syncTask: Task<Void, Never>?
    private let storage = DatabaseManager.shared

    struct SyncConflict: Identifiable, Codable {
        let id = UUID()
        let recordID: String
        let localData: Data
        let remoteData: Data
        let localModifiedAt: Date
        let remoteModifiedAt: Date
        var resolved: Bool = false
        var resolution: SyncConflictResolution?
    }

    private init() {
        privateDatabase = container.privateCloudDatabase
        checkAccountStatus()
        startPeriodicSync()
    }

    func sync() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard accountStatus == .available else { throw CloudSyncError.accountNotAvailable }

        do {
            try await fetchRemoteChanges()
            try await pushLocalChanges()
            lastSyncDate = Date()
        } catch {
            throw CloudSyncError.networkUnavailable
        }
    }

    func resolveConflict(_ conflict: SyncConflict, with resolution: SyncConflictResolution) async throws {
        var updated = conflict
        updated.resolved = true
        updated.resolution = resolution
        if let index = syncConflicts.firstIndex(where: { $0.id == conflict.id }) {
            syncConflicts[index] = updated
        }
        let data: Data
        switch resolution {
        case .latestWins:
            data = conflict.localModifiedAt > conflict.remoteModifiedAt ? conflict.localData : conflict.remoteData
        case .localWins: data = conflict.localData
        case .remoteWins: data = conflict.remoteData
        case .merge:
            let local = try? JSONDecoder.flye.decode([String: CloudAnyCodable].self, from: conflict.localData)
            let remote = try? JSONDecoder.flye.decode([String: CloudAnyCodable].self, from: conflict.remoteData)
            let merged = mergeDictionaries(local ?? [:], remote ?? [:])
            data = try JSONSerialization.data(withJSONObject: merged)
        }
        try storage.execute("UPDATE sync_state SET data = '\\(data.base64EncodedString())', resolved = 1 WHERE record_id = '\\(conflict.recordID)'", parameters: [:])
    }

    func pauseSync() { syncTask?.cancel(); syncTask = nil }
    func resumeSync() { startPeriodicSync() }

    private func fetchRemoteChanges() async throws {
        let query = CKQuery(recordType: "SYSTEMFLYE_Sync", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: CKRecord.SystemRecordKey.modificationDate.rawValue, ascending: false)]
        let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: nil)
        for (_, record) in results where !record.hasBeenDeleted {
            guard let recordData = record["data"] as? Data else { continue }
            let localData = try? storage.query("SELECT data FROM sync_state WHERE record_id = '\\(record.recordID.recordName)'", parameters: [:]) { row in row.data(at: 0) ?? Data() }
            if let local = localData?.first, local != recordData {
                let conflict = SyncConflict(
                    recordID: record.recordID.recordName,
                    localData: local,
                    remoteData: recordData,
                    localModifiedAt: Date(timeIntervalSince1970: Double(record.modificationDate?.timeIntervalSince1970 ?? 0)),
                    remoteModifiedAt: record.modificationDate ?? Date()
                )
                syncConflicts.append(conflict)
            }
        }
    }

    private func pushLocalChanges() async throws {
        let pendingRecords = try storage.query("SELECT id, data FROM sync_state WHERE synced = 0", parameters: [:]) { row in
            return (id: row.string(at: 0) ?? "", data: row.data(at: 0) ?? Data())
        }
        for (id, data) in pendingRecords {
            let record = CKRecord(recordType: "SYSTEMFLYE_Sync", recordID: CKRecord.ID(recordName: id))
            record["data"] = data as CKRecordValue
            record["modified_at"] = Date() as CKRecordValue
            _ = try await privateDatabase.save(record)
            try storage.execute("UPDATE sync_state SET synced = 1 WHERE id = '\\(id)'", parameters: [:])
            pendingChanges = max(0, pendingChanges - 1)
        }
    }

    private func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            Task { @MainActor in
                self?.accountStatus = status
                if status != .available {
                    self?.isSyncing = false
                }
            }
        }
    }

    private func startPeriodicSync() {
        syncTask?.cancel()
        syncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(600))
                try? await sync()
            }
        }
    }

    private func mergeDictionaries(_ lhs: [String: CloudAnyCodable], _ rhs: [String: CloudAnyCodable]) -> [String: CloudAnyCodable] {
        var merged = lhs
        for (key, value) in rhs {
            if let lhsValue = lhs[key] {
                if let lhsDict = lhsValue.dictionary, let rhsDict = value.dictionary {
                    merged[key] = CloudAnyCodable(mergeDictionaries(lhsDict, rhsDict))
                } else {
                    merged[key] = CloudAnyCodable(Date().timeIntervalSince1970 > lhs[key]?.doubleValue ?? 0 ? value : lhsValue)
                }
            } else {
                merged[key] = value
            }
        }
        return merged
    }
}

struct CloudAnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let dict = try? container.decode([String: CloudAnyCodable].self) { value = dict }
        else if let array = try? container.decode([CloudAnyCodable].self) { value = array.map { $0.value } }
        else { value = NSNull() }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let string = value as? String { try container.encode(string) }
        else if let bool = value as? Bool { try container.encode(bool) }
        else if let dict = value as? [String: CloudAnyCodable] { try container.encode(dict) }
        else if let array = value as? [Any] { try container.encode(array.map { CloudAnyCodable($0) }) }
        else { try container.encodeNil() }
    }

    var stringValue: String { "\(value)" }
    var intValue: Int { (value as? Int) ?? 0 }
    var doubleValue: Double { (value as? Double) ?? 0.0 }
    var boolValue: Bool { (value as? Bool) ?? false }
    var arrayValue: [Any] { (value as? [Any]) ?? [] }
    var dictionaryValue: [String: CloudAnyCodable] { (value as? [String: CloudAnyCodable]) ?? [:] }
}
