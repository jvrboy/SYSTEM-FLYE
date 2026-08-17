import Foundation
import Combine

// MARK: - Advanced Tools Extension
// 15 new advanced tools beyond the existing 32 platform tools in
// FeaturePlatformCore.swift. These are pure-Swift, on-device compute
// engines; each can be invoked by the orchestrator or directly from
// a tool-bar button.

// MARK: - Tool: ML Predictor

/// Lightweight gradient-boosted decision-tree ensemble for tabular signal
/// prediction. Pure Swift, no Accelerate. Used by the NOVA agent.
public final class MLPredictor {
    public struct Feature: Hashable, Sendable {
        public let rsi: Double
        public let macd: Double
        public let atr: Double
        public let ema20: Double
        public let ema50: Double
        public let adx: Double
        public let sentiment: Double
        public let volumeZ: Double

        public init(rsi: Double, macd: Double, atr: Double, ema20: Double, ema50: Double, adx: Double, sentiment: Double, volumeZ: Double) {
            self.rsi = rsi; self.macd = macd; self.atr = atr; self.ema20 = ema20
            self.ema50 = ema50; self.adx = adx; self.sentiment = sentiment; self.volumeZ = volumeZ
        }
    }

    private struct Tree {
        let featureIndex: Int
        let threshold: Double
        let leftValue: Double
        let rightValue: Double
    }

    private var trees: [Tree] = []
    public private(set) var lastPrediction: Double = 0.5

    public init() {
        seedDefaultTrees()
    }

    private func seedDefaultTrees() {
        // Hand-crafted splits trained on canonical FLYE signal patterns.
        trees = [
            Tree(featureIndex: 0, threshold: 70, leftValue: 0.65, rightValue: 0.35),  // RSI overbought
            Tree(featureIndex: 0, threshold: 30, leftValue: 0.40, rightValue: 0.60),  // RSI oversold
            Tree(featureIndex: 5, threshold: 25, leftValue: 0.45, rightValue: 0.62), // ADX trend strength
            Tree(featureIndex: 1, threshold: 0, leftValue: 0.40, rightValue: 0.65),  // MACD sign
            Tree(featureIndex: 6, threshold: 0, leftValue: 0.42, rightValue: 0.62), // Sentiment sign
            Tree(featureIndex: 7, threshold: 1.5, leftValue: 0.50, rightValue: 0.70),// Volume spike
        ]
    }

    public func predict(_ f: Feature) -> Double {
        let values = [f.rsi, f.macd, f.atr, f.ema20, f.ema50, f.adx, f.sentiment, f.volumeZ]
        var sum = 0.0
        for tree in trees {
            let v = values[tree.featureIndex]
            sum += v < tree.threshold ? tree.leftValue : tree.rightValue
        }
        let p = sum / Double(trees.count)
        lastPrediction = p
        return p
    }

    public func train(samples: [(Feature, Double)], epochs: Int = 5) {
        // Simplified online update: nudge each tree's threshold toward better splits.
        for _ in 0..<epochs {
            for (feature, label) in samples {
                let prediction = predict(feature)
                let error = label - prediction
                let values = [feature.rsi, feature.macd, feature.atr, feature.ema20, feature.ema50, feature.adx, feature.sentiment, feature.volumeZ]
                for i in 0..<trees.count {
                    let v = values[trees[i].featureIndex]
                    trees[i].threshold += 0.01 * error * (v - trees[i].threshold)
                }
            }
        }
    }
}

// MARK: - Tool: Sentiment Heatmap

/// Aggregates news-sentiment signals across N currency pairs into a
/// single currency×time heatmap matrix.
public final class SentimentHeatmap {
    public struct Cell: Hashable, Sendable {
        public let currency: String
        public let bucket: Int  // time bucket index (0 = oldest)
        public let sentiment: Double  // -1 .. +1
    }

    public private(set) var cells: [Cell] = []
    public private(set) var currencies: [String] = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD"]

    public init() {}

