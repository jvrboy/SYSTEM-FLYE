import Foundation
import Combine

enum ExportFormat: String, Codable, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case pdf = "PDF"
    case xlsx = "XLSX"
    case sqlite = "SQLITE"
    case xml = "XML"
    case yaml = "YAML"

    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .pdf: return "application/pdf"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .sqlite: return "application/x-sqlite3"
        case .xml: return "application/xml"
        case .yaml: return "application/x-yaml"
        }
    }
}

enum ExportError: LocalizedError {
    case noData
    case encodingFailed
    case writeFailed
    case unsupportedFormat
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .noData: return "No data available for export."
        case .encodingFailed: return "Failed to encode data."
        case .writeFailed: return "Failed to write export file."
        case .unsupportedFormat: return "Unsupported export format."
        case .quotaExceeded: return "Export quota exceeded."
        }
    }
}

struct ExportJob: Identifiable, Codable {
    let id = UUID()
    let format: ExportFormat
    let dataDescription: String
    let recordCount: Int
    let createdAt: Date
    var status: ExportStatus
    var fileURL: String?
    var fileSize: Int64?
    var error: String?

    enum ExportStatus: String, Codable { case pending, processing, completed, failed }
}

@MainActor
final class DataExporter: ObservableObject {
    static let shared = DataExporter()
    @Published private(set) var exportQueue: [ExportJob] = []
    @Published private(set) var completedExports: [ExportJob] = []
    @Published private(set) var isExporting = false
    @Published private(set) var totalExportedBytes: Int64 = 0

    private let maxQueueSize = 10
    private let maxFileSize: Int64 = 50 * 1024 * 1024
    private let storage = DatabaseManager.shared

    private init() {
        loadExportHistory()
    }

