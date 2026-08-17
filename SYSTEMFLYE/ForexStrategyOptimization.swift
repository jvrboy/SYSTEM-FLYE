import Foundation

struct StrategyGenome: Codable, Equatable, Identifiable {
    let id: UUID
    var fastPeriod: Int
    var slowPeriod: Int
    var entryThreshold: Double
    var exitThreshold: Double
    var stopATRMultiplier: Double
    var targetATRMultiplier: Double
    var maxRiskPercent: Double

    static let baseline = StrategyGenome(fastPeriod: 8, slowPeriod: 34, entryThreshold: 0.15, exitThreshold: 0.02, stopATRMultiplier: 1.5, targetATRMultiplier: 2.2, maxRiskPercent: 0.01)

    init(id: UUID = UUID(), fastPeriod: Int, slowPeriod: Int, entryThreshold: Double, exitThreshold: Double, stopATRMultiplier: Double, targetATRMultiplier: Double, maxRiskPercent: Double) {
        self.id = id
        self.fastPeriod = max(3, fastPeriod)
        self.slowPeriod = max(self.fastPeriod + 2, slowPeriod)
        self.entryThreshold = min(0.9, max(0.01, entryThreshold))
        self.exitThreshold = min(self.entryThreshold, max(0, exitThreshold))
        self.stopATRMultiplier = min(5, max(0.5, stopATRMultiplier))
        self.targetATRMultiplier = min(8, max(0.75, targetATRMultiplier))
        self.maxRiskPercent = min(0.02, max(0.001, maxRiskPercent))
    }
}

struct StrategyFitness: Codable, Equatable {
    let genome: StrategyGenome
    let netReturn: Double
    let maxDrawdown: Double
    let sortino: Double
    let calmar: Double
    let trades: Int
    let winRate: Double
    let fitness: Double
}

struct GeneticOptimizationResult: Codable, Equatable {
    let pair: String
    let best: StrategyFitness
    let generations: Int
    let populationSize: Int
    let evaluatedAt: Date
}

struct RiskAdjustedMetrics: Codable, Equatable {
    let totalReturn: Double
    let annualizedReturn: Double
    let annualizedVolatility: Double
    let maxDrawdown: Double
    let sharpe: Double
    let sortino: Double
    let calmar: Double
    let profitFactor: Double
    let winRate: Double
    let observations: Int
}

enum StrategyOptimizer {
    static func optimize(pair: String, history: [PriceData], generations: Int = 12, populationSize: Int = 28, seed: UInt64 = 0xC0FFEE) -> GeneticOptimizationResult? {
        guard history.count >= 100, generations > 0, populationSize > 4 else { return nil }
        var generator = StrategySeededGenerator(seed: seed)
        var population = (0..<populationSize).map { _ in randomGenome(using: &generator) }
        var best = evaluate(population[0], history: history)
        for _ in 0..<generations {
            let scored = population.map { evaluate($0, history: history) }.sorted { $0.fitness > $1.fitness }
            if let candidate = scored.first, candidate.fitness > best.fitness { best = candidate }
            let eliteCount = max(2, populationSize / 5)
            let elites = Array(scored.prefix(eliteCount)).map(\.genome)
            var next = elites
            while next.count < populationSize {
                let first = elites[generator.nextInt(upperBound: elites.count)]
                let second = elites[generator.nextInt(upperBound: elites.count)]
                next.append(mutate(crossover(first, second, using: &generator), using: &generator))
            }
            population = next
        }
        return GeneticOptimizationResult(pair: pair, best: best, generations: generations, populationSize: populationSize, evaluatedAt: Date())
    }

    static func evaluate(_ genome: StrategyGenome, history: [PriceData]) -> StrategyFitness {
        var returns: [Double] = []
        var equity = 0.0
        var peak = 0.0
        var maxDrawdown = 0.0
        var wins = 0
        var trades = 0
        guard history.count > genome.slowPeriod + 2 else { return StrategyFitness(genome: genome, netReturn: 0, maxDrawdown: 0, sortino: 0, calmar: 0, trades: 0, winRate: 0, fitness: -.greatestFiniteMagnitude) }
        for index in genome.slowPeriod..<(history.count - 1) {
            let fastStart = max(0, index - genome.fastPeriod + 1)
            let slowStart = max(0, index - genome.slowPeriod + 1)
            let fast = history[fastStart...index].map(\.close).reduce(0, +) / Double(index - fastStart + 1)
            let slow = history[slowStart...index].map(\.close).reduce(0, +) / Double(index - slowStart + 1)
            let signal = slow > 0 ? (fast - slow) / slow : 0
            let nextReturn = history[index].close > 0 ? (history[index + 1].close - history[index].close) / history[index].close : 0
            let result: Double
            if signal > genome.entryThreshold { result = nextReturn } else if signal < -genome.entryThreshold { result = -nextReturn } else { result = 0 }
            if result != 0 { trades += 1; if result > 0 { wins += 1 } }
            returns.append(result)
            equity += result
            peak = max(peak, equity)
            maxDrawdown = max(maxDrawdown, peak - equity)
        }
        let metrics = RiskMetricsCalculator.calculate(returns: returns, initialCapital: 1)
        let fitness = metrics.sortino * 0.35 + metrics.calmar * 0.35 + metrics.sharpe * 0.15 + min(1, metrics.winRate) * 0.15 - metrics.maxDrawdown * 0.2
        return StrategyFitness(genome: genome, netReturn: metrics.totalReturn, maxDrawdown: metrics.maxDrawdown, sortino: metrics.sortino, calmar: metrics.calmar, trades: trades, winRate: trades > 0 ? Double(wins) / Double(trades) : 0, fitness: fitness)
    }

