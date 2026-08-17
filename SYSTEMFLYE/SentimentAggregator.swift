import Foundation
import Combine

enum SentimentSource: String, Codable {
    case news = "NEWS"
    case social = "SOCIAL"
    case positioning = "POSITIONING"
    case analyst = "ANALYST"
    case earnings = "EARNINGS"
    case centralBank = "CENTRAL_BANK"
}

enum SentimentPolarity: String, Codable {
    case bullish = "BULLISH"
    case bearish = "BEARISH"
    case neutral = "NEUTRAL"
}

struct SentimentScore: Identifiable, Codable {
    let id = UUID()
    let source: SentimentSource
    let polarity: SentimentPolarity
    let score: Double
    let confidence: Double
    let volume: Int64
    let timestamp: Date
    let headline: String
    let asset: String
}

struct CompositeSentiment: Codable, Identifiable {
    let id = UUID()
    let asset: String
    let bullishScore: Double
    let bearishScore: Double
    let netScore: Double
    let confidence: Double
    let sources: [SentimentSource]
    let timestamp: Date
    let momentum: Double
    let divergence: Bool
}

@MainActor
final class SentimentAggregator: ObservableObject {
    static let shared = SentimentAggregator()
    @Published private(set) var recentScores: [SentimentScore] = []
    @Published private(set) var compositeSentiment: [String: CompositeSentiment] = [:]
    @Published private(set) var sentimentMomentum: [String: Double] = [:]
    @Published private(set) var sourceWeights: [SentimentSource: Double] = [
        .news: 0.3, .social: 0.2, .positioning: 0.2, .analyst: 0.15, .earnings: 0.1, .centralBank: 0.25
    ]

    private let maxHistorySize = 2000
    private let storage = DatabaseManager.shared

    private init() {
        loadHistoricalSentiment()
    }

    func addScore(_ score: SentimentScore) {
        recentScores.append(score)
        if recentScores.count > maxHistorySize { recentScores.removeFirst(recentScores.count - maxHistorySize) }
        updateCompositeSentiment(for: score.asset)
    }

    func composite(for asset: String) -> CompositeSentiment? { compositeSentiment[asset] }
    func netSentiment(for asset: String) -> Double { compositeSentiment[asset]?.netScore ?? 0 }
    func bullishProbability(for asset: String) -> Double {
        guard let composite = compositeSentiment[asset] else { return 0.5 }
        return max(0, min(1, 0.5 + composite.netScore * 0.5))
    }

    func divergenceDetected(for asset: String) -> Bool {
        return compositeSentiment[asset]?.divergence ?? false
    }

    func sentimentSurge(for asset: String) -> Bool {
        guard let momentum = sentimentMomentum[asset] else { return false }
        return abs(momentum) > 0.3
    }

    private func updateCompositeSentiment(for asset: String) {
        let assetScores = recentScores.filter { $0.asset == asset }
        guard !assetScores.isEmpty else { return }

        var bullish = 0.0, bearish = 0.0, totalConfidence = 0.0
        var sources: [SentimentSource] = []
        for score in assetScores.suffix(100) {
            let weight = sourceWeights[score.source] ?? 0.1
            let weightedScore = score.score * weight * score.confidence
            if score.polarity == .bullish { bullish += weightedScore }
            else if score.polarity == .bearish { bearish += weightedScore }
            totalConfidence += weight * score.confidence
            if !sources.contains(score.source) { sources.append(score.source) }
        }

        let netScore = bullish - bearish
        let confidence = min(1.0, totalConfidence / Double(max(assetScores.count, 1)))
        let previous = compositeSentiment[asset]?.netScore ?? 0
        let momentum = netScore - previous
        let divergence = (previous > 0 && netScore < -0.2) || (previous < 0 && netScore > 0.2)

        compositeSentiment[asset] = CompositeSentiment(
            asset: asset,
            bullishScore: bullish,
            bearishScore: bearish,
            netScore: netScore,
            confidence: confidence,
            sources: sources,
            timestamp: Date(),
            momentum: momentum,
            divergence: divergence
        )
        sentimentMomentum[asset] = momentum
    }

    private func loadHistoricalSentiment() {
        do {
            let historical = try storage.query("SELECT data FROM sentiment_scores ORDER BY timestamp DESC LIMIT 500", parameters: [:]) { row in
                guard let data = row.data(at: 0) else { return SentimentScore(source: .news, polarity: .neutral, score: 0, confidence: 0, volume: 0, timestamp: Date(), headline: "", asset: "") }
                return try JSONDecoder.flye.decode(SentimentScore.self, from: data)
            }
            recentScores = historical
            for score in historical { updateCompositeSentiment(for: score.asset) }
        } catch { print("Failed to load sentiment history: \\(error)") }
    }
}
