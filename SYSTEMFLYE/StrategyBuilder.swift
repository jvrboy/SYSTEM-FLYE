import Foundation
import Combine
import Accelerate

// MARK: - Block Protocol
protocol StrategyBlock: Codable, Identifiable, Hashable {
    var id: UUID { get }
    var blockType: BlockType { get }
    var name: String { get set }
    var isEnabled: Bool { get set }
    var position: CGPoint { get set }
}

// MARK: - Block Types
enum BlockType: String, Codable, CaseIterable {
    case condition = "CONDITION"
    case action = "ACTION"
    case logicGate = "LOGIC_GATE"
    case indicator = "INDICATOR"
    case filter = "FILTER"
    case output = "OUTPUT"
}

// MARK: - Condition Block
struct ConditionBlock: StrategyBlock {
    let id: UUID
    var blockType: BlockType { .condition }
    var name: String
    var isEnabled: Bool
    var position: CGPoint
    var indicator: TechnicalIndicatorType
    var operator: ComparisonOperator
    var threshold: Double
    var timeFrame: TimeFrame
    var lookbackPeriod: Int
    var smoothing: Int

    enum TechnicalIndicatorType: String, Codable, CaseIterable {
        case rsi = "RSI"
        case macd = "MACD"
        case movingAverage = "MA"
        case bollingerBands = "BB"
        case stochastic = "STOCH"
        case atr = "ATR"
        case volume = "VOLUME"
        case price = "PRICE"
        case custom = "CUSTOM"
    }

    enum ComparisonOperator: String, Codable, CaseIterable {
        case greaterThan = ">"
        case lessThan = "<"
        case greaterThanOrEqual = ">="
        case lessThanOrEqual = "<="
        case equalTo = "=="
        case crossesAbove = "CROSSES_ABOVE"
        case crossesBelow = "CROSSES_BELOW"
        case notEqual = "!="
    }

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, position: CGPoint = .zero, indicator: TechnicalIndicatorType = .rsi, operator: ComparisonOperator = .greaterThan, threshold: Double = 70, timeFrame: TimeFrame = .oneHour, lookbackPeriod: Int = 14, smoothing: Int = 3) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.position = position
        self.indicator = indicator
        self.operator = operator
        self.threshold = max(-1e9, min(1e9, threshold))
        self.timeFrame = timeFrame
        self.lookbackPeriod = max(1, lookbackPeriod)
        self.smoothing = max(1, smoothing)
    }

    func evaluate(history: [PriceData]) -> Bool {
        guard history.count >= lookbackPeriod + smoothing else { return false }
        let values = computeIndicator(history: history)
        guard let current = values.last, values.count >= 2 else { return false }
        let previous = values[values.count - 2]
        switch operator {
        case .greaterThan: return current > threshold
        case .lessThan: return current < threshold
        case .greaterThanOrEqual: return current >= threshold
        case .lessThanOrEqual: return current <= threshold
        case .equalTo: return abs(current - threshold) < 0.0001
        case .notEqual: return abs(current - threshold) >= 0.0001
        case .crossesAbove: return previous <= threshold && current > threshold
        case .crossesBelow: return previous >= threshold && current < threshold
        }
    }

    private func computeIndicator(history: [PriceData]) -> [Double] {
        let closes = history.map(\.close)
        let highs = history.map(\.high)
        let lows = history.map(\.low)
        let period = min(lookbackPeriod, history.count - 1)
        switch indicator {
        case .rsi: return computeRSI(closes, period: period)
        case .macd: return computeMACD(closes).map { $0.macdLine }
        case .movingAverage: return computeSMA(closes, period: period)
        case .bollingerBands: return computeBollingerBands(closes, period: period).map { $0.upper }
        case .stochastic: return computeStochastic(highs, lows, closes, period: period).map { $0.kValue }
        case .atr: return computeATR(history, period: period)
        case .volume: return history.map { Double($0.volume) }
        case .price: return closes
        case .custom: return closes
        }
    }

    private func computeRSI(_ prices: [Double], period: Int) -> [Double] {
        guard prices.count > period else { return [] }
        var deltas = [Double]()
        for i in 1..<prices.count { deltas.append(prices[i] - prices[i - 1]) }
        var gains = deltas.map { max($0, 0) }
        var losses = deltas.map { max(-$0, 0) }
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        var rsi: [Double] = [avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss)]
        for i in period..<deltas.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            rsi.append(avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss))
        }
        return rsi
    }

    private func computeMACD(_ prices: [Double]) -> [TechnicalIndicators.MACDValue] {
        let ema12 = exponentialMovingAverage(prices, period: 12)
        let ema26 = exponentialMovingAverage(prices, period: 26)
        let macdLine = zip(ema12, ema26).map { $0 - $1 }
        let signal = exponentialMovingAverage(macdLine, period: 9)
        return zip(macdLine, signal).map { TechnicalIndicators.MACDValue(macdLine: $0, signalLine: $1, histogram: $0 - $1) }
    }

    private func computeSMA(_ prices: [Double], period: Int) -> [Double] {
        guard prices.count >= period else { return [] }
        var result: [Double] = []
        for i in (period - 1)..<prices.count {
            result.append(prices[(i - period + 1)...i].reduce(0, +) / Double(period))
        }
        return result
    }

    private func computeBollingerBands(_ prices: [Double], period: Int) -> [(upper: Double, middle: Double, lower: Double)] {
        let sma = computeSMA(prices, period: period)
        var result: [(Double, Double, Double)] = []
        for (index, ma) in sma.enumerated() {
            let start = index + period - 1
            let slice = Array(prices[start - period + 1...start])
            let variance = slice.map { pow($0 - ma, 2) }.reduce(0, +) / Double(period)
            let std = sqrt(max(0, variance))
            result.append((ma + 2 * std, ma, ma - 2 * std))
        }
        return result
    }

    private func computeStochastic(_ highs: [Double], _ lows: [Double], _ closes: [Double], period: Int) -> [TechnicalIndicators.StochasticValue] {
        var result: [TechnicalIndicators.StochasticValue] = []
        for i in (period - 1)..<closes.count {
            let h = highs[i - period + 1...i].max() ?? 0
            let l = lows[i - period + 1...i].min() ?? 0
            let range = max(h - l, 0.000001)
            let k = (closes[i] - l) / range * 100
            result.append(TechnicalIndicators.StochasticValue(kValue: k, dValue: k))
        }
        return result
    }

    private func computeATR(_ history: [PriceData], period: Int) -> [Double] {
        guard history.count > period else { return [] }
        let trs = history.enumerated().dropFirst().map { index, candle in
            max(candle.high - candle.low, abs(candle.high - history[index - 1].close), abs(candle.low - history[index - 1].close))
        }
        var result: [Double] = []
        var atr = trs.prefix(period).reduce(0, +) / Double(period)
        result.append(atr)
        for i in period..<trs.count {
            atr = (atr * Double(period - 1) + trs[i]) / Double(period)
            result.append(atr)
        }
        return result
    }
}