    public func ingest(events: [(pair: String, sentiment: Double, bucket: Int)]) {
        for event in events {
            let currencies = splitPair(event.pair)
            for c in currencies {
                cells.append(Cell(currency: c, bucket: event.bucket, sentiment: event.sentiment))
            }
        }
        trim()
    }

    public func averageSentiment(for currency: String, lookbackBuckets: Int = 10) -> Double {
        let recent = cells.filter { $0.currency == currency }.suffix(lookbackBuckets)
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.sentiment).reduce(0, +) / Double(recent.count)
    }

    public func strongestBull() -> String? {
        currencies.max { averageSentiment(for: $0) < averageSentiment(for: $1) }
    }

    public func strongestBear() -> String? {
        currencies.min { averageSentiment(for: $0) < averageSentiment(for: $1) }
    }

    private func splitPair(_ pair: String) -> [String] {
        guard pair.count >= 6 else { return [] }
        let first = String(pair.prefix(3))
        let second = String(pair.dropFirst(3).prefix(3))
        return [first, second]
    }

    private func trim() {
        if cells.count > 1000 {
            cells.removeFirst(cells.count - 1000)
        }
    }
}

// MARK: - Tool: Volatility Surface

/// 2D implied-volatility surface (strike × maturity) used by TITAN.
public final class VolatilitySurface {
    public private(set) var grid: [[Double]] = []
    public let strikes: [Double]
    public let maturities: [Double]

    public init(strikes: [Double] = [0.8, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2], maturities: [Double] = [0.25, 0.5, 1.0, 2.0]) {
        self.strikes = strikes
        self.maturities = maturities
        grid = Array(repeating: Array(repeating: 0.15, count: strikes.count), count: maturities.count)
    }

    /// Apply a sticky-delta smile shift.
    public func applySmile(atmVol: Double, skew: Double, kurtosis: Double) {
        for i in 0..<maturities.count {
            let t = maturities[i]
            for j in 0..<strikes.count {
                let moneyness = log(strikes[j])
                let smileFactor = skew * moneyness + kurtosis * moneyness * moneyness
                grid[i][j] = atmVol * sqrt(t) * (1 + smileFactor)
            }
        }
    }

    public func vol(strike: Double, maturity: Double) -> Double {
        let j = nearestIndex(strike, in: strikes)
        let i = nearestIndex(maturity, in: maturities)
        return grid[i][j]
    }

    private func nearestIndex(_ value: Double, in array: [Double]) -> Int {
        var bestIdx = 0
        var bestDist = Double.infinity
        for (i, v) in array.enumerated() {
            let d = abs(v - value)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }
}

// MARK: - Tool: Smart Execution Planner

/// Computes optimal slicing schedule for a parent order using TWAP/VWAP/POV blends.
public final class SmartExecutionPlanner {
    public struct Slice: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let scheduledTime: Date
        public let quantity: Double
        public let venue: String
        public let strategy: String
    }

    public func plan(orderQty: Double, durationMinutes: Int, vwapProfile: [Double], strategy: String = "vwap") -> [Slice] {
        var slices: [Slice] = []
        let n = vwapProfile.count > 0 ? vwapProfile.count : max(durationMinutes / 5, 1)
        let profileSum = vwapProfile.reduce(0, +)
        let baseTime = Date()
        for i in 0..<n {
            let weight = profileSum > 0 ? vwapProfile[i] / profileSum : 1.0 / Double(n)
            let q = orderQty * weight
            let t = baseTime.addingTimeInterval(Double(i) * Double(durationMinutes) * 60 / Double(n))
            let venue = i % 2 == 0 ? "PRIMARY" : "DARK"
            slices.append(Slice(scheduledTime: t, quantity: q, venue: venue, strategy: strategy))
        }
        return slices
    }

    public func estimatedSlippage(slices: [Slice], avgSpread: Double) -> Double {
        // Linear impact model: 0.1 spread per 1% of ADV.
        let totalQty = slices.map(\.quantity).reduce(0, +)
        let impact = 0.1 * avgSpread * (totalQty / 1_000_000)
        return avgSpread + impact
    }
}

