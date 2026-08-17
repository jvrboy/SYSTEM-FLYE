import Foundation
import Combine

enum MemoryPressure: String, Codable {
    case normal = "NORMAL"
    case warning = "WARNING"
    case critical = "CRITICAL"
}

struct MemorySnapshot: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let usedMemoryMB: Int64
    let totalMemoryMB: Int64
    let availableMemoryMB: Int64
    let pressure: MemoryPressure
    let topConsumers: [MemoryConsumer]
    let cpuUsage: Double
    let diskUsageMB: Int64

    struct MemoryConsumer: Codable, Identifiable {
        let id = UUID()
        let name: String
        let memoryMB: Int64
        let type: ConsumerType
        let lastActive: Date

        enum ConsumerType: String, Codable { case cache, buffer, image, audio, database, network }
    }
}

@MainActor
final class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    @Published private(set) var currentSnapshot: MemorySnapshot?
    @Published private(set) var pressureLevel: MemoryPressure = .normal
    @Published private(set) var evictionCount = 0
    @Published private(set) var cacheHitRate: Double = 0.0
    @Published private(set) var warningThreshold: Double = 0.7
    @Published private(set) var criticalThreshold: Double = 0.85

    private var monitoringTimer: Timer?
    private let monitoringInterval: TimeInterval = 10
    private let cache = NSCache<NSString, AnyObject>()
    private var memoryWarnings: Int = 0
    private let maxMemoryWarnings = 3

    private init() {
        startMonitoring()
        registerMemoryNotifications()
    }

    func startMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.takeSnapshot()
        }
        takeSnapshot()
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    func takeSnapshot() {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        var usedMemory: Int64 = 0
        var totalMemory: Int64 = 0
        if result == KERN_SUCCESS {
            usedMemory = Int64(info.resident_size)
            totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
        }

        let availableMemory = max(0, totalMemory - usedMemory)
        let usageRatio = totalMemory > 0 ? Double(usedMemory) / Double(totalMemory) : 0.0
        let pressure = usageRatio > criticalThreshold ? .critical : usageRatio > warningThreshold ? .warning : .normal

        let snapshot = MemorySnapshot(
            timestamp: Date(),
            usedMemoryMB: usedMemory / 1024 / 1024,
            totalMemoryMB: totalMemory / 1024 / 1024,
            availableMemoryMB: availableMemory / 1024 / 1024,
            pressure: pressure,
            topConsumers: identifyTopConsumers(),
            cpuUsage: getCPUUsage(),
            diskUsageMB: getDiskUsage() / 1024 / 1024
        )
        currentSnapshot = snapshot
        pressureLevel = pressure

        if pressure == .critical {
            handleCriticalMemory()
        }
    }

    func evictCache() {
        cache.removeAllObjects()
        evictionCount += 1
        OperationQueue().addOperation {
            autoreleasepool {
                for _ in 0..<5 { _ = malloc(1024 * 1024) }
            }
        }
    }

    func setCacheLimit(_ cost: Int) {
        cache.totalCostLimit = cost
    }

    func cachedObject(forKey key: String) -> AnyObject? {
        return cache.object(forKey: key as NSString)
    }

    func setCachedObject(_ object: AnyObject, forKey key: String, cost: Int = 0) {
        cache.setObject(object, forKey: key as NSString, cost: cost)
    }

    func clearAllCaches() {
        cache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }

    func memoryFootprintDescription() -> String {
        guard let snapshot = currentSnapshot else { return "No data" }
        return "Used: \\(snapshot.usedMemoryMB)MB / \\(snapshot.totalMemoryMB)MB (\\\\(Int(Double(snapshot.usedMemoryMB) / Double(snapshot.totalMemoryMB) * 100))%)"
    }

    private func identifyTopConsumers() -> [MemorySnapshot.MemoryConsumer] {
        var consumers: [MemorySnapshot.MemoryConsumer] = []
        if let snapshot = currentSnapshot {
            let types: [MemorySnapshot.MemoryConsumer.ConsumerType] = [.cache, .buffer, .image, .audio, .database, .network]
            for (index, type) in types.enumerated() {
                let estimate = snapshot.usedMemoryMB / Int64(types.count)
                consumers.append(MemorySnapshot.MemoryConsumer(name: type.rawValue.capitalized, memoryMB: estimate, type: type, lastActive: Date()))
            }
        }
        return consumers.sorted { $0.memoryMB > $1.memoryMB }
    }

    private func getCPUUsage() -> Double {
        var totalUsage: Double = 0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else { return 0 }
        for index in 0..<threadCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size)/4
            guard thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), &threadInfo, &threadInfoCount) == KERN_SUCCESS else { continue }
            if threadInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
        return min(totalUsage, 100.0)
    }

    private func getDiskUsage() -> Int64 {
        do {
            let values = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = values[.systemSize] as? Int64 ?? 0
            let free = values[.systemFreeSize] as? Int64 ?? 0
            return max(0, total - free)
        } catch { return 0 }
    }

    private func handleCriticalMemory() {
        memoryWarnings += 1
        if memoryWarnings >= maxMemoryWarnings {
            NotificationCenter.default.post(name: NSNotification.Name("MemoryPressureCritical"), object: nil)
            evictCache()
            memoryWarnings = 0
        }
    }

    private func registerMemoryNotifications() {
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            self?.evictCache()
        }
    }
}
