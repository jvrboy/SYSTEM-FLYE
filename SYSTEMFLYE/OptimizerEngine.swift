import Foundation
import Accelerate

// MARK: - Optimizer Engine

public protocol Optimizer: Sendable {
    func step(layers: [any Layer])
    func zeroGrad()
    func saveState() -> Data
    func loadState(_ data: Data) throws
    func setLearningRate(_ lr: Float)
    func getLearningRate() -> Float
}

// MARK: - Optimizer State

public struct OptimizerState: Codable, Sendable {
    public var step: Int
    public var learningRate: Float
    public var momentum: Float
    public var beta1: Float
    public var beta2: Float
    public var epsilon: Float
    public var weightDecay: Float
    public var amsgrad: Bool
    public var initialLearningRate: Float
    public var decay: Float
    public var milestones: [Int]
    public var gamma: Float
    public var warmupSteps: Int

    public init(step: Int = 0, learningRate: Float = 0.001, momentum: Float = 0.9, beta1: Float = 0.9, beta2: Float = 0.999, epsilon: Float = 1e-8, weightDecay: Float = 0, amsgrad: Bool = false, initialLearningRate: Float = 0.001, decay: Float = 0, milestones: [Int] = [], gamma: Float = 0.1, warmupSteps: Int = 0) {
        self.step = step
        self.learningRate = learningRate
        self.momentum = momentum
        self.beta1 = beta1
        self.beta2 = beta2
        self.epsilon = epsilon
        self.weightDecay = weightDecay
        self.amsgrad = amsgrad
        self.initialLearningRate = initialLearningRate
        self.decay = decay
        self.milestones = milestones
        self.gamma = gamma
        self.warmupSteps = warmupSteps
    }
}

// MARK: - Base Optimizer

@MainActor
public final class OptimizerEngine: ObservableObject {
    public static let shared = OptimizerEngine()

    @Published public private(set) var currentOptimizer: (any Optimizer)?
    @Published public private(set) var learningRate: Float = 0.001
    @Published public private(set) var momentum: Float = 0.9
    @Published public private(set) var weightDecay: Float = 0
    @Published public private(set) var beta1: Float = 0.9
    @Published public private(set) var beta2: Float = 0.999
    @Published public private(set) var epsilon: Float = 1e-8
    @Published public private(set) var amsgrad: Bool = false
    @Published public private(set) var scheduler: LearningRateScheduler?
    @Published public private(set) var stepCount: Int = 0
    @Published public private(set) var isTraining: Bool = false

    public private(set) var parameterStates: [UUID: ParameterState] = [:]
    public private(set) var gradientHistory: [Float] = []
    public private(set) var lossHistory: [Float] = []
    public private(set) var learningRateHistory: [Float] = []
    public private let lock = NSLock()

    public init() {
        super.init()
    }
}

// MARK: - Parameter State

public struct ParameterState: Codable, Sendable {
    public var expAvg: [Float]?
    public var expAvgSq: [Float]?
    public var maxExpAvgSq: [Float]?
    public var momentumBuffer: [Float]?
    public var step: Int

    public init(expAvg: [Float]? = nil, expAvgSq: [Float]? = nil, maxExpAvgSq: [Float]? = nil, momentumBuffer: [Float]? = nil, step: Int = 0) {
        self.expAvg = expAvg
        self.expAvgSq = expAvgSq
        self.maxExpAvgSq = maxExpAvgSq
        self.momentumBuffer = momentumBuffer
        self.step = step
    }
}

// MARK: - Learning Rate Scheduler

public protocol LearningRateScheduler: Sendable {
    func getLearningRate(step: Int, initialLR: Float) -> Float
    func step(optimizer: OptimizerEngine)
}

public struct StepLR: LearningRateScheduler {
    public let stepSize: Int
    public let gamma: Float

    public init(stepSize: Int, gamma: Float = 0.1) {
        self.stepSize = stepSize
        self.gamma = gamma
    }

    public func getLearningRate(step: Int, initialLR: Float) -> Float {
        return initialLR * pow(gamma, Float(step / stepSize))
    }

    public func step(optimizer: OptimizerEngine) {}
}

public struct MultiStepLR: LearningRateScheduler {
    public let milestones: [Int]
    public let gamma: Float

    public init(milestones: [Int], gamma: Float = 0.1) {
        self.milestones = milestones
        self.gamma = gamma
    }

    public func getLearningRate(step: Int, initialLR: Float) -> Float {
        var lr = initialLR
        for milestone in milestones where step >= milestone {
            lr *= gamma
        }
        return lr
    }

    public func step(optimizer: OptimizerEngine) {}
}

public struct CosineAnnealingLR: LearningRateScheduler {
    public let tMax: Int
    public let etaMin: Float

    public init(tMax: Int, etaMin: Float = 0) {
        self.tMax = tMax
        self.etaMin = etaMin
    }

    public func getLearningRate(step: Int, initialLR: Float) -> Float {
        let progress = Float(step) / Float(tMax)
        return etaMin + (initialLR - etaMin) * (1 + cos(.pi * progress)) / 2
    }

