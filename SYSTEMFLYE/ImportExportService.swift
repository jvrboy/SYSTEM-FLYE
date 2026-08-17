import Foundation
import Combine
import UniformTypeIdentifiers

enum ImportExportError: LocalizedError {
    case unsupportedFormat
    case fileTooLarge
    case corruptedData
    case validationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported file format."
        case .fileTooLarge: return "File exceeds maximum allowed size."
        case .corruptedData: return "File data is corrupted."
        case .validationFailed: return "Data validation failed."
        case .permissionDenied: return "Permission to access file was denied."
        }
    }
}

enum ImportSource: Equatable {
    case file(URL)
    case clipboard
    case cloudKit
    case url(URL)

    static func == (lhs: ImportSource, rhs: ImportSource) -> Bool {
        switch (lhs, rhs) {
        case (.file(let l), .file(let r)): return l == r
        case (.clipboard, .clipboard): return true
        case (.cloudKit, .cloudKit): return true
        case (.url(let l), .url(let r)): return l == r
        default: return false
        }
    }
}

@MainActor
final class ImportExportService: ObservableObject {
    static let shared = ImportExportService()
    @Published private(set) var importQueue: [ImportJob] = []
    @Published private(set) var lastImportDate: Date?
    @Published private(set) var totalImportedRecords = 0
    @Published private(set) var validationErrors: [ValidationError] = []

    private let maxFileSize: Int64 = 100 * 1024 * 1024
    private let storage = DatabaseManager.shared
    private var importTask: Task<Void, Never>?

    struct ImportJob: Identifiable, Codable {
        let id = UUID()
        let source: ImportSource
        let format: UTType
        let recordCount: Int
        let createdAt: Date
        var status: JobStatus
        var processedRecords: Int = 0
        var errors: [String] = []

        enum JobStatus: String, Codable { case pending, processing, completed, failed }
    }

    struct ValidationError: Identifiable, Codable {
        let id = UUID()
        let rowIndex: Int
        let field: String
        let message: String
        let value: String
    }

    private init() {}

    func importFile(_ url: URL) async throws -> Int {
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        guard let data = try? Data(contentsOf: url) else { throw ImportExportError.permissionDenied }
        return try await importData(data, format: type, source: .file(url))
    }

    func importFromClipboard() async throws -> Int {
        guard let string = UIPasteboard.general.string,
              let data = string.data(using: .utf8) else { throw ImportExportError.corruptedData }
        return try await importData(data, format: .json, source: .clipboard)
    }

    func importFromCloudKit(recordID: String) async throws -> Int {
        let data = try await fetchCloudKitRecord(recordID)
        return try await importData(data, format: .json, source: .cloudKit)
    }

    func exportToCloudKit<T: Codable>(_ data: [T], recordType: String) async throws -> String {
        let payload = try JSONEncoder.flye.encode(data)
        let recordID = try await saveCloudKitRecord(payload, recordType: recordType)
        return recordID
    }

    func validateImport<T: Codable>(_ data: Data, as type: T.Type) throws -> ValidationResult {
        let decoder = JSONDecoder.flye
        do {
            _ = try decoder.decode([T].self, from: data)
            return ValidationResult(isValid: true, errors: [], recordCount: 0)
        } catch {
            let errors: [ValidationError] = []
            return ValidationResult(isValid: false, errors: errors, recordCount: 0)
        }
    }

    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let recordCount: Int
    }

    private func importData(_ data: Data, format: UTType, source: ImportSource) async throws -> Int {
        var imported = 0
        do {
            if format.conforms(to: .json) {
                imported = try importJSON(data)
            } else if format.conforms(to: .csv) {
                imported = try importCSV(data)
            } else if format.conforms(to: .xml) {
                imported = try importXML(data)
            } else {
                throw ImportExportError.unsupportedFormat
            }
            lastImportDate = Date()
            totalImportedRecords += imported
        } catch {
            throw ImportExportError.corruptedData
        }
        return imported
    }

    private func importJSON(_ data: Data) throws -> Int {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        return try storage.transaction {
            for (index, item) in jsonArray.enumerated() {
                let blob = try JSONSerialization.data(withJSONObject: item)
                try storage.execute("INSERT OR REPLACE INTO imported_data (id, data, imported_at) VALUES (:\\(index), '\\(blob.base64EncodedString())', '\\(ISO8601DateFormatter().string(from: Date()))')", parameters: ["index": "import_\\(UUID().uuidString)"])
            }
            return jsonArray.count
        }
    }

    private func importCSV(_ data: Data) throws -> Int {
        guard let csvString = String(data: data, encoding: .utf8) else { return 0 }
        let rows = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let header = rows.first else { return 0 }
        let columns = header.components(separatedBy: ",")
        var imported = 0
        for row in rows.dropFirst() {
            let values = row.components(separatedBy: ",")
            var dict: [String: String] = [:]
            for (index, column) in columns.enumerated() {
                dict[column] = index < values.count ? values[index] : ""
            }
            let blob = try JSONSerialization.data(withJSONObject: dict)
            try storage.execute("INSERT OR REPLACE INTO imported_data (id, data, imported_at) VALUES (:\\(imported), '\\(blob.base64EncodedString())', '\\(ISO8601DateFormatter().string(from: Date()))')", parameters: ["imported": "csv_\\(UUID().uuidString)"])
            imported += 1
        }
        return imported
    }

    private func importXML(_ data: Data) throws -> Int {
        guard let xmlString = String(data: data, encoding: .utf8) else { return 0 }
        let pattern = "<Item>(.*?)</Item>"
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        let matches = regex.matches(in: xmlString, options: [], range: NSRange(location: 0, length: xmlString.utf16.count))
        return try storage.transaction {
            for match in matches {
                let range = Range(match.range(at: 1), in: xmlString)!
                let itemData = String(xmlString[range]).data(using: .utf8) ?? Data()
                try storage.execute("INSERT OR REPLACE INTO imported_data (id, data, imported_at) VALUES (:\\(match.hashValue), '\\(itemData.base64EncodedString())', '\\(ISO8601DateFormatter().string(from: Date()))')", parameters: ["match": "xml_\\(UUID().uuidString)"])
            }
            return matches.count
        }
    }

    private func fetchCloudKitRecord(_ recordID: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: URL(string: "https://api.systemflye.app/v1/cloudkit/\\(recordID)")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \\(AuthService.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let data = data else { continuation.resume(throwing: ImportExportError.corruptedData); return }
                continuation.resume(returning: data)
            }.resume()
        }
    }

    private func saveCloudKitRecord(_ data: Data, recordType: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: URL(string: "https://api.systemflye.app/v1/cloudkit")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \\(AuthService.shared.authToken ?? "")", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": recordType, "data": data.base64EncodedString()])
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error { continuation.resume(throwing: error); return }
                guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let recordID = json["recordID"] as? String else {
                    continuation.resume(throwing: ImportExportError.corruptedData)
                    return
                }
                continuation.resume(returning: recordID)
            }.resume()
        }
    }
}