// MARK: - Action Block
struct ActionBlock: StrategyBlock {
    let id: UUID
    var blockType: BlockType { .action }
    var name: String
    var isEnabled: Bool
    var position: CGPoint
    var actionType: ActionType
    var parameters: [String: Double]
    var priority: Int
    var cooldown: TimeInterval

    enum ActionType: String, Codable, CaseIterable {
        case buy = "BUY"
        case sell = "SELL"
        case closeLong = "CLOSE_LONG"
        case closeShort = "CLOSE_SHORT"
        case closeAll = "CLOSE_ALL"
        case modifyStopLoss = "MODIFY_SL"
        case modifyTakeProfit = "MODIFY_TP"
        case trailStop = "TRAIL_STOP"
        case partialClose = "PARTIAL_CLOSE"
        case log = "LOG"
    }

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, position: CGPoint = .zero, actionType: ActionType = .buy, parameters: [String: Double] = [:], priority: Int = 0, cooldown: TimeInterval = 0) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.position = position
        self.actionType = actionType
        self.parameters = parameters
        self.priority = priority
        self.cooldown = cooldown
    }

    func execute(context: ExecutionContext) -> [TradeSignal] {
        guard isEnabled else { return [] }
        var signals: [TradeSignal] = []
        let size = parameters["size"] ?? 1.0
        let sl = parameters["stopLoss"] ?? 0
        let tp = parameters["takeProfit"] ?? 0
        let trail = parameters["trailAmount"] ?? 0
        switch actionType {
        case .buy:
            signals.append(TradeSignal(type: .buy, size: size, stopLoss: sl > 0 ? context.currentPrice - sl : nil, takeProfit: tp > 0 ? context.currentPrice + tp : nil, trailAmount: trail, priority: priority))
        case .sell:
            signals.append(TradeSignal(type: .sell, size: size, stopLoss: sl > 0 ? context.currentPrice + sl : nil, takeProfit: tp > 0 ? context.currentPrice - tp : nil, trailAmount: trail, priority: priority))
        case .closeLong:
            signals.append(TradeSignal(type: .sell, size: size, isClose: true, closePosition: .long, priority: priority))
        case .closeShort:
            signals.append(TradeSignal(type: .buy, size: size, isClose: true, closePosition: .short, priority: priority))
        case .closeAll:
            signals.append(TradeSignal(type: .neutral, size: size, isClose: true, closePosition: .all, priority: priority))
        case .modifyStopLoss:
            signals.append(TradeSignal(type: .neutral, size: size, modifyStopLoss: sl > 0 ? sl : nil, priority: priority))
        case .modifyTakeProfit:
            signals.append(TradeSignal(type: .neutral, size: size, modifyTakeProfit: tp > 0 ? tp : nil, priority: priority))
        case .trailStop:
            signals.append(TradeSignal(type: .neutral, size: size, trailAmount: trail, priority: priority))
        case .partialClose:
            signals.append(TradeSignal(type: .neutral, size: size * parameters["fraction"] ?? 0.5, isClose: true, closePosition: .partial, priority: priority))
        case .log:
            signals.append(TradeSignal(type: .neutral, size: 0, logMessage: parameters["message"]?.description ?? "Log", priority: priority))
        }
        return signals
    }
}

