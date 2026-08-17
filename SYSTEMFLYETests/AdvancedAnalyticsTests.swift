import XCTest
@testable import SYSTEMFLYE

final class AdvancedAnalyticsTests: XCTestCase {
    func testSharpeRatioCalculatesCorrectly() {
        let returns = Array(repeating: 0.01, count: 252)
        let sharpe = AnalyticsEngine.shared.calculateSharpeRatio(returns: returns)
        XCTAssertGreaterThan(sharpe, 0)
    }
    
    func testSortinoRatioIsHigherThanSharpeForPositiveReturns() {
        let returns = Array(repeating: 0.01, count: 252)
        let sharpe = AnalyticsEngine.shared.calculateSharpeRatio(returns: returns)
        let sortino = AnalyticsEngine.shared.calculateSortinoRatio(returns: returns)
        XCTAssertGreaterThanOrEqual(sortino, sharpe)
    }
    
    func testValueAtRiskIsNegativeForNormalDistribution() {
        let returns = Array(repeating: 0.01, count: 100) + Array(repeating: -0.02, count: 10)
        let var_ = AnalyticsEngine.shared.calculateValueAtRisk(returns: returns, confidence: 0.95)
        XCTAssertLessThan(var_, 0)
    }
    
    func testAnomalyDetectionFindsSpikes() {
        let prices = Array(repeating: 1.0, count: 50)
        let modified = prices.enumerated().map { idx, val in idx == 25 ? 1.3 : val }
        let anomalies = AnalyticsEngine.shared.detectAnomalies(prices: modified, threshold: 2.0)
        XCTAssertGreaterThan(anomalies.count, 0)
    }
    
    func testCorrelationMatrixIsSymmetric() {
        let series1 = [1.0, 2.0, 3.0, 4.0, 5.0]
        let series2 = [2.0, 3.0, 4.0, 5.0, 6.0]
        let matrix = AnalyticsEngine.shared.calculateCorrelationMatrix(series: [series1, series2])
        XCTAssertEqual(matrix.count, 2)
        XCTAssertEqual(matrix[0][1], matrix[1][0])
    }
    
    func testMaxDrawdownCalculatesCorrectly() {
        let prices = [1.0, 1.2, 1.1, 0.9, 1.3, 1.1]
        let drawdown = AnalyticsEngine.shared.calculateMaxDrawdown(prices: prices)
        XCTAssertGreaterThan(drawdown, 0)
        XCTAssertLessThanOrEqual(drawdown, 100)
    }
    
    func testStressTestReturnsWorstCaseScenario() {
        let portfolio = Portfolio(totalBalance: 10000, usedMargin: 2000, availableMargin: 8000, totalProfit: 1500, totalLoss: 300, winRate: 65)
        let scenarios: [StressScenario] = [
            StressScenario(name: "Flash Crash", description: "10% drop", expectedLoss: 0.10, color: .stressRed),
            StressScenario(name: "Liquidity Crisis", description: "15% drop", expectedLoss: 0.15, color: .stressRed)
        ]
        let result = AnalyticsEngine.shared.runStressTest(portfolio: portfolio, scenarios: scenarios)
        XCTAssertEqual(result.worstCase.scenario.name, "Liquidity Crisis")
        XCTAssertEqual(result.worstCase.remainingBalance, 8500)
    }
}