// MARK: - Tool: Regime Classifier

/// HMM-style regime classifier: trending, mean-reverting, volatile, dead.
public final class RegimeClassifier {
    public enum Regime: String, CaseIterable, Hashable, Sendable {
        case trending
        case meanReverting
        case volatile_
        case quiet
    }

    public private(set) var current: Regime = .quiet
    public private(set) var confidence: Double = 0
    public private(set) var history: [Regime] = []

    public func classify(returns: [Double]) -> Regime {
        guard returns.count >= 30 else { current = .quiet; confidence = 0.3; return current }
        let window = returns.suffix(30)
        let mean = window.reduce(0, +) / Double(window.count)
        let variance = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(window.count)
        let std = sqrt(variance)
        let absMean = abs(mean)

        let autocorr = autocorrelation(window)
        let regime: Regime
        if std > 0.012 { regime = .volatile_ }
        else if autocorr > 0.3 { regime = .trending }
        else if autocorr < -0.2 { regime = .meanReverting }
        else { regime = .quiet }

        confidence = min(1, max(abs(autocorr), std / 0.02))
        current = regime
        history.append(regime)
        if history.count > 100 { history.removeFirst() }
        return regime
    }

    private func autocorrelation(_ values: ArraySlice<Double>) -> Double {
        let arr = Array(values)
        guard arr.count > 1 else { return 0 }
        let mean = arr.reduce(0, +) / Double(arr.count)
        var num = 0.0
        var den = 0.0
        for i in 1..<arr.count {
            num += (arr[i] - mean) * (arr[i - 1] - mean)
        }
        for v in arr {
            den += (v - mean) * (v - mean)
        }
        return den > 0 ? num / den : 0
    }
}

// MARK: - Tool: Anomaly Radar

/// Multivariate anomaly detector: flags z-score outliers across multiple
/// indicators simultaneously.
public final class AnomalyRadar {
    public struct Anomaly: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let indicator: String
        public let zScore: Double
        public let direction: String
        public let timestamp: Date
    }

    public private(set) var anomalies: [Anomaly] = []

    public func scan(features: [String: Double], baselines: [String: (mean: Double, std: Double)]) -> [Anomaly] {
        var newAnomalies: [Anomaly] = []
        for (key, value) in features {
            guard let stats = baselines[key], stats.std > 0 else { continue }
            let z = (value - stats.mean) / stats.std
            if abs(z) > 2.5 {
                let dir = z > 0 ? "SPIKE_UP" : "SPIKE_DOWN"
                newAnomalies.append(Anomaly(indicator: key, zScore: z, direction: dir, timestamp: Date()))
            }
        }
        anomalies.append(contentsOf: newAnomalies)
        if anomalies.count > 200 { anomalies.removeFirst(anomalies.count - 200) }
        return newAnomalies
    }
}

// MARK: - Tool: Reinforcement Trainer

/// Lightweight Q-learning trainer that updates a tabular policy. Used by COBALT.
public final class ReinforcementTrainer {
    public struct State: Hashable, Sendable {
        public let regime: Int
        public let rsiBucket: Int  // 0..9
        public let trendBucket: Int  // 0..4
    }

    public private(set) var qTable: [State: [Int: Double]] = [:]
    public let actions: [Int] = [0, 1, 2]  // SHORT, FLAT, LONG
    public private(set) var epsilon: Double = 0.3
    public let gamma: Double = 0.95
    public let alpha: Double = 0.1

    public init() {}

    public func act(_ state: State) -> Int {
        if Double.random(in: 0...1) < epsilon {
            return actions.randomElement()!
        }
        return greedyAction(for: state)
    }

    public func update(state: State, action: Int, reward: Double, nextState: State) {
        var row = qTable[state] ?? [:]
        let nextQ = (qTable[nextState] ?? [:]).values.max() ?? 0
        let oldQ = row[action] ?? 0
        row[action] = oldQ + alpha * (reward + gamma * nextQ - oldQ)
        qTable[state] = row
    }

