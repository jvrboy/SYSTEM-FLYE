import Foundation

enum EventImpact: String, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}

enum EventStatus: String, Codable {
    case scheduled = "SCHEDULED"
    case released = "RELEASED"
    case revised = "REVISED"
    case cancelled = "CANCELLED"
}

struct EconomicEvent: Identifiable, Codable {
    let id = UUID()
    let title: String
    let country: String
    let currency: String
    let impact: EventImpact
    let status: EventStatus
    let scheduledAt: Date
    let releasedAt: Date?
    let previousValue: String
    let forecastValue: String
    let actualValue: String?
    let revision: String?
    let description: String
    let affectedPairs: [String]
    let volatilityExpectation: Double
    let confidence: Double
    let isRecurring: Bool
    let recurrenceRule: String?
}

@MainActor
final class EconomicCalendarEngine: ObservableObject {
    static let shared = EconomicCalendarEngine()
    @Published private(set) var upcomingEvents: [EconomicEvent] = []
    @Published private(set) var recentEvents: [EconomicEvent] = []
    @Published private(set) var highImpactCount: Int = 0
    @Published private(set) var eventHeatmap: [String: Double] = [:]
    @Published private(set) var nextHighImpactEvent: EconomicEvent?

    private let calendarURL = "https://api.systemflye.app/v1/calendar"
    private let storage = DatabaseManager.shared
    private var refreshTask: Task<Void, Never>?

    private init() {
        loadCachedEvents()
        scheduleRefresh()
    }

    func fetchUpcomingEvents(days: Int = 7) async throws -> [EconomicEvent] {
        let request = APIRequest(endpoint: calendarURL, method: .get, headers: [:], body: nil, queryItems: [
            URLQueryItem(name: "days", value: "\\(days)"),
            URLQueryItem(name: "impact", value: "high")
        ])
        let response: CalendarResponse = try await APIClientManager.shared.send(request)
        upcomingEvents = response.events
        cacheEvents(upcomingEvents)
        return upcomingEvents
    }

    func events(for currency: String) -> [EconomicEvent] {
        return upcomingEvents.filter { $0.currency == currency }
    }

    func eventsAffecting(pair: String) -> [EconomicEvent] {
        let components = pair.components(separatedBy: "/")
        guard components.count == 2 else { return [] }
        let base = components[0]
        let quote = components[1]
        return upcomingEvents.filter { $0.affectedPairs.contains(base) || $0.affectedPairs.contains(quote) }
    }

    func volatilityForecast(for pair: String) -> Double {
        let events = eventsAffecting(pair: pair)
        let highImpactEvents = events.filter { $0.impact == .high || $0.impact == .critical }
        return Double(highImpactEvents.count) * 0.15 + Double(events.count) * 0.05
    }

    func marketOpenProbability(session: TradingSession) -> Double {
        let sessionEvents = upcomingEvents.filter { $0.country == session.countryCode }
        let highImpactEvents = sessionEvents.filter { $0.impact == .high || $0.impact == .critical }
        return min(0.99, 0.5 + Double(highImpactEvents.count) * 0.1)
    }

    func nextHighImpactEvent(for pair: String) -> EconomicEvent? {
        let events = eventsAffecting(pair: pair).filter { $0.impact == .high || $0.impact == .critical }
        return events.min { $0.scheduledAt < $1.scheduledAt }
    }

    func markAsReleased(_ event: EconomicEvent, actualValue: String, revision: String? = nil) {
        var updated = event
        updated.status = .released
        updated.actualValue = actualValue
        updated.revision = revision
        if let index = upcomingEvents.firstIndex(where: { $0.id == event.id }) {
            upcomingEvents[index] = updated
            recentEvents.insert(updated, at: 0)
            if recentEvents.count > 500 { recentEvents.removeLast() }
        }
        calculateHeatmapImpact(event: updated)
    }

    func eventSurpriseFactor(event: EconomicEvent) -> Double {
        guard let actual = event.actualValue, let forecast = Double(event.forecastValue),
              let actualNum = Double(actual) else { return 0 }
        let forecastStdDev: Double = 0.1
        let surprise = (actualNum - forecast) / max(forecastStdDev, 0.0001)
        return max(-3, min(3, surprise))
    }

    private func calculateHeatmapImpact(event: EconomicEvent) {
        for pair in event.affectedPairs {
            eventHeatmap[pair, default: 0] += event.impact == .critical ? 0.3 : event.impact == .high ? 0.2 : 0.1
        }
    }

    private func cacheEvents(_ events: [EconomicEvent]) {
        do {
            let data = try JSONEncoder.flye.encode(events)
            try storage.execute("UPDATE sync_state SET data = '\\(data.base64EncodedString())', updated_at = '\\(ISO8601DateFormatter().string(from: Date()))' WHERE id = 'economic_calendar'", parameters: [:])
        } catch { print("Failed to cache calendar: \\(error)") }
    }

    private func loadCachedEvents() {
        do {
            let data = try storage.query("SELECT data FROM sync_state WHERE id = 'economic_calendar'", parameters: [:]) { row in row.data(at: 0) ?? Data() }
            if let first = data.first, let events = try? JSONDecoder.flye.decode([EconomicEvent].self, from: first) {
                upcomingEvents = events.filter { $0.status == .scheduled && $0.scheduledAt > Date() }
                recentEvents = events.filter { $0.status == .released }.prefix(100).map { $0 }
                highImpactCount = upcomingEvents.filter { $0.impact == .high || $0.impact == .critical }.count
                nextHighImpactEvent = upcomingEvents.min { $0.scheduledAt < $1.scheduledAt }
            }
        } catch { print("Failed to load cached events: \\(error)") }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                try? await fetchUpcomingEvents()
            }
        }
    }
}

struct CalendarResponse: Codable {
    let events: [EconomicEvent]
    let fetchedAt: Date
    let total: Int
}

enum TradingSession: String, Codable {
    case sydney = "SYDNEY"
    case tokyo = "TOKYO"
    case london = "LONDON"
    case newYork = "NEW_YORK"

    var countryCode: String {
        switch self {
        case .sydney: return "AU"
        case .tokyo: return "JP"
        case .london: return "GB"
        case .newYork: return "US"
        }
    }

    var startHour: Int {
        switch self {
        case .sydney: return 22
        case .tokyo: return 0
        case .london: return 8
        case .newYork: return 13
        }
    }
}
