import Foundation
import Combine
import Accelerate

// MARK: - Asset Model
struct Asset: Codable, Identifiable, Hashable {
    let id: UUID
    var symbol: String
    var name: String
    var assetClass: AssetClass
    var currency: String
    var sector: String
    var region: String
    var currentPrice: Double
    var previousClose: Double
    var volatility: Double
    var expectedReturn: Double
    var beta: Double
    var liquidityScore: Double
    var marketCap: Double
    var dividendYield: Double
    var tags: [String]
    var metadata: [String: String]

    enum AssetClass: String, Codable, CaseIterable {
        case equity = "EQUITY"
        case forex = "FOREX"
        case commodity = "COMMODITY"
        case fixedIncome = "FIXED_INCOME"
        case crypto = "CRYPTO"
        case alternative = "ALTERNATIVE"
        case cash = "CASH"
    }

    init(id: UUID = UUID(), symbol: String, name: String, assetClass: AssetClass = .equity, currency: String = "USD", sector: String = "Unknown", region: String = "Global", currentPrice: Double = 100, previousClose: Double = 100, volatility: Double = 0.2, expectedReturn: Double = 0.08, beta: Double = 1.0, liquidityScore: Double = 0.5, marketCap: Double = 0, dividendYield: Double = 0, tags: [String] = [], metadata: [String: String] = [:]) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.assetClass = assetClass
        self.currency = currency
        self.sector = sector
        self.region = region
        self.currentPrice = max(0.0001, currentPrice)
        self.previousClose = max(0.0001, previousClose)
        self.volatility = max(0, volatility)
        self.expectedReturn = expectedReturn
        self.beta = beta
        self.liquidityScore = max(0, min(1, liquidityScore))
        self.marketCap = marketCap
        self.dividendYield = max(0, dividendYield)
        self.tags = tags
        self.metadata = metadata
    }

    var priceChange: Double { currentPrice - previousClose }
    var priceChangePercent: Double { previousClose > 0 ? (priceChange / previousClose) * 100 : 0 }
    var isUp: Bool { priceChange >= 0 }
}

// MARK: - Position Model
struct PortfolioPosition: Codable, Identifiable {
    let id: UUID
    let assetId: UUID
    let assetSymbol: String
    let quantity: Double
    var averageCost: Double
    var currentPrice: Double
    var marketValue: Double
    var costBasis: Double
    var unrealizedPnL: Double
    var unrealizedPnLPercent: Double
    var weight: Double
    var sector: String
    var assetClass: Asset.AssetClass
    var currency: String
    var openedAt: Date
    var lastUpdated: Date

