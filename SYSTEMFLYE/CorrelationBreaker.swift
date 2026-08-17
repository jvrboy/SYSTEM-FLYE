import Foundation
import Combine
import Accelerate

// MARK: - Correlation Models
struct CorrelationMatrix: Codable, Identifiable {
    let id = UUID()
    var matrix: [[Double]]
    var assets: [String]
    var timestamp: Date
    var sampleSize: Int
    var halfLife: TimeInterval

    init(assets: [String], matrix: [[Double]], sampleSize: Int = 252, halfLife: TimeInterval = 30 * 86400) {
        self.id = UUID()
        self.assets = assets
        self.matrix = matrix
        self.timestamp = Date()
        self.sampleSize = sampleSize
        self.halfLife = halfLife
    }

    subscript(i: Int, j: Int) -> Double { matrix[i][j] }
    var isSymmetric: Bool {
        for i in 0..<min(assets.count, matrix.count) {
            for j in 0..<min(assets.count, matrix[i].count) {
                if matrix[i][j] != matrix[j][i] { return false }
            }
        }
        return true
    }
    var isPositiveDefinite: Bool {
        let n = min(assets.count, matrix.count)
        for k in 0..<n {
            if matrix[k][k] <= 0 { return false }
            for i in k + 1..<n {
                let factor = matrix[i][k] / max(matrix[k][k], 0.0001)
                for j in k + 1..<n { matrix[i][j] -= factor * matrix[k][j] }
            }
        }
        return true
    }
    var eigenvalues: [Double] {
        let n = min(assets.count, matrix.count)
        var result = Array(repeating: Double(0), count: n)
        for i in 0..<n { result[i] = matrix[i][i] }
        return result.sorted { $0 > $1 }
    }
}

struct RegimeDetection: Codable, Identifiable {
    let id = UUID()
    var currentRegime: Regime
    var regimeProbability: Double
    var regimes: [Regime]
    var transitionMatrix: [[Double]]
    var meanRevertingAssets: [String]
    var trendingAssets: [String]
    var highVolatilityAssets: [String]
    var lowLiquidityAssets: [String]
    var lastUpdated: Date

    struct Regime: Codable, Identifiable, Hashable {
        let id = UUID()
        var name: String
        var description: String
        var volatilityLevel: VolatilityLevel
        var trendDirection: TrendDirection
        var liquidityCondition: LiquidityCondition
        var correlationLevel: CorrelationLevel
        var probability: Double
        var duration: TimeInterval
        var startDate: Date

        enum VolatilityLevel: String, Codable { case low = "LOW", normal = "NORMAL", high = "HIGH", extreme = "EXTREME" }
        enum TrendDirection: String, Codable { case strongUp = "STRONG_UP", up = "UP", sideways = "SIDEWAYS", down = "DOWN", strongDown = "STRONG_DOWN" }
        enum LiquidityCondition: String, Codable { case abundant = "ABUNDANT", normal = "NORMAL", stressed = "STRESSED", illiquid = "ILLIQUID" }
        enum CorrelationLevel: String, Codable { case fragmented = "FRAGMENTED", normal = "NORMAL", elevated = "ELEVATED", extreme = "EXTREME" }
    }

