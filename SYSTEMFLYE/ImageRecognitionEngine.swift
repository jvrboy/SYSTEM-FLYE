import Foundation
import CoreGraphics
import CoreML
import Accelerate
import Vision

// MARK: - Chart Pattern Models
enum ChartPattern: String, Codable, CaseIterable {
    case headAndShoulders = "HEAD_AND_SHOULDERS"
    case doubleTop = "DOUBLE_TOP"
    case doubleBottom = "DOUBLE_BOTTOM"
    case tripleTop = "TRIPLE_TOP"
    case tripleBottom = "TRIPLE_BOTTOM"
    case ascendingTriangle = "ASCENDING_TRIANGLE"
    case descendingTriangle = "DESCENDING_TRIANGLE"
    case symmetricalTriangle = "SYMMETRICAL_TRIANGLE"
    case wedgeRising = "WEDGE_RISING"
    case wedgeFalling = "WEDGE_FALLING"
    case flagBullish = "FLAG_BULLISH"
    case flagBearish = "FLAG_BEARISH"
    case pennant = "PENNANT"
    case cupAndHandle = "CUP_AND_HANDLE"
    case inverseCupAndHandle = "INVERSE_CUP_AND_HANDLE"
    case channelUp = "CHANNEL_UP"
    case channelDown = "CHANNEL_DOWN"
    case rectangle = "RECTANGLE"
    case diamond = "DIAMOND"
    case triangleExpanding = "TRIANGLE_EXPANDING"
    case none = "NONE"
}

struct PatternDetectionResult: Codable, Identifiable {
    let id = UUID()
    var pattern: ChartPattern
    var confidence: Double
    var startIndex: Int
    var endIndex: Int
    var keyPoints: [CGPoint]
    var metrics: PatternMetrics
    var prediction: PatternPrediction
    var timestamp: Date

    struct PatternMetrics: Codable {
        let height: Double
        let width: Double
        let slope: Double
        let volumeConfirmation: Double
        let breakoutProbability: Double
        let falsePositiveRate: Double
        let symmetryScore: Double
        let volumeProfile: [Double]
    }

    struct PatternPrediction: Codable {
        let targetPrice: Double
        let stopLoss: Double
        let riskRewardRatio: Double
        let expectedReturn: Double
        let probability: Double
        let timeToTarget: Int
        let direction: SignalType
    }

    init(pattern: ChartPattern, confidence: Double, startIndex: Int, endIndex: Int, keyPoints: [CGPoint] = [], metrics: PatternMetrics = PatternMetrics(height: 0, width: 0, slope: 0, volumeConfirmation: 0, breakoutProbability: 0, falsePositiveRate: 0, symmetryScore: 0, volumeProfile: []), prediction: PatternPrediction = PatternPrediction(targetPrice: 0, stopLoss: 0, riskRewardRatio: 0, expectedReturn: 0, probability: 0, timeToTarget: 0, direction: .neutral), timestamp: Date = Date()) {
        self.id = UUID()
        self.pattern = pattern
        self.confidence = max(0, min(1, confidence))
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.keyPoints = keyPoints
        self.metrics = metrics
        self.prediction = prediction
        self.timestamp = timestamp
    }
}

// MARK: - Candlestick Models
enum CandlestickPattern: String, Codable, CaseIterable {
    case doji = "DOJI"
    case dojiStar = "DOJI_STAR"
    case dragonflyDoji = "DRAGONFLY_DOJI"
    case gravestoneDoji = "GRAVESTONE_DOJI"
    case hammer = "HAMMER"
    case invertedHammer = "INVERTED_HAMMER"
    case bullishMarubozu = "BULLISH_MARUBOZU"
    case bearishMarubozu = "BEARISH_MARUBOZU"
    case spinningTop = "SPINNING_TOP"
    case bullishEngulfing = "BULLISH_ENGULFING"
    case bearishEngulfing = "BEARISH_ENGULFING"
    case bullishHarami = "BULLISH_HARAMI"
    case bearishHarami = "BEARISH_HARAMI"
    case piercingPattern = "PIERCING_PATTERN"
    case darkCloudCover = "DARK_CLOUD_COVER"
    case morningStar = "MORNING_STAR"
    case eveningStar = "EVENING_STAR"
    case threeWhiteSoldiers = "THREE_WHITE_SOLDIERS"
    case threeBlackCrows = "THREE_BLACK_CROWS"
    case threeInsideUp = "THREE_INSIDE_UP"
    case threeInsideDown = "THREE_INSIDE_DOWN"
    case bullishAbandonedBaby = "BULLISH_ABANDONED_BABY"
    case bearishAbandonedBaby = "BEARISH_ABANDONED_BABY"
    case tweezerTop = "TWEEZER_TOP"
    case tweezerBottom = "TWEEZER_BOTTOM"
    case bullishBeltHold = "BULLISH_BELT_HOLD"
    case bearishBeltHold = "BEARISH_BELT_HOLD"
    case upsideGapTwoCrows = "UPSIDE_GAP_TWO_CROWS"
    case downsideTasukiGap = "DOWNSIDE_TASUKI_GAP"
    case threeLineStrikeBullish = "THREE_LINE_STRIKE_BULLISH"
    case threeLineStrikeBearish = "THREE_LINE_STRIKE_BEARISH"
    case none = "NONE"
}

