import Foundation

enum WaveDegree: String, Codable {
    case grandSupercycle = "GRAND_SUPERCYCLE"
    case supercycle = "SUPERCYCLE"
    case cycle = "CYCLE"
    case primary = "PRIMARY"
    case intermediate = "INTERMEDIATE"
    case minor = "MINOR"
    case minute = "MINUTE"
    case minuette = "MINUETTE"
    case subminuette = "SUBMINUETTE"
}

enum WaveType: String, Codable {
    case impulse = "IMPULSE"
    case corrective = "CORRECTIVE"
    case leadingDiagonal = "LEADING_DIAGONAL"
    case endingDiagonal = "ENDING_DIAGONAL"
    case zigzag = "ZIGZAG"
    case flat = "FLAT"
    case triangle = "TRIANGLE"
    case doubleThree = "DOUBLE_THREE"
    case tripleThree = "TRIPLE_THREE"
    case unknown = "UNKNOWN"
}

struct ElliottWave: Identifiable, Codable {
    let id = UUID()
    let degree: WaveDegree
    let type: WaveType
    let waves: [Wave]
    let startIndex: Int
    let endIndex: Int
    let confidence: Double
    let invalidationLevel: Double
    let targetLevels: [Double]
    let timestamp: Date

    struct Wave: Codable, Identifiable {
        let id = UUID()
        let number: Int
        let startPrice: Double
        let endPrice: Double
        let startIndex: Int
        let endIndex: Int
        let waveType: WaveType
        let fibonacciRatio: Double
    }
}

@MainActor
final class ElliottWaveAnalyzer: ObservableObject {
    static let shared = ElliottWaveAnalyzer()
    @Published private(set) var detectedWaves: [ElliottWave] = []
    @Published private(set) var waveCounts: [WaveType: Int] = [:]

    private let fibRatios: [Double] = [0.236, 0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618, 2.618]
    private let minWaveLength = 10
    private let storage = DatabaseManager.shared

    private init() {}

    func analyze(history: [PriceData]) -> [ElliottWave] {
        guard history.count >= 50 else { return [] }
        let swingPoints = identifySwingPoints(history: history)
        var waves: [ElliottWave] = []

        for degree in WaveDegree.allCases {
            waves.append(contentsOf: detectImpulseWaves(history: history, swingPoints: swingPoints, degree: degree))
            waves.append(contentsOf: detectCorrectiveWaves(history: history, swingPoints: swingPoints, degree: degree))
        }

        waves.sort { $0.confidence > $1.confidence }
        detectedWaves = waves.filter { $0.confidence >= 0.55 }
        for wave in detectedWaves {
            waveCounts[wave.type, default: 0] += 1
        }
        return detectedWaves
    }

    func nextWaveProjection(wave: ElliottWave) -> (probability: Double, target: Double, stop: Double) {
        let lastWave = wave.waves.last
        let lastPrice = lastWave?.endPrice ?? 0
        let fibExtension: Double
        switch wave.type {
        case .impulse: fibExtension = 1.618
        case .corrective: fibExtension = 0.618
        default: fibExtension = 1.0
        }
        let target = lastPrice * fibExtension
        let stop = lastPrice * 0.95
        let probability = wave.confidence * 0.8
        return (probability, target, stop)
    }