// MARK: - Logic Gate Block
struct LogicGateBlock: StrategyBlock {
    let id: UUID
    var blockType: BlockType { .logicGate }
    var name: String
    var isEnabled: Bool
    var position: CGPoint
    var gateType: GateType
    var inputs: [UUID]
    var trueOutputId: UUID?
    var falseOutputId: UUID?
    var inverted: Bool
    var hysteresis: Double

    enum GateType: String, Codable, CaseIterable {
        case and = "AND"
        case or = "OR"
        case xor = "XOR"
        case not = "NOT"
        case nand = "NAND"
        case nor = "NOR"
        case trigger = "TRIGGER"
        case toggle = "TOGGLE"
    }

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, position: CGPoint = .zero, gateType: GateType = .and, inputs: [UUID] = [], trueOutputId: UUID? = nil, falseOutputId: UUID? = nil, inverted: Bool = false, hysteresis: Double = 0) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.position = position
        self.gateType = gateType
        self.inputs = inputs
        self.trueOutputId = trueOutputId
        self.falseOutputId = falseOutputId
        self.inverted = inverted
        self.hysteresis = max(0, hysteresis)
    }

    func evaluate(inputValues: [UUID: Bool]) -> Bool {
        guard isEnabled else { return false }
        let values = inputs.compactMap { inputValues[$0] }
        guard values.count == inputs.count else { return false }
        let raw: Bool
        switch gateType {
        case .and: raw = values.allSatisfy { $0 }
        case .or: raw = values.contains { $0 }
        case .xor: raw = values.filter { $0 }.count % 2 == 1
        case .not: raw = values.first.map { !$0 } ?? false
        case .nand: raw = !values.allSatisfy { $0 }
        case .nor: raw = !values.contains { $0 }
        case .trigger: raw = values.contains { $0 }
        case .toggle: raw = values.contains { $0 }
        }
        return inverted ? !raw : raw
    }
}

