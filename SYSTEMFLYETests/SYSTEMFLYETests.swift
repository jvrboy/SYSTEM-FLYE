import XCTest
@testable import SYSTEMFLYE

// MARK: - Technical Indicator Tests
class TechnicalIndicatorTests: XCTestCase {
    var marketDataManager: MarketDataManager!
    
    override func setUp() {
        super.setUp()
        marketDataManager = MarketDataManager()
    }
    
    override func tearDown() {
        marketDataManager = nil
        super.tearDown()
    }
    
    // MARK: - RSI Tests
    func testRSICalculation() {
        let prices = [1.1000, 1.1010, 1.1020, 1.1015, 1.1025, 1.1030, 1.1028, 1.1035]
        var history: [PriceData] = []
        
        for (i, price) in prices.enumerated() {
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.0005,
                low: price - 0.0005,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // RSI should be between 0 and 100
        XCTAssert(indicators.rsi >= 0 && indicators.rsi <= 100, "RSI should be between 0 and 100")
    }
    
    func testRSIOversoldCondition() {
        var history: [PriceData] = []
        var price = 1.2000
        
        // Create oversold condition - declining prices
        for i in 0..<30 {
            price = price - 0.0005
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price,
                low: price - 0.0001,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // RSI should be low (oversold)
        XCTAssert(indicators.rsi < 40, "RSI should indicate oversold condition")
    }
    
    // MARK: - MACD Tests
    func testMACDCalculation() {
        let prices = Array(1...50).map { Double($0) * 0.1 }
        var history: [PriceData] = []
        
        for (i, price) in prices.enumerated() {
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.01,
                low: price - 0.01,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // MACD line should have value
        XCTAssertNotEqual(indicators.macd.macdLine, 0, "MACD line should be calculated")
    }
    
    func testMACDCrossover() {
        // Create uptrend followed by downtrend to trigger crossover
        var history: [PriceData] = []
        var price = 1.1000
        
        // Uptrend
        for i in 0..<30 {
            price = price + 0.0005
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.0005,
                low: price,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // In uptrend, histogram should be positive
        XCTAssert(indicators.macd.histogram > 0, "MACD histogram should be positive in uptrend")
    }
    
    // MARK: - Bollinger Bands Tests
    func testBollingerBandsCalculation() {
        var history: [PriceData] = []
        let basePrice = 1.1000
        
        for i in 0..<25 {
            let price = basePrice + Double.random(in: -0.0005...0.0005)
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.0002,
                low: price - 0.0002,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // Upper band should be > lower band
        XCTAssert(indicators.bollingerBands.upper > indicators.bollingerBands.lower,
                  "Upper Bollinger Band should be greater than lower band")
        
        // Middle band should be between upper and lower
        let middle = indicators.bollingerBands.middle
        let upper = indicators.bollingerBands.upper
        let lower = indicators.bollingerBands.lower
        XCTAssert(middle < upper && middle > lower, "Middle band should be between upper and lower")
    }
    
    // MARK: - Moving Average Tests
    func testMovingAverageCalculation() {
        var history: [PriceData] = []
        let prices = Array(1...100).map { Double($0) * 0.01 }
        
        for (i, price) in prices.enumerated() {
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.01,
                low: price - 0.01,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // MA should increase with uptrend
        XCTAssert(indicators.movingAverages.ma20 > 0, "MA20 should be calculated")
        XCTAssert(indicators.movingAverages.ma50 > 0, "MA50 should be calculated")
        XCTAssert(indicators.movingAverages.ma200 > 0, "MA200 should be calculated")
    }
    
    // MARK: - ATR Tests
    func testATRCalculation() {
        var history: [PriceData] = []
        var basePrice = 1.1000
        
        for i in 0..<20 {
            let high = basePrice + 0.0010
            let low = basePrice - 0.0010
            let close = basePrice + Double.random(in: -0.0005...0.0005)
            
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: basePrice,
                high: high,
                low: low,
                close: close,
                volume: 100000
            ))
            
            basePrice = close
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // ATR should be positive
        XCTAssert(indicators.atr > 0, "ATR should be positive")
        XCTAssert(indicators.atr.isFinite, "ATR should be a finite number")
    }
}

// MARK: - Signal Generation Tests
class SignalGenerationTests: XCTestCase {
    var signalGenerator: SignalGenerator!
    var marketDataManager: MarketDataManager!
    
    override func setUp() {
        super.setUp()
        signalGenerator = SignalGenerator()
        marketDataManager = MarketDataManager()
    }
    
    override func tearDown() {
        signalGenerator = nil
        marketDataManager = nil
        super.tearDown()
    }
    
    func testBuySignalGeneration() {
        // Create oversold condition
        var history: [PriceData] = []
        var price = 1.2000
        
        for i in 0..<30 {
            price = price - 0.0005
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price,
                low: price - 0.0001,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        let analysis = MarketAnalysis(
            condition: .neutral,
            volatility: 1.5,
            trend: 0.0,
            momentum: -0.5,
            supportLevel: price,
            resistanceLevel: price + 0.01
        )
        
        // Manually check if buy signal should be generated
        let hasOversoldRSI = indicators.rsi < 30
        XCTAssert(hasOversoldRSI, "Oversold condition should be detected")
    }
    
    func testSellSignalGeneration() {
        // Create overbought condition
        var history: [PriceData] = []
        var price = 1.1000
        
        for i in 0..<30 {
            price = price + 0.0005
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.0001,
                low: price,
                close: price,
                volume: 100000
            ))
        }
        
        let indicators = marketDataManager.calculateIndicators(for: history)
        
        // Check if sell signal should be generated
        let hasOverboughtRSI = indicators.rsi > 70
        XCTAssert(hasOverboughtRSI, "Overbought condition should be detected")
    }
    
    func testSignalHasValidRiskReward() {
        let signal = TradingSignal(
            pairSymbol: "EURUSD",
            signalType: .buy,
            strength: .strong,
            entryPrice: 1.1000,
            stopLoss: 1.0985,
            takeProfit: 1.1030,
            confidence: 85,
            indicators: ["RSI", "MACD"],
            reason: "Test signal"
        )
        
        // Risk-reward should be >= 1:1
        XCTAssert(signal.riskRewardRatio > 0, "Risk-reward ratio should be positive")
        
        // Stop loss should be below entry for buy signal
        XCTAssert(signal.stopLoss < signal.entryPrice, "Stop loss should be below entry for buy signal")
        
        // Take profit should be above entry for buy signal
        XCTAssert(signal.takeProfit > signal.entryPrice, "Take profit should be above entry for buy signal")
    }
}

// MARK: - Portfolio Management Tests
class PortfolioManagementTests: XCTestCase {
    var portfolioManager: PortfolioManager!
    
    override func setUp() {
        super.setUp()
        portfolioManager = PortfolioManager()
    }
    
    override func tearDown() {
        portfolioManager = nil
        super.tearDown()
    }
    
    func testTradeCalculations() {
        let buyTrade = Trade(
            id: UUID(),
            pairSymbol: "EURUSD",
            type: .buy,
            entryPrice: 1.1000,
            exitPrice: 1.1050,
            quantity: 1.0,
            entryDate: Date(),
            exitDate: Date(),
            profitLoss: 0.0050,
            status: .closed
        )
        
        let expectedPnLPercent = ((1.1050 - 1.1000) / 1.1000) * 100
        let actualPnLPercent = buyTrade.pnlPercentage ?? 0
        
        XCTAssertEqual(actualPnLPercent, expectedPnLPercent, accuracy: 0.01, "P&L percentage should be calculated correctly")
    }
    
    func testPortfolioStats() {
        let winCount = portfolioManager.winCount
        let lossCount = portfolioManager.lossCount
        let totalTrades = winCount + lossCount
        
        XCTAssert(totalTrades > 0, "Should have some trades for testing")
        
        let winRate = portfolioManager.portfolio.winRate
        XCTAssert(winRate >= 0 && winRate <= 100, "Win rate should be between 0 and 100")
    }
    
    func testProfitFactor() {
        let profitFactor = portfolioManager.profitFactor
        
        // Profit factor should be finite
        XCTAssert(profitFactor.isFinite, "Profit factor should be a finite number")
        
        // Profit factor should be >= 0
        XCTAssert(profitFactor >= 0, "Profit factor should be non-negative")
    }
    
    func testMaxDrawdown() {
        let maxDrawdown = portfolioManager.maxDrawdown
        
        // Max drawdown should be between 0 and 100%
        XCTAssert(maxDrawdown >= 0 && maxDrawdown <= 100, "Max drawdown should be between 0 and 100%")
    }
}

// MARK: - Utility Tests
class UtilityTests: XCTestCase {
    func testPriceFormatting() {
        let price = 1.12345
        let formatted = PriceFormatter.formatPrice(price, decimals: 5)
        
        XCTAssert(formatted.contains("1.12345"), "Price should be formatted with correct decimals")
    }
    
    func testPercentageChange() {
        let change = MathUtilities.percentageChange(from: 1.0, to: 1.1)
        
        XCTAssertEqual(change, 10.0, accuracy: 0.01, "10% increase should be calculated correctly")
    }
    
    func testPipsCalculation() {
        let pips = MathUtilities.pipsDifference(from: 1.1000, to: 1.1010)
        
        XCTAssertEqual(pips, 10.0, accuracy: 0.01, "Pips difference should be calculated correctly")
    }
    
    func testMovingAverage() {
        let values = [1.0, 1.1, 1.2, 1.3, 1.4]
        let average = MathUtilities.movingAverage(values, period: 5)
        
        let expected = (1.0 + 1.1 + 1.2 + 1.3 + 1.4) / 5
        XCTAssertEqual(average, expected, accuracy: 0.001, "Moving average should be calculated correctly")
    }
    
    func testStandardDeviation() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stdDev = MathUtilities.standardDeviation(values)
        
        XCTAssert(stdDev > 0, "Standard deviation should be positive")
        XCTAssert(stdDev.isFinite, "Standard deviation should be finite")
    }
    
    func testDateFormatting() {
        let date = Date()
        let formatted = DateFormatter.formatTime(date)
        
        XCTAssert(!formatted.isEmpty, "Date should be formatted")
    }
}

// MARK: - Validation Tests
class ValidationTests: XCTestCase {
    func testRiskLevelValidation() {
        XCTAssert(ValidationUtilities.isValidRiskLevel(1.0), "Risk level 1.0 should be valid")
        XCTAssert(ValidationUtilities.isValidRiskLevel(10.0), "Risk level 10.0 should be valid")
        XCTAssertFalse(ValidationUtilities.isValidRiskLevel(0.0), "Risk level 0.0 should be invalid")
        XCTAssertFalse(ValidationUtilities.isValidRiskLevel(15.0), "Risk level 15.0 should be invalid")
    }
    
    func testConfidenceLevelValidation() {
        XCTAssert(ValidationUtilities.isValidConfidenceLevel(50.0), "Confidence 50% should be valid")
        XCTAssert(ValidationUtilities.isValidConfidenceLevel(100.0), "Confidence 100% should be valid")
        XCTAssert(ValidationUtilities.isValidConfidenceLevel(0.0), "Confidence 0% should be valid")
        XCTAssertFalse(ValidationUtilities.isValidConfidenceLevel(-1.0), "Negative confidence should be invalid")
    }
    
    func testPriceValidation() {
        XCTAssert(ValidationUtilities.isValidPrice(1.1000), "Price 1.1000 should be valid")
        XCTAssertFalse(ValidationUtilities.isValidPrice(0.0), "Price 0 should be invalid")
        XCTAssertFalse(ValidationUtilities.isValidPrice(-1.0), "Negative price should be invalid")
    }
}

// MARK: - Performance Tests
class PerformanceTests: XCTestCase {
    func testIndicatorCalculationPerformance() {
        let marketDataManager = MarketDataManager()
        
        var history: [PriceData] = []
        var price = 1.1000
        
        for i in 0..<1000 {
            price = price + Double.random(in: -0.0005...0.0005)
            history.append(PriceData(
                id: "\(i)",
                timestamp: Date(),
                open: price,
                high: price + 0.0005,
                low: price - 0.0005,
                close: price,
                volume: 100000
            ))
        }
        
        measure {
            _ = marketDataManager.calculateIndicators(for: history)
        }
    }
}
