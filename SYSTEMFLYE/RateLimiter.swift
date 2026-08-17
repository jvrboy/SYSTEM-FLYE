import Foundation
import Combine

enum RateLimitError: LocalizedError {
    case limitExceeded(retryAfter: TimeInterval)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .limitExceeded(let retry): return "Rate limit exceeded. Retry after \\(retry) seconds."
        case .invalidConfiguration: return "Invalid rate limiter configuration."
        }
    }
}

struct RateLimitRule: Codable, Identifiable {
    let id = UUID()
    let endpoint: String
    let maxRequests: Int
    let windowSeconds: TimeInterval
    let burstLimit: Int
    var penaltyDuration: TimeInterval = 0

    var requestsPerSecond: Double { Double(maxRequests) / windowSeconds }
}

@MainActor
final class RateLimiter: ObservableObject {
    static let shared = RateLimiter()
    @Published private(set) var activeLimits: [String: RateLimitState] = [:]
    @Published private(set) var blockedEndpoints: [String: Date] = [:]
    @Published private(set) var totalRejectedRequests = 0
    @Published private(set) var currentLoad: Double = 0.0

    private let maxRules = 50
    private let cleanupInterval: TimeInterval = 60
    private var cleanupTimer: Timer?
    private var rules: [String: RateLimitRule] = [:]

    struct RateLimitState {
        var requests: [Date] = []
        var blockedUntil: Date?
        var penaltyLevel: Int = 0
    }

    private init() {
        registerDefaultRules()
        startCleanupTimer()
    }

    func allowRequest(for endpoint: String) -> Bool {
        let rule = rules[endpoint] ?? RateLimitRule(endpoint: endpoint, maxRequests: 100, windowSeconds: 60, burstLimit: 10)
        guard !isBlocked(endpoint) else {
            totalRejectedRequests += 1
            return false
        }
        let state = activeLimits[endpoint, default: RateLimitState()]
        let now = Date()
        state.requests = state.requests.filter { now.timeIntervalSince($0) < rule.windowSeconds }
        if state.requests.count >= rule.maxRequests {
            if state.requests.count >= rule.burstLimit + rule.maxRequests {
                state.penaltyLevel = min(state.penaltyLevel + 1, 5)
                let penalty = rule.penaltyDuration + TimeInterval(state.penaltyLevel) * 10
                state.blockedUntil = now.addingTimeInterval(penalty)
                blockedEndpoints[endpoint] = state.blockedUntil
            }
            totalRejectedRequests += 1
            activeLimits[endpoint] = state
            currentLoad = Double(state.requests.count) / Double(rule.maxRequests)
            return false
        }
        state.requests.append(now)
        activeLimits[endpoint] = state
        currentLoad = Double(state.requests.count) / Double(rule.maxRequests)
        return true
    }

    func reset(for endpoint: String) {
        activeLimits.removeValue(forKey: endpoint)
        blockedEndpoints.removeValue(forKey: endpoint)
    }

    func addRule(_ rule: RateLimitRule) {
        guard rules.count < maxRules else { return }
        rules[rule.endpoint] = rule
    }

    func removeRule(for endpoint: String) {
        rules.removeValue(forKey: endpoint)
    }

    func timeUntilAllowed(for endpoint: String) -> TimeInterval? {
        guard let blockedUntil = blockedEndpoints[endpoint] else { return nil }
        return max(0, blockedUntil.timeIntervalSinceNow)
    }

    func isBlocked(_ endpoint: String) -> Bool {
        if let blockedUntil = blockedEndpoints[endpoint], blockedUntil > Date() { return true }
        blockedEndpoints.removeValue(forKey: endpoint)
        return false
    }

    private func registerDefaultRules() {
        addRule(RateLimitRule(endpoint: "/v3/pricing", maxRequests: 120, windowSeconds: 60, burstLimit: 20))
        addRule(RateLimitRule(endpoint: "/v3/instruments", maxRequests: 30, windowSeconds: 60, burstLimit: 5))
        addRule(RateLimitRule(endpoint: "/v1/auth/login", maxRequests: 5, windowSeconds: 60, burstLimit: 2, penaltyDuration: 30))
        addRule(RateLimitRule(endpoint: "/v1/sync", maxRequests: 10, windowSeconds: 60, burstLimit: 3))
    }

    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.cleanupStaleEntries()
        }
    }

    private func cleanupStaleEntries() {
        let now = Date()
        for (endpoint, blockedUntil) in blockedEndpoints where blockedUntil <= now {
            blockedEndpoints.removeValue(forKey: endpoint)
        }
        for (endpoint, state) in activeLimits {
            state.requests.removeAll { now.timeIntervalSince($0) > (rules[endpoint]?.windowSeconds ?? 60) }
            if state.requests.isEmpty { activeLimits.removeValue(forKey: endpoint) }
        }
    }
}