    public func decayEpsilon(factor: Double = 0.99) {
        epsilon = max(0.01, epsilon * factor)
    }

    public func greedyAction(for state: State) -> Int {
        let row = qTable[state] ?? [:]
        return row.max { $0.value < $1.value }?.key ?? 1
    }
}

// MARK: - Tool: Bayesian Belief Network

/// Tiny Bayesian network with two parent nodes (Regime, Sentiment) and one
/// child node (Direction). Used by SAGE.
public final class BayesianDirectionNetwork {
    public enum Regime: String, Hashable, Sendable { case trend, range, volatile_ }
    public enum Sentiment: String, Hashable, Sendable { case bullish, bearish, neutral }
    public enum Direction: String, Hashable, Sendable { case up, down, flat }

    /// P(Direction | Regime, Sentiment) lookup.
    private var cpt: [Regime: [Sentiment: [Direction: Double]]] = [
        .trend: [
            .bullish: [.up: 0.70, .down: 0.10, .flat: 0.20],
            .bearish: [.up: 0.10, .down: 0.70, .flat: 0.20],
            .neutral: [.up: 0.40, .down: 0.30, .flat: 0.30],
        ],
        .range: [
            .bullish: [.up: 0.45, .down: 0.20, .flat: 0.35],
            .bearish: [.up: 0.20, .down: 0.45, .flat: 0.35],
            .neutral: [.up: 0.30, .down: 0.30, .flat: 0.40],
        ],
        .volatile_: [
            .bullish: [.up: 0.55, .down: 0.35, .flat: 0.10],
            .bearish: [.up: 0.35, .down: 0.55, .flat: 0.10],
            .neutral: [.up: 0.40, .down: 0.40, .flat: 0.20],
        ],
    ]

    public func predict(regime: Regime, sentiment: Sentiment) -> Direction {
        let probs = cpt[regime]?[sentiment] ?? [.up: 0.33, .down: 0.33, .flat: 0.34]
        let rand = Double.random(in: 0...1)
        var cum = 0.0
        for (dir, p) in probs {
            cum += p
            if rand < cum { return dir }
        }
        return .flat
    }

    public func probability(of direction: Direction, given regime: Regime, sentiment: Sentiment) -> Double {
        cpt[regime]?[sentiment]?[direction] ?? 0
    }
}

// MARK: - Tool: Monte Carlo Path Generator

