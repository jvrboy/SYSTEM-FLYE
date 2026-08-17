import Foundation
import Accelerate

// MARK: - Reinforcement Learning Models
enum RLAlgorithm: String, Codable, CaseIterable {
    case qLearning = "Q_LEARNING"
    case deepQNetwork = "DQN"
    case doubleDQN = "DOUBLE_DQN"
    case duelingDQN = "DUELING_DQN"
    case policyGradient = "POLICY_GRADIENT"
    case actorCritic = "ACTOR_CRITIC"
    case proximalPolicyOptimization = "PPO"
    case softActorCritic = "SAC"
    case deterministicPolicyGradient = "DPG"
    case multiArmedBandit = "MAB"
}

struct State: Codable, Hashable, Identifiable {
    let id = UUID()
    var features: [Double]
    var categoricalFeatures: [String: String]
    var timestamp: Date

    var featureCount: Int { features.count }

    init(features: [Double] = [], categoricalFeatures: [String: String] = [:], timestamp: Date = Date()) {
        self.id = UUID()
        self.features = features
        self.categoricalFeatures = categoricalFeatures
        self.timestamp = timestamp
    }
}

struct Action: Codable, Hashable, Identifiable {
    let id = UUID()
    var value: Int
    var description: String
    var parameters: [String: Double]
    var timestamp: Date