// MARK: - Indicator Block
struct IndicatorBlock: StrategyBlock {
    let id: UUID
    var blockType: BlockType { .indicator }
    var name: String
    var isEnabled: Bool
    var position: CGPoint
    var indicatorType: ConditionBlock.TechnicalIndicatorType
    var parameters: [String: Int]
    var outputName: String

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, position: CGPoint = .zero, indicatorType: ConditionBlock.TechnicalIndicatorType = .rsi, parameters: [String: Int] = [:], outputName: String = "value") {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.position = position
        self.indicatorType = indicatorType
        self.parameters = parameters
        self.outputName = outputName
    }

    func compute(history: [PriceData]) -> Double? {
        guard isEnabled, history.count > 2 else { return nil }
        let period = parameters["period"] ?? 14
        let closes = history.map(\.close)
        let highs = history.map(\.high)
        let lows = history.map(\.low)
        switch indicatorType {
        case .rsi:
            let rsi = computeRSI(closes, period: period)
            return rsi.last
        case .macd:
            let macd = computeMACD(closes)
            return macd.last?.macdLine
        case .movingAverage:
            let sma = computeSMA(closes, period: period)
            return sma.last
        case .bollingerBands:
            let bb = computeBollingerBands(closes, period: period)
            return bb.last?.middle
        case .stochastic:
            let stoch = computeStochastic(highs, lows, closes, period: period)
            return stoch.last?.kValue
        case .atr:
            let atr = computeATR(history, period: period)
            return atr.last
        case .volume:
            return Double(history.last?.volume ?? 0)
        case .price:
            return closes.last
        case .custom:
            return closes.last
        }
    }

    private func computeRSI(_ prices: [Double], period: Int) -> [Double] {
        guard prices.count > period else { return [] }
        var deltas = [Double]()
        for i in 1..<prices.count { deltas.append(prices[i] - prices[i - 1]) }
        var gains = deltas.map { max($0, 0) }
        var losses = deltas.map { max(-$0, 0) }
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        var rsi: [Double] = [avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss)]
        for i in period..<deltas.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            rsi.append(avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss))
        }
        return rsi
    }

    private func computeMACD(_ prices: [Double]) -> [TechnicalIndicators.MACDValue] {
        let ema12 = exponentialMovingAverage(prices, period: 12)
        let ema26 = exponentialMovingAverage(prices, period: 26)
        let macdLine = zip(ema12, ema26).map { $0 - $1 }
        let signal = exponentialMovingAverage(macdLine, period: 9)
        return zip(macdLine, signal).map { TechnicalIndicators.MACDValue(macdLine: $0, signalLine: $1, histogram: $0 - $1) }
    }

    private func computeSMA(_ prices: [Double], period: Int) -> [Double] {
        guard prices.count >= period else { return [] }
        var result: [Double] = []
        for i in (period - 1)..<prices.count {
            result.append(prices[(i - period + 1)...i].reduce(0, +) / Double(period))
        }
        return result
    }

    private func computeBollingerBands(_ prices: [Double], period: Int) -> [(upper: Double, middle: Double, lower: Double)] {
        let sma = computeSMA(prices, period: period)
        var result: [(Double, Double, Double)] = []
        for (index, ma) in sma.enumerated() {
            let start = index + period - 1
            let slice = Array(prices[start - period + 1...start])
            let variance = slice.map { pow($0 - ma, 2) }.reduce(0, +) / Double(period)
            let std = sqrt(max(0, variance))
            result.append((ma + 2 * std, ma, ma - 2 * std))
        }
        return result
    }

    private func computeStochastic(_ highs: [Double], _ lows: [Double], _ closes: [Double], period: Int) -> [TechnicalIndicators.StochasticValue] {
        var result: [TechnicalIndicators.StochasticValue] = []
        for i in (period - 1)..<closes.count {
            let h = highs[i - period + 1...i].max() ?? 0
            let l = lows[i - period + 1...i].min() ?? 0
            let range = max(h - l, 0.000001)
            let k = (closes[i] - l) / range * 100
            result.append(TechnicalIndicators.StochasticValue(kValue: k, dValue: k))
        }
        return result
    }

    private func computeATR(_ history: [PriceData], period: Int) -> [Double] {
        guard history.count > period else { return [] }
        let trs = history.enumerated().dropFirst().map { index, candle in
            max(candle.high - candle.low, abs(candle.high - history[index - 1].close), abs(candle.low - history[index - 1].close))
        }
        var result: [Double] = []
        var atr = trs.prefix(period).reduce(0, +) / Double(period)
        result.append(atr)
        for i in period..<trs.count {
            atr = (atr * Double(period - 1) + trs[i]) / Double(period)
            result.append(atr)
        }
        return result
    }
}

// MARK: - Filter Block
struct FilterBlock: StrategyBlock {
    let id: UUID
    var blockType: BlockType { .filter }
    var name: String
    var isEnabled: Bool
    var position: CGPoint
    var filterType: FilterType
    var parameters: [String: Double]
    var inputId: UUID

