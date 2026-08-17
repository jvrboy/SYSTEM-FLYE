import Foundation
import Accelerate

// MARK: - Particle Swarm Models
struct Particle: Codable, Identifiable, Hashable {
    let id = UUID()
    var position: [Double]
    var velocity: [Double]
    var bestPosition: [Double]
    var bestFitness: Double
    var currentFitness: Double
    var age: Int
    var dimension: Int
    var timestamp: Date
    var personalBestHistory: [(position: [Double], fitness: Double)]
    var neighbors: [UUID]
    var constraintsViolated: Int
    var metadata: [String: String]

    init(position: [Double], velocity: [Double] = [], bestPosition: [Double]? = nil, bestFitness: Double = -.greatestFiniteMagnitude, currentFitness: Double = 0, age: Int = 0, dimension: Int = 0, timestamp: Date = Date(), personalBestHistory: [(position: [Double], fitness: Double)] = [], neighbors: [UUID] = [], constraintsViolated: Int = 0, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.position = position
        self.velocity = velocity
        self.bestPosition = bestPosition ?? position
        self.bestFitness = bestFitness
        self.currentFitness = currentFitness
        self.age = age
        self.dimension = dimension
        self.timestamp = timestamp
        self.personalBestHistory = personalBestHistory
        self.neighbors = neighbors
        self.constraintsViolated = constraintsViolated
        self.metadata = metadata
    }
}

struct SwarmConfiguration: Codable, Identifiable {
    let id = UUID()
    var swarmSize: Int
    var dimensions: Int
    var iterations: Int
    var inertiaWeight: Double
    var inertiaDecay: InertiaDecay
    var cognitiveCoefficient: Double
    var socialCoefficient: Double
    var maxVelocity: Double
    var positionBounds: [ClosedRange<Double>]
    var velocityBounds: [ClosedRange<Double>]
    var velocityClamping: Bool
    var constrictionFactor: Double
    var neighborTopology: NeighborTopology
    var diversityMechanism: DiversityMechanism
    var adaptiveParameters: Bool
    var tags: [String]
    var createdAt: Date

    enum InertiaDecay: String, Codable, CaseIterable { case linear, exponential, logarithmic, adaptive, constant, random }
    enum NeighborTopology: String, Codable, CaseIterable { case global = "GLOBAL", ring = "RING", vonNeumann = "VON_NEUMANN", random = "RANDOM", hierarchical = "HIERARCHICAL", adaptive = "ADAPTIVE" }
    enum DiversityMechanism: String, Codable, CaseIterable { case none = "NONE", randomRestart = "RANDOM_RESTART", reinitialize = "REINITIALIZE", mutation = "MUTATION", attractorRepulsor = "ATTRACTOR_REPULSOR" }

    init(swarmSize: Int = 30, dimensions: Int = 10, iterations: Int = 200, inertiaWeight: Double = 0.729, inertiaDecay: InertiaDecay = .exponential, cognitiveCoefficient: Double = 1.494, socialCoefficient: Double = 1.494, maxVelocity: Double = 0.2, positionBounds: [ClosedRange<Double>] = [], velocityBounds: [ClosedRange<Double>] = [], velocityClamping: Bool = true, constrictionFactor: Double = 0.729, neighborTopology: NeighborTopology = .global, diversityMechanism: DiversityMechanism = .none, adaptiveParameters: Bool = true, tags: [String] = [], createdAt: Date = Date()) {
        self.id = UUID()
        self.swarmSize = max(2, swarmSize)
        self.dimensions = max(1, dimensions)
        self.iterations = max(1, iterations)
        self.inertiaWeight = max(0, min(1, inertiaWeight))
        self.inertiaDecay = inertiaDecay
        self.cognitiveCoefficient = max(0, cognitiveCoefficient)
        self.socialCoefficient = max(0, socialCoefficient)
        self.maxVelocity = max(0, maxVelocity)
        self.positionBounds = positionBounds
        self.velocityBounds = velocityBounds
        self.velocityClamping = velocityClamping
        self.constrictionFactor = max(0, constrictionFactor)
        self.neighborTopology = neighborTopology
        self.diversityMechanism = diversityMechanism
        self.adaptiveParameters = adaptiveParameters
        self.tags = tags
        self.createdAt = createdAt
    }
}

struct PSOOptimizationResult: Codable, Identifiable {
    let id = UUID()
    var bestParticle: Particle
    var bestFitness: Double
    var iteration: Int
    var fitnessHistory: [Double]
    var diversityHistory: [Double]
    var averageFitness: [Double]
    var convergenceIteration: Int
    var totalEvaluations: Int
    var executionTimeMs: Double
    var swarm: [Particle]
    var timestamp: Date
    var diagnostics: Diagnostics

    struct Diagnostics: Codable {
        let velocityMean: [Double]
        let velocityStd: [Double]
        let explorationRatio: Double
        let exploitationRatio: Double
        let neighborhoodConnectivity: Double
        let diversityTrend: String
        let stagnationCount: Int
        let bestNeighborhoodSize: Int
    }

