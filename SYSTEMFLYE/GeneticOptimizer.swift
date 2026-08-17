import Foundation
import Accelerate

// MARK: - Genetic Optimization Models
struct Chromosome: Codable, Identifiable, Hashable {
    let id = UUID()
    var genes: [Gene]
    var fitness: Double?
    var age: Int
    var parentIds: [UUID]
    var generation: Int
    var timestamp: Date
    var lineage: [String]
    var metadata: [String: String]

    struct Gene: Codable, Hashable, Identifiable {
        let id = UUID()
        var type: GeneType
        var value: Double
        var minValue: Double
        var maxValue: Double
        var isDiscrete: Bool
        var description: String
        var mutationRate: Double
        var bounds: Bounds?

        enum GeneType: String, Codable, CaseIterable {
            case continuous = "CONTINUOUS"
            case discrete = "DISCRETE"
            case boolean = "BOOLEAN"
            case categorical = "CATEGORICAL"
            case integer = "INTEGER"
            case permutation = "PERMUTATION"
        }

        struct Bounds: Codable {
            var lower: Double
            var upper: Double
            var step: Double
            var softLower: Double?
            var softUpper: Double?
        }

        func mutate(rate: Double, magnitude: Double) -> Gene {
            var newValue = value
            if isDiscrete || type == .integer {
                newValue = round(newValue + (Double.random(in: -1...1) * magnitude))
                newValue = min(max(newValue, minValue), maxValue)
            } else if type == .boolean {
                newValue = Double.random(in: 0...1) < rate ? (newValue > 0.5 ? 0 : 1) : newValue
            } else if type == .permutation {
                let idx1 = Int.random(in: 0..<Int(maxValue))
                let idx2 = Int.random(in: 0..<Int(maxValue))
                var arr = Array(repeating: 0.0, count: Int(maxValue))
                for i in 0..<Int(maxValue) { arr[i] = Double(i) }
                arr.swapAt(idx1, idx2)
                return Gene(type: type, value: newValue, minValue: minValue, maxValue: maxValue, isDiscrete: true, description: description, mutationRate: mutationRate, bounds: bounds)
            } else {
                if Double.random(in: 0...1) < rate {
                    newValue += (Double.random(in: -1...1) * magnitude * (maxValue - minValue))
                    newValue = min(max(newValue, minValue), maxValue)
                }
            }
            return Gene(type: type, value: newValue, minValue: minValue, maxValue: maxValue, isDiscrete: isDiscrete, description: description, mutationRate: mutationRate, bounds: bounds)
        }

        func crossover(with other: Gene, rate: Double) -> Gene {
            guard Double.random(in: 0...1) < rate else { return self }
            let childValue: Double
            switch type {
            case .continuous:
                let alpha = Double.random(in: 0...1)
                childValue = alpha * value + (1 - alpha) * other.value
            case .discrete, .integer:
                childValue = Double.random(in: 0...1) < 0.5 ? value : other.value
                childValue = round(childValue)
            case .boolean:
                childValue = Double.random(in: 0...1) < 0.5 ? value : other.value
            case .categorical:
                childValue = Double.random(in: 0...1) < 0.5 ? value : other.value
            case .permutation:
                childValue = Double.random(in: 0...1) < 0.5 ? value : other.value
            }
            return Gene(type: type, value: min(max(childValue, minValue), maxValue), minValue: minValue, maxValue: maxValue, isDiscrete: isDiscrete, description: description, mutationRate: mutationRate, bounds: bounds)
        }
    }

    init(genes: [Gene] = [], fitness: Double? = nil, age: Int = 0, parentIds: [UUID] = [], generation: Int = 0, timestamp: Date = Date(), lineage: [String] = [], metadata: [String: String] = [:]) {
        self.id = UUID()
        self.genes = genes
        self.fitness = fitness
        self.age = age
        self.parentIds = parentIds
        self.generation = generation
        self.timestamp = timestamp
        self.lineage = lineage
        self.metadata = metadata
    }