    enum FilterType: String, Codable, CaseIterable {
        case threshold = "THRESHOLD"
        case range = "RANGE"
        case deadband = "DEADBAND"
        case hysteresis = "HYSTERESIS"
        case rateOfChange = "ROC"
        case minimumPersistence = "PERSISTENCE"
        case smoothing = "SMOOTHING"
        case minimumVolume = "VOLUME"
    }

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, position: CGPoint = .zero, filterType: FilterType = .threshold, parameters: [String: Double] = [:], inputId: UUID) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.position = position
        self.filterType = filterType
        self.parameters = parameters
        self.inputId = inputId
    }

    func evaluate(inputValue: Double, history: [Double]) -> Bool {
        guard isEnabled else { return false }
        switch filterType {
        case .threshold:
            let threshold = parameters["threshold"] ?? 0
            return inputValue >= threshold
        case .range:
            let min = parameters["min"] ?? -1e9
            let max = parameters["max"] ?? 1e9
            return inputValue >= min && inputValue <= max
        case .deadband:
            let width = parameters["width"] ?? 0.1
            return abs(inputValue) > width / 2
        case .hysteresis:
            let high = parameters["high"] ?? 0.5
            let low = parameters["low"] ?? -0.5
            let last = history.last ?? 0
            if last >= low && last <= high { return abs(inputValue) > high / 2 }
            return inputValue > high || inputValue < low
        case .rateOfChange:
            let minROC = parameters["minRate"] ?? -1e9
            let maxROC = parameters["maxRate"] ?? 1e9
            guard history.count >= 2 else { return false }
            let roc = (inputValue - history[history.count - 2]) / max(abs(history[history.count - 2]), 0.0001)
            return roc >= minROC && roc <= maxROC
        case .minimumPersistence:
            let bars = Int(parameters["bars"] ?? 2)
            guard history.count >= bars else { return false }
            let slice = Array(history.suffix(bars))
            let allAbove = slice.allSatisfy { $0 > 0 }
            let allBelow = slice.allSatisfy { $0 < 0 }
            return allAbove || allBelow
        case .smoothing:
            let window = Int(parameters["window"] ?? 3)
            guard history.count >= window else { return true }
            let slice = Array(history.suffix(window))
            let avg = slice.reduce(0, +) / Double(slice.count)
            return abs(inputValue - avg) < (parameters["maxDeviation"] ?? 0.5)
        case .minimumVolume:
            let minVol = parameters["minVolume"] ?? 0
            return inputValue >= minVol
        }
    }
}

// MARK: - Output Block
struct OutputBlock: StrategyBlock {
    let id: UUID
    var blockType: BlockType { .output }
    var name: String
    var isEnabled: Bool
    var position: CGPoint
    var outputType: OutputType
    var inputId: UUID
    var parameters: [String: Double]

    enum OutputType: String, Codable, CaseIterable {
        case signal = "SIGNAL"
        case alert = "ALERT"
        case metric = "METRIC"
        case chartOverlay = "CHART"
        case log = "LOG"
        case webhook = "WEBHOOK"
    }

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, position: CGPoint = .zero, outputType: OutputType = .signal, inputId: UUID, parameters: [String: Double] = [:]) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.position = position
        self.outputType = outputType
        self.inputId = inputId
        self.parameters = parameters
    }

    func produce(inputValue: Bool, context: ExecutionContext) -> StrategyOutput {
        guard isEnabled else { return StrategyOutput(type: outputType, value: false, message: "Disabled", timestamp: Date()) }
        let threshold = parameters["threshold"] ?? 0.5
        let message: String
        switch outputType {
        case .signal:
            message = inputValue ? "Signal triggered at \(context.currentPrice)" : "No signal"
        case .alert:
            message = inputValue ? "ALERT: \(name) condition met at \(context.currentPrice)" : ""
        case .metric:
            message = "Metric: \(inputValue ? "TRUE" : "FALSE")"
        case .chartOverlay:
            message = inputValue ? "MARKER" : ""
        case .log:
            message = inputValue ? "[LOG] \(name): TRUE" : "[LOG] \(name): FALSE"
        case .webhook:
            message = inputValue ? "{\"event\": \"\(name)\", \"price\": \(context.currentPrice)}" : ""
        }
        return StrategyOutput(type: outputType, value: inputValue, message: message, timestamp: Date())
    }
}