    init(id: UUID = UUID(), assetId: UUID, assetSymbol: String, quantity: Double, averageCost: Double, currentPrice: Double, sector: String = "Unknown", assetClass: Asset.AssetClass = .equity, currency: String = "USD", openedAt: Date = Date(), lastUpdated: Date = Date()) {
        self.id = id
        self.assetId = assetId
        self.assetSymbol = assetSymbol
        self.quantity = quantity
        self.averageCost = max(0, averageCost)
        self.currentPrice = max(0, currentPrice)
        self.marketValue = quantity * currentPrice
        self.costBasis = quantity * averageCost
        self.unrealizedPnL = marketValue - costBasis
        self.unrealizedPnLPercent = costBasis > 0 ? (unrealizedPnL / costBasis) * 100 : 0
        self.weight = 0
        self.sector = sector
        self.assetClass = assetClass
        self.currency = currency
        self.openedAt = openedAt
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Transaction
struct Transaction: Codable, Identifiable {
    let id: UUID
    let positionId: UUID?
    let assetSymbol: String
    let type: TransactionType
    let quantity: Double
    let price: Double
    let amount: Double
    let commission: Double
    let fees: Double
    let netAmount: Double
    let currency: String
    let timestamp: Date
    let notes: String

    enum TransactionType: String, Codable, CaseIterable {
        case buy = "BUY"
        case sell = "SELL"
        case dividend = "DIVIDEND"
        case fee = "FEE"
        case deposit = "DEPOSIT"
        case withdrawal = "WITHDRAWAL"
        case rebalance = "REBALANCE"
        case corporateAction = "CORPORATE_ACTION"
    }

    init(id: UUID = UUID(), positionId: UUID? = nil, assetSymbol: String, type: TransactionType, quantity: Double, price: Double, commission: Double = 0, fees: Double = 0, currency: String = "USD", timestamp: Date = Date(), notes: String = "") {
        self.id = id
        self.positionId = positionId
        self.assetSymbol = assetSymbol
        self.type = type
        self.quantity = max(0, quantity)
        self.price = max(0, price)
        self.amount = quantity * price
        self.commission = commission
        self.fees = fees
        self.netAmount = type == .buy || type == .fee || type == .withdrawal ? -(amount + commission + fees) : (amount - commission - fees)
        self.currency = currency
        self.timestamp = timestamp
        self.notes = notes
    }
}

// MARK: - Cash Flow
struct CashFlow: Codable, Identifiable {
    let id = UUID()
    let type: CashFlowType
    let amount: Double
    let currency: String
    let timestamp: Date
    let description: String
    let category: String
    let recurring: Bool
    let frequency: TimeFrequency?
    let linkedAssetId: UUID?

    enum CashFlowType: String, Codable { case inflow = "INFLOW", outflow = "OUTFLOW" }
    enum TimeFrequency: String, Codable { case daily, weekly, monthly, quarterly, yearly }

    init(type: CashFlowType, amount: Double, currency: String = "USD", timestamp: Date = Date(), description: String = "", category: String = "General", recurring: Bool = false, frequency: TimeFrequency? = nil, linkedAssetId: UUID? = nil) {
        self.type = type
        self.amount = amount
        self.currency = currency
        self.timestamp = timestamp
        self.description = description
        self.category = category
        self.recurring = recurring
        self.frequency = frequency
        self.linkedAssetId = linkedAssetId
    }
}

// MARK: - Rebalance Configuration
struct RebalanceConfiguration: Codable, Identifiable {
    let id = UUID()
    var targetWeights: [String: Double]
    var tolerance: Double
    var rebalanceFrequency: TimeFrequency
    var minTradeSize: Double
    var taxOptimization: Bool
    var considerTaxLots: Bool
    var rebalanceOnNewCash: Bool
    var constraints: [RebalanceConstraint]

    struct RebalanceConstraint: Codable, Identifiable {
        let id = UUID()
        let assetSymbol: String
        let minWeight: Double?
        let maxWeight: Double?
        let maxTurnover: Double?
        let excluded: Bool
    }

    init(targetWeights: [String: Double] = [:], tolerance: Double = 0.02, rebalanceFrequency: TimeFrequency = .monthly, minTradeSize: Double = 100, taxOptimization: Bool = false, considerTaxLots: Bool = true, rebalanceOnNewCash: Bool = true, constraints: [RebalanceConstraint] = []) {
        self.targetWeights = targetWeights
        self.tolerance = max(0, tolerance)
        self.rebalanceFrequency = rebalanceFrequency
        self.minTradeSize = max(0, minTradeSize)
        self.taxOptimization = taxOptimization
        self.considerTaxLots = considerTaxLots
        self.rebalanceOnNewCash = rebalanceOnNewCash
        self.constraints = constraints
    }
}

// MARK: - Portfolio Snapshot
struct PortfolioSnapshot: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let totalValue: Double
    let cash: Double
    let investedValue: Double
    let unrealizedPnL: Double
    let realizedPnL: Double
    let totalReturn: Double
    let dayReturn: Double
    let positions: [PortfolioPosition]
    let assetAllocation: [String: Double]
    let sectorAllocation: [String: Double]
    let currencyExposure: [String: Double]
    let riskMetrics: PortfolioRiskMetrics

    struct PortfolioRiskMetrics: Codable {
        let volatility: Double
        let beta: Double
        let var95: Double
        let expectedShortfall95: Double
        let maxDrawdown: Double
        let sharpeRatio: Double
        let trackingError: Double
        let informationRatio: Double
        let concentration: Double
        let liquidityScore: Double

        static let empty = PortfolioRiskMetrics(volatility: 0, beta: 0, var95: 0, expectedShortfall95: 0, maxDrawdown: 0, sharpeRatio: 0, trackingError: 0, informationRatio: 0, concentration: 0, liquidityScore: 0)
    }
}

// MARK: - Simulation Configuration
struct SimulationConfiguration: Codable, Identifiable {
    let id = UUID()
    var name: String
    var initialCapital: Double
    var currency: String
    var startDate: Date
    var endDate: Date
    var rebalanceConfig: RebalanceConfiguration
    var cashFlowSchedule: [CashFlow]
    var riskFreeRate: Double
    var benchmarkSymbol: String?
    var simulationType: SimulationType
    var pathCount: Int
    var randomSeed: UInt64
    var tags: [String]