    private func detectImpulseWaves(history: [PriceData], swingPoints: [SwingPoint], degree: WaveDegree) -> [ElliottWave] {
        guard swingPoints.count >= 6 else { return [] }
        var results: [ElliottWave] = []

        for i in 0..<(swingPoints.count - 5) {
            let points = Array(swingPoints[i..<i + 5])
            let wave1 = points[1].price - points[0].price
            let wave2 = points[2].price - points[1].price
            let wave3 = points[3].price - points[2].price
            let wave4 = points[4].price - points[3].price
            let wave5 = history.last?.close ?? points[4].price - points[3].price

            let w1 = abs(wave1)
            let w2 = abs(wave2)
            let w3 = abs(wave3)
            let w4 = abs(wave4)

            let w2W1 = w2 / max(w1, 0.0001)
            let w3W1 = w3 / max(w1, 0.0001)
            let w4W1 = w4 / max(w1, 0.0001)
            let w4W2 = w4 / max(w2, 0.0001)

            let validWave2 = w2W1 >= 0.382 && w2W1 <= 0.786
            let validWave3 = w3W1 >= 1.0 && w3W1 <= 2.618
            let validWave4 = w4W1 >= 0.236 && w4W1 <= 0.786 && w4W2 >= 0.236 && w4W2 <= 0.786

            guard validWave2 && validWave3 && validWave4 else { continue }

            let confidence = calculateWaveConfidence(waves: [w1, w2, w3, w4])
            let invalidation = points[4].price * 0.95
            let targets = calculateWaveTargets(waves: [w1, w2, w3, w4], lastPrice: points[4].price)

            let waveEntities = (1...4).map { index -> ElliottWave.Wave in
                return ElliottWave.Wave(
                    number: index,
                    startPrice: points[index - 1].price,
                    endPrice: points[index].price,
                    startIndex: points[index - 1].index,
                    endIndex: points[index].index,
                    waveType: index % 2 == 1 ? .impulse : .corrective,
                    fibonacciRatio: index == 1 ? w2W1 : index == 2 ? w3W1 : index == 3 ? w4W1 : 0.0
                )
            }

            results.append(ElliottWave(
                degree: degree, type: .impulse, waves: waveEntities,
                startIndex: points[0].index, endIndex: points[4].index,
                confidence: confidence, invalidationLevel: invalidation,
                targetLevels: targets, timestamp: Date()
            ))
        }
        return results
    }

    private func detectCorrectiveWaves(history: [PriceData], swingPoints: [SwingPoint], degree: WaveDegree) -> [ElliottWave] {
        guard swingPoints.count >= 3 else { return [] }
        var results: [ElliottWave] = []

        for i in 0..<(swingPoints.count - 2) {
            let points = Array(swingPoints[i..<i + 3])
            let a = points[0].price
            let b = points[1].price
            let c = points[2].price

            let ab = abs(b - a)
            let bc = abs(c - b)
            let bcAB = bc / max(ab, 0.0001)

            let isZigzag = bcAB >= 0.618 && bcAB <= 2.618
            let isFlat = bcAB >= 0.382 && bcAB <= 1.236
            let isTriangle = bcAB >= 0.382 && bcAB <= 1.618

            let waveType: WaveType = isZigzag ? .zigzag : isFlat ? .flat : isTriangle ? .triangle : .corrective

            if isZigzag || isFlat || isTriangle {
                let confidence = calculateCorrectiveConfidence(ab: ab, bc: bc, type: waveType)
                let waveEntities = (1...2).map { index -> ElliottWave.Wave in
                    return ElliottWave.Wave(
                        number: index,
                        startPrice: points[index - 1].price,
                        endPrice: points[index].price,
                        startIndex: points[index - 1].index,
                        endIndex: points[index].index,
                        waveType: .corrective,
                        fibonacciRatio: index == 1 ? bc / max(ab, 0.0001) : 0.0
                    )
                }
                results.append(ElliottWave(
                    degree: degree, type: waveType, waves: waveEntities,
                    startIndex: points[0].index, endIndex: points[2].index,
                    confidence: confidence, invalidationLevel: a * 0.95,
                    targetLevels: [c * 1.0, c * 1.618], timestamp: Date()
                ))
            }
        }
        return results
    }

    private func identifySwingPoints(history: [PriceData]) -> [SwingPoint] {
        var points: [SwingPoint] = []
        for i in 1..<(history.count - 1) {
            let prev = history[i - 1]
            let curr = history[i]
            let next = history[i + 1]
            if curr.high > prev.high && curr.high > next.high {
                points.append(SwingPoint(index: i, price: curr.high, type: .high))
            } else if curr.low < prev.low && curr.low < next.low {
                points.append(SwingPoint(index: i, price: curr.low, type: .low))
            }
        }
        return points
    }

    private func calculateWaveConfidence(waves: [Double]) -> Double {
        let fibMatches = waves.count { wave in
            fibRatios.contains { ratio in abs(wave - ratio) < 0.05 }
        }
        return Double(fibMatches) / Double(max(waves.count, 1))
    }

    private func calculateCorrectiveConfidence(ab: Double, bc: Double, type: WaveType) -> Double {
        let ratio = bc / max(ab, 0.0001)
        return type == .flat ? 0.75 : type == .zigzag ? 0.78 : 0.65
    }

    private func calculateWaveTargets(waves: [Double], lastPrice: Double) -> [Double] {
        let avgWave = waves.reduce(0, +) / Double(max(waves.count, 1))
        return [lastPrice + avgWave, lastPrice + avgWave * 1.618, lastPrice + avgWave * 2.618]
    }
}
