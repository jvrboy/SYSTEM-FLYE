import Foundation
import Combine
import Accelerate

// MARK: - Order Models
enum OrderSide: String, Codable { case buy = "BUY", sell = "SELL" }
enum OrderType: String, Codable { case market = "MARKET", limit = "LIMIT", stop = "STOP", stopLimit = "STOP_LIMIT", trailingStop = "TRAILING_STOP" }
enum OrderStatus: String, Codable { case pending = "PENDING", filled = "FILLED", partiallyFilled = "PARTIALLY_FILLED", cancelled = "CANCELLED", rejected = "REJECTED", expired = "EXPIRED" }
enum OrderTif: String, Codable { case gtc = "GTC", ioc = "IOC", fok = "FOK", day = "DAY" }

struct Order: Codable, Identifiable {
    let id: UUID
    let pair: String
    let side: OrderSide
    let type: OrderType
    let quantity: Double
    let filledQuantity: Double
    var price: Double?
    var stopPrice: Double?
    var limitPrice: Double?
    var status: OrderStatus
    let tif: OrderTif
    let placedAt: Date
    var filledAt: Date?
    var averageFillPrice: Double?
    let commission: Double
    let slippage: Double
    let fees: [Fee]
    let parentId: UUID?
    let tags: [String]
    let notes: String

    init(id: UUID = UUID(), pair: String, side: OrderSide, type: OrderType, quantity: Double, filledQuantity: Double = 0, price: Double? = nil, stopPrice: Double? = nil, limitPrice: Double? = nil, status: OrderStatus = .pending, tif: OrderTif = .gtc, placedAt: Date = Date(), filledAt: Date? = nil, averageFillPrice: Double? = nil, commission: Double = 0, slippage: Double = 0, fees: [Fee] = [], parentId: UUID? = nil, tags: [String] = [], notes: String = "") {
        self.id = id
        self.pair = pair
        self.side = side
        self.type = type
        self.quantity = max(0, quantity)
        self.filledQuantity = max(0, min(filledQuantity, quantity))
        self.price = price
        self.stopPrice = stopPrice
        self.limitPrice = limitPrice
        self.status = status
        self.tif = tif
        self.placedAt = placedAt
        self.filledAt = filledAt
        self.averageFillPrice = averageFillPrice
        self.commission = commission
        self.slippage = slippage
        self.fees = fees
        self.parentId = parentId
        self.tags = tags
        self.notes = notes
    }

    var remainingQuantity: Double { max(0, quantity - filledQuantity) }
    var isFilled: Bool { status == .filled }
    var isActive: Bool { status == .pending || status == .partiallyFilled }
}

struct Fee: Codable, Identifiable {
    let id = UUID()
    let type: FeeType
    let amount: Double
    let currency: String
    let description: String

    enum FeeType: String, Codable { case commission, spread, slippage, tax, regulatory }
}

// MARK: - Trade Record
struct BacktestTrade: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let pair: String
    let side: OrderSide
    let entryPrice: Double
    let exitPrice: Double
    let quantity: Double
    let entryTime: Date
    var exitTime: Date?
    var grossPnL: Double?
    var netPnL: Double?
    var commission: Double
    var slippage: Double
    var returnPercent: Double?
    var barsHeld: Int?
    var status: TradeStatus
    var exitReason: ExitReason

    enum TradeStatus: String, Codable { case open = "OPEN", closed = "CLOSED", stopped = "STOPPED", expired = "EXPIRED" }
    enum ExitReason: String, Codable { case manual = "MANUAL", stopLoss = "STOP_LOSS", takeProfit = "TAKE_PROFIT", trailStop = "TRAILING_STOP", timeExpiry = "TIME_EXPIRY", forceClose = "FORCE_CLOSE" }

    init(id: UUID = UUID(), orderId: UUID, pair: String, side: OrderSide, entryPrice: Double, quantity: Double, entryTime: Date = Date(), commission: Double = 0, slippage: Double = 0, status: TradeStatus = .open, exitReason: ExitReason = .manual) {
        self.id = id
        self.orderId = orderId
        self.pair = pair
        self.side = side
        self.entryPrice = entryPrice
        self.exitPrice = 0
        self.quantity = quantity
        self.entryTime = entryTime
        self.exitTime = nil
        self.grossPnL = nil
        self.netPnL = nil
        self.commission = commission
        self.slippage = slippage
        self.returnPercent = nil
        self.barsHeld = nil
        self.status = status
        self.exitReason = exitReason
    }
}

