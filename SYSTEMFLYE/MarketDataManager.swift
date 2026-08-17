import Foundation
import Combine

@MainActor
class MarketDataManager: ObservableObject {
    @Published var currentPrices: [String: Double] = [:]
    @Published var priceHistory: [String: [PriceData]] = [:]
    @Published var technicalIndicators: [String: TechnicalIndicators] = [:]
    @Published var advancedTechnicalIndicators: [String: AdvancedTechnicalIndicators] = [:]
    @Published var marketAnalysis: [String: MarketAnalysis] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedPairs: [String] = ["EURUSD", "GBPUSD", "USDJPY"]
    @Published private(set) var dataSource = "offline sample"
    
    private var cancellables = Set<AnyCancellable>()
    private let apiClient = APIClientManager.shared
    private let updateTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    // MARK: - Popular Forex Pairs
    let popularPairs: [ForexPair] = [
        ForexPair(symbol: "EURUSD", name: "EUR/USD", baseCurrency: "EUR", quoteCurrency: "USD"),
        ForexPair(symbol: "GBPUSD", name: "GBP/USD", baseCurrency: "GBP", quoteCurrency: "USD"),
        ForexPair(symbol: "USDJPY", name: "USD/JPY", baseCurrency: "USD", quoteCurrency: "JPY"),
        ForexPair(symbol: "USDCHF", name: "USD/CHF", baseCurrency: "USD", quoteCurrency: "CHF"),
        ForexPair(symbol: "AUDUSD", name: "AUD/USD", baseCurrency: "AUD", quoteCurrency: "USD"),
        ForexPair(symbol: "NZDUSD", name: "NZD/USD", baseCurrency: "NZD", quoteCurrency: "USD"),
        ForexPair(symbol: "USDCAD", name: "USD/CAD", baseCurrency: "USD", quoteCurrency: "CAD"),
        ForexPair(symbol: "EURGBP", name: "EUR/GBP", baseCurrency: "EUR", quoteCurrency: "GBP"),
        ForexPair(symbol: "EURJPY", name: "EUR/JPY", baseCurrency: "EUR", quoteCurrency: "JPY"),
        ForexPair(symbol: "GBPJPY", name: "GBP/JPY", baseCurrency: "GBP", quoteCurrency: "JPY"),
    ]
    
    init() {
        setupPriceUpdates()
        loadMockData()
    }
    