    init(bestParticle: Particle, bestFitness: Double, iteration: Int, fitnessHistory: [Double] = [], diversityHistory: [Double] = [], averageFitness: [Double] = [], convergenceIteration: Int = 0, totalEvaluations: Int = 0, executionTimeMs: Double = 0, swarm: [Particle] = [], diagnostics: Diagnostics = Diagnostics(velocityMean: [], velocityStd: [], explorationRatio: 0, exploitationRatio: 0, neighborhoodConnectivity: 0, diversityTrend: "", stagnationCount: 0, bestNeighborhoodSize: 0), timestamp: Date = Date()) {
        self.id = UUID()
        self.bestParticle = bestParticle
        self.bestFitness = bestFitness
        self.iteration = iteration
        self.fitnessHistory = fitnessHistory
        self.diversityHistory = diversityHistory
        self.averageFitness = averageFitness
        self.convergenceIteration = convergenceIteration
        self.totalEvaluations = totalEvaluations
        self.executionTimeMs = executionTimeMs
        self.swarm = swarm
        self.timestamp = timestamp
        self.diagnostics = diagnostics
    }
}

// MARK: - Particle Swarm Optimizer Engine
@MainActor
final class ParticleSwarmOptimizer: ObservableObject {
    static let shared = ParticleSwarmOptimizer()
    @Published private(set) var results: [PSOOptimizationResult] = []
    @Published private(set) var isOptimizing = false
    @Published private(set) var currentIteration: Int = 0
    @Published private(set) var bestFitness: Double = 0
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50
    private var globalBestPosition: [Double] = []
    private var globalBestFitness = Double(-.greatestFiniteMagnitude)
    private var stagnationCounter = 0

