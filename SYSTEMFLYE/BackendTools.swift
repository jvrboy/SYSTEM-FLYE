import Foundation
import Combine

// MARK: - Circuit Breaker
enum CircuitState { case closed, open, halfOpen }

actor CircuitBreaker {
    static let shared = CircuitBreaker()
    private let maxFailures: Int
    private let resetInterval: TimeInterval
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var state: CircuitState = .closed
    
    init(maxFailures: Int = 5, resetInterval: TimeInterval = 30) {
        self.maxFailures = maxFailures
        self.resetInterval = resetInterval
    }
    
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let currentState = await currentState()
        guard currentState != .open else { throw BackendError.circuitOpen }
        
        do {
            let result = try await operation()
            await recordSuccess()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }
    
    private func currentState() async -> CircuitState {
        guard state == .open, let lastFailure = lastFailureTime else { return state }
        if Date().timeIntervalSince(lastFailure) > resetInterval { state = .halfOpen }
        return state
    }
    
    private func recordSuccess() { failureCount = 0; state = .closed }
    private func recordFailure() { failureCount += 1; lastFailureTime = Date(); if failureCount >= maxFailures { state = .open } }
}

// MARK: - Rate Limiter
actor TokenBucketRateLimiter {
    static let shared = TokenBucketRateLimiter()
    private let capacity: Double
    private let refillRate: Double
    private var tokens: Double
    private var lastRefill: Date
    
    init(capacity: Double = 60, refillRate: Double = 1) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.tokens = capacity
        self.lastRefill = Date()
    }
    
    func waitIfNeeded() async {
        refill()
        guard tokens >= 1 else {
            let waitTime = (1 - tokens) / refillRate
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            return
        }
        tokens -= 1
    }
    
    private func refill() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        tokens = min(capacity, tokens + elapsed * refillRate)
        lastRefill = now
    }
}

// MARK: - Batch Request Coordinator
actor BatchCoordinator {
    static let shared = BatchCoordinator()
    private var pendingRequests: [UUID: (operation: () async throws -> Any, continuation: CheckedContinuation<Any, Error>)] = [:]
    private let batchLock = NSLock()
    private var batchTimer: Timer?
    private let batchWindow: TimeInterval = 0.1
    private let maxBatchSize = 10
    
    func add<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            batchLock.lock()
            pendingRequests[id] = (operation, continuation)
            if pendingRequests.count >= maxBatchSize { flush() }
            batchLock.unlock()
            if batchTimer == nil {
                batchTimer = Timer.scheduledTimer(withTimeInterval: batchWindow, repeats: false) { [weak self] _ in self?.flush() }
            }
        }
    }
    
    private func flush() {
        batchLock.lock()
        let batch = pendingRequests
        pendingRequests.removeAll()
        batchLock.unlock()
        Task {
            for (_, item) in batch { try? await item.operation() }
        }
    }
}

// MARK: - Metrics Collector
@MainActor
final class MetricsCollector: ObservableObject {
    static let shared = MetricsCollector()
    @Published private(set) var requestCount = 0
    @Published private(set) var successCount = 0
    @Published private(set) var failureCount = 0
    @Published private(set) var averageLatency: Double = 0
    @Published private(set) var p95Latency: Double = 0
    @Published private(set) var lastLatencies: [Double] = []
    private let maxLatencies = 100
    
    func record(success: Bool, latency: TimeInterval) {
        requestCount += 1
        success ? successCount += 1 : failureCount += 1
        lastLatencies.append(latency)
        if lastLatencies.count > maxLatencies { lastLatencies.removeFirst() }
        averageLatency = lastLatencies.reduce(0, +) / Double(lastLatencies.count)
        let sorted = lastLatencies.sorted()
        let p95Index = Int(Double(sorted.count) * 0.95)
        p95Latency = p95Index < sorted.count ? sorted[p95Index] : 0
    }
    
    var successRate: Double { requestCount > 0 ? Double(successCount) / Double(requestCount) : 0 }
    var failureRate: Double { requestCount > 0 ? Double(failureCount) / Double(requestCount) : 0 }
}

// MARK: - Request Interceptor
actor RequestInterceptorChain {
    static let shared = RequestInterceptorChain()
    private var interceptors: [any RequestInterceptor] = []
    
    func add<T: RequestInterceptor>(_ interceptor: T) { interceptors.append(interceptor) }
    
    func intercept(request: URLRequest) async -> URLRequest {
        var current = request
        for interceptor in interceptors { current = await interceptor.intercept(request: current) }
        return current
    }
    
    func intercept(response: (data: Data, response: HTTPURLResponse), for request: URLRequest) async -> (data: Data, response: HTTPURLResponse) {
        var current = (data: response.data, response: response.response)
        for interceptor in interceptors { current = await interceptor.intercept(response: current, for: request) }
        return current
    }
}

protocol RequestInterceptor {
    func intercept(request: URLRequest) async -> URLRequest
    func intercept(response: (data: Data, response: HTTPURLResponse), for request: URLRequest) async -> (data: Data, response: HTTPURLResponse)
}

struct LoggingInterceptor: RequestInterceptor {
    func intercept(request: URLRequest) async -> URLRequest {
        print("[HTTP] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        return request
    }
    func intercept(response: (data: Data, response: HTTPURLResponse), for request: URLRequest) async -> (data: Data, response: HTTPURLResponse) {
        print("[HTTP] \(response.response.statusCode) \(request.url?.absoluteString ?? "")")
        return response
    }
}

struct MetricsInterceptor: RequestInterceptor {
    let collector = MetricsCollector.shared
    private var startTime: Date?
    
    mutating func intercept(request: URLRequest) async -> URLRequest {
        startTime = Date()
        return request
    }
    mutating func intercept(response: (data: Data, response: HTTPURLResponse), for request: URLRequest) async -> (data: Data, response: HTTPURLResponse) {
        let latency = startTime.map { Date().timeIntervalSince($0) } ?? 0
        collector.record(success: 200...299 ~= response.response.statusCode, latency: latency)
        return response
    }
}

// MARK: - Background Sync Scheduler
actor BackgroundSyncScheduler {
    static let shared = BackgroundSyncScheduler()
    private var tasks: [String: (task: @Sendable () async -> Void, interval: TimeInterval)] = [:]
    
    func schedule(id: String, interval: TimeInterval, task: @escaping @Sendable () async -> Void) {
        tasks[id] = (task: task, interval: interval)
    }
    
    func cancel(id: String) { tasks.removeValue(forKey: id) }
    
    func runAll() async {
        for (id, item) in tasks { await item.task() }
    }
}

// MARK: - Backend Errors
enum BackendError: LocalizedError {
    case circuitOpen
    case rateLimited
    case batchTimeout
    case serviceUnavailable
    case cacheMiss
    
    var errorDescription: String? {
        switch self {
        case .circuitOpen: return "Service temporarily unavailable"
        case .rateLimited: return "Rate limit exceeded"
        case .batchTimeout: return "Batch operation timed out"
        case .serviceUnavailable: return "Service unavailable"
        case .cacheMiss: return "Cache miss"
        }
    }
}