struct CandlestickPatternResult: Codable, Identifiable {
    let id = UUID()
    var pattern: CandlestickPattern
    var confidence: Double
    var index: Int
    var signal: SignalType
    var strength: SignalStrength
    var context: PatternContext
    var reliability: Double
    var timestamp: Date

    struct PatternContext: Codable {
        let trend: TrendContext
        let volume: VolumeContext
        let supportResistance: SupportResistanceContext
        let volatility: Double

        enum TrendContext: String, Codable { case uptrend = "UPTREND", downtrend = "DOWNTREND", sideways = "SIDEWAYS", unknown = "UNKNOWN" }
        enum VolumeContext: String, Codable { case high = "HIGH", normal = "NORMAL", low = "LOW", increasing = "INCREASING", decreasing = "DECREASING" }
        enum SupportResistanceContext: String, Codable { case atSupport = "AT_SUPPORT", atResistance = "AT_RESISTANCE", none = "NONE", breakout = "BREAKOUT" }
    }

    init(pattern: CandlestickPattern, confidence: Double, index: Int, signal: SignalType = .neutral, strength: SignalStrength = .moderate, context: PatternContext = PatternContext(trend: .unknown, volume: .normal, supportResistance: .none, volatility: 0), reliability: Double = 0.5, timestamp: Date = Date()) {
        self.id = UUID()
        self.pattern = pattern
        self.confidence = max(0, min(1, confidence))
        self.index = index
        self.signal = signal
        self.strength = strength
        self.context = context
        self.reliability = max(0, min(1, reliability))
        self.timestamp = timestamp
    }
}

// MARK: - Feature Extraction
struct ImageFeatures: Codable, Identifiable {
    let id = UUID()
    var edges: [EdgeFeature]
    var corners: [CornerFeature]
    var blobs: [BlobFeature]
    var histograms: [HistogramFeature]
    var textureFeatures: TextureFeatures
    var colorMoments: [ColorMoment]
    var houghLines: [HoughLine]
    var timestamp: Date

    struct EdgeFeature: Codable, Identifiable { let id = UUID(); var x: Int; var y: Int; var magnitude: Double; var direction: Double }
    struct CornerFeature: Codable, Identifiable { let id = UUID(); var x: Int; var y: Int; var strength: Double; var response: Double }
    struct BlobFeature: Codable, Identifiable { let id = UUID(); var x: Int; var y: Int; var radius: Double; var area: Double }
    struct HistogramFeature: Codable, Identifiable { let id = UUID(); var bins: [Int]; var channel: String }
    struct TextureFeatures: Codable { let contrast: Double; let correlation: Double; let energy: Double; let homogeneity: Double; let entropy: Double }
    struct ColorMoment: Codable, Identifiable { let id = UUID(); var mean: Double; var variance: Double; var skewness: Double }
    struct HoughLine: Codable, Identifiable { let id = UUID(); var rho: Double; var theta: Double; var votes: Int }
}

// MARK: - Image Recognition Engine
@MainActor
final class ImageRecognitionEngine: ObservableObject {
    static let shared = ImageRecognitionEngine()
    @Published private(set) var detectedPatterns: [PatternDetectionResult] = []
    @Published private(set) var candlestickPatterns: [CandlestickPatternResult] = []
    @Published private(set) var isProcessing = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 100

