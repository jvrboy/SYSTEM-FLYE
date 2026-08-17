import Foundation
import Combine
import Accelerate

// MARK: - Monte Carlo Models
enum MonteCarloMethod: String, Codable, CaseIterable {
    case geometricBrownianMotion = "GBM"
    case arithmeticBrownianMotion = "ABM"
    case jumpDiffusion = "JUMP_DIFFUSION"
    case hestonStochasticVolatility = "HESTON"
    case vasicekInterestRate = "VASICEK"
    case coxIngersollRoss = "CIR"
    case meanReverting = "MEAN_REVERT"
    case customStochastic = "CUSTOM"
}

struct MonteCarloPath: Codable, Identifiable {
    let id = UUID()
    let method: MonteCarloMethod
    let values: [Double]
    let times: [Double]
    let parameters: [String: Double]
    let seed: UInt64

    var lastValue: Double { values.last ?? 0 }
    var minValue: Double { values.min() ?? 0 }
    var maxValue: Double { values.max() ?? 0 }
    var maxDrawdown: Double {
        var peak = values.first ?? 0
        var maxDD = 0.0
        for value in values {
            if value > peak { peak = value }
            let dd = (peak - value) / max(peak, 0.0001)
            maxDD = max(maxDD, dd)
        }
        return maxDD
    }
    var terminalValueDistribution: Double { lastValue }
    var averageValue: Double { values.reduce(0, +) / Double(max(1, values.count)) }
}

struct MonteCarloStatistics: Codable, Identifiable {
    let id = UUID()
    let paths: Int
    let steps: Int
    let timeHorizon: Double
    let meanTerminalValue: Double
    let medianTerminalValue: Double
    let stdDevTerminalValue: Double
    let minTerminalValue: Double
    let maxTerminalValue: Double
    let percentile5: Double
    let percentile25: Double
    let percentile75: Double
    let percentile95: Double
    let percentile99: Double
    let probabilityOfLoss: Double
    let valueAtRisk95: Double
    let valueAtRisk99: Double
    let conditionalValueAtRisk95: Double
    let expectedShortfall99: Double
    let skewness: Double
    let kurtosis: Double
    var confidenceInterval95: (lower: Double, upper: Double) { (percentile5, percentile95) }
    var confidenceInterval99: (lower: Double, upper: Double) { (percentile1 ?? minTerminalValue, percentile99) }
    var percentile1: Double?

    init(paths: Int, steps: Int, timeHorizon: Double, terminalValues: [Double]) {
        self.id = UUID()
        self.paths = paths
        self.steps = steps
        self.timeHorizon = timeHorizon
        let sorted = terminalValues.sorted()
        let n = Double(sorted.count)
        self.meanTerminalValue = sorted.reduce(0, +) / n
        self.medianTerminalValue = sorted[Int(n * 0.5)]
        let mean = self.meanTerminalValue
        let variance = sorted.map { pow($0 - mean, 2) }.reduce(0, +) / n
        self.stdDevTerminalValue = sqrt(max(0, variance))
        self.minTerminalValue = sorted.first ?? 0
        self.maxTerminalValue = sorted.last ?? 0
        self.percentile5 = sorted[Int(n * 0.05)]
        self.percentile25 = sorted[Int(n * 0.25)]
        self.percentile75 = sorted[Int(n * 0.75)]
        self.percentile95 = sorted[Int(n * 0.95)]
        self.percentile99 = sorted[Int(n * 0.99)]
        self.percentile1 = sorted[Int(n * 0.01)]
        self.probabilityOfLoss = Double(sorted.filter { $0 < mean }.count) / n
        self.valueAtRisk95 = sorted[Int(n * 0.05)]
        self.valueAtRisk99 = sorted[Int(n * 0.01)]
        let cvarSamples = sorted.prefix(max(1, Int(n * 0.05)))
        self.conditionalValueAtRisk95 = cvarSamples.isEmpty ? 0 : cvarSamples.reduce(0, +) / Double(cvarSamples.count)
        let es99Samples = sorted.prefix(max(1, Int(n * 0.01)))
        self.expectedShortfall99 = es99Samples.isEmpty ? 0 : es99Samples.reduce(0, +) / Double(es99Samples.count)
        let m3 = sorted.map { pow($0 - mean, 3) }.reduce(0, +) / n
        let m4 = sorted.map { pow($0 - mean, 4) }.reduce(0, +) / n
        self.skewness = variance > 0 ? m3 / pow(variance, 1.5) : 0
        self.kurtosis = variance > 0 ? m4 / (variance * variance) - 3 : 0
    }
}