    init(currentRegime: Regime, regimeProbability: Double = 1.0, regimes: [Regime] = [], transitionMatrix: [[Double]] = [], meanRevertingAssets: [String] = [], trendingAssets: [String] = [], highVolatilityAssets: [String] = [], lowLiquidityAssets: [String] = [], lastUpdated: Date = Date()) {
        self.id = UUID()
        self.currentRegime = currentRegime
        self.regimeProbability = regimeProbability
        self.regimes = regimes
        self.transitionMatrix = transitionMatrix
        self.meanRevertingAssets = meanRevertingAssets
        self.trendingAssets = trendingAssets
        self.highVolatilityAssets = highVolatilityAssets
        self.lowLiquidityAssets = lowLiquidityAssets
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Risk Decomposition
struct RiskDecomposition: Codable, Identifiable {
    let id = UUID()
    var totalRisk: Double
    var systematicRisk: Double
    var idiosyncraticRisk: Double
    var factorExposures: [FactorExposure]
    var marginalContributions: [String: Double]
    var componentValueAtRisk: [String: Double]
    var diversificationRatio: Double
    var concentrationIndex: Double
    var tailDependence: [String: Double]
    var timestamp: Date

    struct FactorExposure: Codable, Identifiable {
        let id = UUID()
        var factorName: String
        var beta: Double
        var alpha: Double
        var rSquared: Double
        var trackingError: Double
        var informationRatio: Double
        var contribution: Double
    }

    init(totalRisk: Double = 0, systematicRisk: Double = 0, idiosyncraticRisk: Double = 0, factorExposures: [FactorExposure] = [], marginalContributions: [String: Double] = [:], componentValueAtRisk: [String: Double] = [:], diversificationRatio: Double = 0, concentrationIndex: Double = 0, tailDependence: [String: Double] = [:], timestamp: Date = Date()) {
        self.id = UUID()
        self.totalRisk = totalRisk
        self.systematicRisk = systematicRisk
        self.idiosyncraticRisk = idiosyncraticRisk
        self.factorExposures = factorExposures
        self.marginalContributions = marginalContributions
        self.componentValueAtRisk = componentValueAtRisk
        self.diversificationRatio = diversificationRatio
        self.concentrationIndex = concentrationIndex
        self.tailDependence = tailDependence
        self.timestamp = timestamp
    }
}

// MARK: - Correlation Analysis Result
struct CorrelationAnalysisResult: Codable, Identifiable {
    let id = UUID()
    var correlationMatrix: CorrelationMatrix
    var decomposition: RiskDecomposition
    var regime: RegimeDetection
    var breakdownSignals: [BreakdownSignal]
    var timestamp: Date

    struct BreakdownSignal: Codable, Identifiable {
        let id = UUID()
        var asset1: String
        var asset2: String
        var oldCorrelation: Double
        var newCorrelation: Double
        var zScore: Double
        var severity: Severity
        var timestamp: Date

        enum Severity: String, Codable { case low = "LOW", medium = "MEDIUM", high = "HIGH", extreme = "EXTREME" }
    }

    init(correlationMatrix: CorrelationMatrix, decomposition: RiskDecomposition, regime: RegimeDetection, breakdownSignals: [BreakdownSignal] = [], timestamp: Date = Date()) {
        self.id = UUID()
        self.correlationMatrix = correlationMatrix
        self.decomposition = decomposition
        self.regime = regime
        self.breakdownSignals = breakdownSignals
        self.timestamp = timestamp
    }
}

// MARK: - Factor Model
struct FactorModel: Codable, Identifiable {
    let id = UUID()
    var factors: [Factor]
    var factorReturns: [[Double]]
    var assetLoadings: [[Double]]
    var residualCovariance: [[Double]]
    var explainedVariance: Double
    var timestamp: Date

    struct Factor: Codable, Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var eigenvalue: Double
        var explainedVariance: Double
        var cumulativeVariance: Double
        var topAssets: [String]
        var interpretation: String
    }
}

// MARK: - Correlation Breaker Engine
@MainActor
final class CorrelationBreaker: ObservableObject {
    static let shared = CorrelationBreaker()
    @Published private(set) var correlationMatrix: CorrelationMatrix?
    @Published private(set) var regimeDetection: RegimeDetection?
    @Published private(set) var analysisResults: [CorrelationAnalysisResult] = []
    @Published private(set) var isAnalyzing = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func analyzeCorrelation(priceHistory: [String: [Double]], lookbackWindow: Int = 252, decayFactor: Double = 0.94) async -> CorrelationAnalysisResult? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        defer { isAnalyzing = false }
        let assets = Array(priceHistory.keys)
        let n = assets.count
        guard n > 1 else { return nil }
        let returns = priceHistory.values.map { calculateReturns(prices: $0.suffix(lookbackWindow).map { $0 }) }
        let matrix = calculateCorrelationMatrix(returns: returns, decayFactor: decayFactor)
        let correlationMatrix = CorrelationMatrix(assets: assets, matrix: matrix, sampleSize: lookbackWindow)
        let decomposition = decomposeRisk(matrix: correlationMatrix, returns: returns, assets: assets)
        let regime = detectRegime(priceHistory: priceHistory, correlationMatrix: correlationMatrix)
        let breakdownSignals = detectBreakdowns(matrix: correlationMatrix, assets: assets)
        let result = CorrelationAnalysisResult(correlationMatrix: correlationMatrix, decomposition: decomposition, regime: regime, breakdownSignals: breakdownSignals)
        self.correlationMatrix = correlationMatrix
        self.regimeDetection = regime
        if analysisResults.count >= maxResults { analysisResults.removeFirst() }
        analysisResults.append(result)
        return result
    }