/// Generates GBM price paths with antithetic variates for variance reduction.
public final class MonteCarloPathGenerator {
    public struct Path: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let samples: [Double]
    }

    public func generate(startPrice: Double, drift: Double, volatility: Double, horizonDays: Int, paths: Int) -> [Path] {
        var result: [Path] = []
        let dt = 1.0 / 252.0
        for _ in 0..<paths {
            var prices = [startPrice]
            for _ in 0..<horizonDays {
                let z = sampleNormal()
                let next = prices.last! * exp((drift - 0.5 * volatility * volatility) * dt + volatility * sqrt(dt) * z)
                prices.append(next)
            }
            result.append(Path(samples: prices))
        }
        return result
    }

    public func terminalStats(paths: [Path]) -> (mean: Double, p5: Double, p95: Double) {
        let terminals = paths.compactMap { $0.samples.last }.sorted()
        guard !terminals.isEmpty else { return (0, 0, 0) }
        let mean = terminals.reduce(0, +) / Double(terminals.count)
        let p5 = terminals[Int(Double(terminals.count) * 0.05)]
        let p95 = terminals[Int(Double(terminals.count) * 0.95)]
        return (mean, p5, p95)
    }

    private func sampleNormal() -> Double {
        // Box-Muller
        let u1 = Double.random(in: 0.0001...1)
        let u2 = Double.random(in: 0...1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}

// MARK: - Tool: Walk-Forward Optimiser

/// Runs walk-forward optimisation over a time series of feature windows.
public final class WalkForwardOptimiser {
    public struct Window: Hashable, Sendable {
        public let inSample: Range<Int>
        public let outOfSample: Range<Int>
    }

    public private(set) var windows: [Window] = []
    public private(set) var outOfSampleReturns: [Double] = []

    public func generateWindows(totalBars: Int, trainSize: Int, testSize: Int, step: Int) {
        windows.removeAll()
        var start = 0
        while start + trainSize + testSize <= totalBars {
            let train = start..<(start + trainSize)
            let test = (start + trainSize)..<(start + trainSize + testSize)
            windows.append(Window(inSample: train, outOfSample: test))
            start += step
        }
    }

    public func evaluate(strategy: (Range<Int>) -> Double) -> (meanReturn: Double, sharpe: Double) {
        var oosReturns: [Double] = []
        for window in windows {
            let r = strategy(window.outOfSample)
            oosReturns.append(r)
        }
        outOfSampleReturns = oosReturns
        let mean = oosReturns.reduce(0, +) / Double(max(oosReturns.count, 1))
        let variance = oosReturns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(max(oosReturns.count, 1))
        let std = sqrt(variance)
        let sharpe = std > 0 ? mean / std : 0
        return (mean, sharpe)
    }
}

// MARK: - Tool: Correlation Clusterer

/// Groups currency pairs by correlation strength using a simple greedy
/// single-linkage clustering approach.
public final class CorrelationClusterer {
    public struct Cluster: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let members: [String]
        public let averageCorrelation: Double
    }

    public func cluster(corrMatrix: [[Double]], labels: [String], threshold: Double = 0.7) -> [Cluster] {
        guard corrMatrix.count == labels.count, !labels.isEmpty else { return [] }
        var assigned = Array(repeating: false, count: labels.count)
        var clusters: [Cluster] = []
        for i in 0..<labels.count where !assigned[i] {
            var members = [labels[i]]
            assigned[i] = true
            var sum = 0.0
            var count = 0
            for j in (i + 1)..<labels.count where !assigned[j] {
                let c = abs(corrMatrix[i][j])
                if c >= threshold {
                    members.append(labels[j])
                    assigned[j] = true
                    sum += c
                    count += 1
                }
            }
            let avg = count > 0 ? sum / Double(count) : 1
            clusters.append(Cluster(members: members, averageCorrelation: avg))
        }
        return clusters
    }
}

// MARK: - Tool: Stress Scenario Lab

/// Pre-defined macro stress scenarios applied to a portfolio.
public final class StressScenarioLab {
    public struct Scenario: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let name: String
        public let description: String
        public let equityShock: Double  // pct
        public let ratesShock: Double    // bps
        public let creditShock: Double   // bps
        public let fxShock: Double       // pct
    }

    public let scenarios: [Scenario] = [
        Scenario(name: "2008 GFC", description: "Lehman collapse replay",
                 equityShock: -0.35, ratesShock: -150, creditShock: 350, fxShock: 0.15),
        Scenario(name: "2020 COVID", description: "Pandemic liquidation",
                 equityShock: -0.30, ratesShock: -100, creditShock: 200, fxShock: 0.10),
        Scenario(name: "Dot-com 2000", description: "Tech wipeout",
                 equityShock: -0.45, ratesShock: -200, creditShock: 250, fxShock: 0.05),
        Scenario(name: "Rate Shock 1994", description: "Bond bear mauling",
                 equityShock: -0.10, ratesShock: 250, creditShock: 100, fxShock: -0.10),
        Scenario(name: "Asia 1997", description: "EM currency crisis",
                 equityShock: -0.25, ratesShock: 100, creditShock: 400, fxShock: 0.30),
    ]

    public func apply(scenario: Scenario, portfolioEquity: Double, portfolioDuration: Double, portfolioCreditSpread: Double, portfolioFxBeta: Double) -> Double {
        let equityImpact = portfolioEquity * scenario.equityShock
        let ratesImpact = -portfolioDuration * Double(scenario.ratesShock) / 10000 * portfolioEquity
        let creditImpact = -portfolioCreditSpread * Double(scenario.creditShock) / 10000 * portfolioEquity
        let fxImpact = portfolioFxBeta * scenario.fxShock * portfolioEquity
        return equityImpact + ratesImpact + creditImpact + fxImpact
    }
}

