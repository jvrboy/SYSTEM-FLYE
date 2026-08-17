import Foundation

enum WyckoffPhase: String, Codable, Identifiable {
    case accumulation = "ACCUMULATION"
    case markup = "MARKUP"
    case distribution = "DISTRIBUTION"
    case markdown = "MARKDOWN"

    var id: String { rawValue }
}

enum WyckoffEvent: String, Codable {
    case preliminarySupport = "PS"
    case buyingClimax = "BC"
    case automaticResponse = "AR"
    case secondaryTest = "ST"
    case spring = "SPRING"
    case test = "TEST"
    case lastPointOfSupport = "LPS"
    case markup = "MARKUP"
    case preliminarySupply = "PSY"
    case sellingClimax = "SC"
    case automaticRally = "AR"
    case secondaryTestUp = "ST_UP"
    case upthrust = "UPTHRUST"
    case lastPointOfSupply = "LPSY"
    case distribution = "DIST"
    case markdown = "MARKDOWN"
}

struct WyckoffAnalysis: Identifiable, Codable {
    let id = UUID()
    let phase: WyckoffPhase
    let events: [WyckoffEvent]
    let compositeOperatorActivity: Double
    let volumeProfile: VolumeProfile
    let priceAction: PriceActionProfile
    let confidence: Double
    let timestamp: Date
    let keyLevels: [Double]

    struct VolumeProfile: Codable {
        let averageVolume: Double
        let volumeTrend: Double
        let volumeClimax: Bool
        let volumeDryUp: Bool
    }

    struct PriceActionProfile: Codable {
        let trendDirection: Double
        let volatility: Double
        let momentum: Double
        let supportTestCount: Int
        let resistanceTestCount: Int
    }
}

@MainActor
final class WyckoffMethodEngine: ObservableObject {
    static let shared = WyckoffMethodEngine()
    @Published private(set) var currentAnalysis: WyckoffAnalysis?
    @Published private(set) var analysisHistory: [WyckoffAnalysis] = []
    @Published private(set) var operatorActivityScore: Double = 0.0

    private let volumeThresholdMultiplier = 1.5
    private let minHistoryLength = 50
    private let storage = DatabaseManager.shared

    private init() {}

    func analyze(history: [PriceData]) -> WyckoffAnalysis? {
        guard history.count >= minHistoryLength else { return nil }
        let volumeProfile = analyzeVolumeProfile(history: history)
        let priceAction = analyzePriceAction(history: history)
        let events = detectWyckoffEvents(history: history, volumeProfile: volumeProfile, priceAction: priceAction)
        let phase = determineWyckoffPhase(events: events, volumeProfile: volumeProfile, priceAction: priceAction)
        let confidence = calculateConfidence(events: events, volumeProfile: volumeProfile, priceAction: priceAction)
        let compositeActivity = calculateCompositeOperatorActivity(history: history, volumeProfile: volumeProfile)

        let analysis = WyckoffAnalysis(
            phase: phase,
            events: events,
            compositeOperatorActivity: compositeActivity,
            volumeProfile: volumeProfile,
            priceAction: priceAction,
            confidence: confidence,
            timestamp: Date(),
            keyLevels: extractKeyLevels(history: history, phase: phase)
        )
        currentAnalysis = analysis
        analysisHistory.append(analysis)
        if analysisHistory.count > 200 { analysisHistory.removeFirst(analysisHistory.count - 200) }
        operatorActivityScore = compositeActivity
        return analysis
    }

    func operatorPosition() -> (accumulation: Double, distribution: Double) {
        guard let analysis = currentAnalysis else { return (0, 0) }
        switch analysis.phase {
        case .accumulation: return (analysis.compositeOperatorActivity, 1 - analysis.compositeOperatorActivity)
        case .distribution: return (1 - analysis.compositeOperatorActivity, analysis.compositeOperatorActivity)
        case .markup: return (analysis.compositeOperatorActivity * 0.7, 0.3)
        case .markdown: return (0.3, analysis.compositeOperatorActivity * 0.7)
        }
    }

    private func analyzeVolumeProfile(history: [PriceData]) -> WyckoffAnalysis.VolumeProfile {
        let volumes = history.map { Double($0.volume) }
        let avgVolume = volumes.reduce(0, +) / Double(max(volumes.count, 1))
        let recentVolumes = volumes.suffix(20)
        let recentAvg = recentVolumes.reduce(0, +) / Double(max(recentVolumes.count, 1))
        let volumeTrend = avgVolume > 0 ? recentAvg / avgVolume : 0
        let maxVolume = volumes.max() ?? 0
        let volumeClimax = maxVolume > avgVolume * volumeThresholdMultiplier * 3
        let volumeDryUp = recentAvg < avgVolume * 0.5
        return WyckoffAnalysis.VolumeProfile(averageVolume: avgVolume, volumeTrend: volumeTrend, volumeClimax: volumeClimax, volumeDryUp: volumeDryUp)
    }

    private func analyzePriceAction(history: [PriceData]) -> WyckoffAnalysis.PriceActionProfile {
        let closes = history.map { $0.close }
        let trend = calculateTrendDirection(closes: closes)
        let volatility = calculateVolatility(closes: closes)
        let momentum = calculateMomentum(closes: closes)
        let supportTests = countTests(history: history, levelType: .support)
        let resistanceTests = countTests(history: history, levelType: .resistance)
        return WyckoffAnalysis.PriceActionProfile(trendDirection: trend, volatility: volatility, momentum: momentum, supportTestCount: supportTests, resistanceTestCount: resistanceTests)
    }