    // MARK: - Setup
    private func setupPriceUpdates() {
        updateTimer
            .sink { [weak self] _ in
                self?.updatePrices()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Updates
    func updatePrices() {
        if apiClient.provider != nil {
            Task { await refreshLivePrices() }
            return
        }
        dataSource = "offline sample"
        for pair in selectedPairs {
            if let currentPrice = currentPrices[pair] {
                let change = Double.random(in: -0.005...0.005)
                let newPrice = currentPrice * (1 + change)
                currentPrices[pair] = newPrice
                
                // Update price history
                let newPriceData = PriceData(
                    id: "\(pair)-\(Date().timeIntervalSince1970)",
                    timestamp: Date(),
                    open: currentPrice,
                    high: max(currentPrice, newPrice),
                    low: min(currentPrice, newPrice),
                    close: newPrice,
                    volume: Int.random(in: 100000...1000000)
                )
                
                if priceHistory[pair] != nil {
                    priceHistory[pair]?.append(newPriceData)
                    // Keep last 1000 candles
                    if priceHistory[pair]?.count ?? 0 > 1000 {
                        priceHistory[pair]?.removeFirst()
                    }
                } else {
                    priceHistory[pair] = [newPriceData]
                }
                
                // Calculate technical indicators
                if let history = priceHistory[pair], history.count > 20 {
                    technicalIndicators[pair] = calculateIndicators(for: history)
                    advancedTechnicalIndicators[pair] = AdvancedTechnicalAnalyzer.calculate(history: history)
                    marketAnalysis[pair] = analyzeMarket(history: history, indicators: technicalIndicators[pair]!)
                }
            }
        }
    }
    
    func refreshLivePrices() async {
        guard let provider = apiClient.provider else { return }
        do {
            let prices = try await provider.fetchPrices(for: selectedPairs)
            dataSource = "live provider"
            for pair in selectedPairs {
                guard let newPrice = prices[pair], newPrice > 0 else { continue }
                let previous = currentPrices[pair] ?? newPrice
                currentPrices[pair] = newPrice
                let candle = PriceData(id: "\(pair)-\(Date().timeIntervalSince1970)", timestamp: Date(), open: previous, high: max(previous, newPrice), low: min(previous, newPrice), close: newPrice, volume: priceHistory[pair]?.last?.volume ?? 0)
                priceHistory[pair, default: []].append(candle)
                if priceHistory[pair, default: []].count > 1000 { priceHistory[pair]?.removeFirst() }
                recalculate(pair: pair)
            }
            error = nil
        } catch {
            dataSource = "provider error"
            self.error = "Live price refresh failed: \(error.localizedDescription)"
        }
    }

    private func recalculate(pair: String) {
        guard let history = priceHistory[pair], history.count > 20 else { return }
        let basic = calculateIndicators(for: history)
        technicalIndicators[pair] = basic
        advancedTechnicalIndicators[pair] = AdvancedTechnicalAnalyzer.calculate(history: history)
        marketAnalysis[pair] = analyzeMarket(history: history, indicators: basic)
    }

    func fetchHistoricalData(for pair: String, timeframe: HistoricalDataRequest.Timeframe) async {
        isLoading = true
        defer { isLoading = false }
        
        // In production, this would call a real API like:
        // - OANDA API
        // - Twelve Data API
        // - Forex Factory API
        
        do {
            if let provider = apiClient.provider {
                let history = try await provider.fetchHistoricalData(pair: pair, timeframe: timeframe.rawValue, limit: 500)
                guard !history.isEmpty else { throw APIError.invalidResponse }
                dataSource = "live provider"
                priceHistory[pair] = history
                currentPrices[pair] = history.last?.close
                recalculate(pair: pair)
                error = nil
                return
            }
            dataSource = "offline sample"
            try await Task.sleep(nanoseconds: 150_000_000)
            
            var history: [PriceData] = []
            var currentPrice = currentPrices[pair] ?? 1.0
            
            for i in (0..<100).reversed() {
                let timestamp = Date(timeIntervalSinceNow: TimeInterval(-i * 3600))
                let open = currentPrice
                let close = currentPrice * (1 + Double.random(in: -0.005...0.005))
                let high = max(open, close) * (1 + Double.random(in: 0...0.002))
                let low = min(open, close) * (1 - Double.random(in: 0...0.002))
                
                history.append(PriceData(
                    id: "\(pair)-\(i)",
                    timestamp: timestamp,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: Int.random(in: 100000...1000000)
                ))
                
                currentPrice = close
            }
            
            priceHistory[pair] = history
            recalculate(pair: pair)
        } catch {
            self.error = "Failed to fetch historical data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Technical Analysis
    func calculateIndicators(for history: [PriceData]) -> TechnicalIndicators {
        let rsi = calculateRSI(history: history)
        let macd = calculateMACD(history: history)
        let bb = calculateBollingerBands(history: history)
        let ma = calculateMovingAverages(history: history)
        let atr = calculateATR(history: history)
        let stochastic = calculateStochastic(history: history)
        
        return TechnicalIndicators(
            rsi: rsi,
            macd: macd,
            bollingerBands: bb,
            movingAverages: ma,
            atr: atr,
            stochastic: stochastic
        )
    }
    
    private func calculateRSI(history: [PriceData], period: Int = 14) -> Double {
        guard history.count > period else { return 50 }
        
        let closes = history.map { $0.close }
        var gains = 0.0
        var losses = 0.0
        
        for i in 1..<min(period + 1, closes.count) {
            let change = closes[i] - closes[i - 1]
            if change > 0 {
                gains += change
            } else {
                losses -= change
            }
        }
        
        let avgGain = gains / Double(period)
        let avgLoss = losses / Double(period)
        
        guard avgLoss != 0 else { return 50 }
        
        let rs = avgGain / avgLoss
        let rsi = 100 - (100 / (1 + rs))
        
        return min(100, max(0, rsi))
    }
    
    private func calculateMACD(history: [PriceData]) -> TechnicalIndicators.MACDValue {
        let closes = history.map { $0.close }
        let ema12 = calculateEMA(closes: closes, period: 12)
        let ema26 = calculateEMA(closes: closes, period: 26)
        let macdLine = ema12 - ema26
        
        var macdValues: [Double] = []
        for i in 0..<closes.count {
            let ema12Current = calculateEMA(closes: Array(closes.prefix(i + 1)), period: 12)
            let ema26Current = calculateEMA(closes: Array(closes.prefix(i + 1)), period: 26)
            macdValues.append(ema12Current - ema26Current)
        }
        
        let signalLine = calculateEMA(closes: macdValues, period: 9)
        let histogram = macdLine - signalLine
        
        return TechnicalIndicators.MACDValue(
            macdLine: macdLine,
            signalLine: signalLine,
            histogram: histogram
        )
    }
    
    private func calculateBollingerBands(history: [PriceData], period: Int = 20, stdDev: Double = 2) -> TechnicalIndicators.BollingerBands {
        let closes = history.suffix(period).map { $0.close }
        guard closes.count >= period else {
            return TechnicalIndicators.BollingerBands(upper: 0, middle: 0, lower: 0, bandwidth: 0)
        }
        
        let sma = closes.reduce(0, +) / Double(closes.count)
        let variance = closes.map { pow($0 - sma, 2) }.reduce(0, +) / Double(closes.count)
        let stdDeviation = sqrt(variance)
        
        let upper = sma + (stdDev * stdDeviation)
        let lower = sma - (stdDev * stdDeviation)
        let bandwidth = ((upper - lower) / sma) * 100
        
        return TechnicalIndicators.BollingerBands(
            upper: upper,
            middle: sma,
            lower: lower,
            bandwidth: bandwidth
        )
    }
    
    private func calculateMovingAverages(history: [PriceData]) -> TechnicalIndicators.MovingAverages {
        let closes = history.map { $0.close }
        
        return TechnicalIndicators.MovingAverages(
            ma20: calculateSMA(closes: closes, period: 20),
            ma50: calculateSMA(closes: closes, period: 50),
            ma100: calculateSMA(closes: closes, period: 100),
            ma200: calculateSMA(closes: closes, period: 200)
        )
    }
    
    private func calculateATR(history: [PriceData], period: Int = 14) -> Double {
        guard history.count > 1 else { return 0 }
        
        var trueRanges: [Double] = []
        for i in 1..<history.count {
            let current = history[i]
            let previous = history[i - 1]
            
            let tr1 = current.high - current.low
            let tr2 = abs(current.high - previous.close)
            let tr3 = abs(current.low - previous.close)
            
            trueRanges.append(max(tr1, tr2, tr3))
        }
        
        let atr = trueRanges.suffix(period).reduce(0, +) / Double(period)
        return atr
    }
    
    private func calculateStochastic(history: [PriceData], period: Int = 14) -> TechnicalIndicators.StochasticValue {
        guard history.count >= period else {
            return TechnicalIndicators.StochasticValue(kValue: 50, dValue: 50)
        }
        
        let recent = history.suffix(period)
        let high = recent.map { $0.high }.max() ?? 0
        let low = recent.map { $0.low }.min() ?? 0
        let close = recent.last?.close ?? 0
        
        let range = high - low
        guard range > 0 else {
            return TechnicalIndicators.StochasticValue(kValue: 50, dValue: 50)
        }
        
        let kValue = ((close - low) / range) * 100
        let dValue = kValue * 0.7 + 50 * 0.3 // Simplified D calculation
        
        return TechnicalIndicators.StochasticValue(kValue: kValue, dValue: dValue)
    }
    
    private func calculateSMA(closes: [Double], period: Int) -> Double {
        guard closes.count >= period else { return closes.last ?? 0 }
        return closes.suffix(period).reduce(0, +) / Double(period)
    }
    
    private func calculateEMA(closes: [Double], period: Int) -> Double {
        guard closes.count > 0 else { return 0 }
        guard closes.count >= period else {
            return closes.reduce(0, +) / Double(closes.count)
        }
        
        let sma = closes.suffix(period).reduce(0, +) / Double(period)
        let multiplier = 2.0 / Double(period + 1)
        
        var ema = sma
        for i in period..<closes.count {
            ema = closes[i] * multiplier + ema * (1 - multiplier)
        }
        
        return ema
    }
    
    private func analyzeMarket(history: [PriceData], indicators: TechnicalIndicators) -> MarketAnalysis {
        let closes = history.map { $0.close }
        let recentClose = closes.last ?? 0
        let prevClose = closes.count > 1 ? closes[closes.count - 2] : recentClose
        
        // Calculate trend
        let ma20 = indicators.movingAverages.ma20
        let ma50 = indicators.movingAverages.ma50
        var trend = 0.0
        
        if recentClose > ma20 && ma20 > ma50 {
            trend = 1.0 // Strong uptrend
        } else if recentClose > ma20 {
            trend = 0.5 // Uptrend
        } else if recentClose < ma20 && ma20 < ma50 {
            trend = -1.0 // Strong downtrend
        } else if recentClose < ma20 {
            trend = -0.5 // Downtrend
        }
        
        // Determine market condition
        let condition: MarketCondition
        if trend >= 0.8 {
            condition = .strongUptrend
        } else if trend > 0 {
            condition = .uptrend
        } else if trend <= -0.8 {
            condition = .strongDowntrend
        } else if trend < 0 {
            condition = .downtrend
        } else {
            condition = .neutral
        }
        
        // Calculate volatility
        let variance = history.suffix(20).map { pow($0.close - (history.map { $0.close }.reduce(0, +) / Double(history.count)), 2) }
            .reduce(0, +) / Double(min(20, history.count))
        let volatility = sqrt(variance) / recentClose * 100
        
        // Support and Resistance
        let recentPrices = history.suffix(50).map { $0.close }
        let supportLevel = recentPrices.min() ?? recentClose
        let resistanceLevel = recentPrices.max() ?? recentClose
        
        return MarketAnalysis(
            condition: condition,
            volatility: volatility,
            trend: trend,
            momentum: Double(recentClose - prevClose) / prevClose * 100,
            supportLevel: supportLevel,
            resistanceLevel: resistanceLevel
        )
    }
    
    // MARK: - Mock Data
    private func loadMockData() {
        for pair in selectedPairs {
            currentPrices[pair] = Double.random(in: 0.7...2.0)
            
            var history: [PriceData] = []
            var currentPrice = currentPrices[pair]!
            
            for i in (0..<100).reversed() {
                let timestamp = Date(timeIntervalSinceNow: TimeInterval(-i * 3600))
                let open = currentPrice
                let close = currentPrice * (1 + Double.random(in: -0.005...0.005))
                let high = max(open, close) * (1 + Double.random(in: 0...0.002))
                let low = min(open, close) * (1 - Double.random(in: 0...0.002))
                
                history.append(PriceData(
                    id: "\(pair)-\(i)",
                    timestamp: timestamp,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: Int.random(in: 100000...1000000)
                ))
                
                currentPrice = close
            }
            
            priceHistory[pair] = history
            technicalIndicators[pair] = calculateIndicators(for: history)
            advancedTechnicalIndicators[pair] = AdvancedTechnicalAnalyzer.calculate(history: history)
            marketAnalysis[pair] = analyzeMarket(history: history, indicators: technicalIndicators[pair]!)
        }
    }
}