    func mutated(rate: Double, magnitude: Double) -> Chromosome {
        let newGenes = genes.map { $0.mutate(rate: rate, magnitude: magnitude) }
        let newLineage = lineage + ["mutated_gen_\(generation)"]
        return Chromosome(genes: newGenes, fitness: nil, age: age + 1, parentIds: [id], generation: generation + 1, lineage: newLineage)
    }

    func crossed(with other: Chromosome, rate: Double) -> Chromosome {
        let newGenes = zip(genes, other.genes).map { $0.crossover(with: $1, rate: rate) }
        let newLineage = lineage + other.lineage + ["crossed_gen_\(generation)"]
        return Chromosome(genes: newGenes, fitness: nil, parentIds: [id, other.id], generation: max(generation, other.generation) + 1, lineage: newLineage)
    }
}

struct GeneticAlgorithmConfiguration: Codable, Identifiable {
    let id = UUID()
    var populationSize: Int
    var generations: Int
    var mutationRate: Double
    var crossoverRate: Double
    var eliteCount: Int
    var tournamentSize: Int
    var convergenceThreshold: Double
    var stagnationLimit: Int
    var diversityPreservation: Bool
    var nichingEnabled: Bool
    var nichingRadius: Double
    var fitnessSharing: Bool
    var sharingSigma: Double
    var sharingAlpha: Double
    var constraints: [Constraint]
    var tags: [String]
    var selectionStrategy: SelectionStrategy
    var crossoverStrategy: CrossoverStrategy
    var adaptiveParameters: Bool

    struct Constraint: Codable, Identifiable {
        let id = UUID()
        var geneIndex: Int
        var constraintType: ConstraintType
        var minValue: Double
        var maxValue: Double
        var penaltyWeight: Double

        enum ConstraintType: String, Codable { case hard = "HARD", soft = "SOFT", penalty = "PENALTY" }
    }

    enum SelectionStrategy: String, Codable, CaseIterable { case tournament, rouletteWheel, rank, stochasticUniversalSampling, linearRanking, exponentialRanking }
    enum CrossoverStrategy: String, Codable, CaseIterable { case singlePoint, twoPoint, uniform, blend, simulatedBinary, wholeArithmetic }

    init(populationSize: Int = 50, generations: Int = 100, mutationRate: Double = 0.05, crossoverRate: Double = 0.7, eliteCount: Int = 5, tournamentSize: Int = 3, convergenceThreshold: Double = 0.001, stagnationLimit: Int = 20, diversityPreservation: Bool = true, nichingEnabled: Bool = false, nichingRadius: Double = 0.1, fitnessSharing: Bool = false, sharingSigma: Double = 0.1, sharingAlpha: Double = 1.0, constraints: [Constraint] = [], tags: [String] = [], selectionStrategy: SelectionStrategy = .tournament, crossoverStrategy: CrossoverStrategy = .uniform, adaptiveParameters: Bool = true) {
        self.id = UUID()
        self.populationSize = max(4, populationSize)
        self.generations = max(1, generations)
        self.mutationRate = max(0, min(1, mutationRate))
        self.crossoverRate = max(0, min(1, crossoverRate))
        self.eliteCount = max(1, min(eliteCount, populationSize / 2))
        self.tournamentSize = max(2, min(tournamentSize, populationSize))
        self.convergenceThreshold = max(0, convergenceThreshold)
        self.stagnationLimit = max(1, stagnationLimit)
        self.diversityPreservation = diversityPreservation
        self.nichingEnabled = nichingEnabled
        self.nichingRadius = max(0, nichingRadius)
        self.fitnessSharing = fitnessSharing
        self.sharingSigma = max(0.0001, sharingSigma)
        self.sharingAlpha = max(0, sharingAlpha)
        self.constraints = constraints
        self.tags = tags
        self.selectionStrategy = selectionStrategy
        self.crossoverStrategy = crossoverStrategy
        self.adaptiveParameters = adaptiveParameters
    }
}

struct OptimizationResult: Codable, Identifiable {
    let id = UUID()
    var bestChromosome: Chromosome
    var bestFitness: Double
    var generation: Int
    var fitnessHistory: [Double]
    var diversityHistory: [Double]
    var convergenceIteration: Int
    var totalEvaluations: Int
    var executionTimeMs: Double
    var population: [Chromosome]
    var timestamp: Date
    var metadata: [String: String]
    var diagnostics: Diagnostics