    public func step(optimizer: OptimizerEngine) {}
}

public struct ExponentialLR: LearningRateScheduler {
    public let gamma: Float

    public init(gamma: Float = 0.95) {
        self.gamma = gamma
    }

    public func getLearningRate(step: Int, initialLR: Float) -> Float {
        return initialLR * pow(gamma, Float(step))
    }

    public func step(optimizer: OptimizerEngine) {}
}

public struct WarmupLR: LearningRateScheduler {
    public let warmupSteps: Int
    public let baseScheduler: LearningRateScheduler

    public init(warmupSteps: Int, baseScheduler: LearningRateScheduler) {
        self.warmupSteps = warmupSteps
        self.baseScheduler = baseScheduler
    }

    public func getLearningRate(step: Int, initialLR: Float) -> Float {
        if step < warmupSteps {
            return initialLR * Float(step) / Float(warmupSteps)
        }
        return baseScheduler.getLearningRate(step: step - warmupSteps, initialLR: initialLR)
    }

    public func step(optimizer: OptimizerEngine) {}
}

public struct ReduceLROnPlateau: LearningRateScheduler {
    public let factor: Float
    public let patience: Int
    public let threshold: Float
    public let minLR: Float
    public var bestLoss: Float = .infinity
    public var waitCount: Int = 0

    public init(factor: Float = 0.1, patience: Int = 10, threshold: Float = 1e-4, minLR: Float = 1e-6) {
        self.factor = factor
        self.patience = patience
        self.threshold = threshold
        self.minLR = minLR
    }

    public func getLearningRate(step: Int, initialLR: Float) -> Float {
        return initialLR
    }

    public mutating func step(optimizer: OptimizerEngine) {
        guard let currentLoss = optimizer.lossHistory.last else { return }
        if currentLoss < bestLoss - threshold {
            bestLoss = currentLoss
            waitCount = 0
        } else {
            waitCount += 1
            if waitCount >= patience {
                optimizer.setLearningRate(max(minLR, optimizer.learningRate * factor))
                waitCount = 0
            }
        }
    }
}

// MARK: - SGD Optimizer

public struct SGDOptimizer: Optimizer {
    public let lr: Float
    public let momentum: Float
    public let weightDecay: Float
    public let dampening: Float
    public let nesterov: Bool

    public init(lr: Float = 0.01, momentum: Float = 0, weightDecay: Float = 0, dampening: Float = 0, nesterov: Bool = false) {
        self.lr = lr
        self.momentum = momentum
        self.weightDecay = weightDecay
        self.dampening = dampening
        self.nesterov = nesterov
    }

    public func step(layers: [any Layer]) {
        let optimizer = OptimizerEngine.shared
        for layer in layers where layer.trainable {
            for param in layer.parameters where param.requiresGrad {
                guard var grad = param.grad else { continue }
                if weightDecay != 0 {
                    for i in 0..<param.data.count {
                        grad[i] += weightDecay * param.data[i]
                    }
                }
                if momentum != 0 {
                    let paramID = param.id
                    if var state = optimizer.parameterStates[paramID] {
                        if var buffer = state.momentumBuffer {
                            vDSP_vmul([1 - dampening], 1, buffer, 1, &buffer, 1, vDSP_Length(buffer.count))
                            vDSP_vadd(grad, 1, buffer, 1, &buffer, 1, vDSP_Length(buffer.count))
                            state.momentumBuffer = buffer
                            if nesterov {
                                vDSP_vmul([momentum], 1, buffer, 1, &buffer, 1, vDSP_Length(buffer.count))
                                vDSP_vadd(grad, 1, buffer, 1, &grad, 1, vDSP_Length(grad.count))
                            } else {
                                grad = buffer
                            }
                        } else {
                            state.momentumBuffer = grad
                        }
                        optimizer.parameterStates[paramID] = state
                    }
                }
                vDSP_vsmul(grad, 1, [-lr], &grad, 1, vDSP_Length(grad.count))
                for i in 0..<param.data.count {
                    param.data[i] += grad[i]
                }
            }
        }
    }

    public func zeroGrad() {
        for layer in OptimizerEngine.shared.parameters {
            layer.zeroGrad()
        }
    }

    public func saveState() -> Data {
        return try! JSONEncoder().encode(OptimizerEngine.shared.parameterStates)
    }

    public func loadState(_ data: Data) throws {
        let states = try JSONDecoder().decode([UUID: ParameterState].self, from: data)
        OptimizerEngine.shared.parameterStates = states
    }

    public func setLearningRate(_ lr: Float) {
        OptimizerEngine.shared.learningRate = lr
    }

    public func getLearningRate() -> Float {
        return lr
    }
}

// MARK: - Optimizer Configuration

public struct OptimizerConfiguration: Codable, Sendable {
    public let type: String
    public let learningRate: Float
    public let momentum: Float
    public let weightDecay: Float
    public let beta1: Float
    public let beta2: Float
    public let epsilon: Float
    public let amsgrad: Bool
    public let dampening: Float
    public let nesterov: Bool

