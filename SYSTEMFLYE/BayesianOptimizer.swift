import Foundation
import Accelerate

// MARK: - Bayesian Optimization Models
struct BayesianOptimizerState: Codable, Identifiable {
    let id = UUID()
    var observedPoints: [(x: [Double], y: Double)]
    var currentBest: (x: [Double], y: Double)
    var iteration: Int
    var acquisitionValue: Double
    var model: GaussianProcessModel
    var timestamp: Date

    struct GaussianProcessModel: Codable, Identifiable {
        let id = UUID()
        var mean: Double
        var variance: Double
        var lengthScale: Double
        var signalVariance: Double
        var noiseVariance: Double
        var kernelType: KernelType
        var alpha: Double
        var timestamp: Date

        enum KernelType: String, Codable, CaseIterable {
            case rbf = "RBF"
            case matern52 = "MATERN52"
            case matern32 = "MATERN32"
            case rationalQuadratic = "RATIONAL_QUADRATIC"
            case exponential = "EXPONENTIAL"
            case dotProduct = "DOT_PRODUCT"
        }
    }

    init(observedPoints: [(x: [Double], y: Double)] = [], currentBest: (x: [Double], y: Double) = ([], 0), iteration: Int = 0, acquisitionValue: Double = 0, model: GaussianProcessModel = GaussianProcessModel(mean: 0, variance: 1, lengthScale: 1, signalVariance: 1, noiseVariance: 0.1, kernelType: .rbf, alpha: 1e-6), timestamp: Date = Date()) {
        self.id = UUID()
        self.observedPoints = observedPoints
        self.currentBest = currentBest
        self.iteration = iteration
        self.acquisitionValue = acquisitionValue
        self.model = model
        self.timestamp = timestamp
    }
}

struct BayesianOptimizationResult: Codable, Identifiable {
    let id = UUID()
    var bestSolution: [Double]
    var bestObjective: Double
    var convergenceHistory: [(iteration: Int, objective: Double, uncertainty: Double)]
    var acquisitionHistory: [Double]
    var totalEvaluations: Int
    var modelHyperparameters: [String: Double]
    var confidenceInterval: (lower: Double, upper: Double)
    var executionTimeMs: Double
    var timestamp: Date

    init(bestSolution: [Double], bestObjective: Double, convergenceHistory: [(Int, Double, Double)] = [], acquisitionHistory: [Double] = [], totalEvaluations: Int = 0, modelHyperparameters: [String: Double] = [:], confidenceInterval: (Double, Double) = (0, 0), executionTimeMs: Double = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.bestSolution = bestSolution
        self.bestObjective = bestObjective
        self.convergenceHistory = convergenceHistory
        self.acquisitionHistory = acquisitionHistory
        self.totalEvaluations = totalEvaluations
        self.modelHyperparameters = modelHyperparameters
        self.confidenceInterval = confidenceInterval
        self.executionTimeMs = executionTimeMs
        self.timestamp = timestamp
    }
}