    private static func randomGenome(using generator: inout StrategySeededGenerator) -> StrategyGenome {
        StrategyGenome(fastPeriod: generator.nextInt(upperBound: 20) + 4, slowPeriod: generator.nextInt(upperBound: 80) + 30, entryThreshold: generator.nextDouble(in: 0.05...0.35), exitThreshold: generator.nextDouble(in: 0.01...0.08), stopATRMultiplier: generator.nextDouble(in: 0.8...2.8), targetATRMultiplier: generator.nextDouble(in: 1.2...4.5), maxRiskPercent: generator.nextDouble(in: 0.005...0.02))
    }

    private static func crossover(_ first: StrategyGenome, _ second: StrategyGenome, using generator: inout StrategySeededGenerator) -> StrategyGenome {
        StrategyGenome(fastPeriod: generator.nextBool() ? first.fastPeriod : second.fastPeriod, slowPeriod: generator.nextBool() ? first.slowPeriod : second.slowPeriod, entryThreshold: generator.nextBool() ? first.entryThreshold : second.entryThreshold, exitThreshold: generator.nextBool() ? first.exitThreshold : second.exitThreshold, stopATRMultiplier: generator.nextBool() ? first.stopATRMultiplier : second.stopATRMultiplier, targetATRMultiplier: generator.nextBool() ? first.targetATRMultiplier : second.targetATRMultiplier, maxRiskPercent: generator.nextBool() ? first.maxRiskPercent : second.maxRiskPercent)
    }

    private static func mutate(_ genome: StrategyGenome, using generator: inout StrategySeededGenerator) -> StrategyGenome {
        StrategyGenome(fastPeriod: generator.nextBool() ? genome.fastPeriod + generator.nextInt(upperBound: 5) - 2 : genome.fastPeriod, slowPeriod: generator.nextBool() ? genome.slowPeriod + generator.nextInt(upperBound: 9) - 4 : genome.slowPeriod, entryThreshold: generator.nextBool() ? genome.entryThreshold + generator.nextDouble(in: -0.04...0.04) : genome.entryThreshold, exitThreshold: generator.nextBool() ? genome.exitThreshold + generator.nextDouble(in: -0.02...0.02) : genome.exitThreshold, stopATRMultiplier: generator.nextBool() ? genome.stopATRMultiplier + generator.nextDouble(in: -0.25...0.25) : genome.stopATRMultiplier, targetATRMultiplier: generator.nextBool() ? genome.targetATRMultiplier + generator.nextDouble(in: -0.4...0.4) : genome.targetATRMultiplier, maxRiskPercent: genome.maxRiskPercent)
    }
}

enum RiskMetricsCalculator {
    static func calculate(returns: [Double], initialCapital: Double = 1, periodsPerYear: Double = 252) -> RiskAdjustedMetrics {
        guard !returns.isEmpty else { return RiskAdjustedMetrics(totalReturn: 0, annualizedReturn: 0, annualizedVolatility: 0, maxDrawdown: 0, sharpe: 0, sortino: 0, calmar: 0, profitFactor: 0, winRate: 0, observations: 0) }
        let capital = max(0.000001, initialCapital)
        var equity = capital
        var peak = capital
        var maxDrawdown = 0.0
        var wins = 0
        var losses = 0
        var grossWins = 0.0
        var grossLosses = 0.0
        for change in returns { equity *= 1 + change; if change > 0 { wins += 1; grossWins += change } else if change < 0 { losses += 1; grossLosses += abs(change) }; peak = max(peak, equity); maxDrawdown = max(maxDrawdown, (peak - equity) / peak) }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.count > 1 ? returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count - 1) : 0
        let volatility = sqrt(max(0, variance))
        let downside = returns.filter { $0 < 0 }.map { $0 * $0 }.reduce(0, +)
        let downsideDeviation = sqrt(downside / Double(returns.count))
        let annualizedReturn = pow(max(0.000001, equity / capital), periodsPerYear / Double(returns.count)) - 1
        let annualizedVolatility = volatility * sqrt(periodsPerYear)
        let sharpe = annualizedVolatility > 0 ? annualizedReturn / annualizedVolatility : 0
        let sortino = downsideDeviation > 0 ? annualizedReturn / (downsideDeviation * sqrt(periodsPerYear)) : 0
        let calmar = maxDrawdown > 0 ? annualizedReturn / maxDrawdown : 0
        return RiskAdjustedMetrics(totalReturn: equity / capital - 1, annualizedReturn: annualizedReturn, annualizedVolatility: annualizedVolatility, maxDrawdown: maxDrawdown, sharpe: sharpe, sortino: sortino, calmar: calmar, profitFactor: grossLosses > 0 ? grossWins / grossLosses : 0, winRate: Double(wins) / Double(max(1, wins + losses)), observations: returns.count)
    }
}

struct StrategySeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 { state = state &* 2862933555777941757 &+ 3037000493; return state }
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double { let unit = Double(next() % 1_000_000) / 1_000_000; return range.lowerBound + (range.upperBound - range.lowerBound) * unit }
    mutating func nextInt(upperBound: Int) -> Int { guard upperBound > 0 else { return 0 }; return Int(next() % UInt64(upperBound)) }
    mutating func nextBool() -> Bool { next() % 2 == 0 }
}
