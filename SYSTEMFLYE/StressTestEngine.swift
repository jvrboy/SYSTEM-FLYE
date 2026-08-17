import Foundation
import Combine
import Accelerate

// MARK: - Stress Scenario Models
struct StressScenario: Codable, Identifiable, Hashable {
    let id = UUID()
    var name: String
    var description: String
    var severity: Severity
    var category: Category
    var shocks: [Shock]
    var correlations: [CorrelationShock]
    var historicalReference: HistoricalReference?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    enum Severity: String, Codable, CaseIterable { case mild = "MILD", moderate = "MODERATE", severe = "SEVERE", extreme = "EXTREME" }
    enum Category: String, Codable, CaseIterable { case marketCrash, interestRate, currency, commodity, geopolitical, pandemic, regulatory, custom }

    struct Shock: Codable, Identifiable, Hashable {
        let id = UUID()
        var asset: String
        var assetClass: AssetClass
        var type: ShockType
        var magnitude: Double
        var duration: TimeInterval
        var decay: DecayType
        var probability: Double
        var volatilityMultiplier: Double
        var liquidityImpact: Double
        var contagionFactor: Double
        var startOffset: TimeInterval

        enum ShockType: String, Codable { case priceDrop, priceSurge, volatilitySpike, liquidityDryUp, rateSpike, rateCut, default }
        enum DecayType: String, Codable { case none, exponential, linear, sinusoidal, powerLaw }
    }

    struct CorrelationShock: Codable, Identifiable, Hashable {
        let id = UUID()
        var asset1: String
        var asset2: String
        var newCorrelation: Double
        var duration: TimeInterval
        var decay: DecayType
    }

    struct HistoricalReference: Codable, Identifiable, Hashable {
        let id = UUID()
        var event: String
        var date: Date
        var duration: TimeInterval
        var description: String
        var source: String
        var assetImpacts: [String: [Double]]
        var macroeconomicData: [String: Double]
    }

    init(id: UUID = UUID(), name: String, description: String, severity: Severity = .moderate, category: Category = .marketCrash, shocks: [Shock] = [], correlations: [CorrelationShock] = [], historicalReference: HistoricalReference? = nil, tags: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.severity = severity
        self.category = category
        self.shocks = shocks
        self.correlations = correlations
        self.historicalReference = historicalReference
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum AssetClass: String, Codable { case equity, forex, commodity, fixedIncome, crypto, alternative }
}

// MARK: - Portfolio Stress Test Models
struct PortfolioStressTest: Codable, Identifiable {
    let id = UUID()
    let portfolioId: UUID
    let scenarioId: UUID
    let scenarioName: String
    let startValue: Double
    let endValue: Double
    let maxLoss: Double
    let maxLossPercent: Double
    let recoveryTime: TimeInterval?
    let assetImpacts: [AssetImpact]
    let riskMetrics: RiskMetrics
    let liquidityStress: LiquidityStress
    let executedAt: Date
    let success: Bool
    let error: String?

    struct AssetImpact: Codable, Identifiable {
        let id = UUID()
        let assetSymbol: String
        let assetClass: StressScenario.AssetClass
        let initialValue: Double
        let stressedValue: Double
        let loss: Double
        let lossPercent: Double
        let liquidityScore: Double
        let recoveryProbability: Double
        let volatilityShock: Double
        let correlationImpact: Double
        let timeToRecover: TimeInterval?
        let hedgingEffectiveness: Double
    }

    struct RiskMetrics: Codable {
        let var95: Double
        let var99: Double
        let expectedShortfall95: Double
        let betaStressed: Double
        let correlationBreakdown: Bool
        let diversificationRatio: Double
        let concentrationRisk: Double
        let tailRiskMeasure: Double
        let systemicRiskScore: Double
        let liquidityRiskScore: Double
        let stressDuration: TimeInterval
        let drawdownProfile: [DrawdownPoint]
    }

    struct DrawdownPoint: Codable, Identifiable {
        let id = UUID()
        let timestamp: Date
        let drawdown: Double
        let peakEquity: Double
        let recoveryProgress: Double
    }

    struct LiquidityStress: Codable {
        let bidAskSpreadWidening: Double
        let marketDepthReduction: Double
        let timeToLiquidate: TimeInterval
        let liquidationCost: Double
        let marketImpact: Double
        let fundingStress: Double
    }