    init(value: Int, description: String = "", parameters: [String: Double] = [:], timestamp: Date = Date()) {
        self.id = UUID()
        self.value = value
        self.description = description
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

struct Transition: Codable, Identifiable {
    let id = UUID()
    var state: State
    var action: Action
    var reward: Double
    var nextState: State
    var done: Bool
    var timestamp: Date

    init(state: State, action: Action, reward: Double, nextState: State, done: Bool = false, timestamp: Date = Date()) {
        self.id = UUID()
        self.state = state
        self.action = action
        self.reward = reward
        self.nextState = nextState
        self.done = done
        self.timestamp = timestamp
    }
}

struct ExperienceBuffer: Codable, Identifiable {
    let id = UUID()
    var transitions: [Transition]
    var capacity: Int
    var position: Int
    var size: Int

    mutating func add(_ transition: Transition) {
        if transitions.count < capacity {
            transitions.append(transition)
        } else {
            transitions[position] = transition
        }
        position = (position + 1) % capacity
        size = min(transitions.count + 1, capacity)
    }

    func sample(batchSize: Int) -> [Transition] {
        guard transitions.count >= batchSize else { return transitions }
        return transitions.shuffled().prefix(batchSize).map { $0 }
    }

    init(capacity: Int = 10000) {
        self.id = UUID()
        self.transitions = []
        self.capacity = capacity
        self.position = 0
        self.size = 0
    }
}

struct QTable: Codable, Identifiable {
    let id = UUID()
    var table: [String: [Double]]
    var actionCount: Int
    var learningRate: Double
    var discountFactor: Double
    var explorationRate: Double
    var minExplorationRate: Double
    var explorationDecay: Double
    var updateCount: Int

    subscript(stateKey: String, action: Int) -> Double {
        get { table[stateKey]?[action] ?? 0 }
        set { table[stateKey, default: Array(repeating: 0, count: actionCount)][action] = newValue }
    }

    init(actionCount: Int, learningRate: Double = 0.1, discountFactor: Double = 0.99, explorationRate: Double = 1.0, minExplorationRate: Double = 0.01, explorationDecay: Double = 0.995) {
        self.id = UUID()
        self.table = [:]
        self.actionCount = actionCount
        self.learningRate = learningRate
        self.discountFactor = discountFactor
        self.explorationRate = explorationRate
        self.minExplorationRate = minExplorationRate
        self.explorationDecay = explorationDecay
        self.updateCount = 0
    }

    mutating func update(stateKey: String, action: Int, target: Double) {
        let current = table[stateKey]?[action] ?? 0
        let newValue = current + learningRate * (target - current)
        table[stateKey, default: Array(repeating: 0, count: actionCount)][action] = newValue
        updateCount += 1
    }

    mutating func decayExploration() {
        explorationRate = max(minExplorationRate, explorationRate * explorationDecay)
    }

    func bestAction(for stateKey: String) -> Int {
        guard let actions = table[stateKey] else { return Int.random(in: 0..<actionCount) }
        return actions.enumerated().max { $0.element < $1.element }?.offset ?? 0
    }
}

struct PolicyNetwork: Codable, Identifiable {
    let id = UUID()
    var weights: [[Double]]
    var biases: [Double]
    var learningRate: Double
    var architecture: [Int]

    init(architecture: [Int], learningRate: Double = 0.01) {
        self.id = UUID()
        self.architecture = architecture
        self.learningRate = learningRate
        weights = []
        biases = []
        for i in 0..<architecture.count - 1 {
            let rows = architecture[i + 1]
            let cols = architecture[i]
            weights.append((0..<rows).map { _ in (0..<cols).map { _ in Double.random(in: -0.1...0.1) } })
            biases.append((0..<rows).map { _ in Double.random(in: -0.1...0.1) })
        }
    }

    func forward(input: [Double]) -> [Double] {
        var current = input
        for (layerIndex, layer) in weights.enumerated() {
            let output = Array(repeating: 0.0, count: layer.count)
            for (i, neuronWeights) in layer.enumerated() {
                var sum = biases[layerIndex][i]
                for (j, weight) in neuronWeights.enumerated() {
                    sum += weight * (current.indices.contains(j) ? current[j] : 0)
                }
                output[i] = layerIndex < weights.count - 1 ? max(0, sum) : (layerIndex == weights.count - 1 ? 1.0 / (1.0 + exp(-sum)) : sum)
            }
            current = output
        }
        return current
    }

    func predict(actionValues: [Double], temperature: Double = 1.0) -> Int {
        let scaled = actionValues.map { $0 / temperature }
        let maxVal = scaled.max() ?? 0
        let expValues = scaled.map { exp($0 - maxVal) }
        let sumExp = expValues.reduce(0, +)
        guard sumExp > 0 else { return actionValues.enumerated().max { $0.element < $1.element }?.offset ?? 0 }
        let probabilities = expValues.map { $0 / sumExp }
        var cumulative = 0.0
        let random = Double.random(in: 0...1)
        for (index, prob) in probabilities.enumerated() {
            cumulative += prob
            if random <= cumulative { return index }
        }
        return probabilities.count - 1
    }
}

// MARK: - RL Environment
struct RLEnvironment: Codable, Identifiable {
    let id = UUID()
    var stateSize: Int
    var actionSize: Int
    var episodeLength: Int
    var rewardScale: Double
    var features: [String]
    var timestamp: Date

    init(stateSize: Int, actionSize: Int, episodeLength: Int = 1000, rewardScale: Double = 1.0, features: [String] = []) {
        self.id = UUID()
        self.stateSize = stateSize
        self.actionSize = actionSize
        self.episodeLength = episodeLength
        self.rewardScale = rewardScale
        self.features = features
        self.timestamp = Date()
    }
}

// MARK: - Reward Shaping
struct RewardShaper: Codable, Identifiable {
    let id = UUID()
    var baseReward: Double
    var shapingTerms: [ShapingTerm]
    var potentialFunction: String
    var discountFactor: Double

    struct ShapingTerm: Codable, Identifiable {
        let id = UUID()
        var name: String
        var coefficient: Double
        var threshold: Double
        var active: Bool
    }

    init(baseReward: Double = 0, shapingTerms: [ShapingTerm] = [], potentialFunction: String = "linear", discountFactor: Double = 0.99) {
        self.id = UUID()
        self.baseReward = baseReward
        self.shapingTerms = shapingTerms
        self.potentialFunction = potentialFunction
        self.discountFactor = discountFactor
    }

    func shapeReward(state: State, nextState: State, baseReward: Double) -> Double {
        var shaped = baseReward
        for term in shapingTerms where term.active {
            let diff = nextState.features.reduce(0, +) - state.features.reduce(0, +)
            shaped += term.coefficient * diff
        }
        return shaped
    }
}

// MARK: - RL Agent
@MainActor
final class ReinforcementLearningAgent: ObservableObject {
    static let shared = ReinforcementLearningAgent()
    @Published private(set) var episodes: Int = 0
    @Published private(set) var totalReward: Double = 0
    @Published private(set) var averageReward: Double = 0
    @Published private(set) var epsilon: Double = 1.0
    @Published private(set) var isTraining = false
    private var cancellationToken: Task<Void, Never>?
    private var qTable: QTable?
    private var policyNetwork: PolicyNetwork?
    private var experienceBuffer: ExperienceBuffer?
    private var rewardHistory: [Double] = []
    private let maxHistory = 1000

    func configure(algorithm: RLAlgorithm, stateSize: Int, actionSize: Int) {
        switch algorithm {
        case .qLearning, .multiArmedBandit:
            qTable = QTable(actionCount: actionSize)
        case .policyGradient, .actorCritic, .ppo, .sac:
            let hiddenSize = max(16, (stateSize + actionSize) / 2)
            policyNetwork = PolicyNetwork(architecture: [stateSize, hiddenSize, hiddenSize, actionSize])
        default:
            qTable = QTable(actionCount: actionSize)
            let hiddenSize = max(16, (stateSize + actionSize) / 2)
            policyNetwork = PolicyNetwork(architecture: [stateSize, hiddenSize, hiddenSize, actionSize])
        }
        experienceBuffer = ExperienceBuffer(capacity: 10000)
    }

    func train(environment: RLEnvironment, episodes: Int = 100) async {
        guard !isTraining else { return }
        isTraining = true
        defer { isTraining = false }
        for episode in 0..<episodes {
            if Task.isCancelled { break }
            var state = createInitialState(environment: environment)
            var episodeReward = 0.0
            for step in 0..<environment.episodeLength {
                if Task.isCancelled { break }
                let action = selectAction(state: state, algorithm: .qLearning)
                let (nextState, reward, done) = stepEnvironment(state: state, action: action, environment: environment)
                let transition = Transition(state: state, action: action, reward: reward, nextState: nextState, done: done)
                if let buffer = experienceBuffer { buffer.add(transition) }
                if let q = qTable, let buffer = experienceBuffer, step % 4 == 0, buffer.transitions.count >= 32 {
                    let batch = buffer.sample(batchSize: 32)
                    for t in batch { updateQValue(transition: t, qTable: &q) }
                }
                episodeReward += reward
                state = nextState
                if done { break }
            }
            rewardHistory.append(episodeReward)
            if rewardHistory.count > maxHistory { rewardHistory.removeFirst() }
            self.episodes += 1
            totalReward += episodeReward
            averageReward = rewardHistory.reduce(0, +) / Double(max(1, rewardHistory.count))
            if let q = qTable { q.decayExploration() }
            epsilon = max(0.01, epsilon * 0.995)
        }
    }

    func predict(state: State, algorithm: RLAlgorithm = .qLearning) -> (action: Int, confidence: Double) {
        if let q = qTable {
            let stateKey = state.features.map { String(format: "%.4f", $0) }.joined(separator: ",")
            let bestAction = q.bestAction(for: stateKey)
            let confidence = abs(q[stateKey, bestAction])
            return (bestAction, min(1, confidence))
        }
        if let network = policyNetwork {
            let actionValues = network.forward(input: state.features)
            let bestAction = actionValues.enumerated().max { $0.element < $1.element }?.offset ?? 0
            return (bestAction, actionValues[bestAction])
        }
        return (0, 0)
    }

    func cancelTraining() { cancellationToken?.cancel() }

    private func selectAction(state: State, algorithm: RLAlgorithm) -> Action {
        if let q = qTable {
            let stateKey = state.features.map { String(format: "%.4f", $0) }.joined(separator: ",")
            if Double.random(in: 0...1) < q.explorationRate {
                return Action(value: Int.random(in: 0..<q.actionCount), description: "exploration")
            }
            let bestAction = q.bestAction(for: stateKey)
            return Action(value: bestAction, description: "exploitation")
        }
        if let network = policyNetwork {
            let actionValues = network.forward(input: state.features)
            let selectedAction = network.predict(actionValues: actionValues, temperature: 1.0)
            return Action(value: selectedAction, description: "policy")
        }
        return Action(value: Int.random(in: 0..<10), description: "random")
    }

    private func createInitialState(environment: RLEnvironment) -> State {
        return State(features: (0..<environment.stateSize).map { _ in Double.random(in: -1...1) })
    }

    private func stepEnvironment(state: State, action: Action, environment: RLEnvironment) -> (State, Double, Bool) {
        let nextFeatures = state.features.map { $0 + Double.random(in: -0.1...0.1) }
        let nextState = State(features: Array(nextFeatures.prefix(environment.stateSize)))
        let reward = Double.random(in: -1...1) * environment.rewardScale
        let done = false
        return (nextState, reward, done)
    }

    private func updateQValue(transition: Transition, qTable: inout QTable) {
        let stateKey = transition.state.features.map { String(format: "%.4f", $0) }.joined(separator: ",")
        let nextStateKey = transition.nextState.features.map { String(format: "%.4f", $0) }.joined(separator: ",")
        let target = transition.reward + qTable.discountFactor * (transition.done ? 0 : qTable[nextStateKey, qTable.bestAction(for: nextStateKey)])
        qTable.update(stateKey: stateKey, action: transition.action.value, target: target)
    }
}
