import Foundation

struct VolumeProfilePoint: Codable, Identifiable {
    let id = UUID()
    let price: Double
    let volume: Int64
    let delta: Int64
    let cumulativeVolume: Int64
    let buyVolume: Int64
    let sellVolume: Int64
    let timestamp: Date
}

struct VolumeProfileAnalysis: Codable, Identifiable {
    let id = UUID()
    let poc: Double
    let vah: Double
    let val: Double
    let hvn: [Double]
    let lvn: [Double]
    let nodeWidth: Double
    let profileShape: ProfileShape
    let timestamp: Date

    enum ProfileShape: String, Codable {
        case normal = "NORMAL"
        case bellCurve = "BELL_CURVE"
        case flatTop = "FLAT_TOP"
        case flatBottom = "FLAT_BOTTOM"
        case dDistribution = "D_DISTRIBUTION"
        case bDistribution = "B_DISTRIBUTION"
        case pDistribution = "P_DISTRIBUTION"
    }
}

@MainActor
final class VolumeProfileEngine: ObservableObject {
    static let shared = VolumeProfileEngine()
    @Published private(set) var currentProfile: VolumeProfileAnalysis?
    @Published private(set) var profileHistory: [VolumeProfileAnalysis] = []
    @Published private(set) var pocHistory: [Double] = []
    @Published private(set) var valueAreaWidth: Double = 0.0

    private let priceLevels = 50
    private let valueAreaPercent: Double = 0.7
    private let storage = DatabaseManager.shared

    private init() {}

    func calculate(history: [PriceData], lookback: Int = 100) -> VolumeProfileAnalysis? {
        guard history.count >= 20 else { return nil }
        let window = Array(history.suffix(lookback))
        let points = calculateVolumePoints(history: window)
        let poc = calculatePOC(points: points)
        let valueArea = calculateValueArea(points: points, poc: poc)
        let hvn = detectHighVolumeNodes(points: points)
        let lvn = detectLowVolumeNodes(points: points)
        let shape = determineProfileShape(points: points, poc: poc)

        let analysis = VolumeProfileAnalysis(
            poc: poc,
            vah: valueArea.upper,
            val: valueArea.lower,
            hvn: hvn,
            lvn: lvn,
            nodeWidth: valueArea.upper - valueArea.lower,
            profileShape: shape,
            timestamp: Date()
        )
        currentProfile = analysis
        profileHistory.append(analysis)
        if profileHistory.count > 200 { profileHistory.removeFirst() }
        pocHistory.append(poc)
        if pocHistory.count > 200 { pocHistory.removeFirst() }
        valueAreaWidth = analysis.nodeWidth
        return analysis
    }

    func pointOfControl() -> Double { currentProfile?.poc ?? 0 }
    func valueAreaHigh() -> Double { currentProfile?.vah ?? 0 }
    func valueAreaLow() -> Double { currentProfile?.val ?? 0 }
    func isPriceInValueArea(_ price: Double) -> Bool {
        guard let profile = currentProfile else { return false }
        return price >= profile.val && price <= profile.vah
    }

    func balancedPriceRange() -> (low: Double, high: Double)? {
        guard let profile = currentProfile else { return nil }
        let width = profile.nodeWidth
        return (profile.poc - width * 0.5, profile.poc + width * 0.5)
    }

    private func calculateVolumePoints(history: [PriceData]) -> [VolumeProfilePoint] {
        let minPrice = history.map { $0.low }.min() ?? 0
        let maxPrice = history.map { $0.high }.max() ?? 1
        let step = max(0.0001, (maxPrice - minPrice) / Double(priceLevels))
        var points: [VolumeProfilePoint] = []

        for i in 0..<priceLevels {
            let price = minPrice + step * Double(i)
            var volume: Int64 = 0
            var buyVolume: Int64 = 0
            var sellVolume: Int64 = 0
            var delta: Int64 = 0
            var cumulativeVolume: Int64 = 0

            for candle in history {
                if candle.low <= price && candle.high >= price {
                    volume += Int64(candle.volume)
                    if candle.close > candle.open { buyVolume += Int64(candle.volume) }
                    else { sellVolume += Int64(candle.volume) }
                    delta += Int64(candle.close > candle.open ? candle.volume : -candle.volume)
                }
                cumulativeVolume += Int64(candle.volume)
            }
            points.append(VolumeProfilePoint(price: price, volume: volume, delta: delta, cumulativeVolume: cumulativeVolume, buyVolume: buyVolume, sellVolume: sellVolume, timestamp: history.last!.timestamp))
        }
        return points
    }

    private func calculatePOC(points: [VolumeProfilePoint]) -> Double {
        return points.max { $0.volume < $1.volume }?.price ?? 0
    }

    private func calculateValueArea(points: [VolumeProfilePoint], poc: Double) -> (upper: Double, lower: Double) {
        let totalVolume = points.reduce(0) { $0 + $1.volume }
        let targetVolume = Int64(Double(totalVolume) * valueAreaPercent)
        var cumulativeVolume: Int64 = 0
        var vah = poc
        var val = poc

        let sorted = points.sorted { $0.price < $1.price }
        guard let pocIndex = sorted.firstIndex(where: { $0.price == poc }) else { return (poc, poc) }

        for i in (pocIndex + 1)..<sorted.count {
            cumulativeVolume += sorted[i].volume
            if cumulativeVolume >= targetVolume { vah = sorted[i].price; break }
        }
        cumulativeVolume = 0
        for i in stride(from: pocIndex - 1, through: 0, by: -1) {
            cumulativeVolume += sorted[i].volume
            if cumulativeVolume >= targetVolume { val = sorted[i].price; break }
        }
        return (vah, val)
    }

    private func detectHighVolumeNodes(points: [VolumeProfilePoint]) -> [Double] {
        let avgVolume = points.map { $0.volume }.reduce(0, +) / Int64(max(points.count, 1))
        return points.filter { $0.volume > avgVolume * 1.5 }.map { $0.price }
    }

    private func detectLowVolumeNodes(points: [VolumeProfilePoint]) -> [Double] {
        let avgVolume = points.map { $0.volume }.reduce(0, +) / Int64(max(points.count, 1))
        return points.filter { $0.volume < avgVolume * 0.5 }.map { $0.price }
    }

    private func determineProfileShape(points: [VolumeProfilePoint], poc: Double) -> VolumeProfileAnalysis.ProfileShape {
        let totalVolume = points.reduce(0) { $0 + $1.volume }
        guard totalVolume > 0 else { return .normal }
        let pocVolume = points.first { $0.price == poc }?.volume ?? 0
        let pocPercent = Double(pocVolume) / Double(totalVolume)

        if pocPercent > 0.3 { return .dDistribution }
        let upperHalf = points.filter { $0.price > poc }
        let lowerHalf = points.filter { $0.price < poc }
        let upperVolume = upperHalf.reduce(0) { $0 + $1.volume }
        let lowerVolume = lowerHalf.reduce(0) { $0 + $1.volume }

        if upperVolume > lowerVolume * 2 { return .flatTop }
        if lowerVolume > upperVolume * 2 { return .flatBottom }
        if upperVolume > lowerVolume * 1.2 { return .pDistribution }
        if lowerVolume > upperVolume * 1.2 { return .bDistribution }
        return .bellCurve
    }
}