    func cancelAnalysis() { cancellationToken?.cancel() }

    func calculateRollingCorrelation(series1: [Double], series2: [Double], window: Int = 30) -> [Double] {
        guard series1.count == series2.count, series1.count >= window else { return [] }
        var correlations: [Double] = []
        for i in (window - 1)..<series1.count {
            let slice1 = Array(series1[i - window + 1...i])
            let slice2 = Array(series2[i - window + 1...i])
            correlations.append(pearsonCorrelation(slice1, slice2))
        }
        return correlations
    }

    func calculateBeta(assetReturns: [Double], marketReturns: [Double]) -> Double {
        guard assetReturns.count == marketReturns.count, assetReturns.count > 1 else { return 0 }
        let covariance = zip(assetReturns, marketReturns).map { $0 * $1 }.reduce(0, +) / Double(assetReturns.count - 1)
        let marketVariance = marketReturns.map { $0 * $0 }.reduce(0, +) / Double(marketReturns.count - 1)
        return marketVariance > 0 ? covariance / marketVariance : 0
    }

    func performPCA(priceHistory: [String: [Double]]) -> FactorModel? {
        guard priceHistory.count > 2 else { return nil }
        let assets = Array(priceHistory.keys)
        let returns = priceHistory.values.map { calculateReturns(prices: $0) }
        let matrix = calculateCorrelationMatrix(returns: returns)
        let eigenvectors = computeEigenvectors(matrix: matrix)
        let eigenvalues = eigenvectors.map { $0.reduce(0, +) }
        let totalVariance = eigenvalues.reduce(0, +)
        let explainedVariance = totalVariance > 0 ? eigenvalues.reduce(0, +) / totalVariance : 0
        let factors: [FactorModel.Factor] = eigenvalues.enumerated().compactMap { index, eigenvalue in
            guard assets.count == eigenvectors[index].count else { return nil }
            let explained = totalVariance > 0 ? eigenvalue / totalVariance : 0
            let topAssets = zip(assets, eigenvectors[index]).sorted { $0.1 > $1.1 }.prefix(5).map { $0.0 }
            return FactorModel.Factor(id: UUID(), name: "PC\(index + 1)", description: "Principal Component \(index + 1)", eigenvalue: eigenvalue, explainedVariance: explained, cumulativeVariance: 0, topAssets: topAssets, interpretation: "")
        }
        let cumulativeVariances = factors.reduce(into: [Double]()) { result, factor in
            result.append((result.last ?? 0) + factor.explainedVariance)
        }
        let factorReturns = eigenvectors.map { eigenvector in
            returns.map { assetReturns in zip(assetReturns, eigenvector).map { $0 * $1 }.reduce(0, +) }
        }
        return FactorModel(factors: factors.enumerated().map { FactorModel.Factor(id: $0.element.id, name: $0.element.name, description: $0.element.description, eigenvalue: $0.element.eigenvalue, explainedVariance: $0.element.explainedVariance, cumulativeVariance: cumulativeVariances[$0.offset], topAssets: $0.element.topAssets, interpretation: $0.element.interpretation) }, factorReturns: factorReturns, assetLoadings: eigenvectors, residualCovariance: matrix, explainedVariance: explainedVariance, timestamp: Date())
    }