    enum SimulationType: String, Codable { case deterministic, monteCarlo, historical, parametric }
}

// MARK: - Simulation Result
struct SimulationResult: Codable, Identifiable {
    let id = UUID()
    let configurationId: UUID
    let snapshots: [PortfolioSnapshot]
    let transactions: [Transaction]
    let cashFlows: [CashFlow]
    let summary: PortfolioSummary
    let pathStatistics: PathStatistics
    let executionTimeMs: Double
    let completedAt: Date

    struct PortfolioSummary: Codable {
        let finalValue: Double
        let totalReturn: Double
        let annualizedReturn: Double
        let maxDrawdown: Double
        let sharpeRatio: Double
        let sortinoRatio: Double
        let totalTrades: Int
        let turnover: Double
        let taxOwed: Double
        let netReturn: Double
        let benchmarkReturn: Double
        let alpha: Double
        let beta: Double
    }

    struct PathStatistics: Codable {
        let meanFinalValue: Double
        let medianFinalValue: Double
        let stdDevFinalValue: Double
        let percentile5: Double
        let percentile95: Double
        let probabilityOfLoss: Double
        let expectedReturn: Double
        let valueAtRisk95: Double
        let conditionalValueAtRisk95: Double
    }
}

// MARK: - Portfolio Simulator
@MainActor
final class PortfolioSimulator: ObservableObject {
    static let shared = PortfolioSimulator()
    @Published private(set) var results: [SimulationResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var progress: Double = 0
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func runSimulation(configuration: SimulationConfiguration, assets: [Asset]) async -> SimulationResult {
        guard !isRunning else { return SimulationResult(configurationId: configuration.id, snapshots: [], transactions: [], cashFlows: [], summary: .init(finalValue: 0, totalReturn: 0, annualizedReturn: 0, maxDrawdown: 0, sharpeRatio: 0, sortinoRatio: 0, totalTrades: 0, turnover: 0, taxOwed: 0, netReturn: 0, benchmarkReturn: 0, alpha: 0, beta: 0), pathStatistics: .init(meanFinalValue: 0, medianFinalValue: 0, stdDevFinalValue: 0, percentile5: 0, percentile95: 0, probabilityOfLoss: 0, expectedReturn: 0, valueAtRisk95: 0, conditionalValueAtRisk95: 0), executionTimeMs: 0, completedAt: Date()) }
        isRunning = true
        progress = 0
        defer { isRunning = false; progress = 0 }
        let startTime = Date()
        var snapshots: [PortfolioSnapshot] = []
        var transactions: [Transaction] = []
        var cashFlows: [CashFlow] = []
        var currentDate = configuration.startDate
        var capital = configuration.initialCapital
        var cash = capital * 0.1
        var portfolioValue = capital
        var peakValue = capital
        var maxDD = 0.0
        let calendar = Calendar.current
        var assetMap: [String: Asset] = Dictionary(uniqueKeysWithValues: assets.map { ($0.symbol, $0) })
        var holdings: [String: PortfolioPosition] = [:]
        let targetWeights = configuration.rebalanceConfig.targetWeights
        let stepsPerYear = 252.0
        var dailyReturns: [Double] = []
        var rebalanceCounter = 0
        while currentDate <= configuration.endDate {
            progress = (currentDate.timeIntervalSince(configuration.startDate) / max(configuration.endDate.timeIntervalSince(configuration.startDate), 1))
            if Task.isCancelled { break }
            for asset in assets {
                let drift = asset.expectedReturn / stepsPerYear
                let diffusion = asset.volatility / sqrt(stepsPerYear)
                let z = randomNormal(seed: UInt64(currentDate.timeIntervalSince1970))
                let return_ = exp(drift - 0.5 * diffusion * diffusion + diffusion * z)
                assetMap[asset.symbol]?.currentPrice *= return_
            }
            for (symbol, targetWeight) in targetWeights {
                let targetValue = portfolioValue * targetWeight
                if let asset = assetMap[symbol] {
                    if let position = holdings[symbol] {
                        position.currentPrice = asset.currentPrice
                        position.marketValue = position.quantity * asset.currentPrice
                        position.unrealizedPnL = position.marketValue - position.costBasis
                        position.unrealizedPnLPercent = position.costBasis > 0 ? (position.unrealizedPnL / position.costBasis) * 100 : 0
                        position.lastUpdated = currentDate
                    } else if targetWeight > 0.001 && cash >= targetValue * 0.01 {
                        let quantity = (targetValue * 0.5) / max(asset.currentPrice, 0.0001)
                        let newPosition = PortfolioPosition(assetId: asset.id, assetSymbol: symbol, quantity: quantity, averageCost: asset.currentPrice, currentPrice: asset.currentPrice, sector: asset.sector, assetClass: asset.assetClass, currency: asset.currency, openedAt: currentDate)
                        holdings[symbol] = newPosition
                        cash -= newPosition.marketValue
                        let transaction = Transaction(assetSymbol: symbol, type: .buy, quantity: quantity, price: asset.currentPrice, timestamp: currentDate)
                        transactions.append(transaction)
                    }
                }
            }
            rebalanceCounter += 1
            if rebalanceCounter >= 21 {
                rebalanceCounter = 0
                let rebalanceResult = performRebalance(portfolioValue: portfolioValue, holdings: &holdings, targetWeights: targetWeights, assetMap: assetMap, tolerance: configuration.rebalanceConfig.tolerance, minTradeSize: configuration.rebalanceConfig.minTradeSize)
                for transaction in rebalanceResult.transactions {
                    transactions.append(transaction)
                    if transaction.type == .buy { cash -= transaction.netAmount } else { cash += abs(transaction.netAmount) }
                }
            }
            let investedValue = holdings.values.reduce(0) { $0 + $1.marketValue }
            portfolioValue = cash + investedValue
            if portfolioValue > peakValue { peakValue = portfolioValue }
            let currentDD = (peakValue - portfolioValue) / max(peakValue, 0.0001)
            if currentDD > maxDD { maxDD = currentDD }
            let dayReturn = dailyReturns.last ?? 0
            let assetAllocation = calculateAssetAllocation(holdings: holdings, totalValue: portfolioValue)
            let sectorAllocation = calculateSectorAllocation(holdings: holdings, totalValue: portfolioValue)
            let currencyExposure = calculateCurrencyExposure(holdings: holdings)
            let riskMetrics = calculateRiskMetrics(holdings: holdings, returns: dailyReturns, riskFreeRate: configuration.riskFreeRate, maxDrawdown: maxDD)
            let snapshot = PortfolioSnapshot(timestamp: currentDate, totalValue: portfolioValue, cash: cash, investedValue: investedValue, unrealizedPnL: holdings.values.reduce(0) { $0 + $1.unrealizedPnL }, realizedPnL: 0, totalReturn: (portfolioValue - configuration.initialCapital) / max(configuration.initialCapital, 0.0001), dayReturn: dayReturn, positions: Array(holdings.values), assetAllocation: assetAllocation, sectorAllocation: sectorAllocation, currencyExposure: currencyExposure, riskMetrics: riskMetrics)
            snapshots.append(snapshot)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let summary = calculateSummary(snapshots: snapshots, transactions: transactions, initialCapital: configuration.initialCapital, riskFreeRate: configuration.riskFreeRate)
        let pathStats = calculatePathStatistics(snapshots: snapshots, initialCapital: configuration.initialCapital)
        let result = SimulationResult(configurationId: configuration.id, snapshots: snapshots, transactions: transactions, cashFlows: cashFlows, summary: summary, pathStatistics: pathStats, executionTimeMs: executionTime, completedAt: Date())
        if results.count >= maxResults { results.removeFirst() }
        results.append(result)
        return result
    }

    func cancelSimulation() { cancellationToken?.cancel() }

    private func performRebalance(portfolioValue: Double, holdings: inout [String: PortfolioPosition], targetWeights: [String: Double], assetMap: [String: Asset], tolerance: Double, minTradeSize: Double) -> (transactions: [Transaction], traded: Bool) {
        var transactions: [Transaction] = []
        var traded = false
        for (symbol, targetWeight) in targetWeights {
            let targetValue = portfolioValue * targetWeight
            let currentValue = holdings[symbol]?.marketValue ?? 0
            let deviation = abs(currentValue - targetValue) / max(portfolioValue, 0.0001)
            if deviation > tolerance {
                let diff = targetValue - currentValue
                if abs(diff) > minTradeSize {
                    let asset = assetMap[symbol]
                    if diff > 0, let asset = asset {
                        let quantity = diff / max(asset.currentPrice, 0.0001)
                        let newPosition = PortfolioPosition(assetId: asset.id, assetSymbol: symbol, quantity: quantity, averageCost: asset.currentPrice, currentPrice: asset.currentPrice, sector: asset.sector, assetClass: asset.assetClass, currency: asset.currency)
                        holdings[symbol] = newPosition
                        transactions.append(Transaction(assetSymbol: symbol, type: .buy, quantity: quantity, price: asset.currentPrice, type: .rebalance))
                    } else if diff < 0, let position = holdings[symbol] {
                        let sellQuantity = min(abs(diff) / max(position.currentPrice, 0.0001), position.quantity)
                        transactions.append(Transaction(assetSymbol: symbol, type: .sell, quantity: sellQuantity, price: position.currentPrice, type: .rebalance))
                        holdings[symbol]?.quantity -= sellQuantity
                    }
                    traded = true
                }
            }
        }
        return (transactions, traded)
    }

    private func calculateAssetAllocation(holdings: [String: PortfolioPosition], totalValue: Double) -> [String: Double] {
        let total = totalValue > 0 ? totalValue : holdings.values.reduce(0) { $0 + $1.marketValue }
        var allocation: [String: Double] = [:]
        for position in holdings.values { allocation[position.assetSymbol] = position.marketValue / max(total, 0.0001) }
        return allocation
    }

    private func calculateSectorAllocation(holdings: [String: PortfolioPosition], totalValue: Double) -> [String: Double] {
        let total = totalValue > 0 ? totalValue : holdings.values.reduce(0) { $0 + $1.marketValue }
        var allocation: [String: Double] = [:]
        for position in holdings.values { allocation[position.sector, default: 0] += position.marketValue / max(total, 0.0001) }
        return allocation
    }

    private func calculateCurrencyExposure(holdings: [String: PortfolioPosition]) -> [String: Double] {
        var exposure: [String: Double] = [:]
        for position in holdings.values { exposure[position.currency, default: 0] += position.marketValue }
        return exposure
    }

    private func calculateRiskMetrics(holdings: [String: PortfolioPosition], returns: [Double], riskFreeRate: Double, maxDrawdown: Double) -> PortfolioSnapshot.PortfolioRiskMetrics {
        let meanReturn = returns.reduce(0, +) / Double(max(1, returns.count))
        let variance = returns.count > 1 ? returns.map { pow($0 - meanReturn, 2) }.reduce(0, +) / Double(returns.count - 1) : 0
        let volatility = sqrt(max(0, variance))
        let sharpe = volatility > 0 ? (meanReturn - riskFreeRate / 252.0) / volatility : 0
        let downside = returns.filter { $0 < 0 }.map { $0 * $0 }.reduce(0, +)
        let downsideDev = sqrt(downside / Double(max(1, returns.count)))
        let sortino = downsideDev > 0 ? (meanReturn - riskFreeRate / 252.0) / downsideDev : 0
        let sortedReturns = returns.sorted()
        let varIndex = Int(Double(sortedReturns.count) * 0.05)
        let var95 = sortedReturns.indices.contains(varIndex) ? sortedReturns[varIndex] : 0
        let cvarSamples = sortedReturns.prefix(max(1, varIndex))
        let cvar95 = cvarSamples.isEmpty ? 0 : cvarSamples.reduce(0, +) / Double(cvarSamples.count)
        let weights = holdings.values.map { $0.weight }
        let concentration = weights.map { $0 * $0 }.reduce(0, +)
        let liquidity = holdings.values.map { $0.assetClass == .cash ? 1.0 : $0.liquidityScore }.reduce(0, +) / Double(max(1, holdings.count))
        return PortfolioSnapshot.PortfolioRiskMetrics(volatility: volatility, beta: 0, var95: var95, expectedShortfall95: cvar95, maxDrawdown: maxDrawdown, sharpeRatio: sharpe, trackingError: 0, informationRatio: 0, concentration: concentration, liquidityScore: liquidity)
    }

    private func calculateSummary(snapshots: [PortfolioSnapshot], transactions: [Transaction], initialCapital: Double, riskFreeRate: Double) -> SimulationResult.PortfolioSummary {
        guard let finalSnapshot = snapshots.last else { return .init(finalValue: 0, totalReturn: 0, annualizedReturn: 0, maxDrawdown: 0, sharpeRatio: 0, sortinoRatio: 0, totalTrades: 0, turnover: 0, taxOwed: 0, netReturn: 0, benchmarkReturn: 0, alpha: 0, beta: 0) }
        let finalValue = finalSnapshot.totalValue
        let totalReturn = (finalValue - initialCapital) / max(initialCapital, 0.0001)
        let years = Double(max(1, snapshots.count)) / 252.0
        let annualizedReturn = pow(max(0.0001, finalValue / initialCapital), 1.0 / max(years, 0.0001)) - 1
        let returns = zip(snapshots, snapshots.dropFirst()).map { prev, curr in (curr.totalValue - prev.totalValue) / max(prev.totalValue, 0.0001) }
        let meanReturn = returns.reduce(0, +) / Double(max(1, returns.count))
        let variance = returns.count > 1 ? returns.map { pow($0 - meanReturn, 2) }.reduce(0, +) / Double(returns.count - 1) : 0
        let volatility = sqrt(max(0, variance)) * sqrt(252.0)
        let sharpe = volatility > 0 ? (annualizedReturn - riskFreeRate) / volatility : 0
        let downside = returns.filter { $0 < 0 }.map { $0 * $0 }.reduce(0, +)
        let downsideDev = sqrt(downside / Double(max(1, returns.count)))
        let sortino = downsideDev > 0 ? (annualizedReturn - riskFreeRate) / downsideDev : 0
        let turnover = Double(transactions.count) * 0.1
        return SimulationResult.PortfolioSummary(finalValue: finalValue, totalReturn: totalReturn, annualizedReturn: annualizedReturn, maxDrawdown: finalSnapshot.riskMetrics.maxDrawdown, sharpeRatio: sharpe, sortinoRatio: sortino, totalTrades: transactions.count, turnover: turnover, taxOwed: 0, netReturn: totalReturn, benchmarkReturn: 0, alpha: 0, beta: 0)
    }

    private func calculatePathStatistics(snapshots: [PortfolioSnapshot], initialCapital: Double) -> SimulationResult.PathStatistics {
        guard let finalValue = snapshots.last?.totalValue else { return .init(meanFinalValue: 0, medianFinalValue: 0, stdDevFinalValue: 0, percentile5: 0, percentile95: 0, probabilityOfLoss: 0, expectedReturn: 0, valueAtRisk95: 0, conditionalValueAtRisk95: 0) }
        let returns = zip(snapshots, snapshots.dropFirst()).map { prev, curr in (curr.totalValue - prev.totalValue) / max(prev.totalValue, 0.0001) }
        let mean = returns.reduce(0, +) / Double(max(1, returns.count))
        let variance = returns.count > 1 ? returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count - 1) : 0
        let std = sqrt(max(0, variance))
        let sortedReturns = returns.sorted()
        let varIndex = Int(Double(sortedReturns.count) * 0.05)
        let var95 = sortedReturns.indices.contains(varIndex) ? sortedReturns[varIndex] : 0
        let cvarSamples = sortedReturns.prefix(max(1, varIndex))
        let cvar95 = cvarSamples.isEmpty ? 0 : cvarSamples.reduce(0, +) / Double(cvarSamples.count)
        let probLoss = Double(returns.filter { $0 < 0 }.count) / Double(max(1, returns.count))
        return SimulationResult.PathStatistics(meanFinalValue: finalValue, medianFinalValue: finalValue, stdDevFinalValue: std * finalValue, percentile5: finalValue * (1 + var95), percentile95: finalValue * (1 + returns.sorted()[Int(Double(sortedReturns.count) * 0.95)]), probabilityOfLoss: probLoss, expectedReturn: mean * 252.0, valueAtRisk95: var95, conditionalValueAtRisk95: cvar95)
    }
}

private func randomNormal(seed: UInt64) -> Double {
    var s = seed
    func next() -> UInt64 { s = s &* 2862933555777941757 &+ 3037000493; return s }
    let u1 = Double(next() % 1_000_000) / 1_000_000
    let u2 = Double(next() % 1_000_000) / 1_000_000
    return sqrt(-2.0 * log(max(u1, 0.0001))) * cos(2.0 * .pi * u2)
}