    public init(type: String = "sgd", learningRate: Float = 0.01, momentum: Float = 0.9, weightDecay: Float = 0, beta1: Float = 0.9, beta2: Float = 0.999, epsilon: Float = 1e-8, amsgrad: Bool = false, dampening: Float = 0, nesterov: Bool = false) {
        self.type = type
        self.learningRate = learningRate
        self.momentum = momentum
        self.weightDecay = weightDecay
        self.beta1 = beta1
        self.beta2 = beta2
        self.epsilon = epsilon
        self.amsgrad = amsgrad
        self.dampening = dampening
        self.nesterov = nesterov
    }
}

// MARK: - Gradient Clipping

public enum GradientClippingType: String, Codable, Sendable, CaseIterable {
    case value = "VALUE"
    case norm = "NORM"
    case globalNorm = "GLOBAL_NORM"
}

public struct GradientClipper: Sendable {
    public let type: GradientClippingType
    public let value: Float
    public let maxNorm: Float

    public init(type: GradientClippingType = .norm, value: Float = 1, maxNorm: Float = 1) {
        self.type = type
        self.value = value
        self.maxNorm = maxNorm
    }

    public func clip(_ gradient: inout [Float], shape: [Int]) {
        switch type {
        case .value:
            for i in 0..<gradient.count {
                gradient[i] = max(-value, min(value, gradient[i]))
            }
        case .norm:
            var norm: Float = 0
            vDSP_svesq(gradient, 1, &norm, vDSP_Length(gradient.count))
            let normVal = sqrt(norm)
            if normVal > maxNorm {
                vDSP_vsmul(gradient, 1, [maxNorm / normVal], &gradient, 1, vDSP_Length(gradient.count))
            }
        case .globalNorm:
            var norm: Float = 0
            vDSP_svesq(gradient, 1, &norm, vDSP_Length(gradient.count))
            let normVal = sqrt(norm)
            if normVal > value {
                vDSP_vsmul(gradient, 1, [value / normVal], &gradient, 1, vDSP_Length(gradient.count))
            }
        }
    }
}

// MARK: - Parameter Group

public struct ParameterGroup: Sendable {
    public let params: [Tensor]
    public let lr: Float
    public let momentum: Float
    public let weightDecay: Float
    public let dampening: Float
    public let nesterov: Bool

    public init(params: [Tensor], lr: Float = 0.01, momentum: Float = 0, weightDecay: Float = 0, dampening: Float = 0, nesterov: Bool = false) {
        self.params = params
        self.lr = lr
        self.momentum = momentum
        self.weightDecay = weightDecay
        self.dampening = dampening
        self.nesterov = nesterov
    }
}

// MARK: - LRScheduler Wrapper

public struct LRScheduler: Sendable {
    public let optimizer: OptimizerEngine
    public let schedulerType: String
    public let stepSize: Int
    public let gamma: Float
    public let milestones: [Int]
    public let tMax: Int
    public let etaMin: Float
    public let factor: Float
    public let patience: Int
    public let threshold: Float
    public let minLR: Float
    public let warmupSteps: Int

    public init(optimizer: OptimizerEngine, schedulerType: String = "step", stepSize: Int = 30, gamma: Float = 0.1, milestones: [Int] = [], tMax: Int = 100, etaMin: Float = 0, factor: Float = 0.1, patience: Int = 10, threshold: Float = 1e-4, minLR: Float = 1e-6, warmupSteps: Int = 0) {
        self.optimizer = optimizer
        self.schedulerType = schedulerType
        self.stepSize = stepSize
        self.gamma = gamma
        self.milestones = milestones
        self.tMax = tMax
        self.etaMin = etaMin
        self.factor = factor
        self.patience = patience
        self.threshold = threshold
        self.minLR = minLR
        self.warmupSteps = warmupSteps
    }

    public func step() {
        optimizer.stepCount += 1
        if let scheduler = optimizer.scheduler {
            scheduler.step(optimizer: optimizer)
        }
        optimizer.learningRateHistory.append(optimizer.learningRate)
    }
}

// MARK: - Gradient Accumulator

public class GradientAccumulator: Sendable {
    public private(set) var accumulationSteps: Int
    public private(set) var currentStep: Int = 0
    public private(set) var accumulatedGradients: [UUID: [Float]] = [:]
    public private let lock = NSLock()

    public init(accumulationSteps: Int = 1) {
        self.accumulationSteps = accumulationSteps
    }

    public func accumulate(layerID: UUID, gradient: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        if var existing = accumulatedGradients[layerID] {
            for i in 0..<min(existing.count, gradient.count) {
                existing[i] += gradient[i]
            }
            accumulatedGradients[layerID] = existing
        } else {
            accumulatedGradients[layerID] = gradient
        }
        currentStep += 1
    }

    public func shouldStep() -> Bool {
        return currentStep >= accumulationSteps
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        currentStep = 0
        accumulatedGradients.removeAll()
    }

    public func getAccumulatedGradients() -> [UUID: [Float]] {
        lock.lock()
        defer { lock.unlock() }
        return accumulatedGradients
    }
}