struct ConvergenceMetrics: Codable, Identifiable {
    let id = UUID()
    let pathsSimulated: Int
    let runningMean: Double
    let runningStd: Double
    let standardError: Double
    let relativeError: Double
    let isConverged: Bool
    let confidenceIntervalWidth: Double

    init(pathsSimulated: Int, terminalValues: [Double]) {
        self.pathsSimulated = pathsSimulated
        let mean = terminalValues.reduce(0, +) / Double(max(1, terminalValues.count))
        let variance = terminalValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, terminalValues.count))
        let std = sqrt(max(0, variance))
        self.runningMean = mean
        self.runningStd = std
        self.standardError = std / sqrt(Double(max(1, terminalValues.count)))
        self.relativeError = mean != 0 ? self.standardError / abs(mean) : 0
        self.isConverged = self.relativeError < 0.01
        self.confidenceIntervalWidth = 1.96 * self.standardError * 2
    }
}

// MARK: - Simulation Configuration
struct SimulationParameters: Codable, Identifiable {
    let id = UUID()
    var method: MonteCarloMethod
    var initialValue: Double
    var drift: Double
    var volatility: Double
    var timeHorizon: Double
    var steps: Int
    var pathCount: Int
    var jumpIntensity: Double
    var jumpMean: Double
    var jumpVolatility: Double
    var meanReversionSpeed: Double
    var longTermMean: Double
    var correlationMatrix: [[Double]]
    var randomSeed: UInt64
    var antitheticVariates: Bool
    var controlVariates: Bool
    var quasiRandom: Bool
    var tags: [String]

    static let equityDefault = SimulationParameters(method: .geometricBrownianMotion, initialValue: 100, drift: 0.08, volatility: 0.2, timeHorizon: 1.0, steps: 252, pathCount: 10000, jumpIntensity: 0, jumpMean: 0, jumpVolatility: 0, meanReversionSpeed: 0, longTermMean: 0, correlationMatrix: [], randomSeed: 0xCAFEBABE, antitheticVariates: true, controlVariates: true, quasiRandom: false, tags: [])
}

// MARK: - Visualization Data
struct VisualizationData: Codable, Identifiable {
    let id = UUID()
    let histogramBins: [(value: Double, frequency: Int, cumulative: Double)]
    let pathSamples: [MonteCarloPath]
    let percentilesOverTime: [(time: Double, p5: Double, p25: Double, p50: Double, p75: Double, p95: Double)]
    let scatterData: [(pathIndex: Int, terminalValue: Double)]
    let heatmapData: [[Double]]
    let summary: String
}

// MARK: - Monte Carlo Engine
@MainActor
final class MonteCarloEngine: ObservableObject {
    static let shared = MonteCarloEngine()
    @Published private(set) var statistics: MonteCarloStatistics?
    @Published private(set) var paths: [MonteCarloPath] = []
    @Published private(set) var isRunning = false
    @Published private(set) var convergence: ConvergenceMetrics?
    private var cancellationToken: Task<Void, Never>?