    func optimize(configuration: SwarmConfiguration, fitnessFunction: @escaping ([Double]) -> Double, initialSwarm: [Particle] = []) async -> PSOOptimizationResult {
        guard !isOptimizing else { return PSOOptimizationResult(bestParticle: Particle(position: []), bestFitness: 0, iteration: 0, diagnostics: .init(velocityMean: [], velocityStd: [], explorationRatio: 0, exploitationRatio: 0, neighborhoodConnectivity: 0, diversityTrend: "", stagnationCount: 0, bestNeighborhoodSize: 0)) }
        isOptimizing = true
        defer { isOptimizing = false }
        let startTime = Date()
        let defaultBounds = configuration.positionBounds.isEmpty ? Array(repeating: -5.0...5.0, count: configuration.dimensions) : configuration.positionBounds
        let defaultVelocityBounds = configuration.velocityBounds.isEmpty ? Array(repeating: -0.5...0.5, count: configuration.dimensions) : configuration.velocityBounds
        var swarm: [Particle] = []
        if initialSwarm.isEmpty {
            for _ in 0..<configuration.swarmSize {
                let position = (0..<configuration.dimensions).map { index in
                    let bound = defaultBounds.indices.contains(index) ? defaultBounds[index] : -5.0...5.0
                    return Double.random(in: bound)
                }
                let velocity = (0..<configuration.dimensions).map { index in
                    let bound = defaultVelocityBounds.indices.contains(index) ? defaultVelocityBounds[index] : -0.5...0.5
                    return Double.random(in: bound)
                }
                swarm.append(Particle(position: position, velocity: velocity, dimension: configuration.dimensions))
            }
        } else { swarm = initialSwarm }
        globalBestPosition = swarm[0].position
        globalBestFitness = Double(-.greatestFiniteMagnitude)
        stagnationCounter = 0
        var fitnessHistory: [Double] = []
        var diversityHistory: [Double] = []
        var averageFitness: [Double] = []
        var convergenceIteration = 0
        var totalEvaluations = 0
        for iteration in 0..<configuration.iterations {
            if Task.isCancelled { break }
            currentIteration = iteration
            var iterBestFitness = Double(-.greatestFiniteMagnitude)
            for particle in swarm {
                let fitness = fitnessFunction(particle.position)
                totalEvaluations += 1
                particle.currentFitness = fitness
                if fitness > particle.bestFitness {
                    particle.bestFitness = fitness
                    particle.bestPosition = particle.position
                    particle.personalBestHistory.append((position: particle.position, fitness: fitness))
                    if particle.personalBestHistory.count > 50 { particle.personalBestHistory.removeFirst() }
                }
                if fitness > globalBestFitness {
                    globalBestFitness = fitness
                    globalBestPosition = particle.position
                    convergenceIteration = iteration
                    stagnationCounter = 0
                }
                if fitness > iterBestFitness { iterBestFitness = fitness }
            }
            fitnessHistory.append(globalBestFitness)
            let diversity = calculateDiversity(swarm: swarm)
            diversityHistory.append(diversity)
            let avgFit = swarm.map { $0.currentFitness }.reduce(0, +) / Double(swarm.count)
            averageFitness.append(avgFit)
            bestFitness = globalBestFitness
            for i in 0..<swarm.count {
                var newVelocity = swarm[i].velocity
                let r1 = Double.random(in: 0...1)
                let r2 = Double.random(in: 0...1)
                let inertia = configuration.adaptiveParameters ? calculateAdaptiveInertia(iteration: iteration, maxIterations: configuration.iterations, initialInertia: configuration.inertiaWeight, decay: configuration.inertiaDecay) : configuration.inertiaWeight
                for d in 0..<configuration.dimensions {
                    let cognitive = configuration.cognitiveCoefficient * r1 * (swarm[i].bestPosition[d] - swarm[i].position[d])
                    let social = configuration.socialCoefficient * r2 * (globalBestPosition[d] - swarm[i].position[d])
                    var velocityUpdate = inertia * swarm[i].velocity[d] + cognitive + social
                    if configuration.velocityClamping {
                        let maxV = defaultVelocityBounds.indices.contains(d) ? defaultVelocityBounds[d].upperBound : 0.5
                        velocityUpdate = min(max(velocityUpdate, -maxV), maxV)
                    }
                    newVelocity[d] = velocityUpdate
                    swarm[i].position[d] += newVelocity[d]
                    let bound = defaultBounds.indices.contains(d) ? defaultBounds[d] : -5.0...5.0
                    swarm[i].position[d] = min(max(swarm[i].position[d], bound.lowerBound), bound.upperBound)
                }
                swarm[i].velocity = newVelocity
            }
            if configuration.diversityMechanism != .none && diversity < 0.001 {
                for i in 0..<swarm.count {
                    swarm[i].position = (0..<configuration.dimensions).map { index in
                        let bound = defaultBounds.indices.contains(index) ? defaultBounds[index] : -5.0...5.0
                        return Double.random(in: bound)
                    }
                }
                stagnationCounter += 1
            }
            if stagnationCounter >= 50 {
                globalBestPosition = (0..<configuration.dimensions).map { index in
                    let bound = defaultBounds.indices.contains(index) ? defaultBounds[index] : -5.0...5.0
                    return Double.random(in: bound)
                }
                globalBestFitness = Double(-.greatestFiniteMagnitude)
                stagnationCounter = 0
            }
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let bestParticle = swarm.max { $0.currentFitness < $1.currentFitness } ?? swarm[0]
        let velocityMeans = (0..<configuration.dimensions).map { d in swarm.map { $0.velocity[d] }.reduce(0, +) / Double(swarm.count) }
        let velocityStds = (0..<configuration.dimensions).map { d in sqrt(swarm.map { pow($0.velocity[d] - velocityMeans[d], 2) }.reduce(0, +) / Double(swarm.count)) }
        let diagnostics = PSOOptimizationResult.Diagnostics(velocityMean: velocityMeans, velocityStd: velocityStds, explorationRatio: 0.5, exploitationRatio: 0.5, neighborhoodConnectivity: 0.8, diversityTrend: diversityHistory.count > 1 ? (diversityHistory.last ?? 0 > diversityHistory.first ?? 0 ? "increasing" : "decreasing") : "stable", stagnationCount: stagnationCounter, bestNeighborhoodSize: configuration.swarmSize / 5)
        let result = PSOOptimizationResult(bestParticle: bestParticle, bestFitness: globalBestFitness, iteration: currentIteration, fitnessHistory: fitnessHistory, diversityHistory: diversityHistory, averageFitness: averageFitness, convergenceIteration: convergenceIteration, totalEvaluations: totalEvaluations, executionTimeMs: executionTime, swarm: swarm, diagnostics: diagnostics)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        self.bestFitness = globalBestFitness
        return result
    }

    func cancelOptimization() { cancellationToken?.cancel() }

    private func calculateAdaptiveInertia(iteration: Int, maxIterations: Int, initialInertia: Double, decay: SwarmConfiguration.InertiaDecay) -> Double {
        let progress = Double(iteration) / Double(maxIterations)
        switch decay {
        case .linear: return initialInertia * (1.0 - progress)
        case .exponential: return initialInertia * exp(-5.0 * progress)
        case .logarithmic: return initialInertia * (log(Double(maxIterations) + 1) / log(Double(iteration) + 2))
        case .adaptive: return initialInertia * (1.0 + 0.5 * sin(progress * .pi))
        case .constant: return initialInertia
        case .random: return Double.random(in: initialInertia * 0.5...initialInertia)
        }
    }

    private func calculateDiversity(swarm: [Particle]) -> Double {
        guard swarm.count > 1 else { return 0 }
        let positions = swarm.map { $0.position }
        var totalDistance = 0.0
        var count = 0
        for i in 0..<positions.count {
            for j in i + 1..<positions.count {
                let distance = zip(positions[i], positions[j]).map { pow($0 - $1, 2) }.reduce(0, +)
                totalDistance += distance
                count += 1
            }
        }
        return count > 0 ? totalDistance / Double(count) : 0
    }
}
