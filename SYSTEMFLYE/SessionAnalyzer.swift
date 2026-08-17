import Foundation

struct SessionProfile: Codable, Identifiable {
    let id = UUID()
    let session: TradingSession
    let startHour: Int
    let endHour: Int
    let avgVolatility: Double
    let avgRange: Double
    let liquidityScore: Double
    let spreadMultiplier: Double
    let preferredPairs: [String]
    let typicalVolume: Int64
    let isOptimal: Bool
}

struct SessionOverlap: Codable, Identifiable {
    let id = UUID()
    let sessions: [TradingSession]
    let startHour: Int
    let endHour: Int
    let volatilityBoost: Double
    let liquidityBoost: Double
    let description: String
}

@MainActor
final class SessionAnalyzer: ObservableObject {
    static let shared = SessionAnalyzer()
    @Published private(set) var profiles: [SessionProfile] = []
    @Published private(set) var overlaps: [SessionOverlap] = []
    @Published private(set) var currentSession: TradingSession = .sydney
    @Published private(set) var nextSessionChange: Date?
    @Published private(set) var sessionVolatility: Double = 0.0

    private let calendar = EconomicCalendarEngine.shared
    private let storage = DatabaseManager.shared

    private init() {
        buildSessionProfiles()
        buildSessionOverlaps()
        startSessionMonitoring()
    }

    func currentSessionProfile() -> SessionProfile? {
        return profiles.first { $0.session == currentSession }
    }

    func optimalSession(for pair: String) -> SessionProfile? {
        return profiles.filter { $0.isOptimal && $0.preferredPairs.contains(pair) }.max { $0.liquidityScore < $1.liquidityScore }
    }

    func sessionVolatilityMultiplier(for pair: String) -> Double {
        guard let profile = currentSessionProfile() else { return 1.0 }
        let pairOptimal = profiles.first { $0.preferredPairs.contains(pair) && $0.isOptimal }
        let baseMultiplier = pairOptimal?.avgVolatility ?? 1.0
        return baseMultiplier * profile.spreadMultiplier
    }

    func optimalEntryWindow(for pair: String) -> (start: Date, end: Date, score: Double)? {
        guard let profile = optimalSession(for: pair) else { return nil }
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startComponents.hour = profile.startHour
        let start = calendar.date(from: startComponents) ?? Date()
        var endComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        endComponents.hour = profile.endHour
        let end = calendar.date(from: endComponents) ?? Date().addingTimeInterval(3600)
        return (start: start, end: end, score: profile.liquidityScore)
    }

    func isHighLiquidityPeriod() -> Bool {
        return overlaps.contains { overlap in
            let currentHour = Calendar.current.component(.hour, from: Date())
            return currentHour >= overlap.startHour && currentHour <= overlap.endHour
        }
    }

    func spreadEstimate(for pair: String) -> Double {
        guard let profile = currentSessionProfile() else { return 1.5 }
        let baseSpread = profile.spreadMultiplier
        let calendarImpact = calendar.volatilityForecast(for: pair)
        return baseSpread * (1 + calendarImpact)
    }

    private func buildSessionProfiles() {
        profiles = [
            SessionProfile(session: .sydney, startHour: 22, endHour: 7, avgVolatility: 0.4, avgRange: 0.008, liquidityScore: 0.3, spreadMultiplier: 1.5, preferredTypes: ["AUD", "NZD", "JPY"], typicalVolume: 300000, isOptimal: false),
            SessionProfile(session: .tokyo, startHour: 0, endHour: 9, avgVolatility: 0.5, avgRange: 0.01, liquidityScore: 0.5, spreadMultiplier: 1.3, preferredTypes: ["JPY", "AUD", "NZD"], typicalVolume: 500000, isOptimal: true),
            SessionProfile(session: .london, startHour: 8, endHour: 17, avgVolatility: 0.7, avgRange: 0.015, liquidityScore: 0.85, spreadMultiplier: 1.0, preferredTypes: ["EUR", "GBP", "CHF"], typicalVolume: 1200000, isOptimal: true),
            SessionProfile(session: .newYork, startHour: 13, endHour: 22, avgVolatility: 0.75, avgRange: 0.016, liquidityScore: 0.9, spreadMultiplier: 0.9, preferredTypes: ["USD", "CAD", "EUR"], typicalVolume: 1500000, isOptimal: true)
        ]
    }

    private func buildSessionOverlaps() {
        overlaps = [
            SessionOverlap(sessions: [.tokyo, .london], startHour: 1, endHour: 4, volatilityBoost: 1.3, liquidityBoost: 1.4, description: "Tokyo-London overlap: moderate liquidity increase"),
            SessionOverlap(sessions: [.london, .newYork], startHour: 13, endHour: 16, volatilityBoost: 1.5, liquidityBoost: 1.6, description: "London-NY overlap: peak liquidity and volatility"),
            SessionOverlap(sessions: [.sydney, .tokyo], startHour: 0, endHour: 2, volatilityBoost: 1.1, liquidityBoost: 1.2, description: "Sydney-Tokyo overlap: Asian session open"),
            SessionOverlap(sessions: [.sydney, .newYork], startHour: 21, endHour: 23, volatilityBoost: 1.2, liquidityBoost: 1.3, description: "Sydney-NY overlap: end of NY session")
        ]
    }

    private func startSessionMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateCurrentSession()
        }
        updateCurrentSession()
    }

    private func updateCurrentSession() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...23, 0...6: currentSession = .sydney
        case 7...12: currentSession = .tokyo
        case 13...16: currentSession = .newYork
        default: currentSession = .london
        }
        nextSessionChange = calculateNextSessionChange()
        sessionVolatility = currentSessionProfile()?.avgVolatility ?? 0.5
    }

    private func calculateNextSessionChange() -> Date {
        let hour = Calendar.current.component(.hour, from: Date())
        var nextHour: Int
        switch hour {
        case 22...23, 0...6: nextHour = 7
        case 7...12: nextHour = 13
        case 13...16: nextHour = 17
        default: nextHour = 22
        }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = nextHour
        return Calendar.current.date(from: components) ?? Date().addingTimeInterval(3600)
    }
}