// MARK: - Bayesian Optimizer Engine
@MainActor
final class BayesianOptimizer: ObservableObject {
    static let shared = BayesianOptimizer()
    @Published private(set) var results: [BayesianOptimizationResult] = []
    @Published private(set) var isOptimizing = false
    @Published private(set) var currentState: BayesianOptimizerState?
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func optimize(objectiveFunction: @escaping ([Double]) -> Double, bounds: [ClosedRange<Double>], dimensions: Int, initialPoints: Int = 5, iterations: Int = 100, acquisitionFunction: AcquisitionFunction = .expectedImprovement, kernelType: BayesianOptimizerState.GaussianProcessModel.KernelType = .rbf) async -> BayesianOptimizationResult {
        guard !isOptimizing else { return BayesianOptimizationResult(bestSolution: [], bestObjective: 0) }
        isOptimizing = true
        defer { isOptimizing = false }
        let startTime = Date()
        var observedPoints: [(x: [Double], y: Double)] = []
        for _ in 0..<initialPoints {
            let point = (0..<dimensions).map { index in
                let bound = bounds.indices.contains(index) ? bounds[index] : -5.0...5.0
                return Double.random(in: bound)
            }
            let y = objectiveFunction(point)
            observedPoints.append((x: point, y: y))
        }
        let initialBest = observedPoints.max { $0.y < $1.y } ?? observedPoints[0]
        var model = BayesianOptimizerState.GaussianProcessModel(mean: 0, variance: 1, lengthScale: 1.0, signalVariance: 1.0, noiseVariance: 0.1, kernelType: kernelType, alpha: 1e-6)
        var convergenceHistory: [(Int, Double, Double)] = []
        var acquisitionHistory: [Double] = []
        var currentBest = initialBest
        var totalEvaluations = initialPoints
        for iteration in initialPoints..<iterations {
            if Task.isCancelled { break }
            let gpPrediction = predictGaussianProcess(newPoint: currentBest.x, observedPoints: observedPoints, model: model)
            let nextPoint = selectNextPoint(observedPoints: observedPoints, bounds: bounds, dimensions: dimensions, acquisitionFunction: acquisitionFunction, model: model)
            let acquisitionValue = computeAcquisition(point: nextPoint, observedPoints: observedPoints, model: model, function: acquisitionFunction, bestY: currentBest.y)
            let y = objectiveFunction(nextPoint)
            totalEvaluations += 1
            observedPoints.append((x: nextPoint, y: y))
            if y > currentBest.y {
                currentBest = (x: nextPoint, y: y)
                convergenceHistory.append((iteration, y, gpPrediction.variance))
                acquisitionHistory.append(acquisitionValue)
            }
            model = updateHyperparameters(observedPoints: observedPoints, model: model)
            currentState = BayesianOptimizerState(observedPoints: observedPoints, currentBest: currentBest, iteration: iteration, acquisitionValue: acquisitionValue, model: model)
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let result = BayesianOptimizationResult(bestSolution: currentBest.x, bestObjective: currentBest.y, convergenceHistory: convergenceHistory, acquisitionHistory: acquisitionHistory, totalEvaluations: totalEvaluations, modelHyperparameters: ["lengthScale": model.lengthScale, "signalVariance": model.signalVariance, "noiseVariance": model.noiseVariance], confidenceInterval: (currentBest.y - 1.96 * sqrt(model.variance), currentBest.y + 1.96 * sqrt(model.variance)), executionTimeMs: executionTime)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        return result
    }

    func cancelOptimization() { cancellationToken?.cancel() }

    private func computeKernel(x1: [Double], x2: [Double], model: BayesianOptimizerState.GaussianProcessModel) -> Double {
        switch model.kernelType {
        case .rbf:
            let sqDiff = zip(x1, x2).map { pow($0 - $1, 2) }.reduce(0, +)
            return model.signalVariance * exp(-sqDiff / (2 * model.lengthScale * model.lengthScale))
        case .matern52:
            let sqDiff = sqrt(zip(x1, x2).map { pow($0 - $1, 2) }.reduce(0, +))
            let scaledDist = sqrt(5) * sqDiff / max(model.lengthScale, 0.0001)
            return model.signalVariance * (1 + scaledDist) * exp(-scaledDist)
        case .matern32:
            let sqDiff = sqrt(zip(x1, x2).map { pow($0 - $1, 2) }.reduce(0, +))
            let scaledDist = sqrt(3) * sqDiff / max(model.lengthScale, 0.0001)
            return model.signalVariance * (1 + scaledDist) * exp(-scaledDist)
        case .rationalQuadratic:
            let sqDiff = zip(x1, x2).map { pow($0 - $1, 2) }.reduce(0, +)
            return model.signalVariance * pow(1 + sqDiff / (2 * model.alpha * model.lengthScale * model.lengthScale), -model.alpha)
        case .exponential:
            let dist = zip(x1, x2).map { abs($0 - $1) }.reduce(0, +)
            return model.signalVariance * exp(-dist / max(model.lengthScale, 0.0001))
        case .dotProduct:
            return model.signalVariance * zip(x1, x2).map { $0 * $1 }.reduce(0, +)
        }
    }

    private func predictGaussianProcess(newPoint: [Double], observedPoints: [(x: [Double], y: Double)], model: BayesianOptimizerState.GaussianProcessModel) -> (mean: Double, variance: Double) {
        guard !observedPoints.isEmpty else { return (0, model.signalVariance) }
        let n = observedPoints.count
        var K = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        var kStar = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            for j in 0..<n {
                K[i][j] = computeKernel(x1: observedPoints[i].x, x2: observedPoints[j].x, model: model)
                if i == j { K[i][j] += model.noiseVariance }
            }
            kStar[i] = computeKernel(x1: newPoint, x2: observedPoints[i].x, model: model)
        }
        let y = observedPoints.map { $0.y }
        let L = choleskyDecomposition(K)
        let alpha = solveLowerTriangular(L, solveLowerTriangularTranspose(L, y))
        let mean = zip(kStar, alpha).map { $0 * $1 }.reduce(0, +)
        let v = solveLowerTriangular(L, kStar)
        let variance = computeKernel(x1: newPoint, x2: newPoint, model: model) - zip(v, v).map { $0 * $1 }.reduce(0, +) + model.noiseVariance
        return (mean, max(0, variance))
    }