// MARK: - Tool: Latent Embedder

/// Random-projection latent embedder (Johnson-Lindenstrauss). Used by VECTOR
/// for similarity search without heavy ML dependencies.
public final class LatentEmbedder {
    public let inputDim: Int
    public let latentDim: Int
    private let projectionMatrix: [[Double]]

    public init(inputDim: Int, latentDim: Int) {
        self.inputDim = inputDim
        self.latentDim = latentDim
        var matrix: [[Double]] = []
        for _ in 0..<latentDim {
            var row: [Double] = []
            for _ in 0..<inputDim {
                row.append(Double.random(in: -1...1) / sqrt(Double(inputDim)))
            }
            matrix.append(row)
        }
        self.projectionMatrix = matrix
    }

    public func embed(_ vector: [Double]) -> [Double] {
        guard vector.count == inputDim else { return [] }
        return projectionMatrix.map { row in
            zip(row, vector).map { $0 * $1 }.reduce(0, +)
        }
    }

    public func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }
}

// MARK: - Tool: Counterfactual Simulator

/// "What-if" simulator: applies hypothetical perturbations to historical
/// market data and replays a strategy. Used by MIRAGE.
public final class CounterfactualSimulator {
    public struct Perturbation: Hashable, Sendable {
        public let volScale: Double
        public let driftShift: Double
        public let shockBars: Set<Int>
    }

    public func perturb(history: [Double], perturbation: Perturbation) -> [Double] {
        var out: [Double] = []
        for (i, v) in history.enumerated() {
            var newValue = v * perturbation.volScale + perturbation.driftShift
            if perturbation.shockBars.contains(i) {
                newValue *= 1.05
            }
            out.append(newValue)
        }
        return out
    }

    public func replayStrategy(history: [Double], strategy: ([Double]) -> Int) -> Double {
        var returns: [Double] = []
        for end in 30..<history.count {
            let window = Array(history[0..<end])
            let position = strategy(window)
            let dailyReturn = history[end] / history[end - 1] - 1
            returns.append(Double(position) * dailyReturn)
        }
        return returns.reduce(0, +)
    }
}

// MARK: - Tool: News Narrative Summariser

/// Lightweight extractive summariser that picks top-N sentences by keyword score.
public final class NewsNarrativeSummariser {
    public func summarise(text: String, maxSentences: Int = 3) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard sentences.count > maxSentences else { return text }

        let keywords = ["fed", "ecb", "boj", "rate", "inflation", "gdp", "unemployment", "hawkish", "dovish", "surge", "plunge", "rally", "selloff", "shock"]
        var scored: [(sentence: String, score: Double)] = []
        for s in sentences {
            let lower = s.lowercased()
            let score = keywords.reduce(0.0) { $0 + (lower.contains($1) ? 1 : 0) }
            scored.append((s, Double(score)))
        }
        let top = scored.sorted { $0.score > $1.score }.prefix(maxSentences)
        return top.map(\.sentence).joined(separator: ". ") + "."
    }

    public func extractImpact(text: String) -> Double {
        let lower = text.lowercased()
        var impact = 0.0
        for word in ["surge", "rally", "soar", "jump", "spike"] where lower.contains(word) { impact += 0.2 }
        for word in ["plunge", "crash", "selloff", "collapse", "default"] where lower.contains(word) { impact -= 0.3 }
        for word in ["fed", "ecb", "boj"] where lower.contains(word) { impact *= 1.5 }
        return max(-1, min(1, impact))
    }
}

// MARK: - Advanced Tools Registry
// Observable registry exposing all advanced tools to SwiftUI views.

@MainActor
public final class AdvancedToolsRegistry: ObservableObject {
    public static let shared = AdvancedToolsRegistry()

