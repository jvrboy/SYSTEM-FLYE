import Foundation
import Accelerate

// MARK: - Analytics Engine
@MainActor
final class AnalyticsEngine: ObservableObject {
    static let shared = AnalyticsEngine()
    @Published private(set) var monteCarloResults: [Double] = []
    @Published private(set) var valueAtRisk: Double = 0
    @Published private(set) var sharpeRatio: Double = 0
    @Published private(set) var sortinoRatio: Double = 0
    @Published private(set) var correlationMatrix: [[Double]] = []
    @Published private(set) var anomalies: [Anomaly] = []
    @Published private(set) var stressTestResults: StressTestResult?
    
    func runMonteCarloSimulation(basePrice: Double, volatility: Double, days: Int = 30, simulations: Int = 1000) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var results: [Double] = []
                let dt = 1.0 / 252.0
                let mu = 0.05
                let steps = days
                
                for _ in 0..<simulations {
                    var price = basePrice
                    for _ in 0..<steps {
                        let z = self.randomNormal()
                        price *= exp((mu - 0.5 * volatility * volatility) * dt + volatility * sqrt(dt) * z)
                    }
                    results.append(price)
                }
                self.monteCarloResults = results
                continuation.resume()
            }
        }
    }
    
    func calculateValueAtRisk(returns: [Double], confidence: Double = 0.95) -> Double {
        guard returns.count > 1 else { return 0 }
        let sorted = returns.sorted()
        let index = Int(Double(sorted.count) * (1 - confidence))
        return sorted[min(index, sorted.count - 1)]
    }
    
    func calculateSharpeRatio(returns: [Double], riskFreeRate: Double = 0.02) -> Double {
        guard returns.count > 1 else { return 0 }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count - 1)
        let stdDev = sqrt(variance)
        guard stdDev > 0 else { return 0 }
        let annualizedReturn = mean * 252
        let annualizedVol = stdDev * sqrt(252)
        return (annualizedReturn - riskFreeRate) / annualizedVol
    }
    
    func calculateSortinoRatio(returns: [Double], riskFreeRate: Double = 0.02) -> Double {
        guard returns.count > 1 else { return 0 }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let downside = returns.filter { $0 < 0 }.map { pow($0, 2) }.reduce(0, +)
        let downsideDev = sqrt(downside / Double(returns.count))
        guard downsideDev > 0 else { return 0 }
        let annualizedReturn = mean * 252
        let annualizedDownside = downsideDev * sqrt(252)
        return (annualizedReturn - riskFreeRate) / annualizedDownside
    }
    
    func calculateCorrelationMatrix(series: [[Double]]) -> [[Double]] {
        let n = series.count
        guard n > 1 else { return [] }
        var matrix: [[Double]] = Array(repeating: Array(repeating: 0, count: n), count: n)
        
        for i in 0..<n {
            for j in 0..<n {
                matrix[i][j] = pearsonCorrelation(series[i], series[j])
                matrix[j][i] = matrix[i][j]
            }
        }
        correlationMatrix = matrix
        return matrix
    }
    
    func detectAnomalies(prices: [Double], threshold: Double = 2.0) -> [Anomaly] {
        guard prices.count > 5 else { return [] }
        let mean = prices.reduce(0, +) / Double(prices.count)
        let variance = prices.map { pow($0 - mean, 2) }.reduce(0, +) / Double(prices.count)
        let stdDev = sqrt(variance)
        
        var found: [Anomaly] = []
        for (index, price) in prices.enumerated() {
            let zScore = abs(price - mean) / max(stdDev, 0.001)
            if zScore > threshold {
                found.append(Anomaly(index: index, price: price, zScore: zScore, type: zScore > 0 ? .spike : .drop))
            }
        }
        anomalies = found
        return found
    }
    
    func runStressTest(portfolio: Portfolio, scenarios: [StressScenario]) -> StressTestResult {
        let worstDrawdown = scenarios.map { scenario in
            let loss = portfolio.totalBalance * scenario.expectedLoss
            return StressScenarioResult(scenario: scenario, loss: loss, remainingBalance: portfolio.totalBalance - loss)
        }.min { $0.remainingBalance > $1.remainingBalance } ?? StressScenarioResult(scenario: scenarios[0], loss: 0, remainingBalance: portfolio.totalBalance)
        
        let result = StressTestResult(worstCase: worstDrawdown, scenarios: scenarios.map { scenario in
            StressScenarioResult(scenario: scenario, loss: portfolio.totalBalance * scenario.expectedLoss, remainingBalance: portfolio.totalBalance * (1 - scenario.expectedLoss))
        })
        stressTestResults = result
        return result
    }
    
    func calculateMaxDrawdown(prices: [Double]) -> Double {
        var peak = prices.first ?? 0
        var maxDD = 0.0
        for price in prices {
            if price > peak { peak = price }
            let dd = (peak - price) / max(peak, 0.001)
            maxDD = max(maxDD, dd)
        }
        return maxDD * 100
    }
    
    private func randomNormal() -> Double {
        var u1 = Double.random(in: 0...1)
        var u2 = Double.random(in: 0...1)
        while u1 == 0 { u1 = Double.random(in: 0...1) }
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }
    
    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var num = 0.0, denX = 0.0, denY = 0.0
        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }
        let den = sqrt(denX * denY)
        return den == 0 ? 0 : num / den
    }
}

// MARK: - Data Structures
struct Anomaly: Identifiable {
    let id = UUID()
    let index: Int
    let price: Double
    let zScore: Double
    let type: AnomalyType
    
    enum AnomalyType { case spike, drop }
}

struct StressScenario: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let expectedLoss: Double
    let color: Color
}

struct StressScenarioResult: Identifiable {
    let id = UUID()
    let scenario: StressScenario
    let loss: Double
    let remainingBalance: Double
}

struct StressTestResult: Identifiable {
    let id = UUID()
    let worstCase: StressScenarioResult
    let scenarios: [StressScenarioResult]
}

extension Color { static let stressRed = Color(red: 0.9, green: 0.3, blue: 0.3); static let stressOrange = Color(red: 1, green: 0.6, blue: 0.2); static let stressGreen = Color(red: 0.3, green: 0.9, blue: 0.6) }