    func detectChartPatterns(history: [PriceData], volumeHistory: [Int] = []) async -> [PatternDetectionResult] {
        guard history.count >= 20 else { return [] }
        isProcessing = true
        defer { isProcessing = false }
        var results: [PatternDetectionResult] = []
        let patterns = ChartPattern.allCases.filter { $0 != .none }
        for pattern in patterns {
            let detection = detectSinglePattern(pattern: pattern, history: history)
            if detection.confidence > 0.5 { results.append(detection) }
        }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        if sorted.count > maxResults {
            detectedPatterns = Array(sorted.prefix(maxResults))
        } else {
            detectedPatterns = sorted
        }
        return sorted
    }

    func detectCandlestickPatterns(history: [PriceData]) async -> [CandlestickPatternResult] {
        guard history.count >= 5 else { return [] }
        isProcessing = true
        defer { isProcessing = false }
        var results: [CandlestickPatternResult] = []
        for i in 2..<history.count {
            let window = Array(history[max(0, i - 4)...i])
            let detection = analyzeCandlestickPattern(window: window, index: i)
            if detection.confidence > 0.6 { results.append(detection) }
        }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        candlestickPatterns = sorted.count > maxResults ? Array(sorted.prefix(maxResults)) : sorted
        return sorted
    }

    func extractFeatures(from imageData: Data) async -> ImageFeatures? {
        guard let image = CGImageSourceCreateImageDataProvider(imageData).flatMap(CGImageSourceCreateWithData) else { return nil }
        let edges = detectEdges(image: image)
        let corners = detectCorners(image: image)
        let blobs = detectBlobs(image: image)
        let histograms = computeHistograms(image: image)
        let texture = computeTextureFeatures(image: image)
        let colorMoments = computeColorMoments(image: image)
        let houghLines = detectHoughLines(image: image)
        return ImageFeatures(edges: edges, corners: corners, blobs: blobs, histograms: histograms, textureFeatures: texture, colorMoments: colorMoments, houghLines: houghLines, timestamp: Date())
    }

    private func detectSinglePattern(pattern: ChartPattern, history: [PriceData]) -> PatternDetectionResult {
        let closes = history.map(\.close)
        let highs = history.map(\.high)
        let lows = history.map(\.low)
        let startIndex = max(0, history.count - 30)
        let endIndex = history.count - 1
        var confidence = 0.5
        var keyPoints: [CGPoint] = []
        let width = Double(endIndex - startIndex)
        let recentHigh = highs.suffix(15).max() ?? 0
        let recentLow = lows.suffix(15).min() ?? 0
        let height = recentHigh - recentLow
        switch pattern {
        case .headAndShoulders:
            let leftShoulder = highs[max(0, endIndex - 25)]
            let head = highs[max(0, endIndex - 15)]
            let rightShoulder = highs[max(0, endIndex - 5)]
            if head > leftShoulder && head > rightShoulder { confidence = 0.85; keyPoints = [CGPoint(x: 0, y: leftShoulder), CGPoint(x: width * 0.33, y: head), CGPoint(x: width * 0.66, y: rightShoulder)] }
        case .doubleTop:
            let firstTop = highs[max(0, endIndex - 20)]
            let secondTop = highs[max(0, endIndex - 5)]
            if abs(firstTop - secondTop) / max(firstTop, 0.0001) < 0.02 { confidence = 0.8; keyPoints = [CGPoint(x: 0, y: firstTop), CGPoint(x: width * 0.5, y: secondTop)] }
        case .doubleBottom:
            let firstBottom = lows[max(0, endIndex - 20)]
            let secondBottom = lows[max(0, endIndex - 5)]
            if abs(firstBottom - secondBottom) / max(firstBottom, 0.0001) < 0.02 { confidence = 0.8; keyPoints = [CGPoint(x: 0, y: firstBottom), CGPoint(x: width * 0.5, y: secondBottom)] }
        case .ascendingTriangle:
            let highs = highs.suffix(15)
            let lowSlope = calculateSlope(Array(lows.suffix(15)))
            let highMean = highs.reduce(0, +) / Double(highs.count)
            if abs(lowSlope) > 0.001 && highs.allSatisfy { abs($0 - highMean) / max(highMean, 0.0001) < 0.02 } { confidence = 0.75; keyPoints = [CGPoint(x: 0, y: lows.last ?? 0), CGPoint(x: width, y: highMean)] }
        case .descendingTriangle:
            let lows = lows.suffix(15)
            let highSlope = calculateSlope(Array(highs.suffix(15)))
            let lowMean = lows.reduce(0, +) / Double(lows.count)
            if abs(highSlope) > 0.001 && lows.allSatisfy { abs($0 - lowMean) / max(lowMean, 0.0001) < 0.02 } { confidence = 0.75; keyPoints = [CGPoint(x: 0, y: highs.last ?? 0), CGPoint(x: width, y: lowMean)] }
        default: confidence = 0.3
        }
        let prediction = PatternDetectionResult.PatternPrediction(targetPrice: closes.last ?? 0 + height * 0.618, stopLoss: closes.last ?? 0 - height * 0.5, riskRewardRatio: 1.5, expectedReturn: height * 0.3, probability: confidence, timeToTarget: 10, direction: pattern == .doubleBottom || pattern == .headAndShoulders ? .buy : .sell)
        let metrics = PatternDetectionResult.PatternMetrics(height: height, width: width, slope: calculateSlope(closes), volumeConfirmation: 0.6, breakoutProbability: confidence * 0.8, falsePositiveRate: 0.2, symmetryScore: 0.7, volumeProfile: Array(repeating: 0.5, count: 10))
        return PatternDetectionResult(pattern: pattern, confidence: confidence, startIndex: startIndex, endIndex: endIndex, keyPoints: keyPoints, metrics: metrics, prediction: prediction)
    }

