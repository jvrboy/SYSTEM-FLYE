import Foundation
import Combine

struct CrashReport: Identifiable, Codable {
    let id = UUID()
    let exceptionType: String
    let exceptionReason: String
    let stackTrace: [StackFrame]
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
    let timestamp: Date
    let isSimulator: Bool
    let memoryUsage: Int64
    let diskUsage: Int64

    struct StackFrame: Codable, Identifiable {
        let id = UUID()
        let binaryName: String
        let address: UInt64
        let symbol: String
        let fileName: String?
        let lineNumber: Int?
    }

    struct DeviceInfo: Codable {
        let model: String
        let systemName: String
        let systemVersion: String
        let identifier: String
        let batteryLevel: Double
        let isPluggedIn: Bool
    }

    struct AppInfo: Codable {
        let version: String
        let build: String
        let bundleIdentifier: String
    }
}

@MainActor
final class CrashReporter: ObservableObject {
    static let shared = CrashReporter()
    @Published private(set) var recentCrashes: [CrashReport] = []
    @Published private(set) var crashCount = 0
    @Published private(set) var lastCrashDate: Date?
    @Published private(set) var isMonitoringEnabled = true

    private let storage = DatabaseManager.shared
    private var isRecording = false

    private init() {
        loadCrashHistory()
    }

    func startMonitoring() {
        guard !isRecording else { return }
        isRecording = true
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.recordException(exception)
        }
        setupSignalHandlers()
    }

    func recordException(_ exception: NSException) {
        let report = buildCrashReport(
            exceptionType: exception.name.rawValue,
            exceptionReason: exception.reason ?? "No reason provided",
            stackTrace: exception.callStackReturnAddresses.enumerated().map { index, address in
                CrashReport.StackFrame(
                    binaryName: "unknown",
                    address: address.uintValue,
                    symbol: "frame_\\(index)",
                    fileName: nil,
                    lineNumber: nil
                )
            }
        )
        saveCrashReport(report)
    }

    func recordFatalError(message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let report = buildCrashReport(
            exceptionType: "FATAL_ERROR",
            exceptionReason: message,
            stackTrace: [
                CrashReport.StackFrame(
                    binaryName: (file as NSString).lastPathComponent,
                    address: 0,
                    symbol: function,
                    fileName: file,
                    lineNumber: line
                )
            ]
        )
        saveCrashReport(report)
    }

    func exportReports() -> Data? {
        return try? JSONEncoder.flye.encode(recentCrashes)
    }

    func clearHistory() {
        recentCrashes.removeAll()
        crashCount = 0
        lastCrashDate = nil
        try? storage.execute("DELETE FROM crash_reports")
    }

    private func buildCrashReport(exceptionType: String, exceptionReason: String, stackTrace: [CrashReport.StackFrame]) -> CrashReport {
        let device = UIDevice.current
        let app = Bundle.main
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return CrashReport(
            exceptionType: exceptionType,
            exceptionReason: exceptionReason,
            stackTrace: stackTrace,
            deviceInfo: CrashReport.DeviceInfo(
                model: device.model,
                systemName: device.systemName,
                systemVersion: device.systemVersion,
                identifier: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                batteryLevel: Double(device.batteryLevel),
                isPluggedIn: device.batteryState == .charging || device.batteryState == .full
            ),
            appInfo: CrashReport.AppInfo(
                version: app.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                build: app.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                bundleIdentifier: app.bundleIdentifier ?? "unknown"
            ),
            timestamp: Date(),
            isSimulator: false,
            memoryUsage: getMemoryUsage(),
            diskUsage: getDiskUsage()
        )
    }

    private func saveCrashReport(_ report: CrashReport) {
        recentCrashes.append(report)
        crashCount += 1
        lastCrashDate = report.timestamp
        if let data = try? JSONEncoder.flye.encode(report) {
            try? storage.execute("INSERT OR REPLACE INTO crash_reports (id, data) VALUES (:\id), '\\(data.base64EncodedString())'", parameters: ["id": report.id.uuidString])
        }
    }

    private func loadCrashHistory() {
        do {
            let reports = try storage.query("SELECT data FROM crash_reports ORDER BY timestamp DESC LIMIT 50", parameters: [:]) { row in
                guard let data = row.data(at: 0) else { return CrashReport(
                    exceptionType: "", exceptionReason: "", stackTrace: [], deviceInfo: CrashReport.DeviceInfo(model: "", systemName: "", systemVersion: "", identifier: "", batteryLevel: 0, isPluggedIn: false),
                    appInfo: CrashReport.AppInfo(version: "", build: "", bundleIdentifier: ""), timestamp: Date(), isSimulator: false, memoryUsage: 0, diskUsage: 0
                )}
                return try JSONDecoder.flye.decode(CrashReport.self, from: data)
            }
            recentCrashes = reports
            crashCount = reports.count
            if let last = reports.first { lastCrashDate = last.timestamp }
        } catch {
            print("Failed to load crash history: \\(error)")
        }
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    private func getDiskUsage() -> Int64 {
        do {
            let values = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return values[.systemSize] as? Int64 ?? 0
        } catch { return 0 }
    }

    private func setupSignalHandlers() {
        signal(SIGABRT) { _ in
            CrashReporter.shared.recordFatalError(message: "SIGABRT")
            exit(1)
        }
        signal(SIGILL) { _ in
            CrashReporter.shared.recordFatalError(message: "SIGILL")
            exit(1)
        }
    }
}