    private func computeAcquisition(point: [Double], observedPoints: [(x: [Double], y: Double)], model: BayesianOptimizerState.GaussianProcessModel, function: AcquisitionFunction, bestY: Double) -> Double {
        let prediction = predictGaussianProcess(newPoint: point, observedPoints: observedPoints, model: model)
        let mean = prediction.mean
        let variance = prediction.variance
        let std = sqrt(max(variance, 0))
        switch function {
        case .expectedImprovement:
            let z = std > 0 ? (mean - bestY) / std : 0
            return std > 0 ? (mean - bestY) * normalCDF(z) + std * normalPDF(z) : max(0, mean - bestY)
        case .upperConfidenceBound:
            return mean + 2.0 * std
        case .probabilityOfImprovement:
            let z = std > 0 ? (mean - bestY) / std : 0
            return normalCDF(z)
        case .entropySearch:
            return variance > 0 ? 0.5 * log(2 * .pi * .e * variance) : 0
        case .knowledgeGradient:
            return std * normalPDF((mean - bestY) / max(std, 0.0001))
        }
    }

    private func selectNextPoint(observedPoints: [(x: [Double], y: Double)], bounds: [ClosedRange<Double>], dimensions: Int, acquisitionFunction: AcquisitionFunction, model: BayesianOptimizerState.GaussianProcessModel) -> [Double] {
        let gridSize = 20
        var bestPoint = (0..<dimensions).map { index in
            let bound = bounds.indices.contains(index) ? bounds[index] : -5.0...5.0
            return Double.random(in: bound)
        }
        var bestAcquisition = -Double.greatestFiniteMagnitude
        for _ in 0..<50 {
            let candidate = (0..<dimensions).map { index in
                let bound = bounds.indices.contains(index) ? bounds[index] : -5.0...5.0
                return Double.random(in: bound)
            }
            let acquisition = computeAcquisition(point: candidate, observedPoints: observedPoints, model: model, function: acquisitionFunction, bestY: observedPoints.map { $0.y }.max() ?? 0)
            if acquisition > bestAcquisition {
                bestAcquisition = acquisition
                bestPoint = candidate
            }
        }
        return bestPoint
    }

    private func updateHyperparameters(observedPoints: [(x: [Double], y: Double)], model: BayesianOptimizerState.GaussianProcessModel) -> BayesianOptimizerState.GaussianProcessModel {
        let ys = observedPoints.map { $0.y }
        let meanY = ys.reduce(0, +) / Double(max(1, ys.count))
        var varianceY = ys.map { pow($0 - meanY, 2) }.reduce(0, +) / Double(max(1, ys.count))
        let lengthScale = max(0.01, model.lengthScale * (1 + Double.random(in: -0.1...0.1)))
        return BayesianOptimizerState.GaussianProcessModel(mean: meanY, variance: varianceY, lengthScale: lengthScale, signalVariance: max(0.01, model.signalVariance), noiseVariance: max(1e-6, model.noiseVariance), kernelType: model.kernelType, alpha: model.alpha)
    }

    private func choleskyDecomposition(_ matrix: [[Double]]) -> [[Double]] {
        let n = matrix.count
        var L = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in 0...i {
                var sum = matrix[i][j]
                for k in 0..<j { sum -= L[i][k] * L[j][k] }
                if i == j { L[i][j] = sqrt(max(sum, 0)) } else { L[i][j] = sum / max(L[j][j], 0.0001) }
            }
        }
        return L
    }

    private func solveLowerTriangular(_ L: [[Double]], _ b: [Double]) -> [Double] {
        let n = L.count
        var x = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            var sum = b[i]
            for j in 0..<i { sum -= L[i][j] * x[j] }
            x[i] = sum / max(L[i][i], 0.0001)
        }
        return x
    }

    private func solveLowerTriangularTranspose(_ L: [[Double]], _ b: [Double]) -> [Double] {
        let n = L.count
        var x = Array(repeating: 0.0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = b[i]
            for j in i + 1..<n { sum -= L[j][i] * x[j] }
            x[i] = sum / max(L[i][i], 0.0001)
        }
        return x
    }

    private func normalCDF(_ x: Double) -> Double {
        return 0.5 * erfc(-x / sqrt(2))
    }

    private func normalPDF(_ x: Double) -> Double {
        return exp(-0.5 * x * x) / sqrt(2 * .pi)
    }
}

enum AcquisitionFunction: String, Codable, CaseIterable {
    case expectedImprovement = "EI"
    case upperConfidenceBound = "UCB"
    case probabilityOfImprovement = "PI"
    case entropySearch = "ENTROPY"
    case knowledgeGradient = "KG"
}