    func runSimulation(parameters: SimulationParameters) async -> MonteCarloStatistics {
        guard !isRunning else { return MonteCarloStatistics(paths: 0, steps: 0, timeHorizon: 0, terminalValues: []) }
        isRunning = true
        defer { isRunning = false }
        let startTime = Date()
        var rng = SeededGenerator(seed: parameters.randomSeed)
        var terminalValues: [Double] = []
        terminalValues.reserveCapacity(parameters.pathCount)
        var currentPaths: [MonteCarloPath] = []
        currentPaths.reserveCapacity(min(100, parameters.pathCount))
        let dt = parameters.timeHorizon / Double(parameters.steps)
        let halfSteps = parameters.steps / 2
        for pathIndex in 0..<parameters.pathCount {
            if Task.isCancelled { break }
            var values: [Double] = []
            values.reserveCapacity(parameters.steps + 1)
            var times: [Double] = []
            times.reserveCapacity(parameters.steps + 1)
            var currentValue = parameters.initialValue
            var z1: Double = 0, z2: Double = 0, useZ2 = false
            if parameters.antitheticVariates && pathIndex % 2 == 0 {
                z1 = randomNormal(rng: &rng)
                z2 = -z1
                useZ2 = true
            } else if !parameters.antitheticVariates {
                z1 = randomNormal(rng: &rng)
                useZ2 = false
            }
            values.append(currentValue)
            times.append(0)
            var zIndex = 0
            for step in 1...parameters.steps {
                let z: Double
                if parameters.antitheticVariates {
                    z = (step % 2 == 1) ? z1 : z2
                } else {
                    z = randomNormal(rng: &rng)
                }
                zIndex += 1
                let drift = (parameters.drift - 0.5 * parameters.volatility * parameters.volatility) * dt
                let diffusion = parameters.volatility * sqrt(dt) * z
                var shock = 0.0
                if parameters.jumpIntensity > 0 {
                    let u = randomNormal(rng: &rng)
                    let lambdaDt = parameters.jumpIntensity * dt
                    let n = poissonRandom(lambda: lambdaDt, rng: &rng)
                    shock = Double(n) * parameters.jumpMean + sqrt(Double(n)) * parameters.jumpVolatility * u
                }
                var return_: Double = 0
                switch parameters.method {
                case .geometricBrownianMotion:
                    return_ = exp(drift + diffusion) - 1
                    currentValue *= (1 + return_)
                case .arithmeticBrownianMotion:
                    return_ = parameters.drift * dt + parameters.volatility * sqrt(dt) * z
                    currentValue += return_
                case .jumpDiffusion:
                    return_ = exp(drift + diffusion) - 1
                    currentValue *= (1 + return_ + shock)
                case .meanReverting:
                    let reversion = parameters.meanReversionSpeed * (parameters.longTermMean - currentValue) * dt
                    currentValue += reversion + parameters.volatility * sqrt(dt) * z
                default:
                    return_ = exp(drift + diffusion) - 1
                    currentValue *= (1 + return_)
                }
                currentValue = max(currentValue, parameters.initialValue * 0.001)
                values.append(currentValue)
                times.append(Double(step) * dt)
            }
            let path = MonteCarloPath(method: parameters.method, values: values, times: times, parameters: ["drift": parameters.drift, "volatility": parameters.volatility], seed: parameters.randomSeed)
            if pathIndex < 100 { currentPaths.append(path) }
            terminalValues.append(currentValue)
            if pathIndex % 1000 == 0 && terminalValues.count >= 1000 {
                convergence = ConvergenceMetrics(pathsSimulated: terminalValues.count, terminalValues: terminalValues)
            }
        }
        let stats = MonteCarloStatistics(paths: parameters.pathCount, steps: parameters.steps, timeHorizon: parameters.timeHorizon, terminalValues: terminalValues)
        statistics = stats
        paths = currentPaths
        convergence = ConvergenceMetrics(pathsSimulated: terminalValues.count, terminalValues: terminalValues)
        return stats
    }

    func cancelSimulation() { cancellationToken?.cancel() }