// MARK: - Market Data
struct BacktestCandle: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let spread: Double
    let fundingRate: Double?

    init(timestamp: Date, open: Double, high: Double, low: Double, close: Double, volume: Double = 0, spread: Double = 0, fundingRate: Double? = nil) {
        self.timestamp = timestamp
        self.open = max(0, open)
        self.high = max(0, high)
        self.low = max(0, low)
        self.close = max(0, close)
        self.volume = max(0, volume)
        self.spread = max(0, spread)
        self.fundingRate = fundingRate
    }

    var typicalPrice: Double { (high + low + close) / 3 }
    var isBullish: Bool { close >= open }
    var isBearish: Bool { close < open }
    var range: Double { high - low }
    var bodySize: Double { abs(close - open) }
    var upperWick: Double { high - max(open, close) }
    var lowerWick: Double { min(open, close) - low }
}

// MARK: - Slippage Model
enum SlippageModel: String, Codable {
    case none = "NONE"
    case fixed = "FIXED"
    case percentage = "PERCENTAGE"
    case volumeBased = "VOLUME_BASED"
    case marketImpact = "MARKET_IMPACT"
    case custom = "CUSTOM"
}

struct SlippageConfiguration: Codable {
    var model: SlippageModel
    var fixedAmount: Double
    var percentage: Double
    var volumeCoefficient: Double
    var marketImpactCoefficient: Double
    var maxSlippage: Double
    var spreadAddition: Double
    var volatilityMultiplier: Bool

    static let `default` = SlippageConfiguration(model: .percentage, fixedAmount: 0, volumeCoefficient: 0.1, marketImpactCoefficient: 0.5, percentage: 0.05, maxSlippage: 0.5, spreadAddition: 0, volatilityMultiplier: true)
}

// MARK: - Commission Model
enum CommissionModel: String, Codable {
    case fixed = "FIXED"
    case percentage = "PERCENTAGE"
    case tiered = "TIERED"
    case perTrade = "PER_TRADE"
}

struct CommissionConfiguration: Codable {
    var model: CommissionModel
    var fixedAmount: Double
    var percentage: Double
    var minimumCommission: Double
    var maximumCommission: Double
    var tierThresholds: [TierThreshold]
    var currency: String

    struct TierThreshold: Codable {
        let volume: Double
        let rate: Double
    }

    static let `default` = CommissionConfiguration(model: .percentage, fixedAmount: 0, percentage: 0.0001, minimumCommission: 0, maximumCommission: 100, tierThresholds: [], currency: "USD")
}

// MARK: - Backtest Configuration
struct BacktestConfiguration: Codable, Identifiable {
    let id: UUID
    var pair: String
    var startDate: Date
    var endDate: Date
    var initialCapital: Double
    var currency: String
    var leverage: Double
    var marginRequirement: Double
    var slippage: SlippageConfiguration
    var commission: CommissionConfiguration
    var maxPositions: Int
    var positionSizing: PositionSizingMode
    var defaultQuantity: Double
    var hedgingEnabled: Bool
    var allowShorting: Bool
    var fillModel: FillModel
    var barModel: BarModel
    var randomSeed: UInt64
    var tags: [String]
    var notes: String
    var createdAt: Date

    enum PositionSizingMode: String, Codable { case fixed, percentOfCapital, riskBased, kelly, volatilityAdjusted }
    enum FillModel: String, Codable { case nextOpen, nextClose, randomWithinBar, worstCase, bestCase, realistic }
    enum BarModel: String, Codable { case open, close, midpoint, ohlc, tickByTick }