// MARK: - Supporting Types
struct TradeSignal: Codable, Identifiable {
    let id: UUID
    let type: SignalType
    let size: Double
    let stopLoss: Double?
    let takeProfit: Double?
    let trailAmount: Double
    let isClose: Bool
    let closePosition: ClosePosition
    let modifyStopLoss: Double?
    let modifyTakeProfit: Double?
    let logMessage: String?
    let priority: Int
    let timestamp: Date

    init(id: UUID = UUID(), type: SignalType, size: Double = 1.0, stopLoss: Double? = nil, takeProfit: Double? = nil, trailAmount: Double = 0, isClose: Bool = false, closePosition: ClosePosition = .all, modifyStopLoss: Double? = nil, modifyTakeProfit: Double? = nil, logMessage: String? = nil, priority: Int = 0, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.size = max(0, size)
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.trailAmount = max(0, trailAmount)
        self.isClose = isClose
        self.closePosition = closePosition
        self.modifyStopLoss = modifyStopLoss
        self.modifyTakeProfit = modifyTakeProfit
        self.logMessage = logMessage
        self.priority = priority
        self.timestamp = timestamp
    }
}

enum ClosePosition: String, Codable {
    case long, short, all, partial
}

struct StrategyOutput: Codable, Identifiable {
    let id: UUID
    let type: OutputBlock.OutputType
    let value: Bool
    let message: String
    let timestamp: Date

    init(id: UUID = UUID(), type: OutputBlock.OutputType, value: Bool, message: String, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.value = value
        self.message = message
        self.timestamp = timestamp
    }
}

struct ExecutionContext: Codable {
    let currentPrice: Double
    let timestamp: Date
    let pair: String
    let accountBalance: Double
    let openPositions: [Position]
    let marketState: MarketState

    enum MarketState: String, Codable {
        case trending, ranging, volatile, quiet, illiquid
    }
}

struct Position: Codable, Identifiable {
    let id: UUID
    let pair: String
    let type: SignalType
    let entryPrice: Double
    let size: Double
    let openTime: Date
    var stopLoss: Double?
    var takeProfit: Double?
}

// MARK: - Connection
struct BlockConnection: Codable, Identifiable, Hashable {
    let id: UUID
    var fromBlockId: UUID
    var fromOutput: String
    var toBlockId: UUID
    var toInput: String
    var enabled: Bool

    init(id: UUID = UUID(), fromBlockId: UUID, fromOutput: String = "output", toBlockId: UUID, toInput: String = "input", enabled: Bool = true) {
        self.id = id
        self.fromBlockId = fromBlockId
        self.fromOutput = fromOutput
        self.toBlockId = toBlockId
        self.toInput = toInput
        self.enabled = enabled
    }
}

