import Foundation

enum OrderFlowSignal: String, Codable {
    case absorption = "ABSORPTION"
    case exhaustion = "EXHAUSTION"
    case imbalance = "IMBALANCE"
    case sweep = "SWEEP"
    case iceberg = "ICEBERG"
    case stopRun = "STOP_RUN"
}

struct OrderFlowSnapshot: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let bidVolume: Int64
    let askVolume: Int64
    let delta: Int64
    let cumulativeDelta: Int64
    let imbalanceRatio: Double
    let signals: [OrderFlowSignal]
    let liquidityWalls: [LiquidityWall]
}

struct LiquidityWall: Codable, Identifiable {
    let id = UUID()
    let price: Double
    let volume: Int64
    let side: Side
    let isIceberg: Bool
    let testCount: Int

    enum Side: String, Codable { case bid, ask }
}

@MainActor
final class OrderFlowAnalyzer: ObservableObject {
    static let shared = OrderFlowAnalyzer()
    @Published private(set) var snapshots: [OrderFlowSnapshot] = []
    @Published private(set) var cumulativeDelta: Int64 = 0
    @Published private(set) var deltaProfile: [Int64] = []
    @Published private(set) var activeSignals: [OrderFlowSignal] = []

    private let maxSnapshots = 1000
    private let windowSize = 50
    private let storage = DatabaseManager.shared

    private init() {}

    func processTick(price: Double, bidVolume: Int64, askVolume: Int64, timestamp: Date) {
        let delta = askVolume - bidVolume
        cumulativeDelta += delta
        deltaProfile.append(cumulativeDelta)
        if deltaProfile.count > maxSnapshots { deltaProfile.removeFirst() }

        let signals = detectSignals(bidVolume: bidVolume, askVolume: askVolume, delta: delta, price: price, timestamp: timestamp)
        activeSignals = signals

        let snapshot = OrderFlowSnapshot(
            timestamp: timestamp,
            bidVolume: bidVolume,
            askVolume: askVolume,
            delta: delta,
            cumulativeDelta: cumulativeDelta,
            imbalanceRatio: Double(bidVolume + askVolume) > 0 ? Double(abs(bidVolume - askVolume)) / Double(bidVolume + askVolume) : 0,
            signals: signals,
            liquidityWalls: detectLiquidityWalls(price: price, bidVolume: bidVolume, askVolume: askVolume)
        )
        snapshots.append(snapshot)
        if snapshots.count > maxSnapshots { snapshots.removeFirst() }
    }

    func detectSignals(bidVolume: Int64, askVolume: Int64, delta: Int64, price: Double, timestamp: Date) -> [OrderFlowSignal] {
        var signals: [OrderFlowSignal] = []
        let total = max(bidVolume + askVolume, 1)
        let imbalance = abs(Double(bidVolume - askVolume)) / Double(total)

        if imbalance > 0.8 {
            if bidVolume > askVolume { signals.append(.imbalance) }
            else { signals.append(.sweep) }
        }

        if delta > 0 && delta > total / 2 { signals.append(.absorption) }
        if delta < 0 && abs(delta) > total / 2 { signals.append(.exhaustion) }

        if bidVolume > total * 5 || askVolume > total * 5 {
            signals.append(.iceberg)
        }

        return signals
    }

    func detectLiquidityWalls(price: Double, bidVolume: Int64, askVolume: Int64) -> [LiquidityWall] {
        var walls: [LiquidityWall] = []
        let threshold = Int64(100000)
        if bidVolume > threshold {
            walls.append(LiquidityWall(price: price, volume: bidVolume, side: .bid, isIceberg: bidVolume > threshold * 5, testCount: 1))
        }
        if askVolume > threshold {
            walls.append(LiquidityWall(price: price, volume: askVolume, side: .ask, isIceberg: askVolume > threshold * 5, testCount: 1))
        }
        return walls
    }

    func deltaDivergence(priceHistory: [Double]) -> Double {
        guard deltaProfile.count == priceHistory.count, deltaProfile.count > 1 else { return 0 }
        let priceChange = priceHistory.last! - priceHistory.first!
        let deltaChange = Double(deltaProfile.last! - deltaProfile.first!)
        let priceTrend = priceChange / max(abs(priceChange), 0.00001)
        let deltaTrend = deltaChange / max(abs(deltaChange), 1)
        return priceTrend * deltaTrend
    }

    func volumeProfileAnalysis() -> [VolumeNode] {
        guard snapshots.count > 10 else { return [] }
        let nodes = snapshots.map { VolumeNode(price: 0, volume: $0.bidVolume + $0.askVolume, delta: $0.delta, timestamp: $0.timestamp) }
        return nodes
    }
}

struct VolumeNode: Codable, Identifiable {
    let id = UUID()
    let price: Double
    let volume: Int64
    let delta: Int64
    let timestamp: Date
}
