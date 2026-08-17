import Foundation
import Combine

struct ForexTradePlan: Identifiable, Codable, Equatable {
    let id: UUID
    let pair: String
    let direction: SignalType
    let entry: Double
    let stopLoss: Double
    let takeProfit: Double
    let positionUnits: Double
    let riskAmount: Double
    let rewardRisk: Double
    let confidence: Double
    let reasons: [String]
    let createdAt: Date
}

struct ForexAnalysisReport: Codable, Equatable {
    let pair: String
    let lastPrice: Double
    let bias: SignalType
    let confidence: Double
    let trendScore: Double
    let momentumScore: Double
    let volatilityScore: Double
    let liquidityScore: Double
    let support: Double
    let resistance: Double
    let atr: Double
    let recommendation: String
    let generatedAt: Date
}

struct ForexRiskCheck: Codable, Equatable {
    let isValid: Bool
    let riskAmount: Double
    let riskPercent: Double
    let rewardRisk: Double
    let messages: [String]
}

enum ForexPipelineStage: String, CaseIterable, Codable {
    case acquire = "Acquire feed"
    case validate = "Validate candles"
    case indicators = "Calculate indicators"
    case analyze = "Score market"
    case risk = "Run risk gate"
    case publish = "Publish plan"
}

struct ForexBacktestResult: Codable, Equatable {
    let pair: String
    let trades: Int
    let wins: Int
    let losses: Int
    let netReturnPercent: Double
    let maxDrawdownPercent: Double
    let profitFactor: Double
    let winRate: Double
}

@MainActor
final class ForexTradingBackend: ObservableObject {
    static let shared = ForexTradingBackend()

    @Published private(set) var reports: [String: ForexAnalysisReport] = [:]
    @Published private(set) var plans: [ForexTradePlan] = []
    @Published private(set) var riskChecks: [UUID: ForexRiskCheck] = [:]
    @Published private(set) var pipelineProgress: [ForexPipelineStage: Double] = [:]
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    func analyze(pair: String, history: [PriceData], basic: TechnicalIndicators, advanced: AdvancedTechnicalIndicators) -> ForexAnalysisReport? {
        guard let last = history.last, history.count >= 20 else {
            lastError = "At least 20 validated candles are required for analysis"
            return nil
        }
        let trendScore = min(1, max(-1, advanced.trendStrength + (basic.macd.histogram >= 0 ? 0.15 : -0.15)))
        let momentumScore = min(1, max(-1, (basic.rsi - 50) / 50 + (advanced.mfi - 50) / 200))
        let volatilityScore = min(1, max(0, advanced.trueRangePercent / 2))
        let liquidityScore = min(1, max(0, Double(history.suffix(20).map(\.volume).reduce(0, +)) / 20_000_000))
        let composite = trendScore * 0.4 + momentumScore * 0.3 + (0.5 - volatilityScore * 0.25) + liquidityScore * 0.1
        let bias: SignalType = composite > 0.15 ? .buy : composite < -0.15 ? .sell : .neutral
        let confidence = min(0.99, max(0.05, 0.5 + abs(composite) * 0.5))
        let recommendation: String
        switch bias {
        case .buy: recommendation = "Bullish bias; require a risk-gated long plan above validated structure."
        case .sell: recommendation = "Bearish bias; require a risk-gated short plan below validated structure."
        case .neutral: recommendation = "Neutral regime; wait for confirmation or a volatility expansion."
        }
        let report = ForexAnalysisReport(pair: pair, lastPrice: last.close, bias: bias, confidence: confidence, trendScore: trendScore, momentumScore: momentumScore, volatilityScore: volatilityScore, liquidityScore: liquidityScore, support: advanced.donchianLower, resistance: advanced.donchianUpper, atr: basic.atr, recommendation: recommendation, generatedAt: Date())
        reports[pair] = report
        return report
    }