// MARK: - Strategy Definition
struct StrategyDefinition: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var blocks: [StrategyBlock]
    var connections: [BlockConnection]
    var entryConditions: [UUID]
    var exitConditions: [UUID]
    var riskParameters: RiskParameters
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    struct RiskParameters: Codable {
        var maxPositionSize: Double
        var maxDrawdownPercent: Double
        var dailyLossLimit: Double
        var trailingStopEnabled: Bool
        var breakevenEnabled: Bool
        var positionSizing: PositionSizing

        enum PositionSizing: String, Codable {
            case fixed, percentage, kelly, volatilityAdjusted
        }

        static let `default` = RiskParameters(maxPositionSize: 1.0, maxDrawdownPercent: 20, dailyLossLimit: 5, trailingStopEnabled: true, breakevenEnabled: true, positionSizing: .percentage)
    }

    init(id: UUID = UUID(), name: String, description: String = "", blocks: [StrategyBlock] = [], connections: [BlockConnection] = [], entryConditions: [UUID] = [], exitConditions: [UUID] = [], riskParameters: RiskParameters = .default, tags: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.blocks = blocks
        self.connections = connections
        self.entryConditions = entryConditions
        self.exitConditions = exitConditions
        self.riskParameters = riskParameters
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Execution Result
struct StrategyExecutionResult: Codable, Identifiable {
    let id: UUID
    let strategyId: UUID
    let signals: [TradeSignal]
    let outputs: [StrategyOutput]
    let evaluatedAt: Date
    let executionTimeMs: Double
    let success: Bool
    let error: String?

    init(id: UUID = UUID(), strategyId: UUID, signals: [TradeSignal] = [], outputs: [StrategyOutput] = [], evaluatedAt: Date = Date(), executionTimeMs: Double = 0, success: Bool = true, error: String? = nil) {
        self.id = id
        self.strategyId = strategyId
        self.signals = signals
        self.outputs = outputs
        self.evaluatedAt = evaluatedAt
        self.executionTimeMs = executionTimeMs
        self.success = success
        self.error = error
    }
}

// MARK: - Strategy Builder Engine
@MainActor
final class StrategyBuilderEngine: ObservableObject {
    static let shared = StrategyBuilderEngine()
    @Published private(set) var strategies: [StrategyDefinition] = []
    @Published private(set) var executionHistory: [StrategyExecutionResult] = []
    @Published private(set) var isExecuting = false

    private let maxHistory = 200

    func createStrategy(name: String, description: String = "") -> StrategyDefinition {
        let strategy = StrategyDefinition(name: name, description: description)
        strategies.append(strategy)
        return strategy
    }

    func addBlock(to strategyId: UUID, block: StrategyBlock) {
        guard let index = strategies.firstIndex(where: { $0.id == strategyId }) else { return }
        var strategy = strategies[index]
        strategy.blocks.append(block)
        strategy.updatedAt = Date()
        strategies[index] = strategy
    }

    func removeBlock(from strategyId: UUID, blockId: UUID) {
        guard let index = strategies.firstIndex(where: { $0.id == strategyId }) else { return }
        var strategy = strategies[index]
        strategy.blocks.removeAll { $0.id == blockId }
        strategy.connections.removeAll { $0.fromBlockId == blockId || $0.toBlockId == blockId }
        strategy.updatedAt = Date()
        strategies[index] = strategy
    }

    func connect(from: UUID, to: UUID, strategyId: UUID) {
        guard let index = strategies.firstIndex(where: { $0.id == strategyId }) else { return }
        let connection = BlockConnection(fromBlockId: from, toBlockId: to)
        var strategy = strategies[index]
        if !strategy.connections.contains(where: { $0.fromBlockId == from && $0.toBlockId == to }) {
            strategy.connections.append(connection)
            strategy.updatedAt = Date()
            strategies[index] = strategy
        }
    }

    func execute(strategyId: UUID, context: ExecutionContext) -> StrategyExecutionResult {
        let startTime = Date()
        guard let strategy = strategies.first(where: { $0.id == strategyId }) else {
            return StrategyExecutionResult(strategyId: strategyId, success: false, error: "Strategy not found")
        }
        guard !strategy.blocks.isEmpty else {
            return StrategyExecutionResult(strategyId: strategyId, success: false, error: "No blocks to execute")
        }
        isExecuting = true
        defer { isExecuting = false }
        let blockMap = Dictionary(uniqueKeysWithValues: strategy.blocks.map { ($0.id, $0) })
        var conditionResults: [UUID: Bool] = [:]
        var indicatorValues: [UUID: Double] = [:]
        var signals: [TradeSignal] = []
        var outputs: [StrategyOutput] = []
        let sortedBlocks = topologicalSort(blocks: strategy.blocks, connections: strategy.connections)
        for block in sortedBlocks {
            guard block.isEnabled else { continue }
            switch block {
            case let cond as ConditionBlock:
                let result = cond.evaluate(history: [])
                conditionResults[cond.id] = result
            case let ind as IndicatorBlock:
                let value = ind.compute(history: [])
                if let v = value { indicatorValues[ind.id] = v }
            case let gate as LogicGateBlock:
                let result = gate.evaluate(inputValues: conditionResults)
                conditionResults[gate.id] = result
            case let filter as FilterBlock:
                let inputValue = indicatorValues[filter.inputId] ?? 0
                let history = indicatorValues.values.suffix(10).map { $0 }
                let result = filter.evaluate(inputValue: inputValue, history: history)
                conditionResults[filter.id] = result
            case let action as ActionBlock:
                let tradeSignals = action.execute(context: context)
                signals.append(contentsOf: tradeSignals)
            case let output as OutputBlock:
                let inputValue = conditionResults[output.inputId] ?? false
                let strategyOutput = output.produce(inputValue: inputValue, context: context)
                outputs.append(strategyOutput)
            default: break
            }
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let result = StrategyExecutionResult(strategyId: strategyId, signals: signals, outputs: outputs, evaluatedAt: Date(), executionTimeMs: executionTime, success: true)
        if executionHistory.count >= maxHistory { executionHistory.removeFirst() }
        executionHistory.append(result)
        return result
    }

    private func topologicalSort(blocks: [StrategyBlock], connections: [BlockConnection]) -> [StrategyBlock] {
        var graph: [UUID: [UUID]] = [:]
        var inDegree: [UUID: Int] = [:]
        for block in blocks {
            graph[block.id] = []
            inDegree[block.id] = 0
        }
        for conn in connections where conn.enabled {
            graph[conn.fromBlockId]?.append(conn.toBlockId)
            inDegree[conn.toBlockId] = (inDegree[conn.toBlockId] ?? 0) + 1
        }
        var queue = blocks.filter { (inDegree[$0.id] ?? 0) == 0 }.sorted { $0.position.y < $1.position.y }
        var sorted: [StrategyBlock] = []
        while !queue.isEmpty {
            let current = queue.removeFirst()
            sorted.append(current)
            for neighbor in graph[current.id] ?? [] {
                inDegree[neighbor] = max(0, (inDegree[neighbor] ?? 1) - 1)
                if inDegree[neighbor] == 0 { queue.append(blocks.first { $0.id == neighbor } ?? current) }
            }
        }
        let remaining = blocks.filter { !sorted.contains(where: { $0.id == $0.id }) }.sorted { $0.position.y < $1.position.y }
        return sorted + remaining
    }

    func validateStrategy(_ strategy: StrategyDefinition) -> [ValidationError] {
        var errors: [ValidationError] = []
        let hasEntry = strategy.blocks.contains { block in
            if let cond = block as? ConditionBlock { return strategy.entryConditions.contains(cond.id) }
            if let gate = block as? LogicGateBlock { return strategy.entryConditions.contains(gate.id) }
            return false
        }
        if !hasEntry { errors.append(ValidationError(field: "entry", message: "No entry conditions defined", severity: .warning)) }
        let hasAction = strategy.blocks.contains { $0 is ActionBlock }
        if !hasAction { errors.append(ValidationError(field: "actions", message: "No action blocks defined", severity: .error)) }
        let cycles = detectCycles(blocks: strategy.blocks, connections: strategy.connections)
        if !cycles.isEmpty { errors.append(ValidationError(field: "connections", message: "Cyclic dependencies detected", severity: .error)) }
        return errors
    }

    private func detectCycles(blocks: [StrategyBlock], connections: [BlockConnection]) -> [[UUID]] {
        var graph: [UUID: [UUID]] = [:]
        for block in blocks { graph[block.id] = [] }
        for conn in connections where conn.enabled { graph[conn.fromBlockId]?.append(conn.toBlockId) }
        var visited: [UUID: Bool] = [:]
        var path: [UUID] = []
        var cycles: [[UUID]] = []
        func dfs(_ node: UUID) {
            if visited[node] == true {
                if let cycleStart = path.firstIndex(where: { $0 == node }) {
                    cycles.append(Array(path[cycleStart...]))
                }
                return
            }
            visited[node] = true
            path.append(node)
            for neighbor in graph[node] ?? [] { dfs(neighbor) }
            path.removeLast()
        }
        for block in blocks { if visited[block.id] == nil { dfs(block.id) } }
        return cycles
    }
}

struct ValidationError: Codable, Identifiable {
    let id = UUID()
    let field: String
    let message: String
    let severity: Severity

    enum Severity: String, Codable { case info = "INFO", warning = "WARNING", error = "ERROR" }
}

// MARK: - Math Helpers
private func exponentialMovingAverage(_ prices: [Double], period: Int) -> [Double] {
    guard prices.count >= period, period > 0 else { return [] }
    let k = 2.0 / Double(period + 1)
    var ema = prices.prefix(period).reduce(0, +) / Double(period)
    var result: [Double] = [ema]
    for i in period..<prices.count {
        ema = prices[i] * k + ema * (1 - k)
        result.append(ema)
    }
    return result
}

enum TimeFrame: String, Codable, CaseIterable {
    case oneMinute = "1m"
    case fiveMinute = "5m"
    case fifteenMinute = "15m"
    case oneHour = "1h"
    case fourHour = "4h"
    case oneDay = "1d"
    case oneWeek = "1w"
}