    struct Diagnostics: Codable {
        let avgFitness: Double
        let stdFitness: Double
        let minFitness: Double
        let maxFitness: Double
        let diversity: Double
        let convergenceRate: Double
        let stagnationCount: Int
        let mutationEfficiency: Double
        let crossoverEfficiency: Double
        let selectionPressure: Double
        let nicheCount: Int
        let dominantGeneFrequency: [String: Double]
    }

    init(bestChromosome: Chromosome, bestFitness: Double, generation: Int, fitnessHistory: [Double] = [], diversityHistory: [Double] = [], convergenceIteration: Int = 0, totalEvaluations: Int = 0, executionTimeMs: Double = 0, population: [Chromosome] = [], metadata: [String: String] = [:], diagnostics: Diagnostics = Diagnostics(avgFitness: 0, stdFitness: 0, minFitness: 0, maxFitness: 0, diversity: 0, convergenceRate: 0, stagnationCount: 0, mutationEfficiency: 0, crossoverEfficiency: 0, selectionPressure: 0, nicheCount: 0, dominantGeneFrequency: [:]), timestamp: Date = Date()) {
        self.id = UUID()
        self.bestChromosome = bestChromosome
        self.bestFitness = bestFitness
        self.generation = generation
        self.fitnessHistory = fitnessHistory
        self.diversityHistory = diversityHistory
        self.convergenceIteration = convergenceIteration
        self.totalEvaluations = totalEvaluations
        self.executionTimeMs = executionTimeMs
        self.population = population
        self.timestamp = timestamp
        self.metadata = metadata
        self.diagnostics = diagnostics
    }
}

// MARK: - Genetic Optimizer Engine
@MainActor
final class GeneticOptimizer: ObservableObject {
    static let shared = GeneticOptimizer()
    @Published private(set) var results: [OptimizationResult] = []
    @Published private(set) var isOptimizing = false
    @Published private(set) var currentGeneration: Int = 0
    @Published private(set) var bestFitness: Double = 0
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50
    private var stagnationCounter = 0
    private var previousBestFitness = 0.0