    private func calculateCorrelationMatrix(returns: [[Double]], decayFactor: Double = 1.0) -> [[Double]] {
        let n = returns.count
        guard n > 1 else { return [] }
        var matrix: [[Double]] = Array(repeating: Array(repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in i..<n {
                let corr = decayFactor == 1.0 ? pearsonCorrelation(returns[i], returns[j]) : exponentialWeightedCorrelation(returns[i], returns[j], decayFactor: decayFactor)
                matrix[i][j] = corr
                matrix[j][i] = corr
            }
            matrix[i][i] = 1.0
        }
        return matrix
    }

    private func exponentialWeightedCorrelation(_ x: [Double], _ y: [Double], decayFactor: Double) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let n = Double(x.count)
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0
        var weightSum = 0.0
        for i in 0..<x.count {
            let weight = pow(decayFactor, Double(x.count - 1 - i))
            sumX += x[i] * weight
            sumY += y[i] * weight
            sumXY += x[i] * y[i] * weight
            sumX2 += x[i] * x[i] * weight
            sumY2 += y[i] * y[i] * weight
            weightSum += weight
        }
        let meanX = sumX / weightSum
        let meanY = sumY / weightSum
        let covXY = (sumXY / weightSum) - meanX * meanY
        let varX = (sumX2 / weightSum) - meanX * meanX
        let varY = (sumY2 / weightSum) - meanY * meanY
        let denom = sqrt(max(0, varX * varY))
        return denom > 0 ? covXY / denom : 0
    }

    private func decomposeRisk(matrix: CorrelationMatrix, returns: [[Double]], assets: [String]) -> RiskDecomposition {
        let n = assets.count
        let totalVolatility = returns.map { stdDev($0) }.reduce(0, +) / Double(max(1, n))
        let systematicRisk = totalVolatility * 0.6
        let idiosyncraticRisk = totalVolatility * 0.4
        let weights = Array(repeating: 1.0 / Double(max(1, n)), count: n)
        let diversificationRatio = n > 1 ? totalVolatility / (weights.map { $0 * $0 }.reduce(0, +) * totalVolatility) : 1.0
        let concentrationIndex = weights.map { $0 * $0 }.reduce(0, +)
        let marginalContributions = Dictionary(uniqueKeysWithValues: zip(assets, weights))
        let componentVaR = Dictionary(uniqueKeysWithValues: zip(assets, returns.map { _ in totalVolatility * 0.02 }))
        let tailDependence: [String: Double] = [:]
        for i in 0..<n {
            for j in i + 1..<n {
                tailDependence["\(assets[i])-\(assets[j])"] = pearsonCorrelation(returns[i], returns[j]) * 0.5
            }
        }
        return RiskDecomposition(totalRisk: totalVolatility, systematicRisk: systematicRisk, idiosyncraticRisk: idiosyncraticRisk, marginalContributions: marginalContributions, componentValueAtRisk: componentVaR, diversificationRatio: diversificationRatio, concentrationIndex: concentrationIndex, tailDependence: tailDependence)
    }

