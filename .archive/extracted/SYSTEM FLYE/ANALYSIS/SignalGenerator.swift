import Foundation
import Combine

@MainActor
class SignalGenerator: ObservableObject {
    @Published var activeSignals: [TradingSignal] = []
    @Published var signalHistory: [TradingSignal] = []
    @Published var winningTrades = 0
    @Published var losingTrades = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let signalTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    init() {
        setupSignalGeneration()
    }
    
    // MARK: - Setup
    private func setupSignalGeneration() {
        signalTimer
            .sink { [weak self] _ in
                // Signal generation happens when market data updates
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Signal Generation
    func generateSignals(for pair: String, indicators: TechnicalIndicators, currentPrice: Double, marketAnalysis: MarketAnalysis) {
        let signals = detectSignals(pair: pair, indicators: indicators, currentPrice: currentPrice, marketAnalysis: marketAnalysis)
        
        for signal in signals {
            // Don't add duplicate signals
            if !activeSignals.contains(where: { $0.pairSymbol == signal.pairSymbol && $0.signalType == signal.signalType }) {
                activeSignals.append(signal)
                signalHistory.append(signal)
            }
        }
        
        // Keep only recent signals (last 50)
        if activeSignals.count > 10 {
            activeSignals.removeFirst()
        }
    }
    
    // MARK: - Signal Detection
    private func detectSignals(for pair: String, indicators: TechnicalIndicators, currentPrice: Double, marketAnalysis: MarketAnalysis) -> [TradingSignal] {
        var signals: [TradingSignal] = []
        
        // Check for Buy Signals
        if let buySignal = checkBuySignals(pair: pair, indicators: indicators, currentPrice: currentPrice, marketAnalysis: marketAnalysis) {
            signals.append(buySignal)
        }
        
        // Check for Sell Signals
        if let sellSignal = checkSellSignals(pair: pair, indicators: indicators, currentPrice: currentPrice, marketAnalysis: marketAnalysis) {
            signals.append(sellSignal)
        }
        
        return signals
    }
    
    private func checkBuySignals(pair: String, indicators: TechnicalIndicators, currentPrice: Double, marketAnalysis: MarketAnalysis) -> TradingSignal? {
        var buySignalStrength = 0
        var indicators_triggered: [String] = []
        
        // RSI Signal (RSI < 30 = Oversold = Buy)
        if indicators.rsi < 30 {
            buySignalStrength += 2
            indicators_triggered.append("RSI Oversold")
        } else if indicators.rsi < 40 {
            buySignalStrength += 1
            indicators_triggered.append("RSI Weak")
        }
        
        // MACD Signal (MACD crosses above signal line)
        if indicators.macd.histogram > 0 && indicators.macd.macdLine > indicators.macd.signalLine {
            buySignalStrength += 2
            indicators_triggered.append("MACD Bullish")
        }
        
        // Bollinger Bands Signal (Price touching lower band)
        let bbRange = indicators.bollingerBands.upper - indicators.bollingerBands.lower
        if currentPrice < (indicators.bollingerBands.lower + bbRange * 0.2) {
            buySignalStrength += 2
            indicators_triggered.append("BB Lower Band")
        }
        
        // Moving Average Signal (Price above MA20, MA20 > MA50 > MA200)
        if currentPrice > indicators.movingAverages.ma20 &&
           indicators.movingAverages.ma20 > indicators.movingAverages.ma50 &&
           indicators.movingAverages.ma50 > indicators.movingAverages.ma200 {
            buySignalStrength += 2
            indicators_triggered.append("MA Alignment")
        }
        
        // Stochastic Signal (K < 20 and crossing above D)
        if indicators.stochastic.kValue < 20 {
            buySignalStrength += 1
            indicators_triggered.append("Stochastic Oversold")
        }
        
        // Trend Signal
        if marketAnalysis.condition == .uptrend || marketAnalysis.condition == .strongUptrend {
            buySignalStrength += 1
            indicators_triggered.append("Uptrend")
        }
        
        // Generate signal if strength meets threshold
        guard buySignalStrength >= 3 else { return nil }
        
        let strength: SignalStrength = buySignalStrength >= 5 ? .strong : (buySignalStrength >= 4 ? .moderate : .weak)
        let confidence = Double(buySignalStrength) * 15.0 // 45-90%
        
        let atr = indicators.atr
        let stopLoss = currentPrice - (atr * 1.5)
        let takeProfit = currentPrice + (atr * 3.0)
        
        return TradingSignal(
            pairSymbol: pair,
            signalType: .buy,
            strength: strength,
            entryPrice: currentPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            confidence: min(confidence, 95),
            indicators: indicators_triggered,
            reason: "Multiple bullish indicators align: \(indicators_triggered.joined(separator: ", "))"
        )
    }
    
    private func checkSellSignals(pair: String, indicators: TechnicalIndicators, currentPrice: Double, marketAnalysis: MarketAnalysis) -> TradingSignal? {
        var sellSignalStrength = 0
        var indicators_triggered: [String] = []
        
        // RSI Signal (RSI > 70 = Overbought = Sell)
        if indicators.rsi > 70 {
            sellSignalStrength += 2
            indicators_triggered.append("RSI Overbought")
        } else if indicators.rsi > 60 {
            sellSignalStrength += 1
            indicators_triggered.append("RSI Strong")
        }
        
        // MACD Signal (MACD crosses below signal line)
        if indicators.macd.histogram < 0 && indicators.macd.macdLine < indicators.macd.signalLine {
            sellSignalStrength += 2
            indicators_triggered.append("MACD Bearish")
        }
        
        // Bollinger Bands Signal (Price touching upper band)
        let bbRange = indicators.bollingerBands.upper - indicators.bollingerBands.lower
        if currentPrice > (indicators.bollingerBands.upper - bbRange * 0.2) {
            sellSignalStrength += 2
            indicators_triggered.append("BB Upper Band")
        }
        
        // Moving Average Signal (Price below MA20, MA20 < MA50 < MA200)
        if currentPrice < indicators.movingAverages.ma20 &&
           indicators.movingAverages.ma20 < indicators.movingAverages.ma50 &&
           indicators.movingAverages.ma50 < indicators.movingAverages.ma200 {
            sellSignalStrength += 2
            indicators_triggered.append("MA Alignment")
        }
        
        // Stochastic Signal (K > 80 and crossing below D)
        if indicators.stochastic.kValue > 80 {
            sellSignalStrength += 1
            indicators_triggered.append("Stochastic Overbought")
        }
        
        // Trend Signal
        if marketAnalysis.condition == .downtrend || marketAnalysis.condition == .strongDowntrend {
            sellSignalStrength += 1
            indicators_triggered.append("Downtrend")
        }
        
        // Generate signal if strength meets threshold
        guard sellSignalStrength >= 3 else { return nil }
        
        let strength: SignalStrength = sellSignalStrength >= 5 ? .strong : (sellSignalStrength >= 4 ? .moderate : .weak)
        let confidence = Double(sellSignalStrength) * 15.0 // 45-90%
        
        let atr = indicators.atr
        let stopLoss = currentPrice + (atr * 1.5)
        let takeProfit = currentPrice - (atr * 3.0)
        
        return TradingSignal(
            pairSymbol: pair,
            signalType: .sell,
            strength: strength,
            entryPrice: currentPrice,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            confidence: min(confidence, 95),
            indicators: indicators_triggered,
            reason: "Multiple bearish indicators align: \(indicators_triggered.joined(separator: ", "))"
        )
    }
    
    // MARK: - Signal Management
    func removeSignal(_ signal: TradingSignal) {
        activeSignals.removeAll { $0.id == signal.id }
    }
    
    func closeSignal(_ signal: TradingSignal, atPrice exitPrice: Double) {
        removeSignal(signal)
        
        let pnl = signal.signalType == .buy ? 
            (exitPrice - signal.entryPrice) : 
            (signal.entryPrice - exitPrice)
        
        if pnl > 0 {
            winningTrades += 1
        } else {
            losingTrades += 1
        }
    }
    
    var totalSignals: Int {
        activeSignals.count
    }
    
    var strongSignals: [TradingSignal] {
        activeSignals.filter { $0.strength == .strong }
    }
    
    var winRate: Double {
        let total = winningTrades + losingTrades
        guard total > 0 else { return 0 }
        return Double(winningTrades) / Double(total) * 100
    }
}