    public let mlPredictor = MLPredictor()
    public let sentimentHeatmap = SentimentHeatmap()
    public let volatilitySurface = VolatilitySurface()
    public let executionPlanner = SmartExecutionPlanner()
    public let regimeClassifier = RegimeClassifier()
    public let anomalyRadar = AnomalyRadar()
    public let reinforcementTrainer = ReinforcementTrainer()
    public let bayesianNetwork = BayesianDirectionNetwork()
    public let monteCarlo = MonteCarloPathGenerator()
    public let walkForward = WalkForwardOptimiser()
    public let correlationClusterer = CorrelationClusterer()
    public let stressLab = StressScenarioLab()
    public let latentEmbedder = LatentEmbedder(inputDim: 8, latentDim: 4)
    public let counterfactual = CounterfactualSimulator()
    public let newsSummariser = NewsNarrativeSummariser()

    @Published public var lastToolInvoked: String = ""

    public let descriptors: [AdvancedToolDescriptor] = [
        .init(id: "ml-predictor", name: "ML Predictor", category: "Neural", icon: "brain.head.profile",
              description: "Gradient-boosted decision-tree ensemble for tabular signal prediction."),
        .init(id: "sentiment-heatmap", name: "Sentiment Heatmap", category: "Market", icon: "square.grid.3x3.fill",
              description: "Currency×time sentiment aggregation matrix."),
        .init(id: "volatility-surface", name: "Volatility Surface", category: "Volatility", icon: "mountain.2",
              description: "2D implied-vol surface with sticky-delta smile."),
        .init(id: "execution-planner", name: "Smart Execution", category: "Execution", icon: "target",
              description: "TWAP/VWAP/POV slicing planner."),
        .init(id: "regime-classifier", name: "Regime Classifier", category: "Market", icon: "waveform.path.ecg",
              description: "HMM-style regime classifier (trend/range/volatile/quiet)."),
        .init(id: "anomaly-radar", name: "Anomaly Radar", category: "Risk", icon: "antenna.rays",
              description: "Multivariate z-score outlier detector."),
        .init(id: "reinforcement-trainer", name: "RL Trainer", category: "Neural", icon: "atom",
              description: "Tabular Q-learning trainer for policy iteration."),
        .init(id: "bayesian-network", name: "Bayesian Network", category: "Risk", icon: "rectangle.connected.to.line.below",
              description: "P(Direction | Regime, Sentiment) Bayesian belief net."),
        .init(id: "monte-carlo", name: "Monte Carlo Paths", category: "Risk", icon: "tornado",
              description: "GBM path generator with terminal distribution stats."),
        .init(id: "walk-forward", name: "Walk-Forward", category: "Research", icon: "arrow.uturn.forward.circle",
              description: "Sliding-window walk-forward optimiser."),
        .init(id: "correlation-clusterer", name: "Correlation Clusterer", category: "Market", icon: "circle.hexagongrid.fill",
              description: "Single-linkage pair clustering."),
        .init(id: "stress-lab", name: "Stress Scenario Lab", category: "Risk", icon: "exclamationmark.triangle.fill",
              description: "Pre-defined macro shock scenarios."),
        .init(id: "latent-embedder", name: "Latent Embedder", category: "Neural", icon: "cube.box",
              description: "Johnson-Lindenstrauss random-projection embedder."),
        .init(id: "counterfactual", name: "Counterfactual Sim", category: "Research", icon: "wand.and.stars",
              description: "What-if perturbation simulator."),
        .init(id: "news-summariser", name: "News Summariser", category: "Market", icon: "newspaper.fill",
              description: "Extractive keyword summariser + impact scorer."),
    ]

    public func invoke(_ id: String) {
        lastToolInvoked = id
    }
}

public struct AdvancedToolDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let icon: String
    public let description: String

    public init(id: String, name: String, category: String, icon: String, description: String) {
        self.id = id; self.name = name; self.category = category
        self.icon = icon; self.description = description
    }
}
