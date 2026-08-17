import Foundation
import Combine

enum LogLevel: String, Codable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs), let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

struct LogEntry: Identifiable, Codable {
    let id = UUID()
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: String]
    let timestamp: Date
    let fileName: String?
    let functionName: String?
    let lineNumber: Int?
    let threadId: String
    let processId: Int32
}

@MainActor
final class LoggingService: ObservableObject {
    static let shared = LoggingService()
    @Published private(set) var recentLogs: [LogEntry] = []
    @Published private(set) var logCounts: [LogLevel: Int] = [:]
    @Published private(set) var isLoggingPaused = false

    private var logBuffer: [LogEntry] = []
    private let maxBufferSize = 2000
    private let maxFileSize: Int64 = 5 * 1024 * 1024
    private let maxLogFiles = 5
    private let queue = DispatchQueue(label: "logging.queue", qos: .utility, attributes: .concurrent)
    private let storage = DatabaseManager.shared
    private var fileHandle: FileHandle?
    private var logFileURL: URL?

    private init() {
        setupLogFile()
        registerSignalHandlers()
    }

    func log(_ level: LogLevel, category: String, message: String, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        guard !isLoggingPaused else { return }
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            timestamp: Date(),
            fileName: (file as NSString).lastPathComponent,
            functionName: function,
            lineNumber: line,
            threadId: Thread.current.description,
            processId: getpid()
        )
        queue.async(flags: .barrier) { [weak self] in
            self?.logBuffer.append(entry)
            if self?.logBuffer.count ?? 0 > self?.maxBufferSize ?? 2000 {
                self?.logBuffer.removeFirst((self?.logBuffer.count ?? 0) - self?.maxBufferSize! / 4)
            }
        }
        Task { @MainActor in
            self.recentLogs = Array(self.logBuffer.suffix(200))
            self.logCounts[level, default: 0] += 1
        }
        writeToFile(entry)
        if level == .critical {
            sendCriticalAlert(entry)
        }
    }

    func debug(_ message: String, category: String = "general", file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, category: String = "general", file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: String = "general", file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, category: String = "general", error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var metadata: [String: String] = [:]
        if let error = error { metadata["error_domain"] = (error as NSError).domain; metadata["error_code"] = "\\((error as NSError).code)" }
        log(.error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: String = "general", file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message: message, file: file, function: function, line: line)
    }

    func search(query: String, levels: [LogLevel]? = nil, category: String? = nil) -> [LogEntry] {
        var results = logBuffer
        if let levels = levels { results = results.filter { levels.contains($0.level) } }
        if let category = category { results = results.filter { $0.category == category } }
        if !query.isEmpty { results = results.filter { $0.message.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) } }
        return results.sorted { $0.timestamp > $1.timestamp }
    }

    func exportLogs(format: ExportFormat) -> Data? {
        let logsToExport = recentLogs
        switch format {
        case .json:
            return try? JSONEncoder.flye.encode(logsToExport)
        case .csv:
            var csv = "timestamp,level,category,message,file,function,line\\n"
            for entry in logsToExport {
                csv += "\\(ISO8601DateFormatter().string(from: entry.timestamp)),\\(entry.level.rawValue),\\(entry.category),\\"\\(entry.message.replacingOccurrences(of: "\\"", with: "\\\\\\""))\\",\\(entry.fileName ?? ""),\\(entry.functionName ?? ""),\\(entry.lineNumber ?? 0)\\n"
            }
            return csv.data(using: .utf8)
        case .plainText:
            return logsToExport.map { "[\\\($0.level.rawValue)] [\\($0.category)] \\($0.message)" }.joined(separator: "\\n").data(using: .utf8)
        }
    }

    func clearLogs() {
        queue.async(flags: .barrier) { [weak self] in
            self?.logBuffer.removeAll()
        }
        recentLogs.removeAll()
        logCounts.removeAll()
        rotateLogFile()
    }

    enum ExportFormat: String { case json, csv, plainText }

    private func setupLogFile() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let logDirectory = paths[0].appendingPathComponent("SYSTEMFLYE/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        logFileURL = logDirectory.appendingPathComponent("systemflye_\\(ISO8601DateFormatter().string(from: Date()).prefix(10)).log")
        if let url = logFileURL { fileHandle = try? FileHandle(forWritingTo: url) }
    }

    private func writeToFile(_ entry: LogEntry) {
        guard let fileHandle = fileHandle, let url = logFileURL else { return }
        let line = "[\\\(entry.level.rawValue)] [\\(entry.timestamp)] [\\(entry.category)] \\(entry.message)\\n"
        if let data = line.data(using: .utf8) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.synchronizeFile()
            if (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0) ?? 0 > maxFileSize {
                rotateLogFile()
            }
        }
    }

    private func rotateLogFile() {
        fileHandle?.closeFile()
        guard let url = logFileURL else { return }
        let rotatedURL = url.appendingPathExtension("\\(ISO8601DateFormatter().string(from: Date()).prefix(10)).log")
        try? FileManager.default.moveItem(at: url, to: rotatedURL)
        setupLogFile()
    }

    private func sendCriticalAlert(_ entry: LogEntry) {
        Task.detached {
            let content = UNMutableNotificationContent()
            content.title = "SYSTEM FLYE Critical"
            content.body = entry.message
            content.sound = .critical
            let request = UNNotificationRequest(identifier: entry.id.uuidString, content: content, trigger: nil)
            try? UNUserNotificationCenter.current().add(request)
        }
    }

    private func registerSignalHandlers() {
        signal(SIGABRT) { _ in LoggingService.shared.critical("SIGABRT received", category: "signal") exit(1) }
        signal(SIGILL) { _ in LoggingService.shared.critical("SIGILL received", category: "signal") exit(1) }
        signal(SIGSEGV) { _ in LoggingService.shared.critical("SIGSEGV received", category: "signal") exit(1) }
        signal(SIGBUS) { _ in LoggingService.shared.critical("SIGBUS received", category: "signal") exit(1) }
    }
}
