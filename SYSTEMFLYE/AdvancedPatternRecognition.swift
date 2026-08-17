import Foundation

enum ChartPattern: String, Codable, Identifiable {
    case headAndShoulders = "HEAD_AND_SHOULDERS"
    case inverseHeadAndShoulders = "INVERSE_HEAD_AND_SHOULDERS"
    case doubleTop = "DOUBLE_TOP"
    case doubleBottom = "DOUBLE_BOTTOM"
    case tripleTop = "TRIPLE_TOP"
    case tripleBottom = "TRIPLE_BOTTOM"
    case risingWedge = "RISING_WEDGE"
    case fallingWedge = "FALLING_WEDGE"
    case ascendingTriangle = "ASCENDING_TRIANGLE"
    case descendingTriangle = "DESCENDING_TRIANGLE"
    case symmetricalTriangle = "SYMMETRICAL_TRIANGLE"
    case bullFlag = "BULL_FLAG"
    case bearFlag = "BEAR_FLAG"
    case bullPennant = "BULL_PENNANT"
    case bearPennant = "BEAR_PENNANT"
    case cupAndHandle = "CUP_AND_HANDLE"
    case roundingBottom = "ROUNDING_BOTTOM"
    case roundingTop = "ROUNDING_TOP"

    var id: String { rawValue }
    var defaultReliability: Double {
        switch self {
        case .headAndShoulders: return 0.78
        case .inverseHeadAndShoulders: return 0.76
        case .doubleTop: return 0.72
        case .doubleBottom: return 0.71
        case .tripleTop: return 0.68
        case .tripleBottom: return 0.67
        case .cupAndHandle: return 0.74
        case .ascendingTriangle: return 0.73
        case .descendingTriangle: return 0.72
        case .symmetricalTriangle: return 0.65
        default: return 0.60
        }
    }
}

struct PatternDetectionResult: Identifiable, Codable {
    let id = UUID()
    let pattern: ChartPattern
    let startIndex: Int
    let endIndex: Int
    let confidence: Double
    let keyPoints: [CGPoint]
    let breakoutLevel: Double?
    let targetLevel: Double?
    let stopLevel: Double?
    let reliability: Double
    let volumeConfirmation: Bool
    let timestamp: Date
}

@MainActor
final class AdvancedPatternRecognition: ObservableObject {
    static let shared = AdvancedPatternRecognition()
    @Published private(set) var detectedPatterns: [PatternDetectionResult] = []
    @Published private(set) var patternHistory: [PatternDetectionResult] = []
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var patternCounts: [ChartPattern: Int] = [:]

    private let minPatternLength = 20
    private let maxPatternLength = 200
    private let confidenceThreshold = 0.6
    private let storage = DatabaseManager.shared

    private init() {}

    func detectPatterns(history: [PriceData]) -> [PatternDetectionResult] {
        guard history.count >= minPatternLength else { return [] }
        var results: [PatternDetectionResult] = []

        results.append(contentsOf: detectHeadAndShoulders(history: history))
        results.append(contentsOf: detectDoubleTopsBottoms(history: history))
        results.append(contentsOf: detectTriangles(history: history))
        results.append(contentsOf: detectWedges(history: history))
        results.append(contentsOf: detectFlagsPennants(history: history))
        results.append(contentsOf: detectCupAndHandle(history: history))

        results.sort { $0.confidence > $1.confidence }
        detectedPatterns = results.filter { $0.confidence >= confidenceThreshold }
        lastScanDate = Date()
        for pattern in detectedPatterns {
            patternCounts[pattern.pattern, default: 0] += 1
        }
        patternHistory.append(contentsOf: detectedPatterns)
        if patternHistory.count > 500 { patternHistory.removeFirst(patternHistory.count - 500) }
        return detectedPatterns
    }

    func patternReliability(for pattern: ChartPattern, timeframe: Timeframe) -> Double {
        let base = pattern.defaultReliability
        let timeframeMultiplier: Double
        switch timeframe {
        case .oneMinute, .fiveMinute: timeframeMultiplier = 0.85
        case .fifteenMinute: timeframeMultiplier = 0.90
        case .oneHour: timeframeMultiplier = 0.95
        case .fourHour, .oneDay: timeframeMultiplier = 1.0
        case .oneWeek, .oneMonth: timeframeMultiplier = 1.05
        }
        return min(0.99, base * timeframeMultiplier)
    }

