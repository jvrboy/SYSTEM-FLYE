import Foundation

// MARK: - FOREX Pair Models
struct ForexPair: Identifiable, Codable {
    let id: String
    let symbol: String
    let name: String
    let baseCurrency: String
    let quoteCurrency: String
    
    init(symbol: String, name: String, baseCurrency: String, quoteCurrency: String) {
        self.id = symbol
        self.symbol = symbol
        self.name = name
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
    }
}

// MARK: - Price Data
struct PriceData: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
    
    var midPrice: Double {
        (high + low) / 2
    }
}

// MARK: - Technical Indicators
struct TechnicalIndicators: Codable {
    let rsi: Double // Relative Strength Index (0-100)
    let macd: MACDValue // Moving Average Convergence Divergence
    let bollingerBands: BollingerBands
    let movingAverages: MovingAverages
    let atr: Double // Average True Range
    let stochastic: StochasticValue
    
    struct MACDValue: Codable {
        let macdLine: Double
        let signalLine: Double
        let histogram: Double
    }
    
    struct BollingerBands: Codable {
        let upper: Double
        let middle: Double
        let lower: Double
        let bandwidth: Double
    }
    
    struct MovingAverages: Codable {
        let ma20: Double
        let ma50: Double
        let ma100: Double
        let ma200: Double
    }
    
    struct StochasticValue: Codable {
        let kValue: Double // 0-100
        let dValue: Double // 0-100
    }
}

// MARK: - Trading Signal
enum SignalStrength: String, Codable {
    case strong = "Strong"
    case moderate = "Moderate"
    case weak = "Weak"
}

enum SignalType: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case neutral = "NEUTRAL"
}

struct TradingSignal: Identifiable, Codable {
    let id: UUID
    let pairSymbol: String
    let signalType: SignalType
    let strength: SignalStrength
    let entryPrice: Double
    let stopLoss: Double
    let takeProfit: Double
    let riskRewardRatio: Double
    let confidence: Double // 0-100
    let timestamp: Date
    let indicators: [String] // Which indicators triggered this signal
    let reason: String
    
    init(pairSymbol: String, signalType: SignalType, strength: SignalStrength,
         entryPrice: Double, stopLoss: Double, takeProfit: Double,
         confidence: Double, indicators: [String], reason: String) {
        self.id = UUID()
        self.pairSymbol = pairSymbol
        self.signalType = signalType
        self.strength = strength
        self.entryPrice = entryPrice
        self.stopLoss = stopLoss
        self.takeProfit = takeProfit
        self.riskRewardRatio = abs((takeProfit - entryPrice) / (entryPrice - stopLoss))
        self.confidence = confidence
        self.timestamp = Date()
        self.indicators = indicators
        self.reason = reason
    }
}

// MARK: - Trade Record
struct Trade: Identifiable, Codable {
    let id: UUID
    let pairSymbol: String
    let type: SignalType
    let entryPrice: Double
    let exitPrice: Double?
    let quantity: Double
    let entryDate: Date
    let exitDate: Date?
    let profitLoss: Double?
    var status: TradeStatus
    
    var pnlPercentage: Double? {
        guard let exitPrice = exitPrice else { return nil }
        return ((exitPrice - entryPrice) / entryPrice) * 100
    }
    
    enum TradeStatus: String, Codable {
        case open = "Open"
        case closed = "Closed"
        case pending = "Pending"
    }
}

// MARK: - Market Condition
enum MarketCondition: String, Codable {
    case strongUptrend = "Strong Uptrend"
    case uptrend = "Uptrend"
    case neutral = "Neutral"
    case downtrend = "Downtrend"
    case strongDowntrend = "Strong Downtrend"
}

struct MarketAnalysis: Codable {
    let condition: MarketCondition
    let volatility: Double
    let trend: Double // -1 to 1
    let momentum: Double
    let supportLevel: Double
    let resistanceLevel: Double
}

// MARK: - Portfolio
struct Portfolio: Codable {
    var totalBalance: Double
    var usedMargin: Double
    var availableMargin: Double
    var totalProfit: Double
    var totalLoss: Double
    var winRate: Double
    
    var profitLossPercentage: Double {
        let totalPL = totalProfit - totalLoss
        guard totalBalance > 0 else { return 0 }
        return (totalPL / totalBalance) * 100
    }
    
    var marginUsagePercentage: Double {
        guard (usedMargin + availableMargin) > 0 else { return 0 }
        return (usedMargin / (usedMargin + availableMargin)) * 100
    }
}

// MARK: - Historical Data Request
struct HistoricalDataRequest {
    let pairSymbol: String
    let timeframe: Timeframe
    let limit: Int
    
    enum Timeframe: String {
        case oneMinute = "1m"
        case fiveMinute = "5m"
        case fifteenMinute = "15m"
        case oneHour = "1h"
        case fourHour = "4h"
        case oneDay = "1d"
        case oneWeek = "1w"
        case oneMonth = "1M"
    }
}
