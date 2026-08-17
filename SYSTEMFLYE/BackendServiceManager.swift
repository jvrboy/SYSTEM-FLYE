import Foundation
import Combine

// MARK: - Service Health
enum ServiceHealth: String { case healthy = "HEALTHY", degraded = "DEGRADED", down = "DOWN", unknown = "UNKNOWN" }

struct ServiceDescriptor: Identifiable, Codable {
    let id: UUID
    let name: String
    let endpoint: String
    var health: ServiceHealth
    var lastChecked: Date
    var latency: TimeInterval
    var uptime: Double
}

// MARK: - Service Manager
@MainActor
final class BackendServiceManager: ObservableObject {
    static let shared = BackendServiceManager()
    @Published private(set) var services: [ServiceDescriptor] = []
    @Published private(set) var overallHealth: ServiceHealth = .healthy
    @Published private(set) var activeConnections = 0
    @Published private(set) var totalDataTransferred: Int64 = 0
    private var healthTimer: Timer?
    private let healthCheckInterval: TimeInterval = 15
    
    init() {
        registerDefaultServices()
        startHealthChecks()
    }
    
    func registerDefaultServices() {
        services = [
            ServiceDescriptor(id: UUID(), name: "Market Data API", endpoint: "/v3/pricing", health: .healthy, lastChecked: Date(), latency: 0.12, uptime: 99.9),
            ServiceDescriptor(id: UUID(), name: "Historical Data", endpoint: "/v3/instruments", health: .healthy, lastChecked: Date(), latency: 0.34, uptime: 99.5),
            ServiceDescriptor(id: UUID(), name: "Auth Service", endpoint: "/v3/accounts", health: .healthy, lastChecked: Date(), latency: 0.08, uptime: 99.99),
            ServiceDescriptor(id: UUID(), name: "Signal Engine", endpoint: "local://signals", health: .healthy, lastChecked: Date(), latency: 0.02, uptime: 100.0),
            ServiceDescriptor(id: UUID(), name: "Offline Queue", endpoint: "local://queue", health: .healthy, lastChecked: Date(), latency: 0.01, uptime: 100.0)
        ]
    }
    
    func startHealthChecks() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { await self?.performHealthChecks() }
        }
        performHealthChecks()
    }
    
    func performHealthChecks() async {
        for index in services.indices {
            services[index].lastChecked = Date()
            services[index].latency = Double.random(in: 0.01...0.5)
            if services[index].uptime < 95 {
                services[index].health = .degraded
            } else if Double.random(in: 0...100) < 0.1 {
                services[index].health = .degraded
            } else {
                services[index].health = .healthy
            }
        }
        overallHealth = services.allSatisfy { $0.health == .healthy } ? .healthy : .degraded
        totalDataTransferred += Int64.random(in: 1024...10240)
    }
    
    func incrementConnections() { activeConnections += 1 }
    func decrementConnections() { if activeConnections > 0 { activeConnections -= 1 } }
    
    func transferData(bytes: Int64) { totalDataTransferred += bytes }
    
    func formattedDataTransferred() -> String {
        if totalDataTransferred > 1_048_576 { return String(format: "%.1f MB", Double(totalDataTransferred) / 1_048_576) }
        if totalDataTransferred > 1024 { return String(format: "%.1f KB", Double(totalDataTransferred) / 1024) }
        return "\(totalDataTransferred) B"
    }
}

// MARK: - Data Pipeline
@MainActor
final class DataPipeline: ObservableObject {
    static let shared = DataPipeline()
    @Published private(set) var stages: [PipelineStage] = []
    @Published private(set) var isRunning = false
    @Published private(set) var throughput: Double = 0
    
    func runPipeline() async {
        isRunning = true
        stages = [
            PipelineStage(name: "Fetch market data", status: .queued, progress: 0),
            PipelineStage(name: "Validate schema", status: .queued, progress: 0),
            PipelineStage(name: "Compute indicators", status: .queued, progress: 0),
            PipelineStage(name: "Generate signals", status: .queued, progress: 0),
            PipelineStage(name: "Persist results", status: .queued, progress: 0)
        ]
        
        for i in stages.indices {
            stages[i].status = .running
            for p in stride(from: 0, to: 100, by: 10) {
                stages[i].progress = Double(p)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            stages[i].status = .complete
            stages[i].progress = 100
            throughput = Double.random(in: 50...500)
        }
        isRunning = false
    }
    
    func reset() { stages.removeAll(); isRunning = false }
}

struct PipelineStage: Identifiable {
    let id = UUID()
    let name: String
    var status: StageStatus
    var progress: Double
    
    enum StageStatus: String { case queued = "QUEUED", running = "RUNNING", complete = "COMPLETE", failed = "FAILED" }
}

// MARK: - Cache Manager
actor CacheManager {
    static let shared = CacheManager()
    private let memoryCache = NSCache<NSString, AnyObject>()
    private let diskQueue = DispatchQueue(label: "cache.disk", qos: .background)
    private let cacheDirectory: URL
    
    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = base.appendingPathComponent("SYSTEMFLYE/cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func set<T: Codable>(_ value: T, for key: String, ttl: TimeInterval = 3600) {
        memoryCache.setObject(value as AnyObject, forKey: key as NSString)
        diskQueue.async { [weak self] in
            guard let data = try? JSONEncoder.flye.encode(value) else { return }
            let fileURL = self?.cacheDirectory.appendingPathComponent("\(key.hash).cache")
            try? data.write(to: fileURL!, options: .atomic)
            try? FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(ttl)], ofItemAtPath: fileURL!.path)
        }
    }
    
    func get<T: Codable>(_ type: T.Type, for key: String) -> T? {
        if let cached = memoryCache.object(forKey: key as NSString) as? T { return cached }
        let fileURL = cacheDirectory.appendingPathComponent("\(key.hash).cache")
        guard let data = try? Data(contentsOf: fileURL), let value = try? JSONDecoder.flye.decode(T.self, from: data) else { return nil }
        memoryCache.setObject(value as AnyObject, forKey: key as NSString)
        return value
    }
    
    func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
    }
}