    private func detectHeadAndShoulders(history: [PriceData]) -> [PatternDetectionResult] {
        var results: [PatternDetectionResult] = []
        let highs = history.map { $0.high }
        let lows = history.map { $0.low }

        for i in minPatternLength..<(history.count - minPatternLength) {
            let leftShoulder = highs[i - 20]
            let head = highs[i]
            let rightShoulder = highs[i + 20]
            let neckline = min(lows[i - 20], lows[i + 20])

            if head > leftShoulder && head > rightShoulder && abs(leftShoulder - rightShoulder) / leftShoulder < 0.05 {
                let confidence = calculatePatternConfidence(history: history, start: i - 20, end: i + 20)
                if confidence >= confidenceThreshold {
                    results.append(PatternDetectionResult(
                        pattern: .headAndShoulders,
                        startIndex: i - 20,
                        endIndex: i + 20,
                        confidence: confidence,
                        keyPoints: [
                            CGPoint(x: CGFloat(i - 20), y: CGFloat(leftShoulder)),
                            CGPoint(x: CGFloat(i), y: CGFloat(head)),
                            CGPoint(x: CGFloat(i + 20), y: CGFloat(rightShoulder))
                        ],
                        breakoutLevel: neckline,
                        targetLevel: neckline - (head - neckline),
                        stopLevel: head,
                        reliability: patternReliability(for: .headAndShoulders, timeframe: .oneHour),
                        volumeConfirmation: checkVolumeConfirmation(history: history, start: i - 20, end: i + 20),
                        timestamp: history[i].timestamp
                    ))
                }
            }
        }
        return results
    }

    private func detectDoubleTopsBottoms(history: [PriceData]) -> [PatternDetectionResult] {
        var results: [PatternDetectionResult] = []
        for i in minPatternLength..<(history.count - minPatternLength) {
            let firstTop = history[i - 15].high
            let secondTop = history[i + 15].high
            let valley = history[i].low

            if abs(firstTop - secondTop) / firstTop < 0.03 {
                let confidence = calculatePatternConfidence(history: history, start: i - 15, end: i + 15)
                if confidence >= confidenceThreshold {
                    results.append(PatternDetectionResult(
                        pattern: firstTop > valley ? .doubleTop : .doubleBottom,
                        startIndex: i - 15,
                        endIndex: i + 15,
                        confidence: confidence,
                        keyPoints: [
                            CGPoint(x: CGFloat(i - 15), y: CGFloat(firstTop)),
                            CGPoint(x: CGFloat(i), y: CGFloat(valley)),
                            CGPoint(x: CGFloat(i + 15), y: CGFloat(secondTop))
                        ],
                        breakoutLevel: firstTop > valley ? valley : firstTop,
                        targetLevel: firstTop > valley ? valley - (firstTop - valley) : valley + (valley - firstTop),
                        stopLevel: firstTop > valley ? firstTop : valley,
                        reliability: patternReliability(for: firstTop > valley ? .doubleTop : .doubleBottom, timeframe: .oneHour),
                        volumeConfirmation: checkVolumeConfirmation(history: history, start: i - 15, end: i + 15),
                        timestamp: history[i].timestamp
                    ))
                }
            }
        }
        return results
    }

    private func detectTriangles(history: [PriceData]) -> [PatternDetectionResult] {
        var results: [PatternDetectionResult] = []
        for i in minPatternLength..<(history.count - minPatternLength) {
            let highs = history[(i - 20)...(i + 20)].map { $0.high }
            let lows = history[(i - 20)...(i + 20)].map { $0.low }
            let highTrend = linearRegression(highs)
            let lowTrend = linearRegression(lows)

            if abs(highTrend.slope) < 0.001 && lowTrend.slope > 0.001 {
                results.append(createTriangleResult(history: history, type: .ascendingTriangle, center: i, confidence: 0.72))
            } else if highTrend.slope < -0.001 && abs(lowTrend.slope) < 0.001 {
                results.append(createTriangleResult(history: history, type: .descendingTriangle, center: i, confidence: 0.71))
            } else if abs(highTrend.slope + lowTrend.slope) < 0.002 {
                results.append(createTriangleResult(history: history, type: .symmetricalTriangle, center: i, confidence: 0.65))
            }
        }
        return results
    }

    private func detectWedges(history: [PriceData]) -> [PatternDetectionResult] {
        var results: [PatternDetectionResult] = []
        for i in minPatternLength..<(history.count - minPatternLength) {
            let highs = history[(i - 20)...(i + 20)].map { $0.high }
            let lows = history[(i - 20)...(i + 20)].map { $0.low }
            let highTrend = linearRegression(highs)
            let lowTrend = linearRegression(lows)

            if highTrend.slope > 0 && lowTrend.slope > 0 && highTrend.slope < lowTrend.slope {
                results.append(createTriangleResult(history: history, type: .risingWedge, center: i, confidence: 0.68))
            } else if highTrend.slope < 0 && lowTrend.slope < 0 && highTrend.slope > lowTrend.slope {
                results.append(createTriangleResult(history: history, type: .fallingWedge, center: i, confidence: 0.67))
            }
        }
        return results
    }