    init(portfolioId: UUID, scenarioId: UUID, scenarioName: String, startValue: Double, endValue: Double, maxLoss: Double, maxLossPercent: Double, recoveryTime: TimeInterval?, assetImpacts: [AssetImpact], riskMetrics: RiskMetrics, liquidityStress: LiquidityStress, executedAt: Date = Date(), success: Bool = true, error: String? = nil) {
        self.id = UUID()
        self.portfolioId = portfolioId
        self.scenarioId = scenarioId
        self.scenarioName = scenarioName
        self.startValue = startValue
        self.endValue = endValue
        self.maxLoss = maxLoss
        self.maxLossPercent = maxLossPercent
        self.recoveryTime = recoveryTime
        self.assetImpacts = assetImpacts
        self.riskMetrics = riskMetrics
        self.liquidityStress = liquidityStress
        self.executedAt = executedAt
        self.success = success
        self.error = error
    }
}

// MARK: - Custom Shock Definition
struct CustomShock: Codable, Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var assetClass: StressScenario.AssetClass
    var magnitude: Double
    var duration: TimeInterval
    var shape: ShockShape
    var contagionFactor: Double
    var volatilityMultiplier: Double
    var liquidityImpact: Double
    var tags: [String]
    var createdAt: Date

    enum ShockShape: String, Codable, CaseIterable {
        case step = "STEP"
        case ramp = "RAMP"
        case spike = "SPIKE"
        case exponentialDecay = "EXPONENTIAL"
        case gaussian = "GAUSSIAN"
        case powerLaw = "POWER_LAW"
        case custom = "CUSTOM"
    }

    init(id: UUID = UUID(), name: String, description: String, assetClass: StressScenario.AssetClass = .equity, magnitude: Double = -0.2, duration: TimeInterval = 86400 * 30, shape: ShockShape = .step, contagionFactor: Double = 0.3, volatilityMultiplier: Double = 2.0, liquidityImpact: Double = 0.5, tags: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.assetClass = assetClass
        self.magnitude = magnitude
        self.duration = duration
        self.shape = shape
        self.contagionFactor = max(0, min(1, contagionFactor))
        self.volatilityMultiplier = max(0.1, volatilityMultiplier)
        self.liquidityImpact = max(0, min(1, liquidityImpact))
        self.tags = tags
        self.createdAt = createdAt
    }

    func apply(at time: TimeInterval, to value: Double) -> Double {
        let progress = max(0, min(1, time / duration))
        let factor: Double
        switch shape {
        case .step: factor = progress < 0.1 ? 0 : magnitude
        case .ramp: factor = magnitude * progress
        case .spike: factor = magnitude * sin(progress * .pi)
        case .exponentialDecay: factor = magnitude * exp(-3 * progress)
        case .gaussian: factor = magnitude * exp(-pow((progress - 0.5) * 2, 2) / 0.1)
        case .powerLaw: factor = magnitude * pow(1 - progress, 2)
        case .custom: factor = magnitude * sin(progress * .pi / 2)
        }
        return value * (1 + factor)
    }
}

// MARK: - Historical Scenario
struct HistoricalScenario: Codable, Identifiable {
    let id = UUID()
    var name: String
    var eventDate: Date
    var duration: TimeInterval
    var affectedAssets: [String: [Double]]
    var description: String
    var source: String
    var macroeconomicContext: [String: Double]
    var tags: [String]
    var createdAt: Date

