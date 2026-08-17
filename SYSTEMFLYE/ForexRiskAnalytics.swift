import Foundation

struct WalkForwardSegment: Codable, Equatable, Identifiable {
    let id: UUID
    let trainStart: Date
    let trainEnd: Date
    let testStart: Date
    let testEnd: Date
    let trades: Int
    let wins: Int
    let netReturn: Double
    let maxDrawdown: Double
    let winRate: Double
}

struct WalkForwardResult: Codable, Equatable {
    let pair: String
    let segments: [WalkForwardSegment]
    let totalTrades: Int
    let totalWins: Int
    let outOfSampleReturn: Double
    let maxDrawdown: Double
    let winRate: Double
    let stabilityScore: Double
}

struct PortfolioCorrelationReport: Codable, Equatable {
    let pairs: [String]
    let matrix: [String: [String: Double]]
    let highestPair: String?
    let highestCorrelation: Double
    let isWithinLimit: Bool
    let limit: Double
}

struct PortfolioRiskGate: Codable, Equatable {
    let approved: Bool
    let blockedPairs: [String]
    let messages: [String]
}

extension ForexTradingBackend {
    func walkForward(pair: String, history: [PriceData], trainSize: Int = 120, testSize: Int = 30, step: Int = 30) -> WalkForwardResult? {
        guard trainSize >= 30, testSize >= 5, step > 0, history.count >= trainSize + testSize else { return nil }
        var segments: [WalkForwardSegment] = []
        var cursor = 0
        while cursor + trainSize + testSize <= history.count {
            let train = Array(history[cursor..<(cursor + trainSize)])
            let test = Array(history[(cursor + trainSize)..<(cursor + trainSize + testSize)])
            let trainFast = train.suffix(10).map(\.close).reduce(0, +) / 10
            let trainSlow = train.map(\.close).reduce(0, +) / Double(train.count)
            let direction = trainFast > trainSlow ? 1.0 : trainFast < trainSlow ? -1.0 : 0
            var equity = 0.0
            var peak = 0.0
            var drawdown = 0.0
            var wins = 0
            var trades = 0
            for index in 0..<(test.count - 1) {
                let change = test[index + 1].close - test[index].close
                let result = direction * change
                equity += result
                trades += direction == 0 ? 0 : 1
                if result > 0 { wins += 1 }
                peak = max(peak, equity)
                drawdown = max(drawdown, peak - equity)
            }
            if let firstTrain = train.first, let lastTrain = train.last, let firstTest = test.first, let lastTest = test.last {
                segments.append(WalkForwardSegment(id: UUID(), trainStart: firstTrain.timestamp, trainEnd: lastTrain.timestamp, testStart: firstTest.timestamp, testEnd: lastTest.timestamp, trades: trades, wins: wins, netReturn: equity, maxDrawdown: drawdown, winRate: trades > 0 ? Double(wins) / Double(trades) : 0))
            }
            cursor += step
        }
        guard !segments.isEmpty else { return nil }
        let trades = segments.map(\.trades).reduce(0, +)
        let wins = segments.map(\.wins).reduce(0, +)
        let returns = segments.map(\.netReturn).reduce(0, +)
        let drawdown = segments.map(\.maxDrawdown).max() ?? 0
        let segmentWinRates = segments.map(\.winRate)
        let mean = segmentWinRates.reduce(0, +) / Double(segmentWinRates.count)
        let variance = segmentWinRates.map { pow($0 - mean, 2) }.reduce(0, +) / Double(segmentWinRates.count)
        let stability = min(1, max(0, mean * (1 - sqrt(variance))))
        let result = WalkForwardResult(pair: pair, segments: segments, totalTrades: trades, totalWins: wins, outOfSampleReturn: returns, maxDrawdown: drawdown, winRate: trades > 0 ? Double(wins) / Double(trades) : 0, stabilityScore: stability)
        lastWalkForward = result
        return result
    }

    func correlationReport(histories: [String: [PriceData]], limit: Double = 0.75) -> PortfolioCorrelationReport {
        let pairs = histories.keys.sorted()
        var matrix: [String: [String: Double]] = [:]
        var highestPair: String?
        var highest = 0.0
        for left in pairs {
            matrix[left] = [:]
            for right in pairs {
                let correlation = left == right ? 1 : pearsonCorrelation(returns: alignedReturns(histories[left] ?? [], histories[right] ?? []))
                matrix[left]?[right] = correlation
                if left < right, abs(correlation) > highest { highest = abs(correlation); highestPair = "\(left)/\(right)" }
            }
        }
        let report = PortfolioCorrelationReport(pairs: pairs, matrix: matrix, highestPair: highestPair, highestCorrelation: highest, isWithinLimit: highest <= limit, limit: limit)
        lastCorrelationReport = report
        return report
    }

    func portfolioRiskGate(plans: [ForexTradePlan], histories: [String: [PriceData]], maxCorrelation: Double = 0.75, maxAggregateRiskPercent: Double = 0.04, accountBalance: Double) -> PortfolioRiskGate {
        let report = correlationReport(histories: histories, limit: maxCorrelation)
        var blocked: [String] = []
        var messages: [String] = []
        let totalRisk = accountBalance > 0 ? plans.map(\.riskAmount).reduce(0, +) / accountBalance : 1
        if totalRisk > maxAggregateRiskPercent { blocked = plans.map(\.pair); messages.append("Aggregate portfolio risk exceeds configured limit") }
        for plan in plans {
            for other in plans where plan.pair < other.pair {
                let correlation = abs(report.matrix[plan.pair]?[other.pair] ?? 0)
                if correlation > maxCorrelation { blocked += [plan.pair, other.pair]; messages.append("\(plan.pair) and \(other.pair) correlation exceeds limit") }
            }
        }
        blocked = Array(Set(blocked)).sorted()
        if messages.isEmpty { messages.append("Portfolio correlation and aggregate risk limits passed") }
        let gate = PortfolioRiskGate(approved: blocked.isEmpty, blockedPairs: blocked, messages: messages)
        lastPortfolioRiskGate = gate
        return gate
    }

    private func alignedReturns(_ left: [PriceData], _ right: [PriceData]) -> ([Double], [Double]) {
        let count = min(left.count, right.count)
        guard count > 2 else { return ([], []) }
        let leftCloses = Array(left.suffix(count)).map(\.close)
        let rightCloses = Array(right.suffix(count)).map(\.close)
        var leftReturns: [Double] = []
        var rightReturns: [Double] = []
        for index in 1..<count {
            let leftReturn = leftCloses[index - 1] > 0 ? leftCloses[index] / leftCloses[index - 1] - 1 : 0
            let rightReturn = rightCloses[index - 1] > 0 ? rightCloses[index] / rightCloses[index - 1] - 1 : 0
            leftReturns.append(leftReturn)
            rightReturns.append(rightReturn)
        }
        return (leftReturns, rightReturns)
    }

    private func pearsonCorrelation(returns: ([Double], [Double])) -> Double {
        let (left, right) = returns
        guard left.count == right.count, left.count > 2 else { return 0 }
        let leftMean = left.reduce(0, +) / Double(left.count)
        let rightMean = right.reduce(0, +) / Double(right.count)
        let numerator = zip(left, right).map { ($0 - leftMean) * ($1 - rightMean) }.reduce(0, +)
        let leftVariance = left.map { pow($0 - leftMean, 2) }.reduce(0, +)
        let rightVariance = right.map { pow($0 - rightMean, 2) }.reduce(0, +)
        let denominator = sqrt(leftVariance * rightVariance)
        return denominator > 0 ? min(1, max(-1, numerator / denominator)) : 0
    }
}