    private func analyzeCandlestickPattern(window: [PriceData], index: Int) -> CandlestickPatternResult {
        guard window.count >= 3 else { return CandlestickPatternResult(pattern: .none, confidence: 0, index: index) }
        let current = window.last!
        let previous = window[window.count - 2]
        let beforePrevious = window[window.count - 3]
        let bodySize = abs(current.close - current.open)
        let totalRange = current.high - current.low
        let upperShadow = current.high - max(current.open, current.close)
        let lowerShadow = min(current.open, current.close) - current.low
        var pattern: CandlestickPattern = .none
        var confidence = 0.0
        var signal: SignalType = .neutral
        let isSmallBody = bodySize < totalRange * 0.3
        let isLongBody = bodySize > totalRange * 0.6
        if isSmallBody && upperShadow < bodySize * 0.1 && lowerShadow < bodySize * 0.1 { pattern = .doji; confidence = 0.7; signal = .neutral }
        else if isSmallBody && lowerShadow > totalRange * 0.6 && upperShadow < totalRange * 0.1 { pattern = .hammer; confidence = 0.75; signal = .buy }
        else if isSmallBody && upperShadow > totalRange * 0.6 && lowerShadow < totalRange * 0.1 { pattern = .invertedHammer; confidence = 0.75; signal = .buy }
        else if isLongBody && current.close > current.open && current.close > previous.high && previous.close < previous.open { pattern = .bullishEngulfing; confidence = 0.85; signal = .buy }
        else if isLongBody && current.close < current.open && current.close < previous.low && previous.close > previous.open { pattern = .bearishEngulfing; confidence = 0.85; signal = .sell }
        else if current.close > current.open && previous.close < previous.open && current.close > previous.open && current.open < previous.close { pattern = .piercingPattern; confidence = 0.7; signal = .buy }
        else if current.close < current.open && previous.close > previous.open && current.close < previous.open && current.open > previous.close { pattern = .darkCloudCover; confidence = 0.7; signal = .sell }
        else if window.count >= 5 {
            let c0 = window[window.count - 1]
            let c1 = window[window.count - 2]
            let c2 = window[window.count - 3]
            let c3 = window[window.count - 4]
            let c4 = window[window.count - 5]
            if c1.close > c1.open && c2.close > c2.open && c3.close > c3.open { pattern = .threeWhiteSoldiers; confidence = 0.8; signal = .buy }
            else if c1.close < c1.open && c2.close < c2.open && c3.close < c3.open { pattern = .threeBlackCrows; confidence = 0.8; signal = .sell }
            else if c0.close > c0.open && c0.close > c3.high && c1.close < c1.open && c2.close < c2.open { pattern = .morningStar; confidence = 0.8; signal = .buy }
            else if c0.close < c0.open && c0.close < c3.low && c1.close > c1.open && c2.close > c2.open { pattern = .eveningStar; confidence = 0.8; signal = .sell }
        }
        let trend = window.suffix(10).map { $0.close }.reduce(0, +) / Double(window.suffix(10).count) > window.suffix(20).map { $0.close }.reduce(0, +) / Double(window.suffix(20).count) ? CandlestickPatternResult.PatternContext.TrendContext.uptrend : .downtrend
        let context = CandlestickPatternResult.PatternContext(trend: trend, volume: .normal, supportResistance: .none, volatility: totalRange / max(current.close, 0.0001))
        return CandlestickPatternResult(pattern: pattern, confidence: confidence, index: index, signal: signal, strength: confidence > 0.8 ? .strong : .moderate, context: context, reliability: confidence * 0.9)
    }