    func buildPlan(pair: String, report: ForexAnalysisReport, accountBalance: Double, riskPercent: Double = 0.01) -> ForexTradePlan? {
        guard report.bias != .neutral, report.atr > 0, accountBalance > 0 else { return nil }
        let riskRate = min(0.02, max(0.001, riskPercent))
        let riskAmount = accountBalance * riskRate
        let stopDistance = report.atr * 1.5
        let entry = report.lastPrice
        let stop = report.bias == .buy ? entry - stopDistance : entry + stopDistance
        let target = report.bias == .buy ? entry + stopDistance * 2 : entry - stopDistance * 2
        let units = riskAmount / stopDistance
        let plan = ForexTradePlan(id: UUID(), pair: pair, direction: report.bias, entry: entry, stopLoss: stop, takeProfit: target, positionUnits: units, riskAmount: riskAmount, rewardRisk: 2, confidence: report.confidence, reasons: ["Trend score \(String(format: "%.2f", report.trendScore))", "Momentum score \(String(format: "%.2f", report.momentumScore))", report.recommendation], createdAt: Date())
        plans.insert(plan, at: 0)
        return plan
    }

    func validate(plan: ForexTradePlan, accountBalance: Double, maxRiskPercent: Double = 0.02) -> ForexRiskCheck {
        let riskPercent = accountBalance > 0 ? plan.riskAmount / accountBalance : 1
        let messages: [String] = [
            plan.positionUnits > 0 ? "Position size is positive" : "Position size must be positive",
            riskPercent <= maxRiskPercent ? "Risk is inside the configured limit" : "Risk exceeds the configured limit",
            plan.rewardRisk >= 1.5 ? "Reward-to-risk threshold passed" : "Reward-to-risk is below threshold",
            plan.stopLoss != plan.entry ? "Stop-loss is defined" : "Stop-loss cannot equal entry"
        ]
        let valid = plan.positionUnits > 0 && riskPercent <= maxRiskPercent && plan.rewardRisk >= 1.5 && plan.stopLoss != plan.entry
        let check = ForexRiskCheck(isValid: valid, riskAmount: plan.riskAmount, riskPercent: riskPercent, rewardRisk: plan.rewardRisk, messages: messages)
        riskChecks[plan.id] = check
        return check
    }

    func runPipeline(pair: String, history: [PriceData], basic: TechnicalIndicators, advanced: AdvancedTechnicalIndicators, accountBalance: Double) async -> ForexTradePlan? {
        guard !isRunning else { return nil }
        isRunning = true
        lastError = nil
        defer { isRunning = false }
        for stage in ForexPipelineStage.allCases {
            pipelineProgress[stage] = 0
            try? await Task.sleep(for: .milliseconds(120))
            pipelineProgress[stage] = 1
        }
        guard let report = analyze(pair: pair, history: history, basic: basic, advanced: advanced), let plan = buildPlan(pair: pair, report: report, accountBalance: accountBalance) else { return nil }
        _ = validate(plan: plan, accountBalance: accountBalance)
        return plan
    }

    func backtest(pair: String, history: [PriceData], basicPeriod: Int = 20) -> ForexBacktestResult? {
        guard history.count > basicPeriod + 2 else { return nil }
        var equity = 0.0
        var peak = 0.0
        var maxDrawdown = 0.0
        var wins = 0
        var losses = 0
        for index in basicPeriod..<(history.count - 1) {
            let window = Array(history[(index - basicPeriod)...index])
            let fast = window.suffix(5).map(\.close).reduce(0, +) / 5
            let slow = window.map(\.close).reduce(0, +) / Double(window.count)
            let change = history[index + 1].close - history[index].close
            let result = fast > slow ? change : fast < slow ? -change : 0
            equity += result
            if result > 0 { wins += 1 } else if result < 0 { losses += 1 }
            peak = max(peak, equity)
            maxDrawdown = max(maxDrawdown, peak - equity)
        }
        let trades = wins + losses
        let grossWins = history.indices.dropFirst().map { history[$0].close - history[$0 - 1].close }.filter { $0 > 0 }.reduce(0, +)
        let grossLosses = abs(history.indices.dropFirst().map { history[$0].close - history[$0 - 1].close }.filter { $0 < 0 }.reduce(0, +))
        return ForexBacktestResult(pair: pair, trades: trades, wins: wins, losses: losses, netReturnPercent: equity * 100, maxDrawdownPercent: maxDrawdown * 100, profitFactor: grossLosses > 0 ? grossWins / grossLosses : 0, winRate: trades > 0 ? Double(wins) / Double(trades) : 0)
    }
}
