import Foundation
import Accelerate

// MARK: - Simulated Annealing Models
struct AnnealingState: Codable, Identifiable {
    let id = UUID()
    var solution: [Double]
    var energy: Double
    var temperature: Double
    var iteration: Int
    var acceptedCount: Int
    var rejectedCount: Int
    var improvementCount: Int
    var timestamp: Date

    init(solution: [Double], energy: Double, temperature: Double, iteration: Int = 0, acceptedCount: Int = 0, rejectedCount: Int = 0, improvementCount: Int = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.solution = solution
        self.energy = energy
        self.temperature = temperature
        self.iteration = iteration
        self.acceptedCount = acceptedCount
        self.rejectedCount = rejectedCount
        self.improvementCount = improvementCount
        self.timestamp = timestamp
    }
}

struct AnnealingConfiguration: Codable, Identifiable {
    let id = UUID()
    var initialTemperature: Double
    var finalTemperature: Double
    var coolingSchedule: CoolingSchedule
    var maxIterations: Int
    var stepSize: Double
    var dimension: Int
    var bounds: [ClosedRange<Double>]
    var acceptanceCriterion: AcceptanceCriterion
    var reheatingEnabled: Bool
    var reheatingThreshold: Int
    var reheatingFactor: Double
    var adaptiveStepSize: Bool
    var constraintHandling: ConstraintHandling
    var tags: [String]

    enum CoolingSchedule: String, Codable, CaseIterable {
        case linear = "LINEAR"
        case exponential = "EXPONENTIAL"
        case logarithmic = "LOGARITHMIC"
        case quadratic = "QUADRATIC"
        case adaptive = "ADAPTIVE"
        case cauchy = "CAUCHY"
        case fast = "FAST"
        case boltzmann = "BOLTZMANN"
    }

    enum AcceptanceCriterion: String, Codable, CaseIterable {
        case metropolis = "METROPOLIS"
        case heatBath = "HEAT_BATH"
        case modifiedMetropolis = "MODIFIED_METROPOLIS"
        case ssa = "SSA"
    }

    enum ConstraintHandling: String, Codable, CaseIterable {
        case penalty = "PENALTY"
        case repair = "REPAIR"
        case rejection = "REJECTION"
        case lagrange = "LAGRANGE"
    }

    init(initialTemperature: Double = 1000, finalTemperature: Double = 0.01, coolingSchedule: CoolingSchedule = .exponential, maxIterations: Int = 1000, stepSize: Double = 0.1, dimension: Int = 10, bounds: [ClosedRange<Double>] = [], acceptanceCriterion: AcceptanceCriterion = .metropolis, reheatingEnabled: Bool = true, reheatingThreshold: Int = 100, reheatingFactor: Double = 2.0, adaptiveStepSize: Bool = true, constraintHandling: ConstraintHandling = .penalty, tags: [String] = []) {
        self.id = UUID()
        self.initialTemperature = max(0, initialTemperature)
        self.finalTemperature = max(0, finalTemperature)
        self.coolingSchedule = coolingSchedule
        self.maxIterations = max(1, maxIterations)
        self.stepSize = max(0.0001, stepSize)
        self.dimension = max(1, dimension)
        self.bounds = bounds
        self.acceptanceCriterion = acceptanceCriterion
        self.reheatingEnabled = reheatingEnabled
        self.reheatingThreshold = max(1, reheatingThreshold)
        self.reheatingFactor = max(1, reheatingFactor)
        self.adaptiveStepSize = adaptiveStepSize
        self.constraintHandling = constraintHandling
        self.tags = tags
    }
}

struct SimulatedAnnealingResult: Codable, Identifiable {
    let id = UUID()
    var bestState: AnnealingState
    var bestEnergy: Double
    var iterations: Int
    var acceptedMoves: Int
    var rejectedMoves: Int
    var improvementMoves: Int
    var energyHistory: [Double]
    var temperatureHistory: [Double]
    var convergenceIteration: Int
    var totalEvaluations: Int
    var executionTimeMs: Double
    var reheatingEvents: Int
    var timestamp: Date

    init(bestState: AnnealingState, bestEnergy: Double, iterations: Int, acceptedMoves: Int, rejectedMoves: Int, improvementMoves: Int, energyHistory: [Double] = [], temperatureHistory: [Double] = [], convergenceIteration: Int = 0, totalEvaluations: Int = 0, executionTimeMs: Double = 0, reheatingEvents: Int = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.bestState = bestState
        self.bestEnergy = bestEnergy
        self.iterations = iterations
        self.acceptedMoves = acceptedMoves
        self.rejectedMoves = rejectedMoves
        self.improvementMoves = improvementMoves
        self.energyHistory = energyHistory
        self.temperatureHistory = temperatureHistory
        self.convergenceIteration = convergenceIteration
        self.totalEvaluations = totalEvaluations
        self.executionTimeMs = executionTime
        self.reheatingEvents = reheatingEvents
        self.timestamp = timestamp
    }
}