    func generateVisualizationData(parameters: SimulationParameters, stats: MonteCarloStatistics, samplePaths: [MonteCarloPath]) -> VisualizationData {
        let terminalValues = samplePaths.map { $0.lastValue }
        let binCount = 50
        let minVal = stats.percentile5
        let maxVal = stats.percentile95
        let binWidth = max(0.0001, (maxVal - minVal) / Double(binCount))
        var bins: [(Double, Int, Double)] = []
        var cumulative = 0
        for i in 0..<binCount {
            let binStart = minVal + Double(i) * binWidth
            let binEnd = binStart + binWidth
            let count = terminalValues.filter { $0 >= binStart && $0 < binEnd }.count
            cumulative += count
            bins.append((binStart, count, Double(cumulative) / Double(max(1, terminalValues.count))))
        }
        let percentileTimePoints = zip(samplePaths.first?.times ?? [], samplePaths).map { time, _ in time }
        var percentilesOverTime: [(Double, Double, Double, Double, Double, Double)] = []
        if let referencePath = samplePaths.first, !referencePath.values.isEmpty {
            for step in stride(from: 0, to: referencePath.values.count, by: max(1, referencePath.values.count / 50)) {
                let time = referencePath.times[step]
                let valuesAtStep = samplePaths.compactMap { $0.values.indices.contains(step) ? $0.values[step] : nil }.sorted()
                let n = Double(valuesAtStep.count)
                let p5 = valuesAtStep.indices.contains(Int(n * 0.05)) ? valuesAtStep[Int(n * 0.05)] : 0
                let p25 = valuesAtStep.indices.contains(Int(n * 0.25)) ? valuesAtStep[Int(n * 0.25)] : 0
                let p50 = valuesAtStep.indices.contains(Int(n * 0.5)) ? valuesAtStep[Int(n * 0.5)] : 0
                let p75 = valuesAtStep.indices.contains(Int(n * 0.75)) ? valuesAtStep[Int(n * 0.75)] : 0
                let p95 = valuesAtStep.indices.contains(Int(n * 0.95)) ? valuesAtStep[Int(n * 0.95)] : 0
                percentilesOverTime.append((time, p5, p25, p50, p75, p95))
            }
        }
        let scatterData = terminalValues.enumerated().map { ($0, $1) }
        let heatmapRows = 20
        let heatmapCols = 50
        var heatmap: [[Double]] = Array(repeating: Array(repeating: 0, count: heatmapCols), count: heatmapRows)
        for path in samplePaths {
            for step in stride(from: 0, to: path.values.count, by: max(1, path.values.count / heatmapCols)) {
                let col = step * heatmapCols / max(1, path.values.count)
                let normalizedValue = (path.values[step] - stats.minTerminalValue) / max(stats.maxTerminalValue - stats.minTerminalValue, 0.0001)
                let row = Int(normalizedValue * Double(heatmapRows - 1))
                let clampedRow = min(heatmapRows - 1, max(0, row))
                heatmap[clampedRow][min(col, heatmapCols - 1)] += 1
            }
        }
        let maxHeatmap = heatmap.flatMap { $0 }.max() ?? 1
        let normalizedHeatmap = heatmap.map { $0.map { $0 / Double(maxHeatmap) } }
        let summary = String(format: "Simulated %d paths over %.1f years. Mean: %.2f, Std: %.2f, 95%% CI: [%.2f, %.2f], Probability of loss: %.1f%%", stats.paths, stats.timeHorizon, stats.meanTerminalValue, stats.stdDevTerminalValue, stats.percentile5, stats.percentile95, stats.probabilityOfLoss * 100)
        return VisualizationData(histogramBins: bins, pathSamples: samplePaths, percentilesOverTime: percentilesOverTime, scatterData: scatterData, heatmapData: normalizedHeatmap, summary: summary)
    }
}

private func poissonRandom(lambda: Double, rng: inout SeededGenerator) -> Int {
    guard lambda > 0 else { return 0 }
    let L = exp(-lambda)
    var k = 0
    var p = 1.0
    repeat {
        k += 1
        p *= rng.nextDouble(in: 0...1)
    } while p > L
    return k - 1
}

private func randomNormal(rng: inout SeededGenerator) -> Double {
    var u1 = rng.nextDouble(in: 0.0001...1)
    var u2 = rng.nextDouble(in: 0...1)
    while u1 == 0 { u1 = rng.nextDouble(in: 0.0001...1) }
    return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
}

// MARK: - Sobol Quasi-Random Sequence
struct SobolSequence {
    private var directionNumbers: [[UInt64]]
    private var currentIndex: UInt64 = 0
    private let dimension: Int
    private let maxBits: Int

    init(dimension: Int = 1, maxBits: Int = 32) {
        self.dimension = dimension
        self.maxBits = maxBits
        directionNumbers = Array(repeating: Array(repeating: UInt64(0), count: maxBits), count: dimension)
        directionNumbers[0] = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432, 67108864, 134217728, 268435456, 536870912, 1073741824, 2147483648]
        for d in 1..<dimension {
            var poly = UInt64(d + 1)
            var degree = 0
            while poly > 1 {
                degree += 1
                poly >>= 1
            }
            for i in 0..<maxBits {
                let bit = (currentIndex >> i) & 1
                directionNumbers[d][i] = directionNumbers[d][i] ^ (bit * (1 << (maxBits - i - 1)))
            }
        }
    }

    mutating func nextVector() -> [Double] {
        var result: [Double] = []
        var x = currentIndex
        for d in 0..<dimension {
            var gray = x ^ (x >> 1)
            var value: UInt64 = 0
            for i in 0..<maxBits {
                if ((gray >> i) & 1) == 1 { value ^= directionNumbers[d][i] }
            }
            let normalized = Double(value) / pow(2.0, Double(maxBits))
            result.append(normalized)
        }
        currentIndex &+= 1
        return result
    }
}
