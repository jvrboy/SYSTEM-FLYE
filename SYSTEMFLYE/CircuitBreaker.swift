import Foundation
import Combine

enum CircuitBreakerState: String, Codable {
    case closed = "CLOSED"
    case open = "OPEN"
    case halfOpen = "HALF_OPEN"
}

enum CircuitBreakerError: LocalizedError {
    case circuitOpen
    case tooManyFailures
    case timeoutExceeded

    var errorDescription: String? {
        switch self {
        case .circuitOpen: return "Circuit breaker is open. Requests are not allowed."
        case .tooManyFailures: return "Too many failures detected."
        case .timeoutExceeded: return "Operation timed out."
        }
    }
}

struct CircuitBreakerConfig: Codable {
    let failureThreshold: Int
    let recoveryTimeout: TimeInterval
    let monitoringPeriod: TimeInterval
    let halfOpenMaxCalls: Int
}

@MainActor
final class CircuitBreaker: ObservableObject {
    static let shared = CircuitBreaker()
    @Published private(set) var state: CircuitBreakerState = .closed
    @Published private(set) var failureCount = 0
    @Published private(set) var lastFailureDate: Date?
    @Published private(set) var halfOpenCalls = 0
    @Published private(set) var successCount = 0
    @Published private(set) var failureRate: Double = 0.0

    private let config: CircuitBreakerConfig
    private let failureHistory: [Date]
    private var stateTransitionTimer: Timer?
    private var metricsTimer: Timer?
    private let queue = DispatchQueue(label: "circuit.breaker", attributes: .concurrent)

    private init() {
        config = CircuitBreakerConfig(
            failureThreshold: 5,
            recoveryTimeout: 30,
            monitoringPeriod: 60,
            halfOpenMaxCalls: 3
        )
        failureHistory = []
        startStateMonitoring()
        startMetricsCollection()
    }

    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if let lastFailure = lastFailureDate, Date().timeIntervalSince(lastFailure) > config.recoveryTimeout {
                transition(to: .halfOpen)
                halfOpenCalls = 0
            } else {
                throw CircuitBreakerError.circuitOpen
            }
        case .halfOpen:
            if halfOpenCalls >= config.halfOpenMaxCalls {
                throw CircuitBreakerError.circuitOpen
            }
        case .closed: break
        }

        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }

    func currentState() -> CircuitBreakerState { state }
    func failureRateInPeriod() -> Double {
        let cutoff = Date().addingTimeInterval(-config.monitoringPeriod)
        let recent = failureHistory.filter { $0 > cutoff }
        return Double(recent.count) / Double(config.failureThreshold)
    }

    func reset() {
        failureCount = 0
        successCount = 0
        halfOpenCalls = 0
        lastFailureDate = nil
        transition(to: .closed)
    }

    private func recordSuccess() {
        successCount += 1
        switch state {
        case .halfOpen:
            halfOpenCalls += 1
            if halfOpenCalls >= config.halfOpenMaxCalls {
                reset()
            }
        case .closed:
            let cutoff = Date().addingTimeInterval(-config.monitoringPeriod)
            let recentFailures = failureHistory.filter { $0 > cutoff }
            if recentFailures.isEmpty { failureCount = min(failureCount - 1, 0) }
        default: break
        }
    }

    private func recordFailure() {
        failureCount += 1
        lastFailureDate = Date()
        var mutableHistory = failureHistory
        mutableHistory.append(Date())
        if mutableHistory.count > config.failureThreshold * 2 { mutableHistory.removeFirst() }
        if failureCount >= config.failureThreshold {
            transition(to: .open)
        }
    }

    private func transition(to newState: CircuitBreakerState) {
        state = newState
    }

    private func startStateMonitoring() {
        stateTransitionTimer?.invalidate()
        stateTransitionTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self, self.state == .open, let lastFailure = self.lastFailureDate else { return }
            if Date().timeIntervalSince(lastFailure) > self.config.recoveryTimeout {
                self.transition(to: .halfOpen)
                self.halfOpenCalls = 0
            }
        }
    }

    private func startMetricsCollection() {
        metricsTimer?.invalidate()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateFailureRate()
        }
    }

    private func updateFailureRate() {
        let total = failureCount + successCount
        failureRate = total > 0 ? Double(failureCount) / Double(total) : 0.0
    }
}