    private func detectRegime(priceHistory: [String: [Double]], correlationMatrix: CorrelationMatrix) -> RegimeDetection {
        let returns = priceHistory.values.map { calculateReturns(prices: $0) }
        let volatilities = returns.map { stdDev($0) }
        let avgVol = volatilities.reduce(0, +) / Double(max(1, volatilities.count))
        let trendDirections = returns.map { trendDirection(for: $0) }
        let trendingCount = trendDirections.filter { $0 == .up || $0 == .down }.count
        let avgCorrelation = correlationMatrix.matrix.flatMap { $0 }.reduce(0, +) / Double(max(1, correlationMatrix.matrix.count * correlationMatrix.matrix.count))
        let volLevel: RegimeDetection.Regime.VolatilityLevel = avgVol > 0.03 ? .extreme : avgVol > 0.02 ? .high : avgVol > 0.01 ? .normal : .low
        let trendDir: RegimeDetection.Regime.TrendDirection = trendingCount > Double(returns.count) * 0.6 ? .up : trendingCount < Double(returns.count) * 0.3 ? .down : .sideways
        let corrLevel: RegimeDetection.Regime.CorrelationLevel = avgCorrelation > 0.7 ? .extreme : avgCorrelation > 0.5 ? .elevated : avgCorrelation > 0.3 ? .normal : .fragmented
        let regime = RegimeDetection.Regime(id: UUID(), name: "Current Market Regime", description: "Detected \(volLevel.rawValue) volatility, \(trendDir.rawValue) trend", volatilityLevel: volLevel, trendDirection: trendDir, liquidityCondition: .normal, correlationLevel: corrLevel, probability: 0.85, duration: 0, startDate: Date())
        return RegimeDetection(currentRegime: regime, regimeProbability: 0.85, regimes: [regime])
    }

    private func detectBreakdowns(matrix: CorrelationMatrix, assets: [String]) -> [CorrelationAnalysisResult.BreakdownSignal] {
        var signals: [CorrelationAnalysisResult.BreakdownSignal] = []
        let n = assets.count
        for i in 0..<n {
            for j in i + 1..<n {
                let corr = matrix[i, j]
                if abs(corr) > 0.8 {
                    let zScore = abs(corr - 0.3) / 0.2
                    let severity: CorrelationAnalysisResult.BreakdownSignal.Severity = zScore > 3 ? .extreme : zScore > 2 ? .high : zScore > 1 ? .medium : .low
                    signals.append(CorrelationAnalysisResult.BreakdownSignal(asset1: assets[i], asset2: assets[j], oldCorrelation: 0.3, newCorrelation: corr, zScore: zScore, severity: severity, timestamp: Date()))
                }
            }
        }
        return signals
    }

    private func computeEigenvectors(matrix: [[Double]]) -> [[Double]] {
        let n = matrix.count
        var result = matrix
        for k in 0..<n {
            for i in k + 1..<n {
                let factor = result[i][k] / max(result[k][k], 0.0001)
                for j in k..<n { result[i][j] -= factor * result[k][j] }
            }
        }
        return result
    }

    private func trendDirection(for returns: [Double]) -> RegimeDetection.Regime.TrendDirection {
        guard returns.count > 5 else { return .sideways }
        let recent = returns.suffix(5).reduce(0, +)
        if recent > 0.01 { return .up }
        if recent < -0.01 { return .down }
        return .sideways
    }
}

private func calculateReturns(prices: [Double]) -> [Double] {
    guard prices.count > 1 else { return [] }
    return zip(prices, prices.dropFirst()).map { $0 > 0 ? ($1 - $0) / $0 : 0 }
}

private func stdDev(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
    return sqrt(max(0, variance))
}

private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
    guard x.count == y.count, x.count > 1 else { return 0 }
    let n = Double(x.count)
    let meanX = x.reduce(0, +) / n
    let meanY = y.reduce(0, +) / n
    var num = 0.0, denX = 0.0, denY = 0.0
    for i in 0..<x.count {
        let dx = x[i] - meanX
        let dy = y[i] - meanY
        num += dx * dy
        denX += dx * dx
        denY += dy * dy
    }
    let den = sqrt(max(0, denX * denY))
    return den == 0 ? 0 : num / den
}
