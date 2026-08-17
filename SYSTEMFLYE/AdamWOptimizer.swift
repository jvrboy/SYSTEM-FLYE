import Foundation
import Accelerate

// MARK: - AdamW Optimizer

public struct AdamWOptimizer: Optimizer, Identifiable, Codable, Sendable {
    public let id: UUID
    public let lr: Float
    public let beta1: Float
    public let beta2: Float
    public let epsilon: Float
    public let weightDecay: Float
    public let amsgrad: Bool
    public let amsEpsilon: Float

    public init(
        lr: Float = 0.001,
        beta1: Float = 0.9,
        beta2: Float = 0.999,
        epsilon: Float = 1e-8,
        weightDecay: Float = 0.01,
        amsgrad: Bool = false,
        amsEpsilon: Float = 1e-6
    ) {
        self.id = UUID()
        self.lr = lr
        self.beta1 = beta1
        self.beta2 = beta2
        self.epsilon = epsilon
        self.weightDecay = weightDecay
        self.amsgrad = amsgrad
        self.amsEpsilon = amsEpsilon
    }

    public func step(layers: [any Layer]) {
        let optimizer = OptimizerEngine.shared
        optimizer.stepCount += 1

        let biasCorrection1 = 1 - pow(beta1, Float(optimizer.stepCount))
        let biasCorrection2 = 1 - pow(beta2, Float(optimizer.stepCount))
        let stepSize = lr / biasCorrection1

        for layer in layers where layer.trainable {
            for param in layer.parameters where param.requiresGrad {
                guard var grad = param.grad else { continue }
                let paramID = param.id

                var expAvg: [Float]
                var expAvgSq: [Float]
                var maxExpAvgSq: [Float]?

                if let state = optimizer.parameterStates[paramID] {
                    expAvg = state.expAvg ?? [Float](repeating: 0, count: grad.count)
                    expAvgSq = state.expAvgSq ?? [Float](repeating: 0, count: grad.count)
                    maxExpAvgSq = state.maxExpAvgSq
                } else {
                    expAvg = [Float](repeating: 0, count: grad.count)
                    expAvgSq = [Float](repeating: 0, count: grad.count)
                    maxExpAvgSq = nil
                }

                for i in 0..<grad.count {
                    let g = grad[i]
                    expAvg[i] = beta1 * expAvg[i] + (1 - beta1) * g
                    expAvgSq[i] = beta2 * expAvgSq[i] + (1 - beta2) * g * g

                    if amsgrad {
                        if var maxSq = maxExpAvgSq {
                            maxSq[i] = max(maxSq[i], expAvgSq[i])
                            maxExpAvgSq = maxSq
                        } else {
                            maxExpAvgSq = expAvgSq
                        }
                    }

                    let denom = amsgrad && maxExpAvgSq != nil ?
                        sqrt(maxExpAvgSq![i] / biasCorrection2) + epsilon :
                        sqrt(expAvgSq[i] / biasCorrection2) + epsilon

                    param.data[i] -= stepSize * (expAvg[i] / denom + weightDecay * param.data[i])
                }

                optimizer.parameterStates[paramID] = ParameterState(
                    expAvg: expAvg,
                    expAvgSq: expAvgSq,
                    maxExpAvgSq: maxExpAvgSq,
                    step: optimizer.stepCount
                )
                param.grad = nil
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

// MARK: - Adam Optimizer

public struct AdamOptimizer: Optimizer, Identifiable, Codable, Sendable {
    public let id: UUID
    public let lr: Float
    public let beta1: Float
    public let beta2: Float
    public let epsilon: Float
    public let amsgrad: Bool

    public init(lr: Float = 0.001, beta1: Float = 0.9, beta2: Float = 0.999, epsilon: Float = 1e-8, amsgrad: Bool = false) {
        self.id = UUID()
        self.lr = lr
        self.beta1 = beta1
        self.beta2 = beta2
        self.epsilon = epsilon
        self.amsgrad = amsgrad
    }

    public func step(layers: [any Layer]) {
        let optimizer = OptimizerEngine.shared
        optimizer.stepCount += 1

        let biasCorrection1 = 1 - pow(beta1, Float(optimizer.stepCount))
        let biasCorrection2 = 1 - pow(beta2, Float(optimizer.stepCount))
        let stepSize = lr / biasCorrection1

        for layer in layers where layer.trainable {
            for param in layer.parameters where param.requiresGrad {
                guard var grad = param.grad else { continue }
                let paramID = param.id

                var expAvg: [Float]
                var expAvgSq: [Float]
                var maxExpAvgSq: [Float]?

                if let state = optimizer.parameterStates[paramID] {
                    expAvg = state.expAvg ?? [Float](repeating: 0, count: grad.count)
                    expAvgSq = state.expAvgSq ?? [Float](repeating: 0, count: grad.count)
                    maxExpAvgSq = state.maxExpAvgSq
                } else {
                    expAvg = [Float](repeating: 0, count: grad.count)
                    expAvgSq = [Float](repeating: 0, count: grad.count)
                    maxExpAvgSq = nil
                }

                for i in 0..<grad.count {
                    let g = grad[i]
                    expAvg[i] = beta1 * expAvg[i] + (1 - beta1) * g
                    expAvgSq[i] = beta2 * expAvgSq[i] + (1 - beta2) * g * g

                    if amsgrad {
                        if var maxSq = maxExpAvgSq {
                            maxSq[i] = max(maxSq[i], expAvgSq[i])
                            maxExpAvgSq = maxSq
                        } else {
                            maxExpAvgSq = expAvgSq
                        }
                    }

                    let denom = amsgrad && maxExpAvgSq != nil ?
                        sqrt(maxExpAvgSq![i] / biasCorrection2) + epsilon :
                        sqrt(expAvgSq[i] / biasCorrection2) + epsilon

                    param.data[i] -= stepSize * (expAvg[i] / denom)
                }

                optimizer.parameterStates[paramID] = ParameterState(
                    expAvg: expAvg,
                    expAvgSq: expAvgSq,
                    maxExpAvgSq: maxExpAvgSq,
                    step: optimizer.stepCount
                )
                param.grad = nil
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

// MARK: - RMSprop Optimizer

public struct RMSpropOptimizer: Optimizer, Identifiable, Codable, Sendable {
    public let id: UUID
    public let lr: Float
    public let alpha: Float
    public let epsilon: Float
    public let weightDecay: Float
    public let momentum: Float
    public let centered: Bool

    public init(lr: Float = 0.01, alpha: Float = 0.99, epsilon: Float = 1e-8, weightDecay: Float = 0, momentum: Float = 0, centered: Bool = false) {
        self.id = UUID()
        self.lr = lr
        self.alpha = alpha
        self.epsilon = epsilon
        self.weightDecay = weightDecay
        self.momentum = momentum
        self.centered = centered
    }

    public func step(layers: [any Layer]) {
        let optimizer = OptimizerEngine.shared
        for layer in layers where layer.trainable {
            for param in layer.parameters where param.requiresGrad {
                guard var grad = param.grad else { continue }
                let paramID = param.id

                var state = optimizer.parameterStates[paramID]
                let expAvgSq = state?.expAvgSq ?? [Float](repeating: 0, count: grad.count)
                let centering = state?.expAvg ?? [Float](repeating: 0, count: grad.count)
                var buf = state?.momentumBuffer ?? [Float](repeating: 0, count: grad.count)

                for i in 0..<grad.count {
                    if weightDecay != 0 {
                        grad[i] += weightDecay * param.data[i]
                    }
                    expAvgSq[i] = alpha * expAvgSq[i] + (1 - alpha) * grad[i] * grad[i]
                    let denom = sqrt(expAvgSq[i]) + epsilon
                    var update = grad[i] / denom
                    if momentum != 0 {
                        buf[i] = momentum * buf[i] + update
                        update = buf[i]
                    }
                    param.data[i] -= lr * update
                }

                optimizer.parameterStates[paramID] = ParameterState(expAvg: centering, expAvgSq: expAvgSq, momentumBuffer: buf)
                param.grad = nil
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

// MARK: - Optimizer Factory

public struct OptimizerFactory {
    public static func create(_ config: OptimizerConfiguration) -> any Optimizer {
        switch config.type.lowercased() {
        case "adamw": return AdamWOptimizer(lr: config.learningRate, beta1: config.beta1, beta2: config.beta2, epsilon: config.epsilon, weightDecay: config.weightDecay, amsgrad: config.amsgrad)
        case "adam": return AdamOptimizer(lr: config.learningRate, beta1: config.beta1, beta2: config.beta2, epsilon: config.epsilon, amsgrad: config.amsgrad)
        case "sgd": return SGDOptimizer(lr: config.learningRate, momentum: config.momentum, weightDecay: config.weightDecay, dampening: config.dampening, nesterov: config.nesterov)
        case "rmsprop": return RMSpropOptimizer(lr: config.learningRate, alpha: config.beta1, epsilon: config.epsilon, weightDecay: config.weightDecay, momentum: config.momentum)
        default: return SGDOptimizer(lr: config.learningRate)
        }
    }
}
