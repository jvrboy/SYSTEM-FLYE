import Foundation

enum ZoneType: String, Codable {
    case supply = "SUPPLY"
    case demand = "DEMAND"
}

enum ZoneStrength: String, Codable {
    case weak = "WEAK"
    case moderate = "MODERATE"
    case strong = "STRONG"
    case veryStrong = "VERY_STRONG"
}

struct SupplyDemandZone: Identifiable, Codable {
    let id = UUID()
    let type: ZoneType
    let high: Double
    let low: Double
    let strength: ZoneStrength
    let touchCount: Int
    let creationTimestamp: Date
    let lastTestTimestamp: Date
    let confluenceCount: Int
    let volumeAtCreation: Int64
    var isActive: Bool = true
    var retests: Int = 0

    var midpoint: Double { (high + low) / 2 }
    var range: Double { high - low }
}

struct ConfluenceFactor: Codable, Identifiable {
    let id = UUID()
    let type: ConfluenceType
    let value: Double
    let weight: Double
    let description: String

    enum ConfluenceType: String, Codable {
        case fibonacci = "FIBONACCI"
        case pivotPoint = "PIVOT_POINT"
        case movingAverage = "MOVING_AVERAGE"
        case volumeProfile = "VOLUME_PROFILE"
        case swingPoint = "SWING_POINT"
        case roundNumber = "ROUND_NUMBER"
        case trendLine = "TREND_LINE"
        case indicator = "INDICATOR"
    }
}

@MainActor
final class SupplyDemandZoneMapper: ObservableObject {
    static let shared = SupplyDemandZoneMapper()
    @Published private(set) var activeZones: [SupplyDemandZone] = []
    @Published private(set) var retiredZones: [SupplyDemandZone] = []
    @Published private(set) var currentConfluence: [ConfluenceFactor] = []
    @Published private(set) var zoneDensity: Double = 0.0

    private let maxActiveZones = 30
    private let minZoneRange: Double = 0.0001
    private let storage = DatabaseManager.shared

    private init() {}

    func mapZones(history: [PriceData], additionalConfluences: [ConfluenceFactor] = []) -> [SupplyDemandZone] {
        guard history.count >= 20 else { return [] }
        var zones: [SupplyDemandZone] = []

        zones.append(contentsOf: detectFreshZones(history: history))
        zones.append(contentsOf: detectEstablishedZones(history: history))
        zones.append(contentsOf: detectWeakZones(history: history))

        for zone in zones {
            zone.confluenceCount = calculateConfluenceCount(for: zone, history: history, additionalConfluences: additionalConfluences)
            zone.strength = calculateZoneStrength(zone: zone, history: history)
        }

        zones.sort { $0.strength.rawValue > $1.strength.rawValue }
        activeZones = Array(zones.prefix(maxActiveZones))
        zoneDensity = calculateZoneDensity(zones: activeZones, history: history)
        return activeZones
    }

    func nearestZone(to price: Double) -> SupplyDemandZone? {
        return activeZones.min { zone in
            abs(zone.midpoint - price) < abs($0.midpoint - price)
        }
    }

    func zonesNearPrice(_ price: Double, tolerance: Double = 0.001) -> [SupplyDemandZone] {
        return activeZones.filter { zone in
            price >= zone.low - tolerance && price <= zone.high + tolerance
        }
    }

    func retireZone(_ zone: SupplyDemandZone) {
        var retired = zone
        retired.isActive = false
        activeZones.removeAll { $0.id == zone.id }
        retiredZones.append(retired)
        if retiredZones.count > 1000 { retiredZones.removeFirst(retiredZones.count - 1000) }
    }

    private func detectFreshZones(history: [PriceData]) -> [SupplyDemandZone] {
        var zones: [SupplyDemandZone] = []
        let lookback = min(history.count - 1, 30)
        let recent = Array(history.suffix(lookback))
        let maxHigh = recent.map { $0.high }.max() ?? 0
        let minLow = recent.map { $0.low }.min() ?? 0

        for candle in recent {
            if candle.high >= maxHigh * 0.999 {
                let volume = candle.volume
                let strength: ZoneStrength = volume > 1000000 ? .veryStrong : volume > 500000 ? .strong : .moderate
                zones.append(SupplyDemandZone(type: .supply, high: candle.high, low: candle.high * 0.9995, strength: strength, touchCount: 1, creationTimestamp: candle.timestamp, lastTestTimestamp: candle.timestamp, confluenceCount: 0, volumeAtCreation: Int64(volume)))
            }
            if candle.low <= minLow * 1.001 {
                let volume = candle.volume
                let strength: ZoneStrength = volume > 1000000 ? .veryStrong : volume > 500000 ? .strong : .moderate
                zones.append(SupplyDemandZone(type: .demand, high: candle.low * 1.0005, low: candle.low, strength: strength, touchCount: 1, creationTimestamp: candle.timestamp, lastTestTimestamp: candle.timestamp, confluenceCount: 0, volumeAtCreation: Int64(volume)))
            }
        }
        return zones
    }

