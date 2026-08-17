import Foundation

enum DepthSignal: String, Codable {
    case buyPressure = "BUY_PRESSURE"
    case sellPressure = "SELL_PRESSURE"
    case absorption = "ABSORPTION"
    case rejection = "REJECTION"
    case breakout = "BREAKOUT"
    case liquidityGrab = "LIQUIDITY_GRAB"
}

struct DepthLevel: Codable, Identifiable {
    let id = UUID()
    let price: Double
    let bidVolume: Int64
    let askVolume: Int64
    let cumulativeBid: Int64
    let cumulativeAsk: Int64
    let imbalanceRatio: Double
    let isWall: Bool
    let wallStrength: Double
    let testCount: Int
}

struct DepthSnapshot: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let levels: [DepthLevel]
    let totalBidDepth: Int64
    let totalAskDepth: Int64
    let netDepth: Int64
    let bidAskRatio: Double
    let signals: [DepthSignal]
    let supportWalls: [DepthLevel]
    let resistanceWalls: [DepthLevel]
}

@MainActor
final class MarketDepthAnalyzer: ObservableObject {
    static let shared = MarketDepthAnalyzer()
    @Published private(set) var currentSnapshot: DepthSnapshot?
    @Published private(set) var wallHistory: [DepthLevel] = []
    @Published private(set) var depthImbalance: Double = 0.0
    @Published private(set) var liquidityGrabCount = 0

    private let wallThreshold: Int64 = 500000
    private let levelsCount = 20
    private let storage = DatabaseManager.shared

    private init() {}

    func processDepthLevels(_ levels: [DepthLevel]) {
        let supportWalls = levels.filter { $0.side == .bid && $0.isWall }
        let resistanceWalls = levels.filter { $0.side == .ask && $0.isWall }
        let totalBid = levels.filter { $0.side == .bid }.reduce(0) { $0 + $1.bidVolume }
        let totalAsk = levels.filter { $0.side == .ask }.reduce(0) { $0 + $1.askVolume }
        let signals = detectDepthSignals(levels: levels, totalBid: totalBid, totalAsk: totalAsk)

        let snapshot = DepthSnapshot(
            timestamp: Date(),
            levels: levels,
            totalBidDepth: totalBid,
            totalAskDepth: totalAsk,
            netDepth: totalBid - totalAsk,
            bidAskRatio: totalAsk > 0 ? Double(totalBid) / Double(totalAsk) : 0,
            signals: signals,
            supportWalls: supportWalls,
            resistanceWalls: resistanceWalls
        )
        currentSnapshot = snapshot
        depthImbalance = snapshot.bidAskRatio
        wallHistory.append(contentsOf: supportWalls + resistanceWalls)
        if wallHistory.count > 500 { wallHistory.removeFirst(wallHistory.count - 500) }
    }

    func liquidityGrabProbability() -> Double {
        guard let snapshot = currentSnapshot else { return 0 }
        let imbalance = abs(snapshot.bidAskRatio - 1.0)
        let wallCount = snapshot.supportWalls.count + snapshot.resistanceWalls.count
        return min(0.99, imbalance * 0.5 + Double(wallCount) * 0.1)
    }

    func estimatedMoveThroughWalls() -> (bidMove: Double, askMove: Double) {
        guard let snapshot = currentSnapshot else { return (0, 0) }
        let bidWalls = snapshot.supportWalls.sorted { $0.price < $1.price }
        let askWalls = snapshot.resistanceWalls.sorted { $0.price > $1.price }
        let bidMove = bidWalls.first?.price ?? 0
        let askMove = askWalls.first?.price ?? 0
        return (bidMove, askMove)
    }

    func depthOfMarket(for pair: String) -> DepthProfile {
        guard let snapshot = currentSnapshot else { return DepthProfile.empty() }
        let sortedLevels = snapshot.levels.sorted { $0.price < $1.price }
        let buyDepth = sortedLevels.prefix(levelsCount / 2).reduce(0) { $0 + $1.bidVolume }
        let sellDepth = sortedLevels.suffix(levelsCount / 2).reduce(0) { $0 + $1.askVolume }
        return DepthProfile(buyDepth: buyDepth, sellDepth: sellDepth, imbalance: Double(buyDepth - sellDepth) / Double(max(buyDepth + sellDepth, 1)))
    }

    private func detectDepthSignals(levels: [DepthLevel], totalBid: Int64, totalAsk: Int64) -> [DepthSignal] {
        var signals: [DepthSignal] = []
        let total = totalBid + totalAsk
        guard total > 0 else { return signals }

        let buyRatio = Double(totalBid) / Double(total)
        let sellRatio = Double(totalAsk) / Double(total)

        if buyRatio > 0.7 { signals.append(.buyPressure) }
        if sellRatio > 0.7 { signals.append(.sellPressure) }

        let walls = levels.filter { $0.isWall }
        if walls.count > 3 { signals.append(.absorption) }
        if walls.isEmpty && (buyRatio > 0.6 || sellRatio > 0.6) { signals.append(.rejection) }

        return signals
    }
}

struct DepthProfile: Codable {
    let buyDepth: Int64
    let sellDepth: Int64
    let imbalance: Double

    static func empty() -> DepthProfile { DepthProfile(buyDepth: 0, sellDepth: 0, imbalance: 0) }
}