    private func detectFlagsPennants(history: [PriceData]) -> [PatternDetectionResult] {
        var results: [PatternDetectionResult] = []
        for i in minPatternLength..<(history.count - minPatternLength) {
            let preMove = (history[i - 25].close - history[i - 30].close) / history[i - 30].close
            let consolidation = history[(i - 15)...(i + 15)].map { $0.close }
            let postMove = (history[i + 15].close - history[i].close) / history[i].close

            if abs(preMove) > 0.03 {
                let consolidationRange = consolidation.max()! - consolidation.min()!
                let consolidationPercent = consolidationRange / consolidation.average()
                if consolidationPercent < 0.02 && postMove > 0.01 {
                    results.append(PatternDetectionResult(
                        pattern: .bullFlag, startIndex: i - 30, endIndex: i + 15, confidence: 0.70,
                        keyPoints: [], breakoutLevel: consolidation.max(), targetLevel: consolidation.average() + abs(preMove) * consolidation.average(),
                        stopLevel: consolidation.min(), reliability: 0.65, volumeConfirmation: false, timestamp: history[i].timestamp
                    ))
                }
            }
        }
        return results
    }

    private func detectCupAndHandle(history: [PriceData]) -> [PatternDetectionResult] {
        var results: [PatternDetectionResult] = []
        for i in 50..<(history.count - 30) {
            let cup = history[(i - 50)...i]
            let handle = history[(i + 1)...(i + 30)]

            let cupLows = cup.map { $0.low }
            let cupStart = cup.first!.close
            let cupMin = cupLows.min()!
            let cupEnd = cup.last!.close

            if cupStart > cupMin && cupEnd > cupMin && cupEnd > cupStart * 0.95 {
                let handleHighs = handle.map { $0.high }
                let handleLow = handle.map { $0.low }.min()!
                let handleRange = handleHighs.max()! - handleLow

                if handleRange / cupStart < 0.03 {
                    let confidence = calculatePatternConfidence(history: history, start: i - 50, end: i + 30)
                    if confidence >= confidenceThreshold {
                        results.append(PatternDetectionResult(
                            pattern: .cupAndHandle, startIndex: i - 50, endIndex: i + 30, confidence: confidence,
                            keyPoints: [
                                CGPoint(x: CGFloat(i - 50), y: CGFloat(cupStart)),
                                CGPoint(x: CGFloat(i - 25), y: CGFloat(cupMin)),
                                CGPoint(x: CGFloat(i + 30), y: CGFloat(cupEnd))
                            ],
                            breakoutLevel: cupStart,
                            targetLevel: cupStart + (cupStart - cupMin),
                            stopLevel: cupMin,
                            reliability: patternReliability(for: .cupAndHandle, timeframe: .oneDay),
                            volumeConfirmation: checkVolumeConfirmation(history: history, start: i - 50, end: i + 30),
                            timestamp: history[i].timestamp
                        ))
                    }
                }
            }
        }
        return results
    }

    private func calculatePatternConfidence(history: [PriceData], start: Int, end: Int) -> Double {
        let segment = Array(history[max(0, start)...min(history.count - 1, end)])
        let volumes = segment.map { Double($0.volume) }
        let avgVolume = volumes.reduce(0, +) / Double(max(volumes.count, 1))
        let volumeScore = avgVolume > 0 ? min(1.0, avgVolume / 1000000) : 0.5
        let priceChange = abs(segment.last!.close - segment.first!.close) / max(segment.first!.close, 0.00001)
        let magnitudeScore = min(1.0, priceChange * 10)
        return (volumeScore * 0.4 + magnitudeScore * 0.4 + 0.2)
    }

    private func checkVolumeConfirmation(history: [PriceData], start: Int, end: Int) -> Bool {
        let segment = Array(history[max(0, start)...min(history.count - 1, end)])
        let volumes = segment.map { Double($0.volume) }
        let peakVolume = volumes.max() ?? 0
        let avgVolume = volumes.reduce(0, +) / Double(max(volumes.count, 1))
        return peakVolume > avgVolume * 1.5
    }

    private func createTriangleResult(history: [PriceData], type: ChartPattern, center: Int, confidence: Double) -> PatternDetectionResult {
        return PatternDetectionResult(
            pattern: type, startIndex: center - 20, endIndex: center + 20, confidence: confidence,
            keyPoints: [], breakoutLevel: nil, targetLevel: nil, stopLevel: nil,
            reliability: patternReliability(for: type, timeframe: .oneHour),
            volumeConfirmation: checkVolumeConfirmation(history: history, start: center - 20, end: center + 20),
            timestamp: history[center].timestamp
        )
    }

    private func linearRegression(_ values: [Double]) -> (slope: Double, intercept: Double) {
        let n = Double(values.count)
        let sumX = values.enumerated().map { Double($0.offset) }.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(values.enumerated(), values).map { Double($0.offset) * $0.element }.reduce(0, +)
        let sumX2 = values.enumerated().map { Double($0.offset * $0.offset) }.reduce(0, +)
        let slope = (n * sumXY - sumX * sumY) / max(n * sumX2 - sumX * sumX, 0.0001)
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }
}