    private func detectEstablishedZones(history: [PriceData]) -> [SupplyDemandZone] {
        var zones: [SupplyDemandZone] = []
        for i in 20..<(history.count - 20) {
            let window = Array(history[(i - 20)...(i + 20)])
            let highs = window.map { $0.high }
            let lows = window.map { $0.low }
            let maxHigh = highs.max() ?? 0
            let minLow = lows.min() ?? 0
            let range = maxHigh - minLow

            if range < minZoneRange { continue }

            var touchCount = 0
            for candle in window {
                if abs(candle.high - maxHigh) / maxHigh < 0.002 { touchCount += 1 }
                if abs(candle.low - minLow) / minLow < 0.002 { touchCount += 1 }
            }

            if touchCount >= 3 {
                let avgVolume = window.map { Double($0.volume) }.reduce(0, +) / Double(window.count)
                let strength: ZoneStrength = touchCount >= 6 ? .veryStrong : touchCount >= 4 ? .strong : .moderate
                zones.append(SupplyDemandZone(type: .demand, high: maxHigh, low: minLow, strength: strength, touchCount: touchCount, creationTimestamp: window.first!.timestamp, lastTestTimestamp: window.last!.timestamp, confluenceCount: 0, volumeAtCreation: Int64(avgVolume)))
            }
        }
        return zones
    }

    private func detectWeakZones(history: [PriceData]) -> [SupplyDemandZone] {
        var zones: [SupplyDemandZone] = []
        let lookback = min(history.count - 1, 10)
        let recent = Array(history.suffix(lookback))
        let maxHigh = recent.map { $0.high }.max() ?? 0
        let minLow = recent.map { $0.low }.min() ?? 0

        if maxHigh > minLow {
            zones.append(SupplyDemandZone(type: .supply, high: maxHigh, low: maxHigh - minZoneRange, strength: .weak, touchCount: 1, creationTimestamp: recent.last!.timestamp, lastTestTimestamp: recent.last!.timestamp, confluenceCount: 0, volumeAtCreation: 0))
            zones.append(SupplyDemandZone(type: .demand, high: minLow + minZoneRange, low: minLow, strength: .weak, touchCount: 1, creationTimestamp: recent.last!.timestamp, lastTestTimestamp: recent.last!.timestamp, confluenceCount: 0, volumeAtCreation: 0))
        }
        return zones
    }

    private func calculateConfluenceCount(for zone: SupplyDemandZone, history: [PriceData], additionalConfluences: [ConfluenceFactor]) -> Int {
        var count = 0
        let fibLevels = [0.236, 0.382, 0.5, 0.618, 0.786]
        let range = history.map { $0.high - $0.low }.reduce(0, +) / Double(max(history.count, 1))
        for fib in fibLevels {
            let level = history.last!.close - range * fib
            if abs(level - zone.midpoint) / zone.range < 1.5 { count += 1 }
        }
        for ma in [20, 50, 100, 200] {
            if history.count >= ma {
                let maValue = history.suffix(ma).map { $0.close }.reduce(0, +) / Double(ma)
                if abs(maValue - zone.midpoint) / zone.range < 0.5 { count += 1 }
            }
        }
        count += additionalConfluences.count { abs($0.value - zone.midpoint) / zone.range < 1.0 }
        return count
    }

    private func calculateZoneStrength(zone: SupplyDemandZone, history: [PriceData]) -> ZoneStrength {
        let baseScore = Double(zone.touchCount) * 0.2
        let volumeScore = min(0.4, Double(zone.volumeAtCreation) / 2000000)
        let confluenceScore = min(0.3, Double(zone.confluenceCount) * 0.1)
        let total = baseScore + volumeScore + confluenceScore
        if total >= 0.8 { return .veryStrong }
        if total >= 0.6 { return .strong }
        if total >= 0.4 { return .moderate }
        return .weak
    }

    private func calculateZoneDensity(zones: [SupplyDemandZone], history: [PriceData]) -> Double {
        guard let minPrice = history.map({ $0.low }).min(),
              let maxPrice = history.map({ $0.high }).max(),
              maxPrice > minPrice else { return 0 }
        let totalRange = maxPrice - minPrice
        let coveredRange = zones.reduce(0.0) { $0 + $1.range }
        return min(1.0, coveredRange / totalRange)
    }
}
