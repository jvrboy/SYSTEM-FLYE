import Foundation
import Combine

enum RetryStrategy: String, Codable {
    case none = "NONE"
    case linear = "LINEAR"
    case exponential = "EXPONENTIAL"
    case fibonacci = "FIBONACCI"
    case polynomial = "POLYNOMIAL"
}

struct RetryPolicy: Codable, Identifiable {
    let id = UUID()
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let strategy: RetryStrategy
    let jitter: Bool
    let retryableStatusCodes: [Int]
    let retryableErrors: [String]
    let backoffMultiplier: Double

    static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        strategy: .exponential,
        jitter: true,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryableErrors: ["network", "timeout", "connection"],
        backoffMultiplier: 2.0
    )

    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        strategy: .exponential,
        jitter: true,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryableErrors: ["network", "timeout", "connection"],
        backoffMultiplier: 2.5
    )

    static let conservative = RetryPolicy(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 15.0,
        strategy: .linear,
        jitter: false,
        retryableStatusCodes: [503, 504],
        retryableErrors: ["network"],
        backoffMultiplier: 1.0
    )
}

struct RetryAttempt: Identifiable, Codable {
    let id = UUID()
    let attemptNumber: Int
    let delay: TimeInterval
    let timestamp: Date
    let error: String
    let statusCode: Int?
}

@MainActor
final class RetryPolicyEngine: ObservableObject {
    static let shared = RetryPolicyEngine()
    @Published private(set) var attempts: [RetryAttempt] = []
    @Published private(set) var totalRetries = 0
    @Published private(set) var successfulRetries = 0
    @Published private(set) var failedRetries = 0
    @Published private(set) var averageDelay: TimeInterval = 0.0

    private var policies: [String: RetryPolicy] = [:]
    private let maxAttemptHistory = 500
    private let storage = DatabaseManager.shared

    private init() {
        policies["default"] = .default
        policies["aggressive"] = .aggressive
        policies["conservative"] = .conservative
    }

    func retry<T>(policy: RetryPolicy = .default, endpoint: String, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...policy.maxAttempts {
            do {
                let result = try await operation()
                if attempt > 1 {
                    successfulRetries += 1
                    recordAttempt(RetryAttempt(attemptNumber: attempt, delay: 0, timestamp: Date(), error: "success", statusCode: nil))
                }
                return result
            } catch {
                lastError = error
                let shouldRetry = shouldRetry(error: error, attempt: attempt, policy: policy)
                if shouldRetry {
                    let delay = calculateDelay(attempt: attempt, policy: policy)
                    recordAttempt(RetryAttempt(attemptNumber: attempt, delay: delay, timestamp: Date(), error: error.localizedDescription, statusCode: (error as NSError).code as Int?))
                    totalRetries += 1
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    failedRetries += 1
                    recordAttempt(RetryAttempt(attemptNumber: attempt, delay: 0, timestamp: Date(), error: error.localizedDescription, statusCode: (error as NSError).code as Int?))
                    throw error
                }
            }
        }
        failedRetries += 1
        throw lastError ?? NSError(domain: "retry", code: -1)
    }

    func setPolicy(for endpoint: String, policy: RetryPolicy) {
        policies[endpoint] = policy
    }

    func policy(for endpoint: String) -> RetryPolicy {
        return policies[endpoint] ?? .default
    }

    func clearHistory() {
        attempts.removeAll()
        totalRetries = 0
        successfulRetries = 0
        failedRetries = 0
    }

    private func shouldRetry(error: Error, attempt: Int, policy: RetryPolicy) -> Bool {
        guard attempt < policy.maxAttempts else { return false }
        let nsError = error as NSError
        if let statusCode = nsError.code as Int?, policy.retryableStatusCodes.contains(statusCode) { return true }
        let errorString = error.localizedDescription.lowercased()
        return policy.retryableErrors.contains { errorString.contains($0) }
    }

    private func calculateDelay(attempt: Int, policy: RetryPolicy) -> TimeInterval {
        var delay: TimeInterval
        switch policy.strategy {
        case .none: delay = 0
        case .linear: delay = policy.baseDelay * Double(attempt)
        case .exponential:
            delay = policy.baseDelay * pow(policy.backoffMultiplier, Double(attempt - 1))
        case .fibonacci:
            delay = fibonacciDelay(attempt: attempt, base: policy.baseDelay)
        case .polynomial:
            delay = policy.baseDelay * pow(Double(attempt), 2)
        }
        delay = min(delay, policy.maxDelay)
        if policy.jitter {
            delay += Double.random(in: 0...delay * 0.3)
        }
        return max(0, delay)
    }

    private func fibonacciDelay(attempt: Int, base: TimeInterval) -> TimeInterval {
        var a = 0, b = base
        for _ in 1..<attempt {
            let temp = a + b
            a = b
            b = temp
        }
        return min(b, 60)
    }

    private func recordAttempt(_ attempt: RetryAttempt) {
        attempts.append(attempt)
        if attempts.count > maxAttemptHistory { attempts.removeFirst(attempts.count - maxAttemptHistory / 2) }
        let delays = attempts.filter { $0.delay > 0 }.map { $0.delay }
        averageDelay = delays.isEmpty ? 0 : delays.reduce(0, +) / Double(delays.count)
    }
}