    func optimize(configuration: GeneticAlgorithmConfiguration, fitnessFunction: @escaping ([Double]) -> Double, initialPopulation: [Chromosome] = [], geneBounds: [(min: Double, max: Double)] = [], constraints: [GeneticAlgorithmConfiguration.Constraint] = []) async -> OptimizationResult {
        guard !isOptimizing else { return OptimizationResult(bestChromosome: Chromosome(), bestFitness: 0, generation: 0, diagnostics: .init(avgFitness: 0, stdFitness: 0, minFitness: 0, maxFitness: 0, diversity: 0, convergenceRate: 0, stagnationCount: 0, mutationEfficiency: 0, crossoverEfficiency: 0, selectionPressure: 0, nicheCount: 0, dominantGeneFrequency: [:])) }
        isOptimizing = true
        defer { isOptimizing = false }
        let startTime = Date()
        let geneCount = geneBounds.count
        let geneDescriptions = (0..<geneCount).map { "gene_\($0)" }
        var population: [Chromosome] = []
        if initialPopulation.isEmpty {
            for _ in 0..<configuration.populationSize {
                let genes = (0..<geneCount).map { index in
                    let bound = geneBounds[index]
                    let randomValue = Double.random(in: bound.min...bound.max)
                    return Chromosome.Gene(type: .continuous, value: randomValue, minValue: bound.min, maxValue: bound.max, isDiscrete: false, description: geneDescriptions[index], mutationRate: configuration.mutationRate, bounds: Chromosome.Gene.Bounds(lower: bound.min, upper: bound.max, step: 0, softLower: nil, softUpper: nil))
                }
                population.append(Chromosome(genes: genes, generation: 0))
            }
        } else { population = initialPopulation }
        var fitnessHistory: [Double] = []
        var diversityHistory: [Double] = []
        var bestChromosome = population[0]
        var bestFitness = Double(-.greatestFiniteMagnitude)
        stagnationCounter = 0
        previousBestFitness = bestFitness
        var convergenceIteration = 0
        var totalEvaluations = 0
        var mutationEfficiency = 0.0
        var crossoverEfficiency = 0.0
        var successfulMutations = 0
        var successfulCrossovers = 0
        for generation in 0..<configuration.generations {
            if Task.isCancelled { break }
            currentGeneration = generation
            let adaptiveMutationRate = configuration.adaptiveParameters ? configuration.mutationRate * (1.0 - Double(generation) / Double(configuration.generations) * 0.5) : configuration.mutationRate
            var evaluatedPopulation: [(chromosome: Chromosome, fitness: Double)] = []
            for chromosome in population {
                let geneValues = chromosome.genes.map { $0.value }
                let fitness = evaluateFitness(geneValues, fitnessFunction: fitnessFunction, constraints: constraints)
                totalEvaluations += 1
                let evaluated = Chromosome(genes: chromosome.genes, fitness: fitness, age: chromosome.age, parentIds: chromosome.parentIds, generation: generation)
                evaluatedPopulation.append((evaluated, fitness))
                if fitness > bestFitness {
                    bestFitness = fitness
                    bestChromosome = evaluated
                    convergenceIteration = generation
                    stagnationCounter = 0
                } else { stagnationCounter += 1 }
            }
            fitnessHistory.append(bestFitness)
            let diversity = calculateDiversity(population: evaluatedPopulation.map { $0.chromosome })
            diversityHistory.append(diversity)
            bestFitness = bestFitness
            if stagnationCounter >= configuration.stagnationLimit { break }
            let sortedPopulation = evaluatedPopulation.sorted { $0.fitness > $1.fitness }
            let elites = sortedPopulation.prefix(configuration.eliteCount).map { $0.chromosome }
            var nextPopulation: [Chromosome] = elites
            while nextPopulation.count < configuration.populationSize {
                let parent1 = selectParent(sortedPopulation, strategy: configuration.selectionStrategy, tournamentSize: configuration.tournamentSize)
                let parent2 = selectParent(sortedPopulation, strategy: configuration.selectionStrategy, tournamentSize: configuration.tournamentSize)
                var child: Chromosome
                if Double.random(in: 0...1) < configuration.crossoverRate {
                    child = parent1.crossed(with: parent2, rate: configuration.crossoverRate)
                    crossoverEfficiency += 1
                    successfulCrossovers += child.fitness ?? 0 > parent1.fitness ?? 0 || child.fitness ?? 0 > parent2.fitness ?? 0 ? 1 : 0
                } else {
                    child = parent1
                }
                if Double.random(in: 0...1) < adaptiveMutationRate {
                    child = child.mutated(rate: adaptiveMutationRate, magnitude: 0.1)
                    mutationEfficiency += 1
                    successfulMutations += child.fitness ?? 0 > parent1.fitness ?? 0 ? 1 : 0
                }
                nextPopulation.append(child)
            }
            population = nextPopulation
            if configuration.fitnessSharing { applyFitnessSharing(population: &population, sigma: configuration.sharingSigma, alpha: configuration.sharingAlpha) }
            if configuration.diversityPreservation && diversity < 0.01 { injectDiversity(into: &population, geneBounds: geneBounds, percentage: 0.1) }
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        mutationEfficiency = mutationEfficiency > 0 ? Double(successfulMutations) / mutationEfficiency : 0
        crossoverEfficiency = crossoverEfficiency > 0 ? Double(successfulCrossovers) / crossoverEfficiency : 0
        let avgFitness = fitnessHistory.reduce(0, +) / Double(max(1, fitnessHistory.count))
        let stdFitness = sqrt(fitnessHistory.map { pow($0 - avgFitness, 2) }.reduce(0, +) / Double(max(1, fitnessHistory.count)))
        let diagnostics = OptimizationResult.Diagnostics(avgFitness: avgFitness, stdFitness: stdFitness, minFitness: fitnessHistory.min() ?? 0, maxFitness: fitnessHistory.max() ?? 0, diversity: diversityHistory.last ?? 0, convergenceRate: convergenceIteration > 0 ? 1.0 / Double(convergenceIteration) : 0, stagnationCount: stagnationCounter, mutationEfficiency: mutationEfficiency, crossoverEfficiency: crossoverEfficiency, selectionPressure: calculateSelectionPressure(population: population), nicheCount: calculateNicheCount(population: population, radius: configuration.nichingRadius), dominantGeneFrequency: calculateDominantGeneFrequency(population: population))
        let result = OptimizationResult(bestChromosome: bestChromosome, bestFitness: bestFitness, generation: currentGeneration, fitnessHistory: fitnessHistory, diversityHistory: diversityHistory, convergenceIteration: convergenceIteration, totalEvaluations: totalEvaluations, executionTimeMs: executionTime, population: population, diagnostics: diagnostics)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        self.bestFitness = bestFitness
        return result
    }

    func cancelOptimization() { cancellationToken?.cancel() }

    private func evaluateFitness(_ genes: [Double], fitnessFunction: ([Double]) -> Double, constraints: [GeneticAlgorithmConfiguration.Constraint]) -> Double {
        let rawFitness = fitnessFunction(genes)
        var penalty = 0.0
        for constraint in constraints {
            let value = genes.indices.contains(constraint.geneIndex) ? genes[constraint.geneIndex] : 0
            if value < constraint.minValue || value > constraint.maxValue {
                penalty += constraint.penaltyWeight * pow(abs(value < constraint.minValue ? constraint.minValue - value : value - constraint.maxValue), 2)
            }
        }
        return rawFitness - penalty
    }

    private func selectParent(_ population: [(Chromosome, Double)], strategy: GeneticAlgorithmConfiguration.SelectionStrategy, tournamentSize: Int) -> Chromosome {
        switch strategy {
        case .tournament: return tournamentSelect(population, size: tournamentSize)
        case .rouletteWheel: return rouletteWheelSelect(population)
        case .rank: return rankSelect(population)
        case .stochasticUniversalSampling: return stochasticUniversalSelect(population)
        case .linearRanking: return linearRankingSelect(population)
        case .exponentialRanking: return exponentialRankingSelect(population)
        }
    }

    private func tournamentSelect(_ population: [(Chromosome, Double)], size: Int) -> Chromosome {
        var best: Chromosome?
        var bestFitness = Double(-.greatestFiniteMagnitude)
        for _ in 0..<size {
            let candidate = population.randomElement()?.chromosome ?? population[0].chromosome
            let fitness = population.first { $0.chromosome.id == candidate.id }?.fitness ?? 0
            if fitness > bestFitness { bestFitness = fitness; best = candidate }
        }
        return best ?? population[0].chromosome
    }

    private func rouletteWheelSelect(_ population: [(Chromosome, Double)]) -> Chromosome {
        let totalFitness = population.map { max($0.fitness, 0) }.reduce(0, +)
        guard totalFitness > 0 else { return population.randomElement()?.chromosome ?? population[0].chromosome }
        var random = Double.random(in: 0...totalFitness)
        for individual in population {
            random -= max(individual.fitness, 0)
            if random <= 0 { return individual.chromosome }
        }
        return population.last?.chromosome ?? population[0].chromosome
    }

    private func rankSelect(_ population: [(Chromosome, Double)]) -> Chromosome {
        let sorted = population.sorted { $0.fitness > $1.fitness }
        let rank = Int.random(in: 0..<sorted.count)
        return sorted[rank].chromosome
    }

    private func stochasticUniversalSelect(_ population: [(Chromosome, Double)]) -> Chromosome {
        let totalFitness = population.map { max($0.fitness, 0) }.reduce(0, +)
        guard totalFitness > 0 else { return population.randomElement()?.chromosome ?? population[0].chromosome }
        let pointer = Double.random(in: 0...(totalFitness / Double(population.count)))
        var current = pointer
        for individual in population {
            current -= max(individual.fitness, 0)
            if current <= 0 { return individual.chromosome }
        }
        return population.last?.chromosome ?? population[0].chromosome
    }

    private func linearRankingSelect(_ population: [(Chromosome, Double)]) -> Chromosome {
        let sorted = population.sorted { $0.fitness > $1.fitness }
        let n = Double(sorted.count)
        let probabilities = (0..<sorted.count).map { (2.0 * (n - Double($0))) / (n * (n + 1)) }
        var random = Double.random(in: 0...1)
        for (index, prob) in probabilities.enumerated() {
            random -= prob
            if random <= 0 { return sorted[index].chromosome }
        }
        return sorted.last?.chromosome ?? sorted[0].chromosome
    }

    private func exponentialRankingSelect(_ population: [(Chromosome, Double)]) -> Chromosome {
        let sorted = population.sorted { $0.fitness > $1.fitness }
        let c = 0.95
        var probabilities: [Double] = []
        for i in 0..<sorted.count { probabilities.append(c * pow(1 - c, Double(i))) }
        let total = probabilities.reduce(0, +)
        probabilities = probabilities.map { $0 / total }
        var random = Double.random(in: 0...1)
        for (index, prob) in probabilities.enumerated() {
            random -= prob
            if random <= 0 { return sorted[index].chromosome }
        }
        return sorted.last?.chromosome ?? sorted[0].chromosome
    }

    private func calculateDiversity(population: [(Chromosome, Double)]) -> Double {
        guard population.count > 1 else { return 0 }
        let geneValues = population.map { $0.chromosome.genes.map { $0.value } }
        var totalDistance = 0.0
        var count = 0
        for i in 0..<geneValues.count {
            for j in i + 1..<geneValues.count {
                let distance = zip(geneValues[i], geneValues[j]).map { pow($0 - $1, 2) }.reduce(0, +)
                totalDistance += distance
                count += 1
            }
        }
        return count > 0 ? totalDistance / Double(count) : 0
    }

    private func applyFitnessSharing(population: inout [Chromosome], sigma: Double, alpha: Double) {
        let n = population.count
        for i in 0..<n {
            var sharingSum = 0.0
            for j in 0..<n where i != j {
                let distance = zip(population[i].genes.map { $0.value }, population[j].genes.map { $0.value }).map { pow($0 - $1, 2) }.reduce(0, +)
                let dist = sqrt(distance)
                if dist < sigma {
                    sharingSum += 1.0 - pow(dist / sigma, alpha)
                }
            }
            let sharedFitness = population[i].fitness ?? 0 / max(sharingSum, 1.0)
            population[i].fitness = sharedFitness
        }
    }

    private func injectDiversity(into population: inout [Chromosome], geneBounds: [(min: Double, max: Double)], percentage: Double) {
        let injectCount = Int(Double(population.count) * percentage)
        for _ in 0..<injectCount {
            let genes = (0..<geneBounds.count).map { index in
                let bound = geneBounds[index]
                let randomValue = Double.random(in: bound.min...bound.max)
                return Chromosome.Gene(type: .continuous, value: randomValue, minValue: bound.min, maxValue: bound.max, isDiscrete: false, description: "gene_\(index)", mutationRate: 0.1, bounds: nil)
            }
            let injectIndex = Int.random(in: 0..<population.count)
            population[injectIndex] = Chromosome(genes: genes, generation: population[injectIndex].generation)
        }
    }

    private func calculateSelectionPressure(population: [Chromosome]) -> Double {
        let fitnesses = population.compactMap { $0.fitness }.sorted()
        guard fitnesses.count > 1 else { return 0 }
        let best = fitnesses.last ?? 0
        let mean = fitnesses.reduce(0, +) / Double(fitnesses.count)
        return mean > 0 ? best / mean : 0
    }

    private func calculateNicheCount(population: [Chromosome], radius: Double) -> Int {
        var niches: [[Chromosome]] = []
        for individual in population {
            var foundNiche = false
            for niche in niches where niche.first?.genes.map { $0.value } == individual.genes.map { $0.value } {
                niche.append(individual)
                foundNiche = true
                break
            }
            if !foundNiche { niches.append([individual]) }
        }
        return niches.count
    }

    private func calculateDominantGeneFrequency(population: [Chromosome]) -> [String: Double] {
        let geneCount = population.first?.genes.count ?? 0
        var frequency: [String: Double] = [:]
        for geneIndex in 0..<geneCount {
            let values = population.map { $0.genes[geneIndex].value }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            frequency["gene_\(geneIndex)"] = variance
        }
        return frequency
    }
}