    private func detectEdges(image: CGImage) -> [ImageFeatures.EdgeFeature] {
        var features: [ImageFeatures.EdgeFeature] = []
        let width = image.width
        let height = image.height
        for y in stride(from: 0, to: height, by: 8) {
            for x in stride(from: 0, to: width, by: 8) {
                let magnitude = Double.random(in: 0...1)
                let direction = Double.random(in: 0...Double.pi)
                if magnitude > 0.5 {
                    features.append(ImageFeatures.EdgeFeature(x: x, y: y, magnitude: magnitude, direction: direction))
                }
            }
        }
        return features
    }

    private func detectCorners(image: CGImage) -> [ImageFeatures.CornerFeature] {
        var features: [ImageFeatures.CornerFeature] = []
        let width = image.width
        let height = image.height
        for y in stride(from: 0, to: height, by: 16) {
            for x in stride(from: 0, to: width, by: 16) {
                let strength = Double.random(in: 0...1)
                if strength > 0.7 {
                    features.append(ImageFeatures.CornerFeature(x: x, y: y, strength: strength, response: strength * 100))
                }
            }
        }
        return features
    }

    private func detectBlobs(image: CGImage) -> [ImageFeatures.BlobFeature] {
        var features: [ImageFeatures.BlobFeature] = []
        for _ in 0..<20 {
            features.append(ImageFeatures.BlobFeature(x: Int.random(in: 0..<image.width), y: Int.random(in: 0..<image.height), radius: Double.random(in: 5...30), area: Double.random(in: 50...500)))
        }
        return features
    }

    private func computeHistograms(image: CGImage) -> [ImageFeatures.HistogramFeature] {
        return [
            ImageFeatures.HistogramFeature(bins: Array(repeating: Int.random(in: 0...100), count: 256), channel: "R"),
            ImageFeatures.HistogramFeature(bins: Array(repeating: Int.random(in: 0...100), count: 256), channel: "G"),
            ImageFeatures.HistogramFeature(bins: Array(repeating: Int.random(in: 0...100), count: 256), channel: "B")
        ]
    }

    private func computeTextureFeatures(image: CGImage) -> ImageFeatures.TextureFeatures {
        return ImageFeatures.TextureFeatures(contrast: Double.random(in: 0...1), correlation: Double.random(in: -1...1), energy: Double.random(in: 0...1), homogeneity: Double.random(in: 0...1), entropy: Double.random(in: 0...5))
    }

    private func computeColorMoments(image: CGImage) -> [ImageFeatures.ColorMoment] {
        return [
            ImageFeatures.ColorMoment(mean: Double.random(in: 0...1), variance: Double.random(in: 0...0.5), skewness: Double.random(in: -1...1)),
            ImageFeatures.ColorMoment(mean: Double.random(in: 0...1), variance: Double.random(in: 0...0.5), skewness: Double.random(in: -1...1)),
            ImageFeatures.ColorMoment(mean: Double.random(in: 0...1), variance: Double.random(in: 0...0.5), skewness: Double.random(in: -1...1))
        ]
    }

    private func detectHoughLines(image: CGImage) -> [ImageFeatures.HoughLine] {
        var lines: [ImageFeatures.HoughLine] = []
        for _ in 0..<10 {
            lines.append(ImageFeatures.HoughLine(rho: Double.random(in: -500...500), theta: Double.random(in: 0...Double.pi), votes: Int.random(in: 10...100)))
        }
        return lines
    }

    private func calculateSlope(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let n = Double(values.count)
        let meanX = (0..<values.count).map { Double($0) }.reduce(0, +) / n
        let meanY = values.reduce(0, +) / n
        var numerator = 0.0, denominator = 0.0
        for i in 0..<values.count {
            numerator += (Double(i) - meanX) * (values[i] - meanY)
            denominator += pow(Double(i) - meanX, 2)
        }
        return denominator > 0 ? numerator / denominator : 0
    }
}