    init(id: UUID = UUID(), pair: String, startDate: Date, endDate: Date, initialCapital: Double = 10000, currency: String = "USD", leverage: Double = 1, marginRequirement: Double = 0, slippage: SlippageConfiguration = .default, commission: CommissionConfiguration = .default, maxPositions: Int = 10, positionSizing: PositionSizingMode = .fixed, defaultQuantity: Double = 1, hedgingEnabled: Bool = false, allowShorting: Bool = true, fillModel: FillModel = .nextOpen, barModel: BarModel = .close, randomSeed: UInt64 = 0xDEADBEEF, tags: [String] = [], notes: String = "", createdAt: Date = Date()) {
        self.id = id
        self.pair = pair
        self.startDate = startDate
        self.endDate = endDate
        self.initialCapital = max(0, initialCapital)
        self.currency = currency
        self.leverage = max(1, leverage)
        self.marginRequirement = max(0, min(1, marginRequirement))
        self.slippage = slippage
        self.commission = commission
        self.maxPositions = max(1, maxPositions)
        self.positionSizing = positionSizing
        self.defaultQuantity = max(0, defaultQuantity)
        self.hedgingEnabled = hedgingEnabled
        self.allowShorting = allowShorting
        self.fillModel = fillModel
        self.barModel = barModel
        self.randomSeed = randomSeed
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - Backtest Result
struct BacktestResult: Codable, Identifiable {
    let id: UUID
    let configurationId: UUID
    let trades: [BacktestTrade]
    let equityCurve: [EquityPoint]
    let drawdownCurve: [DrawdownPoint]
    let metrics: PerformanceMetrics
    let monthlyReturns: [MonthlyReturn]
    let executionTimeMs: Double
    let completedAt: Date
    let success: Bool
    let error: String?

    struct EquityPoint: Codable, Identifiable {
        let id = UUID()
        let timestamp: Date
        let equity: Double
        let cash: Double
        let positionsValue: Double
    }

    struct DrawdownPoint: Codable, Identifiable {
        let id = UUID()
        let timestamp: Date
        let drawdown: Double
        let peakEquity: Double
    }

    struct MonthlyReturn: Codable, Identifiable {
        let id = UUID()
        let year: Int
        let month: Int
        let returnPercent: Double
        let tradeCount: Int
        let winRate: Double
    }

    init(id: UUID = UUID(), configurationId: UUID, trades: [BacktestTrade] = [], equityCurve: [EquityPoint] = [], drawdownCurve: [DrawdownPoint] = [], metrics: PerformanceMetrics = PerformanceMetrics.empty, monthlyReturns: [MonthlyReturn] = [], executionTimeMs: Double = 0, completedAt: Date = Date(), success: Bool = true, error: String? = nil) {
        self.id = id
        self.configurationId = configurationId
        self.trades = trades
        self.equityCurve = equityCurve
        self.drawdownCurve = drawdownCurve
        self.metrics = metrics
        self.monthlyReturns = monthlyReturns
        self.executionTimeMs = executionTimeMs
        self.completedAt = completedAt
        self.success = success
        self.error = error
    }
}

// MARK: - Performance Metrics
struct PerformanceMetrics: Codable, Equatable {
    let totalReturn: Double
    let annualizedReturn: Double
    let annualizedVolatility: Double
    let sharpeRatio: Double
    let sortinoRatio: Double
    let calmarRatio: Double
    let maxDrawdown: Double
    let maxDrawdownDuration: TimeInterval
    let winRate: Double
    let profitFactor: Double
    let totalTrades: Int
    let winningTrades: Int
    let losingTrades: Int
    let averageWin: Double
    let averageLoss: Double
    let largestWin: Double
    let largestLoss: Double
    let averageTradeDuration: TimeInterval
    let expectancy: Double
    let ulcerIndex: Double
    let recoveryFactor: Double
    let skewness: Double
    let kurtosis: Double
    let valueAtRisk95: Double
    let conditionalValueAtRisk95: Double
    let beta: Double
    let alpha: Double
    let informationRatio: Double
    let omegaRatio: Double
    let gainToPainRatio: Double
    let averageExposure: Double
    let turnover: Double

    static let empty = PerformanceMetrics(totalReturn: 0, annualizedReturn: 0, annualizedVolatility: 0, sharpeRatio: 0, sortinoRatio: 0, calmarRatio: 0, maxDrawdown: 0, maxDrawdownDuration: 0, winRate: 0, profitFactor: 0, totalTrades: 0, winningTrades: 0, losingTrades: 0, averageWin: 0, averageLoss: 0, largestWin: 0, largestLoss: 0, averageTradeDuration: 0, expectancy: 0, ulcerIndex: 0, recoveryFactor: 0, skewness: 0, kurtosis: 0, valueAtRisk95: 0, conditionalValueAtRisk95: 0, beta: 0, alpha: 0, informationRatio: 0, omegaRatio: 0, gainToPainRatio: 0, averageExposure: 0, turnover: 0)
}

// MARK: - Backtest Engine
@MainActor
final class BacktestEngine: ObservableObject {
    static let shared = BacktestEngine()
    @Published private(set) var results: [BacktestResult] = []
    @Published private(set) var isRunning = false
    @Published private(set) var progress: Double = 0
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func runBacktest(configuration: BacktestConfiguration, strategy: StrategyDefinition) async -> BacktestResult {
        guard !isRunning else { return BacktestResult(configurationId: configuration.id, success: false, error: "Backtest already running") }
        isRunning = true
        progress = 0
        defer { isRunning = false; progress = 0 }
        let startTime = Date()
        var capital = configuration.initialCapital
        var cash = capital
        var positions: [Position] = []
        var trades: [BacktestTrade] = []
        var equityCurve: [BacktestResult.EquityPoint] = []
        var drawdownCurve: [BacktestResult.DrawdownPoint] = []
        var peakEquity = capital
        var rng = SeededGenerator(seed: configuration.randomSeed)
        let candles = generateSyntheticMarketData(configuration: configuration, rng: &rng)
        var currentBarIndex = 0
        let totalBars = candles.count
        let context = ExecutionContext(currentPrice: 0, timestamp: Date(), pair: configuration.pair, accountBalance: capital, openPositions: positions, marketState: .trending)
        for (index, candle) in candles.enumerated() {
            currentBarIndex = index
            progress = Double(index) / Double(totalBars)
            if Task.isCancelled { break }
            context.currentPrice = candle.close
            context.timestamp = candle.timestamp
            let executionResult = StrategyBuilderEngine.shared.execute(strategyId: strategy.id, context: context)
            for signal in executionResult.signals {
                let slippageCost = calculateSlippage(configuration: configuration, orderSize: signal.size, price: candle.close, volatility: candle.range / max(candle.close, 0.0001), rng: &rng)
                let commissionCost = calculateCommission(configuration: configuration, size: signal.size, price: candle.close)
                if signal.isClose {
                    closePositions(positions: &positions, signal: signal, price: candle.close + (signal.type == .buy ? slippageCost : -slippageCost), time: candle.timestamp, commission: commissionCost, slippage: slippageCost, trades: &trades)
                } else if positions.count < configuration.maxPositions {
                    let positionSize = calculatePositionSize(configuration: configuration, capital: cash, price: candle.close, volatility: candle.range)
                    let fillPrice = candle.close + (signal.type == .buy ? slippageCost : -slippageCost)
                    let position = Position(id: UUID(), pair: configuration.pair, type: signal.type, entryPrice: fillPrice, size: positionSize, openTime: candle.timestamp, stopLoss: signal.stopLoss, takeProfit: signal.takeProfit)
                    positions.append(position)
                    cash -= positionSize * fillPrice + commissionCost
                }
            }
            updatePositions(positions: &positions, candle: candle, configuration: &configuration, trades: &trades, commission: configuration.commission, slippageConfig: configuration.slippage, rng: &rng)
            let positionsValue = positions.reduce(0) { $0 + ($1.type == .buy ? $1.size * candle.close : -$1.size * candle.close) }
            let totalEquity = cash + positionsValue
            if totalEquity > peakEquity { peakEquity = totalEquity }
            equityCurve.append(BacktestResult.EquityPoint(timestamp: candle.timestamp, equity: totalEquity, cash: cash, positionsValue: positionsValue))
            let currentDrawdown = (peakEquity - totalEquity) / max(peakEquity, 0.0001)
            if currentDrawdown > 0 { drawdownCurve.append(BacktestResult.DrawdownPoint(timestamp: candle.timestamp, drawdown: currentDrawdown, peakEquity: peakEquity)) }
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let metrics = calculateMetrics(trades: trades, equityCurve: equityCurve, initialCapital: capital)
        let monthlyReturns = calculateMonthlyReturns(trades: trades)
        let result = BacktestResult(configurationId: configuration.id, trades: trades, equityCurve: equityCurve, drawdownCurve: drawdownCurve, metrics: metrics, monthlyReturns: monthlyReturns, executionTimeMs: executionTime, completedAt: Date(), success: true)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        return result
    }

    func cancelBacktest() { cancellationToken?.cancel() }

    private func generateSyntheticMarketData(configuration: BacktestConfiguration, rng: inout SeededGenerator) -> [BacktestCandle] {
        var candles: [BacktestCandle] = []
        let start = configuration.startDate
        let end = configuration.endDate
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        var current = calendar.date(from: components) ?? start
        var price = configuration.initialCapital * 0.0001
        let mu = 0.0001
        let sigma = 0.01
        while current <= end {
            let dt = 1.0 / 252.0
            let z = randomNormal(rng: &rng)
            let drift = (mu - 0.5 * sigma * sigma) * dt
            let diffusion = sigma * sqrt(dt) * z
            let return_ = exp(drift + diffusion)
            let open = price
            let close = open * return_
            let high = max(open, close) * (1 + abs(randomNormal(rng: &rng)) * 0.005)
            let low = min(open, close) * (1 - abs(randomNormal(rng: &rng)) * 0.005)
            let volume = rng.nextDouble(in: 1000...100000)
            let spread = max(0.0001, abs(randomNormal(rng: &rng)) * 0.0002)
            candles.append(BacktestCandle(timestamp: current, open: open, high: high, low: low, close: close, volume: volume, spread: spread))
            price = close
            current = calendar.date(byAdding: .hour, value: 1, to: current) ?? current
        }
        return candles
    }

    private func calculateSlippage(configuration: BacktestConfiguration, orderSize: Double, price: Double, volatility: Double, rng: inout SeededGenerator) -> Double {
        let config = configuration.slippage
        var slippage: Double = 0
        switch config.model {
        case .none: slippage = 0
        case .fixed: slippage = config.fixedAmount
        case .percentage: slippage = price * config.percentage / 100.0
        case .volumeBased: slippage = price * config.volumeCoefficient * orderSize / 1000.0
        case .marketImpact: slippage = price * config.marketImpactCoefficient * volatility / 100.0
        case .custom: slippage = price * config.percentage / 100.0
        }
        if config.volatilityMultiplier { slippage *= (1 + volatility * 10) }
        if config.spreadAddition > 0 { slippage += price * config.spreadAddition / 100.0 }
        return min(slippage, price * config.maxSlippage / 100.0)
    }

    private func calculateCommission(configuration: BacktestConfiguration, size: Double, price: Double) -> Double {
        let config = configuration.commission
        let notional = size * price
        switch config.model {
        case .fixed: return max(config.minimumCommission, min(config.maximumCommission, config.fixedAmount))
        case .percentage: return max(config.minimumCommission, min(config.maximumCommission, notional * config.percentage / 100.0))
        case .perTrade: return max(config.minimumCommission, min(config.maximumCommission, config.fixedAmount))
        case .tiered:
            var commission = notional * config.percentage / 100.0
            for tier in config.tierThresholds.sorted(by: { $0.volume < $1.volume }) {
                if notional >= tier.volume { commission = notional * tier.rate / 100.0 }
            }
            return max(config.minimumCommission, min(config.maximumCommission, commission))
        }
    }

    private func calculatePositionSize(configuration: BacktestConfiguration, capital: Double, price: Double, volatility: Double) -> Double {
        switch configuration.positionSizing {
        case .fixed: return configuration.defaultQuantity
        case .percentOfCapital: return (capital * 0.1) / max(price, 0.0001)
        case .riskBased: return (capital * 0.02) / max(volatility * price, 0.0001)
        case .kelly: let winProb = 0.55; let winLossRatio = 1.5; return capital * max(0, (winProb * winLossRatio - (1 - winProb)) / winLossRatio) * 0.1 / max(price, 0.0001)
        case .volatilityAdjusted: return (capital * 0.1 / max(volatility * 100, 1)) / max(price, 0.0001)
        }
    }

    private func closePositions(positions: inout [Position], signal: TradeSignal, price: Double, time: Date, commission: Double, slippage: Double, trades: inout [BacktestTrade]) {
        guard !positions.isEmpty else { return }
        if signal.closePosition == .all {
            for position in positions {
                let pnl = position.type == .buy ? (price - position.entryPrice) * position.size : (position.entryPrice - price) * position.size
                let trade = BacktestTrade(orderId: UUID(), pair: position.pair, side: position.type == .buy ? .sell : .buy, entryPrice: position.entryPrice, exitPrice: price, quantity: position.size, entryTime: position.openTime, exitTime: time, grossPnL: pnl, netPnL: pnl - commission - slippage, commission: commission, slippage: slippage, status: .closed, exitReason: .manual)
                trades.append(trade)
            }
            positions.removeAll()
        } else if signal.closePosition == .long {
            positions = positions.filter { position in
                if position.type == .buy {
                    let pnl = (price - position.entryPrice) * position.size
                    let trade = BacktestTrade(orderId: UUID(), pair: position.pair, side: .sell, entryPrice: position.entryPrice, exitPrice: price, quantity: position.size, entryTime: position.openTime, exitTime: time, grossPnL: pnl, netPnL: pnl - commission - slippage, commission: commission, slippage: slippage, status: .closed, exitReason: .manual)
                    trades.append(trade)
                    return false
                }
                return true
            }
        } else if signal.closePosition == .short {
            positions = positions.filter { position in
                if position.type == .sell {
                    let pnl = (position.entryPrice - price) * position.size
                    let trade = BacktestTrade(orderId: UUID(), pair: position.pair, side: .buy, entryPrice: position.entryPrice, exitPrice: price, quantity: position.size, entryTime: position.openTime, exitTime: time, grossPnL: pnl, netPnL: pnl - commission - slippage, commission: commission, slippage: slippage, status: .closed, exitReason: .manual)
                    trades.append(trade)
                    return false
                }
                return true
            }
        }
    }

    private func updatePositions(positions: inout [Position], candle: BacktestCandle, configuration: inout BacktestConfiguration, trades: inout [BacktestTrade], commission: CommissionConfiguration, slippageConfig: SlippageConfiguration, rng: inout SeededGenerator) {
        var rngCopy = rng
        positions = positions.filter { position in
            let currentPrice = candle.close
            if let stopLoss = position.stopLoss {
                if (position.type == .buy && candle.low <= stopLoss) || (position.type == .sell && candle.high >= stopLoss) {
                    let slippage = calculateSlippage(configuration: configuration, orderSize: position.size, price: stopLoss, volatility: candle.range / max(candle.close, 0.0001), rng: &rngCopy)
                    let commission = calculateCommission(configuration: configuration, size: position.size, price: stopLoss)
                    let pnl = position.type == .buy ? (stopLoss - position.entryPrice) * position.size : (position.entryPrice - stopLoss) * position.size
                    let trade = BacktestTrade(orderId: UUID(), pair: position.pair, side: position.type == .buy ? .sell : .buy, entryPrice: position.entryPrice, exitPrice: stopLoss + slippage, quantity: position.size, entryTime: position.openTime, exitTime: candle.timestamp, grossPnL: pnl, netPnL: pnl - commission - slippage, commission: commission, slippage: slippage, status: .stopped, exitReason: .stopLoss)
                    trades.append(trade)
                    rng = rngCopy
                    return false
                }
            }
            if let takeProfit = position.takeProfit {
                if (position.type == .buy && candle.high >= takeProfit) || (position.type == .sell && candle.low <= takeProfit) {
                    let slippage = calculateSlippage(configuration: configuration, orderSize: position.size, price: takeProfit, volatility: candle.range / max(candle.close, 0.0001), rng: &rngCopy)
                    let commission = calculateCommission(configuration: configuration, size: position.size, price: takeProfit)
                    let pnl = position.type == .buy ? (takeProfit - position.entryPrice) * position.size : (position.entryPrice - takeProfit) * position.size
                    let trade = BacktestTrade(orderId: UUID(), pair: position.pair, side: position.type == .buy ? .sell : .buy, entryPrice: position.entryPrice, exitPrice: takeProfit - slippage, quantity: position.size, entryTime: position.openTime, exitTime: candle.timestamp, grossPnL: pnl, netPnL: pnl - commission - slippage, commission: commission, slippage: slippage, status: .closed, exitReason: .takeProfit)
                    trades.append(trade)
                    rng = rngCopy
                    return false
                }
            }
            return true
        }
        rng = rngCopy
    }

    private func calculateMetrics(trades: [BacktestTrade], equityCurve: [BacktestResult.EquityPoint], initialCapital: Double) -> PerformanceMetrics {
        guard !equityCurve.isEmpty else { return .empty }
        let returns = zip(equityCurve, equityCurve.dropFirst()).map { prev, curr in (curr.equity - prev.equity) / max(prev.equity, 0.0001) }
        let finalEquity = equityCurve.last?.equity ?? initialCapital
        let totalReturn = (finalEquity - initialCapital) / max(initialCapital, 0.0001)
        let years = Double(max(1, equityCurve.count)) / (252.0 * 24.0)
        let annualizedReturn = pow(max(0.0001, finalEquity / initialCapital), 1.0 / max(years, 0.0001)) - 1
        let meanReturn = returns.reduce(0, +) / Double(max(1, returns.count))
        let variance = returns.count > 1 ? returns.map { pow($0 - meanReturn, 2) }.reduce(0, +) / Double(returns.count - 1) : 0
        let annualizedVolatility = sqrt(max(0, variance)) * sqrt(252.0 * 24.0)
        let sharpe = annualizedVolatility > 0 ? (annualizedReturn - 0.02) / annualizedVolatility : 0
        let downsideReturns = returns.filter { $0 < 0 }.map { $0 * $0 }
        let downsideDeviation = sqrt(downsideReturns.reduce(0, +) / Double(max(1, returns.count)))
        let sortino = downsideDeviation > 0 ? (annualizedReturn - 0.02) / (downsideDeviation * sqrt(252.0 * 24.0)) : 0
        var peak = initialCapital
        var maxDD = 0.0
        var maxDDStart = Date()
        var maxDDEnd = Date()
        var ddStart = equityCurve.first?.timestamp ?? Date()
        for point in equityCurve {
            if point.equity > peak { peak = point.equity; ddStart = point.timestamp }
            let dd = (peak - point.equity) / max(peak, 0.0001)
            if dd > maxDD { maxDD = dd; maxDDStart = ddStart; maxDDEnd = point.timestamp }
        }
        let calmar = maxDD > 0 ? annualizedReturn / maxDD : 0
        let winningTrades = trades.filter { ($0.netPnL ?? 0) > 0 }
        let losingTrades = trades.filter { ($0.netPnL ?? 0) <= 0 }
        let totalTrades = trades.count
        let winRate = totalTrades > 0 ? Double(winningTrades.count) / Double(totalTrades) : 0
        let grossProfit = winningTrades.reduce(0) { $0 + ($1.netPnL ?? 0) }
        let grossLoss = abs(losingTrades.reduce(0) { $0 + ($1.netPnL ?? 0) })
        let profitFactor = grossLoss > 0 ? grossProfit / grossLoss : (grossProfit > 0 ? 100 : 0)
        let avgWin = winningTrades.isEmpty ? 0 : winningTrades.reduce(0) { $0 + ($1.netPnL ?? 0) } / Double(winningTrades.count)
        let avgLoss = losingTrades.isEmpty ? 0 : losingTrades.reduce(0) { $0 + ($1.netPnL ?? 0) } / Double(max(1, losingTrades.count))
        let largestWin = winningTrades.map { $0.netPnL ?? 0 }.max() ?? 0
        let largestLoss = losingTrades.map { $0.netPnL ?? 0 }.min() ?? 0
        let expectancy = winRate * avgWin + (1 - winRate) * avgLoss
        let avgDuration = trades.isEmpty ? 0 : trades.compactMap { $0.exitTime.map { $0.timeIntervalSince($0.entryTime) } }.reduce(0, +) / Double(trades.count)
        let sortedReturns = returns.sorted()
        let varIndex = Int(Double(sortedReturns.count) * 0.05)
        let valueAtRisk95 = sortedReturns.indices.contains(varIndex) ? sortedReturns[varIndex] : 0
        let cvarSamples = sortedReturns.prefix(max(1, varIndex))
        let cvar95 = cvarSamples.isEmpty ? 0 : cvarSamples.reduce(0, +) / Double(cvarSamples.count)
        let gains = returns.filter { $0 > 0 }.reduce(0, +)
        let losses = abs(returns.filter { $0 < 0 }.reduce(0, +))
        let omega = losses > 0 ? gains / losses : (gains > 0 ? 100 : 0)
        return PerformanceMetrics(totalReturn: totalReturn, annualizedReturn: annualizedReturn, annualizedVolatility: annualizedVolatility, sharpeRatio: sharpe, sortinoRatio: sortino, calmarRatio: calmar, maxDrawdown: maxDD, maxDrawdownDuration: maxDDEnd.timeIntervalSince(maxDDStart), winRate: winRate, profitFactor: profitFactor, totalTrades: totalTrades, winningTrades: winningTrades.count, losingTrades: losingTrades.count, averageWin: avgWin, averageLoss: avgLoss, largestWin: largestWin, largestLoss: largestLoss, averageTradeDuration: avgDuration, expectancy: expectancy, ulcerIndex: 0, recoveryFactor: maxDD > 0 ? annualizedReturn / maxDD : 0, skewness: 0, kurtosis: 0, valueAtRisk95: valueAtRisk95, conditionalValueAtRisk95: cvar95, beta: 0, alpha: 0, informationRatio: 0, omegaRatio: omega, gainToPainRatio: losses > 0 ? gains / losses : 0, averageExposure: 0, turnover: 0)
    }

    private func calculateMonthlyReturns(trades: [BacktestTrade]) -> [BacktestResult.MonthlyReturn] {
        let calendar = Calendar.current
        var monthlyData: [String: (returnPercent: Double, tradeCount: Int, wins: Int)] = [:]
        for trade in trades {
            let exitDate = trade.exitTime ?? trade.entryTime
            let key = "\(calendar.component(.year, from: exitDate))-\(calendar.component(.month, from: exitDate))"
            let current = monthlyData[key] ?? (0, 0, 0)
            let returnPct = trade.netPnL.map { $0 / 10000.0 } ?? 0
            monthlyData[key] = (current.returnPercent + returnPct, current.tradeCount + 1, current.wins + ((trade.netPnL ?? 0) > 0 ? 1 : 0))
        }
        return monthlyData.sorted { $0.key < $1.key }.compactMap { key, data in
            let parts = key.split(separator: "-")
            guard let year = Int(parts[0]), let month = Int(parts[1]) else { return nil }
            return BacktestResult.MonthlyReturn(year: year, month: month, returnPercent: data.returnPercent, tradeCount: data.tradeCount, winRate: data.tradeCount > 0 ? Double(data.wins) / Double(data.tradeCount) : 0)
        }
    }
}

// MARK: - Seeded Generator
struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 { state = state &* 2862933555777941757 &+ 3037000493; return state }
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double { let unit = Double(next() % 1_000_000) / 1_000_000; return range.lowerBound + (range.upperBound - range.lowerBound) * unit }
    mutating func nextInt(upperBound: Int) -> Int { guard upperBound > 0 else { return 0 }; return Int(next() % UInt64(upperBound)) }
    mutating func nextBool() -> Bool { next() % 2 == 0 }
}

private func randomNormal(rng: inout SeededGenerator) -> Double {
    var u1 = rng.nextDouble(in: 0...1)
    var u2 = rng.nextDouble(in: 0...1)
    while u1 == 0 { u1 = rng.nextDouble(in: 0.0001...1) }
    return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
}
