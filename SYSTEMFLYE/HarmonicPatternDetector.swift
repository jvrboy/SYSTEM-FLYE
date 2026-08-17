import Foundation

enum HarmonicPattern: String, Codable, Identifiable {
    casegartley = "GARTLEY"
    case bat = "BAT"
    case butterfly = "BUTTERFLY"
    case crab = "CRAB"
    case shark = "SHARK"
    case cypher = "CYPHER"
    case fiveZero = "FIVE_ZERO"
    case threeDrives = "THREE_DRIVES"

    var id: String { rawValue }
    var ratios: (XA: Double, AB: Double, BC: Double, CD: Double, AD: Double) {
        switch self {
        case .gartley: return (XA: 0.618, AB: 0.382, BC: 0.382, CD: 1.618, AD: 0.786)
        case .bat: return (XA: 0.618, AB: 0.382, BC: 0.382, CD: 1.618, AD: 0.886)
        case .butterfly: return (XA: 0.786, AB: 0.382, BC: 0.382, CD: 1.618, AD: 1.618)
        case .crab: return (XA: 0.618, AB: 0.382, BC: 0.618, CD: 3.618, AD: 1.618)
        case .shark: return (XA: 0.5, AB: 0.5, BC: 1.618, CD: 0.886, AD: 0.886)
        case .cypher: return (XA: 0.618, AB: 0.382, BC: 1.272, CD: 1.272, AD: 0.786)
        case .fiveZero: return (XA: 1.13, AB: 1.618, BC: 0.618, CD: 1.0, AD: 0.0)
        case .threeDrives: return (XA: 1.618, AB: 0.618, BC: 0.786, CD: 1.272, AD: 0.0)
        }
    }
}

struct HarmonicDetectionResult: Identifiable, Codable {
    let id = UUID()
    let pattern: HarmonicPattern
    let completionPercent: Double
    let entryZone: Double
    let stopLoss: Double
    let takeProfit: [Double]
    let confidence: Double
    let keyPoints: [CGPoint]
    let timestamp: Date
}

@MainActor
final class HarmonicPatternDetector: ObservableObject {
    static let shared = HarmonicPatternDetector()
    @Published private(set) var detectedPatterns: [HarmonicDetectionResult] = []
    @Published private(set) var completedPatterns: [HarmonicDetectionResult] = []

    private let tolerance: Double = 0.05
    private let minSwingPoints = 4
    private let storage = DatabaseManager.shared

    private init() {}

    func detect(history: [PriceData]) -> [HarmonicDetectionResult] {
        guard history.count >= minSwingPoints * 3 else { return [] }
        let swingPoints = findSwingPoints(history: history)
        var results: [HarmonicDetectionResult] = []

        for window in swingPoints.windows(ofCount: 5) {
            for pattern in HarmonicPattern.allCases {
                if let detection = evaluateHarmonicPattern(pattern: pattern, points: window, history: history) {
                    results.append(detection)
                }
            }
        }

        results.sort { $0.confidence > $1.confidence }
        detectedPatterns = results.filter { $0.completionPercent >= 0.8 }
        return detectedPatterns
    }

    func projectedZones(for pattern: HarmonicPattern, xaDistance: Double) -> (entry: Double, stop: Double, targets: [Double]) {
        let ratios = pattern.ratios
        let entry = xaDistance * ratios.AD
        let stop = xaDistance * ratios.AD * 0.95
        let target1 = xaDistance * ratios.AD * 0.618
        let target2 = xaDistance * ratios.AD * 0.5
        return (entry: entry, stop: stop, targets: [target1, target2])
    }

    private func evaluateHarmonicPattern(pattern: HarmonicPattern, points: [SwingPoint], history: [PriceData]) -> HarmonicDetectionResult? {
        let x = points[0].price
        let a = points[1].price
        let b = points[2].price
        let c = points[3].price
        let d = points[4].price

        let xa = abs(a - x)
        let ab = abs(b - a)
        let bc = abs(c - b)
        let cd = abs(d - c)
        let ad = abs(d - x)

        let ratios = pattern.ratios
        let abXA = ab / max(xa, 0.0001)
        let bcAB = bc / max(ab, 0.0001)
        let cdBC = cd / max(bc, 0.0001)
        let adXA = ad / max(xa, 0.0001)

        let abMatch = abs(abXA - ratios.AB) < tolerance
        let bcMatch = abs(bcAB - ratios.BC) < tolerance
        let cdMatch = abs(cdBC - ratios.CD) < tolerance
        let adMatch = abs(adXA - ratios.AD) < tolerance

        guard abMatch && bcMatch && cdMatch && adMatch else { return nil }

        let completion = (abMatch ? 0.25 : 0) + (bcMatch ? 0.25 : 0) + (cdMatch ? 0.25 : 0) + (adMatch ? 0.25 : 0)
        let confidence = calculateConfidence(history: history, points: points)

        let entryZone = d
        let stopLoss = d * (pattern == .butterfly || pattern == .crab ? 1.05 : 0.95)
        let takeProfit1 = x + (x - a) * 0.618
        let takeProfit2 = x + (x - a) * 0.5

        return HarmonicDetectionResult(
            pattern: pattern,
            completionPercent: completion,
            entryZone: entryZone,
            stopLoss: stopLoss,
            takeProfit: [takeProfit1, takeProfit2],
            confidence: confidence,
            keyPoints: points.map { CGPoint(x: CGFloat($0.index), y: CGFloat($0.price)) },
            timestamp: Date()
        )
    }

    private func calculateConfidence(history: [PriceData], points: [SwingPoint]) -> Double {
        let volumes = points.map { Double(history[min($0.index, history.count - 1)].volume) }
        let avgVolume = volumes.reduce(0, +) / Double(max(volumes.count, 1))
        let volumeScore = min(1.0, avgVolume / 500000)
        let symmetry = calculateSymmetry(points: points)
        return (symmetry * 0.6 + volumeScore * 0.4)
    }

    private func calculateSymmetry(points: [SwingPoint]) -> Double {
        guard points.count >= 4 else { return 0 }
        let distances = points.enumerated().map { abs($0.element.price - points[$0.offset > 0 ? $0.offset - 1 : 1].price) }
        let avgDistance = distances.reduce(0, +) / Double(max(distances.count, 1))
        let variance = distances.map { pow($0 - avgDistance, 2) }.reduce(0, +) / Double(max(distances.count, 1))
        return max(0, 1 - sqrt(variance) / max(avgDistance, 0.0001))
    }
}

struct SwingPoint: Identifiable {
    let id = UUID()
    let index: Int
    let price: Double
    let type: SwingType

    enum SwingType { case high, low }
}

extension Collection where Index == Int {
    func windows(ofCount count: Int) -> [Array<Element>] {
        guard count > 0, self.count >= count else { return [] }
        return (0...(self.count - count)).map { Array(self[$0..<$0 + count]) }
    }
}