// MARK: - Simulated Annealing Optimizer Engine
@MainActor
final class SimulatedAnnealingOptimizer: ObservableObject {
    static let shared = SimulatedAnnealingOptimizer()
    @Published private(set) var results: [SimulatedAnnealingResult] = []
    @Published private(set) var isOptimizing = false
    @Published private(set) var currentTemperature: Double = 0
    @Published private(set) var currentEnergy: Double = 0
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func optimize(configuration: AnnealingConfiguration, energyFunction: @escaping ([Double]) -> Double) async -> SimulatedAnnealingResult {
        guard !isOptimizing else { return SimulatedAnnealingResult(bestState: AnnealingState(solution: [], energy: 0, temperature: 0), bestEnergy: 0, iterations: 0, acceptedMoves: 0, rejectedMoves: 0, improvementMoves: 0) }
        isOptimizing = true
        defer { isOptimizing = false }
        let startTime = Date()
        let bounds = configuration.bounds.isEmpty ? Array(repeating: -5.0...5.0, count: configuration.dimension) : configuration.bounds
        var currentSolution = (0..<configuration.dimension).map { index in
            let bound = bounds.indices.contains(index) ? bounds[index] : -5.0...5.0
            return Double.random(in: bound)
        }
        var currentEnergy = energyFunction(currentSolution)
        var bestSolution = currentSolution
        var bestEnergy = currentEnergy
        var temperature = configuration.initialTemperature
        var acceptedMoves = 0
        var rejectedMoves = 0
        var improvementMoves = 0
        var energyHistory: [Double] = [currentEnergy]
        var temperatureHistory: [Double] = [temperature]
        var convergenceIteration = 0
        var reheatingEvents = 0
        var totalEvaluations = 1
        var stepsSinceImprovement = 0
        for iteration in 0..<configuration.maxIterations {
            if Task.isCancelled { break }
            currentTemperature = temperature
            currentEnergy = currentEnergy
            let neighbor = generateNeighbor(currentSolution, stepSize: configuration.stepSize, bounds: bounds)
            let neighborEnergy = energyFunction(neighbor)
            totalEvaluations += 1
            let deltaEnergy = neighborEnergy - currentEnergy
            var accepted = false
            switch configuration.acceptanceCriterion {
            case .metropolis:
                if deltaEnergy < 0 || Double.random(in: 0...1) < exp(-deltaEnergy / max(temperature, 0.0001)) { accepted = true }
            case .heatBath:
                let probability = 1.0 / (1.0 + exp(deltaEnergy / max(temperature, 0.0001)))
                if Double.random(in: 0...1) < probability { accepted = true }
            case .modifiedMetropolis:
                if deltaEnergy < 0 || Double.random(in: 0...1) < exp(-deltaEnergy / max(temperature, 0.0001) * 0.8) { accepted = true }
            case .ssa:
                if deltaEnergy < 0 || Double.random(in: 0...1) < exp(-deltaEnergy / max(temperature, 0.0001)) { accepted = true }
            }
            if accepted {
                currentSolution = neighbor
                currentEnergy = neighborEnergy
                acceptedMoves += 1
                if neighborEnergy < bestEnergy {
                    bestEnergy = neighborEnergy
                    bestSolution = neighbor
                    improvementMoves += 1
                    stepsSinceImprovement = 0
                    convergenceIteration = iteration
                }
            } else { rejectedMoves += 1 }
            energyHistory.append(currentEnergy)
            temperatureHistory.append(temperature)
            let coolingRate: Double
            switch configuration.coolingSchedule {
            case .linear: coolingRate = 1.0 - Double(iteration) / Double(configuration.maxIterations)
            case .exponential: coolingRate = exp(-Double(iteration) / Double(configuration.maxIterations) * 5)
            case .logarithmic: coolingRate = log(Double(iteration) + 1) / log(Double(configuration.maxIterations) + 1)
            case .quadratic: coolingRate = pow(1.0 - Double(iteration) / Double(configuration.maxIterations), 2)
            case .adaptive:
                let ratio = iteration > 0 ? Double(acceptedMoves) / Double(iteration) : 1.0
                coolingRate = max(0.1, min(1.0, 1.0 + log(max(ratio, 0.01))))
            case .cauchy: coolingRate = 1.0 / (1.0 + Double(iteration) / Double(configuration.maxIterations))
            case .fast: coolingRate = 1.0 / (1.0 + iteration)
            case .boltzmann: coolingRate = configuration.initialTemperature / log(Double(iteration) + 2)
            }
            temperature = max(configuration.finalTemperature, configuration.initialTemperature * coolingRate)
            stepsSinceImprovement += 1
            if configuration.reheatingEnabled && stepsSinceImprovement >= configuration.reheatingThreshold {
                temperature *= configuration.reheatingFactor
                reheatingEvents += 1
                stepsSinceImprovement = 0
            }
            if configuration.adaptiveStepSize {
                configuration.stepSize = acceptedMoves > 0 ? configuration.stepSize * 1.01 : configuration.stepSize * 0.99
            }
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let resultState = AnnealingState(solution: bestSolution, energy: bestEnergy, temperature: configuration.finalTemperature, iteration: configuration.maxIterations, acceptedCount: acceptedMoves, rejectedCount: rejectedMoves, improvementCount: improvementMoves)
        let result = SimulatedAnnealingResult(bestState: resultState, bestEnergy: bestEnergy, iterations: configuration.maxIterations, acceptedMoves: acceptedMoves, rejectedMoves: rejectedMoves, improvementMoves: improvementMoves, energyHistory: energyHistory, temperatureHistory: temperatureHistory, convergenceIteration: convergenceIteration, totalEvaluations: totalEvaluations, executionTimeMs: executionTime, reheatingEvents: reheatingEvents)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        return result
    }

    func cancelOptimization() { cancellationToken?.cancel() }

    private func generateNeighbor(_ solution: [Double], stepSize: Double, bounds: [ClosedRange<Double>]) -> [Double] {
        var neighbor = solution
        let index = Int.random(in: 0..<solution.count)
        let change = (Double.random(in: -1...1) * stepSize)
        let bound = bounds.indices.contains(index) ? bounds[index] : -5.0...5.0
        neighbor[index] = min(max(neighbor[index] + change, bound.lowerBound), bound.upperBound)
        return neighbor
    }
}