    private func detectWyckoffEvents(history: [PriceData], volumeProfile: WyckoffAnalysis.VolumeProfile, priceAction: WyckoffAnalysis.PriceActionProfile) -> [WyckoffEvent] {
        var events: [WyckoffEvent] = []
        let last = history.last!
        let recent = Array(history.suffix(30))
        let maxHigh = recent.map { $0.high }.max() ?? last.high
        let minLow = recent.map { $0.low }.min() ?? last.low

        if volumeProfile.volumeClimax && last.close < maxHigh * 0.98 { events.append(.sellingClimax) }
        if volumeProfile.volumeClimax && last.close > minLow * 1.02 { events.append(.buyingClimax) }
        if volumeProfile.volumeDryUp && abs(last.close - minLow) / minLow < 0.01 { events.append(.spring) }
        if volumeProfile.volumeDryUp && abs(last.close - maxHigh) / maxHigh < 0.01 { events.append(.upthrust) }
        if priceAction.supportTestCount > 3 { events.append(.lastPointOfSupport) }
        if priceAction.resistanceTestCount > 3 { events.append(.lastPointOfSupply) }
        if events.isEmpty {
            if priceAction.trendDirection > 0 { events.append(.markup) }
            else if priceAction.trendDirection < 0 { events.append(.markdown) }
            else { events.append(.preliminarySupport) }
        }
        return events
    }

    private func determineWyckoffPhase(events: [WyckoffEvent], volumeProfile: WyckoffAnalysis.VolumeProfile, priceAction: WyckoffAnalysis.PriceActionProfile) -> WyckoffPhase {
        if events.contains(.spring) || events.contains(.preliminarySupport) { return .accumulation }
        if events.contains(.markup) || priceAction.trendDirection > 0.3 { return .markup }
        if events.contains(.upthrust) || events.contains(.sellingClimax) { return .distribution }
        if events.contains(.markdown) || priceAction.trendDirection < -0.3 { return .markdown }
        return .accumulation
    }

    private func calculateConfidence(events: [WyckoffEvent], volumeProfile: WyckoffAnalysis.VolumeProfile, priceAction: WyckoffAnalysis.PriceActionProfile) -> Double {
        let eventScore = Double(events.count) / 8.0
        let volumeScore = volumeProfile.volumeClimax ? 0.8 : volumeProfile.volumeDryUp ? 0.6 : 0.4
        let momentumScore = abs(priceAction.momentum)
        return min(0.99, (eventScore * 0.4 + volumeScore * 0.3 + momentumScore * 0.3))
    }

    private func calculateCompositeOperatorActivity(history: [PriceData], volumeProfile: WyckoffAnalysis.VolumeProfile) -> Double {
        let volumeSignal = volumeProfile.volumeClimax ? 0.8 : volumeProfile.volumeDryUp ? 0.6 : 0.4
        let closes = history.map { $0.close }
        let range = closes.max()! - closes.min()!
        let position = (closes.last! - closes.min()!) / max(range, 0.0001)
        return min(0.99, (volumeSignal * 0.6 + position * 0.4))
    }

    private func extractKeyLevels(history: [PriceData], phase: WyckoffPhase) -> [Double] {
        let recent = Array(history.suffix(50))
        let highs = recent.map { $0.high }
        let lows = recent.map { $0.low }
        var levels: [Double] = []
        levels.append(highs.max()!)
        levels.append(lows.min()!)
        levels.append((highs.max()! + lows.min()!) / 2)
        return levels
    }

    private func countTests(history: [PriceData], levelType: TestType) -> Int {
        let recent = Array(history.suffix(30))
        let level = levelType == .support ? recent.map { $0.low }.min()! : recent.map { $0.high }.max()!
        var count = 0
        for candle in recent {
            if levelType == .support {
                if abs(candle.low - level) / level < 0.005 { count += 1 }
            } else {
                if abs(candle.high - level) / level < 0.005 { count += 1 }
            }
        }
        return count
    }

    private func calculateTrendDirection(closes: [Double]) -> Double {
        let xMean = closes.enumerated().map { Double($0.offset) }.reduce(0, +) / Double(closes.count)
        let yMean = closes.reduce(0, +) / Double(closes.count)
        var numerator = 0.0, denominator = 0.0
        for (index, close) in closes.enumerated() {
            numerator += (Double(index) - xMean) * (close - yMean)
            denominator += pow(Double(index) - xMean, 2)
        }
        return denominator == 0 ? 0 : numerator / denominator
    }

    private func calculateVolatility(closes: [Double]) -> Double {
        let returns = zip(closes.dropFirst(), closes).map { ($0 - $1) / max($1, 0.00001) }
        let mean = returns.reduce(0, +) / Double(max(returns.count, 1))
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(returns.count, 1))
        return sqrt(variance)
    }

    private func calculateMomentum(closes: [Double]) -> Double {
        guard closes.count >= 14 else { return 0 }
        let recent = closes.suffix(14)
        return (recent.last! - recent.first!) / max(recent.first!, 0.00001)
    }

    enum TestType { case support, resistance }
}
