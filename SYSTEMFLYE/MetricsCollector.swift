import Foundation
import Combine

enum MetricType: String, Codable {
    case performance = "PERFORMANCE"
    case network = "NETWORK"
    case memory = "MEMORY"
    case battery = "BATTERY"
    case custom = "CUSTOM"
}

struct MetricSample: Identifiable, Codable {
    let id = UUID()
    let type: MetricType
    let value: Double
    let unit: String
    let timestamp: Date
    let labels: [String: String]
    let deviceInfo: DeviceInfo

    struct DeviceInfo: Codable {
        let model: String
        let osVersion: String
        let appVersion: String
        let isLowPowerModeEnabled: Bool
        let thermalState: String
    }
}

struct MetricAggregate: Identifiable, Codable {
    let id = UUID()
    let metricName: String
    let timeWindow: TimeWindow
    let count: Int
    let min: Double
    let max: Double
    let mean: Double
    let median: Double
    let p95: Double
    let p99: Double
    let standardDeviation: Double
    let unit: String
    let collectedAt: Date

    enum TimeWindow: String, Codable {
        case oneMinute = "1m"
        case fiveMinutes = "5m"
        case fifteenMinutes = "15m"
        case oneHour = "1h"
        case oneDay = "1d"
    }
}

@MainActor
final class MetricsCollector: ObservableObject {
    static let shared = MetricsCollector()
    @Published private(set) var recentSamples: [MetricSample] = []
    @Published private(set) var aggregates: [MetricAggregate] = []
    @Published private(set) var totalSamplesCollected = 0
    @Published private(set) var exportReady = false

    private var samplesBuffer: [MetricSample] = []
    private let maxBufferSize = 1000
    private var collectionTimer: Timer?
    private var aggregationTimer: Timer?
    private let sampleInterval: TimeInterval = 5
    private let aggregateInterval: TimeInterval = 60
    private let storage = DatabaseManager.shared

    private init() {
        startCollection()
        startAggregation()
        registerSystemObservers()
    }

    func recordSample(type: MetricType, value: Double, unit: String, labels: [String: String] = [:]) {
        let sample = MetricSample(
            type: type,
            value: value,
            unit: unit,
            timestamp: Date(),
            labels: labels,
            deviceInfo: MetricSample.DeviceInfo(
                model: UIDevice.current.model,
                osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
                thermalState: String(describing: ProcessInfo.processInfo.thermalState)
            )
        )
        samplesBuffer.append(sample)
        if samplesBuffer.count > maxBufferSize { samplesBuffer.removeFirst(maxBufferSize - maxBufferSize / 4) }
        recentSamples = Array(samplesBuffer.suffix(100))
        totalSamplesCollected += 1
    }

    func recordPerformanceFrameTime(_ frameTime: Double) {
        recordSample(type: .performance, value: frameTime, unit: "ms", labels: ["metric": "frame_time"])
        if frameTime > 16.67 {
            recordSample(type: .performance, value: 1, unit: "jank", labels: ["metric": "jank_count"])
        }
    }

    func recordMemoryUsage() {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024 / 1024
            recordSample(type: .memory, value: memoryMB, unit: "MB", labels: ["metric": "resident_memory"])
        }
    }

    func recordBatteryLevel(_ level: Float) {
        recordSample(type: .battery, value: Double(level), unit: "%", labels: ["metric": "battery_level"])
    }

    func recordNetworkLatency(_ latency: Double) {
        recordSample(type: .network, value: latency, unit: "ms", labels: ["metric": "api_latency"])
    }

    func flushBuffer() {
        guard !samplesBuffer.isEmpty else { return }
        let batch = samplesBuffer
        samplesBuffer.removeAll()
        Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder.flye.encode(batch)
                try self.storage.execute("INSERT OR REPLACE INTO metrics_samples (id, data) VALUES (:\id), '\\(data.base64EncodedString())'", parameters: ["id": UUID().uuidString])
            } catch {
                print("Failed to flush metrics: \\(error)")
            }
        }
    }

    func exportCSV() -> String {
        var csv = "timestamp,type,value,unit,model,os_version\\n"
        for sample in recentSamples {
            csv += "\\(ISO8601DateFormatter().string(from: sample.timestamp)),\\(sample.type.rawValue),\\(sample.value),\\(sample.unit),\\(sample.deviceInfo.model),\\(sample.deviceInfo.osVersion)\\n"
        }
        exportReady = true
        return csv
    }

    func clearHistory() {
        samplesBuffer.removeAll()
        recentSamples.removeAll()
        aggregates.removeAll()
    }

    private func startCollection() {
        collectionTimer?.invalidate()
        collectionTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.collectSystemMetrics()
        }
        collectSystemMetrics()
    }

    private func startAggregation() {
        aggregationTimer?.invalidate()
        aggregationTimer = Timer.scheduledTimer(withTimeInterval: aggregateInterval, repeats: true) { [weak self] _ in
            self?.aggregateMetrics()
        }
    }

    private func collectSystemMetrics() {
        recordMemoryUsage()
        UIDevice.current.isBatteryMonitoringEnabled = true
        recordBatteryLevel(UIDevice.current.batteryLevel)
        if let latency = BackendServiceManager.shared.services.first?.latency {
            recordNetworkLatency(latency * 1000)
        }
    }

    private func aggregateMetrics() {
        let window: MetricAggregate.TimeWindow = .oneMinute
        let cutoff = Date().addingTimeInterval(-60)
        let windowSamples = samplesBuffer.filter { $0.timestamp > cutoff }

        let grouped = Dictionary(grouping: windowSamples) { $0.type.rawValue }
        for (name, samples) in grouped {
            let values = samples.map { $0.value }.sorted()
            guard let min = values.first, let max = values.last else { continue }
            let mean = values.reduce(0, +) / Double(values.count)
            let median = values[values.count / 2]
            let p95 = values[Int(Double(values.count) * 0.95)]
            let p99 = values[Int(Double(values.count) * 0.99)]
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            let stdDev = sqrt(variance)
            let aggregate = MetricAggregate(
                metricName: name,
                timeWindow: window,
                count: values.count,
                min: min,
                max: max,
                mean: mean,
                median: median,
                p95: p95,
                p99: p99,
                standardDeviation: stdDev,
                unit: samples.first?.unit ?? "",
                collectedAt: Date()
            )
            aggregates.append(aggregate)
            if aggregates.count > 200 { aggregates.removeFirst(aggregates.count - 200) }
        }
    }

    private func registerSystemObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.flushBuffer()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.startCollection()
        }
    }
}