    static let blackMonday = HistoricalScenario(name: "Black Monday 1987", eventDate: Date(timeIntervalSince1970: 563016000), duration: 86400 * 5, affectedAssets: ["equity": [-0.22, -0.05, 0.03, 0.04, 0.02]], description: "Largest one-day market crash in history", source: "NYSE Historical", macroeconomicContext: ["volatility": 0.8, "liquidity": 0.2], tags: ["crash", "equity"])
    static let financialCrisis = HistoricalScenario(name: "2008 Financial Crisis", eventDate: Date(timeIntervalSince1970: 1207094400), duration: 86400 * 90, affectedAssets: ["equity": [-0.05, -0.03, 0.02, -0.04, 0.01, -0.02, 0.03, 0.01, -0.01, 0.02]], description: "Global financial crisis triggered by subprime mortgage collapse", source: "Federal Reserve", macroeconomicContext: ["volatility": 0.6, "creditSpread": 0.4], tags: ["crisis", "credit"])
    static let covidCrash = HistoricalScenario(name: "COVID-19 Crash", eventDate: Date(timeIntervalSince1970: 1583020800), duration: 86400 * 30, affectedAssets: ["equity": [-0.08, -0.03, 0.12, 0.08, 0.02, -0.01, 0.03, 0.01, 0.02, 0.01]], description: "Fastest bear market in history", source: "CDC / Market Data", macroeconomicContext: ["volatility": 0.7, "policyResponse": 0.9], tags: ["pandemic", "volatility"])
    static let asianFinancialCrisis = HistoricalScenario(name: "1997 Asian Financial Crisis", eventDate: Date(timeIntervalSince1970: 860774400), duration: 86400 * 180, affectedAssets: ["forex": [-0.15, -0.08, -0.03, 0.05, 0.02, -0.01, 0.03]], description: "Asian currency crisis with contagion effects", source: "IMF", macroeconomicContext: ["volatility": 0.5, "capitalFlight": 0.8], tags: ["currency", "contagion"])

    init(id: UUID = UUID(), name: String, eventDate: Date, duration: TimeInterval, affectedAssets: [String: [Double]], description: String, source: String, macroeconomicContext: [String: Double] = [:], tags: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.eventDate = eventDate
        self.duration = duration
        self.affectedAssets = affectedAssets
        self.description = description
        self.source = source
        self.macroeconomicContext = macroeconomicContext
        self.tags = tags
        self.createdAt = createdAt
    }
}

// MARK: - Stress Test Result
struct StressTestResult: Codable, Identifiable {
    let id = UUID()
    let portfolioId: UUID
    let scenarios: [PortfolioStressTest]
    let worstCase: PortfolioStressTest
    let bestCase: PortfolioStressTest
    let aggregatedRisk: AggregatedRisk
    let scenarioComparison: [ScenarioComparison]
    let executedAt: Date
    let success: Bool
    let error: String?

    struct AggregatedRisk: Codable {
        let expectedShortfall: Double
        let probabilityOfExceedingDrawdown: Double
        let liquidityAtRisk: Double
        let systemicRiskScore: Double
        let diversificationBenefit: Double
        let correlationBreakdownProbability: Double
        let tailRiskMeasure: Double
        let maxStressLoss: Double
        let recoveryTimeEstimate: TimeInterval
        let sensitivityAnalysis: [String: Double]
        let riskFactorContributions: [String: Double]
        let confidenceInterval95: (lower: Double, upper: Double)
    }

    struct ScenarioComparison: Codable, Identifiable {
        let id = UUID()
        var scenarioName: String
        var lossPercent: Double
        var var95: Double
        var recoveryTime: TimeInterval
        var liquidityImpact: Double
        var severity: StressScenario.Severity
        var recommendation: String
    }

    init(id: UUID = UUID(), portfolioId: UUID, scenarios: [PortfolioStressTest], worstCase: PortfolioStressTest, bestCase: PortfolioStressTest, aggregatedRisk: AggregatedRisk, scenarioComparison: [ScenarioComparison] = [], executedAt: Date = Date(), success: Bool = true, error: String? = nil) {
        self.id = id
        self.portfolioId = portfolioId
        self.scenarios = scenarios
        self.worstCase = worstCase
        self.bestCase = bestCase
        self.aggregatedRisk = aggregatedRisk
        self.scenarioComparison = scenarioComparison
        self.executedAt = executedAt
        self.success = success
        self.error = error
    }
}