    func export<T: Codable>(_ data: [T], format: ExportFormat, filename: String) async throws -> URL {
        guard !data.isEmpty else { throw ExportError.noData }
        guard data.count < 100000 else { throw ExportError.quotaExceeded }

        let job = ExportJob(format: format, dataDescription: filename, recordCount: data.count, createdAt: Date(), status: .pending)
        exportQueue.append(job)
        isExporting = true
        defer { isExporting = false }

        let url = try await generateExportFile(data: data, format: format, filename: filename)
        job.status = .completed
        job.fileURL = url.path
        job.fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64)
        totalExportedBytes += job.fileSize ?? 0
        completedExports.insert(job, at: 0)
        if completedExports.count > 100 { completedExports.removeLast() }
        if let index = exportQueue.firstIndex(where: { $0.id == job.id }) { exportQueue.remove(at: index) }
        return url
    }

    func shareExport(_ job: ExportJob) {
        guard let path = job.fileURL, let url = URL(string: "file://\\(path)") else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let presenter = scene.windows.first?.rootViewController {
            presenter.present(activityVC, animated: true)
        }
    }

    func deleteExport(_ job: ExportJob) {
        if let path = job.fileURL { try? FileManager.default.removeItem(atPath: path) }
        if let index = completedExports.firstIndex(where: { $0.id == job.id }) { completedExports.remove(at: index) }
    }

    func clearHistory() {
        for job in completedExports { deleteExport(job) }
        completedExports.removeAll()
    }

    private func generateExportFile<T: Codable>(data: [T], format: ExportFormat, filename: String) async throws -> URL {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: Date()).prefix(10)
        let fileName = "\\(filename)_\\(dateString).\\(format.rawValue.lowercased())"
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SYSTEMFLYE/Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(fileName)

        switch format {
        case .json:
            let jsonData = try JSONEncoder.flye.encode(data)
            try jsonData.write(to: fileURL)
        case .csv:
            let csv = try generateCSV(from: data)
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        case .pdf:
            let pdfData = try generatePDF(from: data, filename: filename)
            try pdfData.write(to: fileURL)
        case .xlsx:
            let xlsxData = try generateXLSX(from: data)
            try xlsxData.write(to: fileURL)
        case .sqlite:
            try generateSQLite(from: data, to: fileURL)
        case .xml:
            let xml = try generateXML(from: data, rootElement: filename)
            try xml.write(to: fileURL, atomically: true, encoding: .utf8)
        case .yaml:
            let yaml = try generateYAML(from: data)
            try yaml.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return fileURL
    }

    private func generateCSV<T: Codable>(from data: [T]) throws -> String {
        guard let first = data.first else { return "" }
        let mirror = Mirror(reflecting: first)
        let headers = mirror.children.compactMap { $0.label }.joined(separator: ",")
        var csv = headers + "\\n"
        for item in data {
            let itemMirror = Mirror(reflecting: item)
            let values = itemMirror.children.map { "\\"\\(String(describing: $0.value).replacingOccurrences(of: "\\"", with: "\\\\\\""))\\"" }.joined(separator: ",")
            csv += values + "\\n"
        }
        return csv
    }

    private func generatePDF(from data: [Any], filename: String) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24)]
            ("SYSTEM FLYE Export: \\(filename)" as NSString).draw(in: CGRect(x: 36, y: 36, width: 540, height: 40), withAttributes: titleAttributes)
            var yOffset: CGFloat = 100
            for item in data.prefix(500) {
                let string = String(describing: item)
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10)]
                (string as NSString).draw(in: CGRect(x: 36, y: yOffset, width: 540, height: 14), withAttributes: attrs)
                yOffset += 18
                if yOffset > 750 { context.beginPage(); yOffset = 36 }
            }
        }
        return data
    }

    private func generateXLSX(from data: [Any]) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\\n"
        xml += "<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\">"
        xml += "<Worksheet ss:Name=\"Sheet1\"><Table>"
        if let first = data.first {
            let mirror = Mirror(reflecting: first)
            xml += "<Row>"
            for child in mirror.children { if let label = child.label { xml += "<Cell><Data ss:Type=\"String\">\\(label)</Data></Cell>" } }
            xml += "</Row>"
        }
        for item in data.prefix(10000) {
            let mirror = Mirror(reflecting: item)
            xml += "<Row>"
            for child in mirror.children {
                let value = String(describing: child.value).replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                xml += "<Cell><Data ss:Type=\"String\">\\(value)</Data></Cell>"
            }
            xml += "</Row>"
        }
        xml += "</Table></Worksheet></Workbook>"
        return xml.data(using: .utf8) ?? Data()
    }

    private func generateSQLite(from data: [Any], to url: URL) throws {
        var db: OpaquePointer?
        let path = url.path
        guard sqlite3_open(path, &db) == SQLITE_OK else { throw ExportError.writeFailed }
        defer { if let db = db { sqlite3_close(db) } }
        guard let first = data.first else { return }
        let mirror = Mirror(reflecting: first)
        var createTable = "CREATE TABLE export ("
        var columns: [String] = []
        for child in mirror.children {
            if let label = child.label { columns.append("\\(label) TEXT") }
        }
        createTable += columns.joined(separator: ", ") + ")"
        sqlite3_exec(db, createTable, nil, nil, nil)
        for item in data.prefix(50000) {
            let itemMirror = Mirror(reflecting: item)
            let values = itemMirror.children.map { "'\\(String(describing: $0.value).replacingOccurrences(of: "'", with: "\\\\'"))'" }.joined(separator: ", ")
            let cols = itemMirror.children.compactMap { $0.label }.joined(separator: ", ")
            sqlite3_exec(db, "INSERT INTO export (\\(cols)) VALUES (\\(values))", nil, nil, nil)
        }
    }

    private func generateXML<T: Codable>(from data: [T], rootElement: String) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Root>"
        for item in data {
            xml += "<Item>"
            let mirror = Mirror(reflecting: item)
            for child in mirror.children {
                if let label = child.label {
                    let value = String(describing: child.value).replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                    xml += "<\\(label)>\\(value)</\\(label)>"
                }
            }
            xml += "</Item>"
        }
        xml += "</Root>"
        return xml.data(using: .utf8) ?? Data()
    }

    private func generateYAML(from data: [Any]) throws -> String {
        var yaml = ""
        for item in data.prefix(10000) {
            yaml += "- "
            let mirror = Mirror(reflecting: item)
            var properties: [String] = []
            for child in mirror.children {
                if let label = child.label {
                    let value = String(describing: child.value).replacingOccurrences(of: "\"", with: "\\\\\"")
                    properties.append("\\(label): \"\\(value)\"")
                }
            }
            yaml += "{ \\(properties.joined(separator: ", ")) }\\n"
        }
        return yaml
    }

    private func loadExportHistory() {
        guard let data = UserDefaults.standard.data(forKey: "export_history"),
              let history = try? JSONDecoder.flye.decode([ExportJob].self, from: data) else { return }
        completedExports = history.filter { $0.status == .completed }
    }
}