// MARK: - Stress Test Engine
@MainActor
final class StressTestEngine: ObservableObject {
    static let shared = StressTestEngine()
    @Published private(set) var results: [StressTestResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var currentScenario: String = ""
    @Published private(set) var progress: Double = 0
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50
    private let builtInScenarios: [StressScenario] = [
        StressScenario(name: "Market Crash", description: "20% equity market decline", severity: .severe, shocks: [StressScenario.Shock(asset: "equity", assetClass: .equity, type: .priceDrop, magnitude: -0.2, duration: 86400 * 30, decay: .exponential, probability: 0.15, volatilityMultiplier: 3.0, liquidityImpact: 0.6, contagionFactor: 0.8, startOffset: 0)]),
        StressScenario(name: "Interest Rate Spike", description: "200bps rate increase", severity: .moderate, shocks: [StressScenario.Shock(asset: "bonds", assetClass: .fixedIncome, type: .priceDrop, magnitude: -0.1, duration: 86400 * 60, decay: .exponential, probability: 0.3, volatilityMultiplier: 2.0, liquidityImpact: 0.4, contagionFactor: 0.5, startOffset: 0)]),
        StressScenario(name: "Currency Crisis", description: "30% currency depreciation", severity: .severe, shocks: [StressScenario.Shock(asset: "forex", assetClass: .forex, type: .priceDrop, magnitude: -0.3, duration: 86400 * 45, decay: .linear, probability: 0.1, volatilityMultiplier: 4.0, liquidityImpact: 0.7, contagionFactor: 0.6, startOffset: 0)]),
        StressScenario(name: "Commodity Shock", description: "50% commodity price spike", severity: .moderate, shocks: [StressScenario.Shock(asset: "commodity", assetClass: .commodity, type: .priceSurge, magnitude: 0.5, duration: 86400 * 20, decay: .sinusoidal, probability: 0.2, volatilityMultiplier: 2.5, liquidityImpact: 0.3, contagionFactor: 0.4, startOffset: 0)]),
        StressScenario(name: "Volatility Explosion", description: "VIX doubles", severity: .high, shocks: [StressScenario.Shock(asset: "volatility", assetClass: .equity, type: .volatilitySpike, magnitude: 1.0, duration: 86400 * 15, decay: .exponential, probability: 0.25, volatilityMultiplier: 5.0, liquidityImpact: 0.5, contagionFactor: 0.7, startOffset: 0)]),
        StressScenario(name: "Liquidity Dry-Up", description: "Market depth reduced by 70%", severity: .extreme, shocks: [StressScenario.Shock(asset: "all", assetClass: .equity, type: .liquidityDryUp, magnitude: -0.7, duration: 86400 * 10, decay: .step, probability: 0.08, volatilityMultiplier: 6.0, liquidityImpact: 0.9, contagionFactor: 0.9, startOffset: 0)]),
        StressScenario(name: "Geopolitical Shock", description: "Major geopolitical event", severity: .severe, shocks: [StressScenario.Shock(asset: "equity", assetClass: .equity, type: .priceDrop, magnitude: -0.15, duration: 86400 * 60, decay: .powerLaw, probability: 0.12, volatilityMultiplier: 3.5, liquidityImpact: 0.5, contagionFactor: 0.6, startOffset: 86400 * 3)]),
        StressScenario(name: "Pandemic Scenario", description: "Global pandemic impact", severity: .extreme, shocks: [StressScenario.Shock(asset: "equity", assetClass: .equity, type: .priceDrop, magnitude: -0.25, duration: 86400 * 90, decay: .gaussian, probability: 0.05, volatilityMultiplier: 4.0, liquidityImpact: 0.7, contagionFactor: 0.8, startOffset: 0), StressScenario.Shock(asset: "credit", assetClass: .fixedIncome, type: .priceDrop, magnitude: -0.12, duration: 86400 * 60, decay: .exponential, probability: 0.3, volatilityMultiplier: 2.5, liquidityImpact: 0.4, contagionFactor: 0.5, startOffset: 86400 * 7)])
    ]

    func runStressTest(portfolio: Portfolio, scenarios: [StressScenario], assets: [Asset]) async -> StressTestResult {
        guard !isRunning else { return StressTestResult(portfolioId: UUID(), scenarios: [], worstCase: PortfolioStressTest(portfolioId: UUID(), scenarioId: UUID(), scenarioName: "", startValue: 0, endValue: 0, maxLoss: 0, maxLossPercent: 0, assetImpacts: [], riskMetrics: PortfolioStressTest.RiskMetrics(var95: 0, var99: 0, expectedShortfall95: 0, betaStressed: 0, correlationBreakdown: false, diversificationRatio: 0, concentrationRisk: 0, tailRiskMeasure: 0, systemicRiskScore: 0, liquidityRiskScore: 0, stressDuration: 0, drawdownProfile: []), liquidityStress: PortfolioStressTest.LiquidityStress(bidAskSpreadWidening: 0, marketDepthReduction: 0, timeToLiquidate: 0, liquidationCost: 0, marketImpact: 0, fundingStress: 0), executedAt: Date()), bestCase: PortfolioStressTest(portfolioId: UUID(), scenarioId: UUID(), scenarioName: "", startValue: 0, endValue: 0, maxLoss: 0, maxLossPercent: 0, assetImpacts: [], riskMetrics: PortfolioStressTest.RiskMetrics(var95: 0, var99: 0, expectedShortfall95: 0, betaStressed: 0, correlationBreakdown: false, diversificationRatio: 0, concentrationRisk: 0, tailRiskMeasure: 0, systemicRiskScore: 0, liquidityRiskScore: 0, stressDuration: 0, drawdownProfile: []), liquidityStress: PortfolioStressTest.LiquidityStress(bidAskSpreadWidening: 0, marketDepthReduction: 0, timeToLiquidate: 0, liquidationCost: 0, marketImpact: 0, fundingStress: 0), executedAt: Date()), aggregatedRisk: .init(expectedShortfall: 0, probabilityOfExceedingDrawdown: 0, liquidityAtRisk: 0, systemicRiskScore: 0, diversificationBenefit: 0, correlationBreakdownProbability: 0, tailRiskMeasure: 0, maxStressLoss: 0, recoveryTimeEstimate: 0, sensitivityAnalysis: [:], riskFactorContributions: [:], confidenceInterval95: (0, 0)), success: false, error: "Stress test already running") }
        isRunning = true
        progress = 0
        defer { isRunning = false; progress = 0 }
        let startTime = Date()
        let allScenarios = scenarios.isEmpty ? builtInScenarios : scenarios
        var scenarioResults: [PortfolioStressTest] = []
        let totalScenarios = allScenarios.count
        for (index, scenario) in allScenarios.enumerated() {
            if Task.isCancelled { break }
            currentScenario = scenario.name
            let result = executeScenario(portfolio: portfolio, scenario: scenario, assets: assets)
            scenarioResults.append(result)
            progress = Double(index + 1) / Double(totalScenarios)
        }
        guard !scenarioResults.isEmpty else {
            return StressTestResult(portfolioId: UUID(), scenarios: [], worstCase: PortfolioStressTest(portfolioId: UUID(), scenarioId: UUID(), scenarioName: "", startValue: 0, endValue: 0, maxLoss: 0, maxLossPercent: 0, assetImpacts: [], riskMetrics: PortfolioStressTest.RiskMetrics(var95: 0, var99: 0, expectedShortfall95: 0, betaStressed: 0, correlationBreakdown: false, diversificationRatio: 0, concentrationRisk: 0, tailRiskMeasure: 0, systemicRiskScore: 0, liquidityRiskScore: 0, stressDuration: 0, drawdownProfile: []), liquidityStress: PortfolioStressTest.LiquidityStress(bidAskSpreadWidening: 0, marketDepthReduction: 0, timeToLiquidate: 0, liquidationCost: 0, marketImpact: 0, fundingStress: 0), executedAt: Date()), bestCase: PortfolioStressTest(portfolioId: UUID(), scenarioId: UUID(), scenarioName: "", startValue: 0, endValue: 0, maxLoss: 0, maxLossPercent: 0, assetImpacts: [], riskMetrics: PortfolioStressTest.RiskMetrics(var95: 0, var99: 0, expectedShortfall95: 0, betaStressed: 0, correlationBreakdown: false, diversificationRatio: 0, concentrationRisk: 0, tailRiskMeasure: 0, systemicRiskScore: 0, liquidityRiskScore: 0, stressDuration: 0, drawdownProfile: []), liquidityStress: PortfolioStressTest.LiquidityStress(bidAskSpreadWidening: 0, marketDepthReduction: 0, timeToLiquidate: 0, liquidationCost: 0, marketImpact: 0, fundingStress: 0), executedAt: Date()), aggregatedRisk: .init(expectedShortfall: 0, probabilityOfExceedingDrawdown: 0, liquidityAtRisk: 0, systemicRiskScore: 0, diversificationBenefit: 0, correlationBreakdownProbability: 0, tailRiskMeasure: 0, maxStressLoss: 0, recoveryTimeEstimate: 0, sensitivityAnalysis: [:], riskFactorContributions: [:], confidenceInterval95: (0, 0)), success: false, error: "No scenarios executed")
        }
        let worstCase = scenarioResults.min { $0.maxLossPercent < $1.maxLossPercent } ?? scenarioResults[0]
        let bestCase = scenarioResults.max { $0.maxLossPercent < $1.maxLossPercent } ?? scenarioResults[0]
        let aggregatedRisk = calculateAggregatedRisk(results: scenarioResults)
        let scenarioComparison = scenarioResults.map { result in
            let recommendation: String
            switch result.maxLossPercent {
            case 0..<0.1: recommendation = "Low risk scenario"
            case 0.1..<0.2: recommendation = "Moderate risk - review hedges"
            case 0.2..<0.4: recommendation = "High risk - reduce exposure"
            default: recommendation = "Extreme risk - emergency hedging required"
            }
            return StressTestResult.ScenarioComparison(scenarioName: result.scenarioName, lossPercent: result.maxLossPercent, var95: result.riskMetrics.var95, recoveryTime: result.recoveryTime ?? 0, liquidityImpact: result.liquidityStress.bidAskSpreadWidening, severity: result.maxLossPercent > 0.3 ? .extreme : result.maxLossPercent > 0.15 ? .severe : result.maxLossPercent > 0.05 ? .moderate : .mild, recommendation: recommendation)
        }
        let result = StressTestResult(portfolioId: UUID(), scenarios: scenarioResults, worstCase: worstCase, bestCase: bestCase, aggregatedRisk: aggregatedRisk, scenarioComparison: scenarioComparison, executedAt: Date(), success: true)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        return result
    }

    func cancelStressTest() { cancellationToken?.cancel() }

    func runHistoricalReplay(portfolio: Portfolio, scenario: HistoricalScenario, assets: [Asset]) async -> PortfolioStressTest? {
        guard !scenario.affectedAssets.isEmpty else { return nil }
        let startValue = portfolio.totalBalance
        var endValue = startValue
        var maxLoss = 0.0
        var assetImpacts: [PortfolioStressTest.AssetImpact] = []
        let assetValueMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.symbol, $0.currentPrice) })
        let days = Int(scenario.duration / 86400)
        for (assetClass, impacts) in scenario.affectedAssets {
            let initialAssetValue = assetValueMap.values.reduce(0, +) / Double(max(1, assetValueMap.count))
            var currentAssetValue = initialAssetValue
            for day in 0..<min(days, impacts.count) {
                let dailyShock = impacts[day]
                currentAssetValue *= (1 + dailyShock * 0.5)
            }
            let loss = initialAssetValue - currentAssetValue
            let lossPercent = initialAssetValue > 0 ? loss / initialAssetValue : 0
            endValue *= (1 + lossPercent * 0.1)
            maxLoss = max(maxLoss, startValue - endValue)
            assetImpacts.append(PortfolioStressTest.AssetImpact(assetSymbol: assetClass, assetClass: .equity, initialValue: initialAssetValue, stressedValue: currentAssetValue, loss: loss, lossPercent: lossPercent, liquidityScore: 0.4, recoveryProbability: max(0, 1 - abs(lossPercent)), volatilityShock: abs(dailyShock), correlationImpact: 0.3, timeToRecover: scenario.duration * (1 + abs(lossPercent)), hedgingEffectiveness: 0.2))
        }
        let maxLossPercent = startValue > 0 ? maxLoss / startValue : 0
        let var95 = maxLossPercent * 0.8
        let es95 = maxLossPercent * 0.9
        let drawdownProfile: [PortfolioStressTest.DrawdownPoint] = (0..<min(30, days)).map { day in
            let timestamp = Calendar.current.date(byAdding: .day, value: day, to: Date()) ?? Date()
            let dd = maxLossPercent * (1 - exp(-Double(day) / 10.0))
            return PortfolioStressTest.DrawdownPoint(timestamp: timestamp, drawdown: dd, peakEquity: startValue, recoveryProgress: day > 15 ? Double(day - 15) / 15.0 : 0)
        }
        let liquidityStress = PortfolioStressTest.LiquidityStress(bidAskSpreadWidening: abs(scenario.affectedAssets.values.first?.first ?? 0) * 0.5, marketDepthReduction: 0.4, timeToLiquidate: max(1, days), liquidationCost: abs(scenario.affectedAssets.values.first?.first ?? 0) * 0.02, marketImpact: 0.3, fundingStress: 0.2)
        let riskMetrics = PortfolioStressTest.RiskMetrics(var95: var95, var99: var95 * 1.2, expectedShortfall95: es95, betaStressed: 1.8, correlationBreakdown: scenario.affectedAssets.count > 3, diversificationRatio: 0.5, concentrationRisk: 0.5, tailRiskMeasure: maxLossPercent * 1.5, systemicRiskScore: 0.7, liquidityRiskScore: 0.6, stressDuration: scenario.duration, drawdownProfile: drawdownProfile)
        return PortfolioStressTest(portfolioId: UUID(), scenarioId: scenario.id, scenarioName: scenario.name, startValue: startValue, endValue: endValue, maxLoss: maxLoss, maxLossPercent: maxLossPercent, recoveryTime: scenario.duration * 1.5, assetImpacts: assetImpacts, riskMetrics: riskMetrics, liquidityStress: liquidityStress)
    }

    private func executeScenario(portfolio: Portfolio, scenario: StressScenario, assets: [Asset]) -> PortfolioStressTest {
        let startValue = portfolio.totalBalance
        var endValue = startValue
        var maxLoss = 0.0
        var assetImpacts: [PortfolioStressTest.AssetImpact] = []
        let assetValueMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.symbol, $0.currentPrice) })
        var cumulativeLoss = 0.0
        var drawdownProfile: [PortfolioStressTest.DrawdownPoint] = []
        for shock in scenario.shocks {
            let initialAssetValue = assetValueMap[shock.asset] ?? 100
            var currentAssetValue = initialAssetValue
            for day in 0..<Int(shock.duration / 86400) {
                let time = Double(day) * 86400
                currentAssetValue = shock.apply(at: time, to: currentAssetValue)
                if day % 7 == 0 {
                    drawdownProfile.append(PortfolioStressTest.DrawdownPoint(timestamp: Calendar.current.date(byAdding: .day, value: day, to: Date()) ?? Date(), drawdown: abs(currentAssetValue - initialAssetValue) / max(initialAssetValue, 0.0001), peakEquity: startValue, recoveryProgress: 0))
                }
            }
            let loss = initialAssetValue - currentAssetValue
            let lossPercent = initialAssetValue > 0 ? loss / initialAssetValue : 0
            cumulativeLoss += lossPercent * 0.1
            endValue *= (1 + lossPercent * 0.1)
            maxLoss = max(maxLoss, startValue - endValue)
            assetImpacts.append(PortfolioStressTest.AssetImpact(assetSymbol: shock.asset, assetClass: .equity, initialValue: initialAssetValue, stressedValue: currentAssetValue, loss: loss, lossPercent: lossPercent, liquidityScore: max(0, 1 - shock.liquidityImpact), recoveryProbability: max(0, 1 - abs(lossPercent)), volatilityShock: shock.volatilityMultiplier * 0.1, correlationImpact: shock.contagionFactor * 0.3, timeToRecover: shock.duration * (1 + abs(lossPercent)), hedgingEffectiveness: 0.3))
        }
        for correlation in scenario.correlations {
            let correlationImpact = abs(correlation.newCorrelation - 0.3)
            cumulativeLoss += correlationImpact * 0.05
            endValue *= (1 - correlationImpact * 0.02)
            maxLoss = max(maxLoss, startValue - endValue)
        }
        let maxLossPercent = startValue > 0 ? maxLoss / startValue : 0
        let var95 = maxLossPercent * 0.8
        let es95 = maxLossPercent * 0.9
        let liquidityStress = PortfolioStressTest.LiquidityStress(bidAskSpreadWidening: abs(scenario.shocks.first?.magnitude ?? 0) * 0.5, marketDepthReduction: abs(scenario.shocks.first?.liquidityImpact ?? 0.5), timeToLiquidate: max(1, abs(scenario.shocks.first?.duration ?? 0)), liquidationCost: abs(scenario.shocks.first?.magnitude ?? 0) * 0.02, marketImpact: abs(scenario.shocks.first?.magnitude ?? 0) * 0.05, fundingStress: abs(scenario.shocks.first?.volatilityMultiplier ?? 2) * 0.1)
        let riskMetrics = PortfolioStressTest.RiskMetrics(var95: var95, var99: var95 * 1.2, expectedShortfall95: es95, betaStressed: 1.5, correlationBreakdown: scenario.correlations.count > 2, diversificationRatio: 0.7, concentrationRisk: 0.3, tailRiskMeasure: maxLossPercent * 1.5, systemicRiskScore: scenario.shocks.reduce(0) { $0 + $1.contagionFactor } / Double(max(1, scenario.shocks.count)), liquidityRiskScore: scenario.shocks.reduce(0) { $0 + $1.liquidityImpact } / Double(max(1, scenario.shocks.count)), stressDuration: scenario.shocks.map { $0.duration }.max() ?? 0, drawdownProfile: drawdownProfile)
        return PortfolioStressTest(portfolioId: UUID(), scenarioId: scenario.id, scenarioName: scenario.name, startValue: startValue, endValue: endValue, maxLoss: maxLoss, maxLossPercent: maxLossPercent, recoveryTime: scenario.shocks.map { $0.duration }.max(), assetImpacts: assetImpacts, riskMetrics: riskMetrics, liquidityStress: liquidityStress)
    }

    private func calculateAggregatedRisk(results: [PortfolioStressTest]) -> StressTestResult.AggregatedRisk {
        let maxLosses = results.map { $0.maxLossPercent }
        let expectedShortfall = maxLosses.reduce(0, +) / Double(max(1, maxLosses.count))
        let probabilityOfExceeding = Double(maxLosses.filter { $0 > 0.1 }.count) / Double(max(1, maxLosses.count))
        let liquidityRisks = results.map { $0.liquidityStress.liquidationCost }
        let liquidityAtRisk = liquidityRisks.reduce(0, +) / Double(max(1, liquidityRisks.count))
        let systemicScores = results.map { $0.riskMetrics.systemicRiskScore }
        let systemicRiskScore = systemicScores.reduce(0, +) / Double(max(1, systemicScores.count))
        let diversificationRatios = results.map { $0.riskMetrics.diversificationRatio }
        let diversificationBenefit = diversificationRatios.reduce(0, +) / Double(max(1, diversificationRatios.count))
        let correlationBreakdownProb = Double(results.filter { $0.riskMetrics.correlationBreakdown }.count) / Double(max(1, results.count))
        let tailRisk = maxLosses.sorted()
        let tailRiskMeasure = tailRisk.indices.contains(Int(Double(tailRisk.count) * 0.01)) ? tailRisk[Int(Double(tailRisk.count) * 0.01)] : 0
        let maxStressLoss = maxLosses.max() ?? 0
        let avgRecovery = results.compactMap { $0.recoveryTime }.reduce(0, +) / Double(max(1, results.compactMap { $0.recoveryTime }.count))
        let sensitivity = Dictionary(uniqueKeysWithValues: results.map { ($0.scenarioName, $0.maxLossPercent) })
        let riskFactorContributions: [String: Double] = ["market": 0.4, "credit": 0.2, "liquidity": 0.2, "operational": 0.1, "geopolitical": 0.1]
        let confidenceLower = expectedShortfall * 0.8
        let confidenceUpper = expectedShortfall * 1.2
        return StressTestResult.AggregatedRisk(expectedShortfall: expectedShortfall, probabilityOfExceedingDrawdown: probabilityOfExceeding, liquidityAtRisk: liquidityAtRisk, systemicRiskScore: systemicRiskScore, diversificationBenefit: diversificationBenefit, correlationBreakdownProbability: correlationBreakdownProb, tailRiskMeasure: tailRiskMeasure, maxStressLoss: maxStressLoss, recoveryTimeEstimate: avgRecovery, sensitivityAnalysis: sensitivity, riskFactorContributions: riskFactorContributions, confidenceInterval95: (confidenceLower, confidenceUpper))
    }
}
