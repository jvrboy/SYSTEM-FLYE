import Foundation
import Accelerate

// MARK: - Batch Normalization

public struct BatchNormalization: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let numFeatures: Int
    public let eps: Float
    public let momentum: Float
    public let affine: Bool
    public let trackRunningStats: Bool

    public var weight: Tensor?
    public var bias: Tensor?
    public var runningMean: Tensor?
    public var runningVar: Tensor?
    public var numBatchesTracked: Int

    private var lastInput: Tensor?
    private var lastNormalized: Tensor?
    private var lastVar: Tensor?
    private var lastMean: Tensor?
    private var lastInvStd: Tensor?

    public init(numFeatures: Int, eps: Float = 1e-5, momentum: Float = 0.1, affine: Bool = true, trackRunningStats: Bool = true, trainable: Bool = true, device: Device = .cpu) {
        self.id = UUID()
        self.numFeatures = numFeatures
        self.eps = eps
        self.momentum = momentum
        self.affine = affine
        self.trackRunningStats = trackRunningStats
        self.trainable = trainable
        self.device = device

        if affine {
            let weightData = [Float](repeating: 1, count: numFeatures)
            self.weight = Tensor(data: weightData, shape: [numFeatures], requiresGrad: trainable, device: device)
            let biasData = [Float](repeating: 0, count: numFeatures)
            self.bias = Tensor(data: biasData, shape: [numFeatures], requiresGrad: trainable, device: device)
        } else {
            self.weight = nil
            self.bias = nil
        }

        if trackRunningStats {
            self.runningMean = Tensor(data: [Float](repeating: 0, count: numFeatures), shape: [numFeatures], requiresGrad: false, device: device)
            self.runningVar = Tensor(data: [Float](repeating: 1, count: numFeatures), shape: [numFeatures], requiresGrad: false, device: device)
        } else {
            self.runningMean = nil
            self.runningVar = nil
        }

        self.numBatchesTracked = 0
        self.parameters = [weight, bias].compactMap { $0 }
        self.lastInput = nil
        self.lastNormalized = nil
        self.lastVar = nil
        self.lastMean = nil
        self.lastInvStd = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        numFeatures = try container.decode(Int.self, forKey: .numFeatures)
        eps = try container.decode(Float.self, forKey: .eps)
        momentum = try container.decode(Float.self, forKey: .momentum)
        affine = try container.decode(Bool.self, forKey: .affine)
        trackRunningStats = try container.decode(Bool.self, forKey: .trackRunningStats)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weight = try container.decodeIfPresent(Tensor.self, forKey: .weight)
        bias = try container.decodeIfPresent(Tensor.self, forKey: .bias)
        runningMean = try container.decodeIfPresent(Tensor.self, forKey: .runningMean)
        runningVar = try container.decodeIfPresent(Tensor.self, forKey: .runningVar)
        numBatchesTracked = try container.decode(Int.self, forKey: .numBatchesTracked)
        parameters = [weight, bias].compactMap { $0 }
        lastInput = nil
        lastNormalized = nil
        lastVar = nil
        lastMean = nil
        lastInvStd = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(numFeatures, forKey: .numFeatures)
        try container.encode(eps, forKey: .eps)
        try container.encode(momentum, forKey: .momentum)
        try container.encode(affine, forKey: .affine)
        try container.encode(trackRunningStats, forKey: .trackRunningStats)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(bias, forKey: .bias)
        try container.encodeIfPresent(runningMean, forKey: .runningMean)
        try container.encodeIfPresent(runningVar, forKey: .runningVar)
        try container.encode(numBatchesTracked, forKey: .numBatchesTracked)
    }

    enum CodingKeys: String, CodingKey {
        case id, numFeatures, eps, momentum, affine, trackRunningStats, trainable, device, weight, bias, runningMean, runningVar, numBatchesTracked
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count == 2, input.shape[1] == numFeatures else { return input }
        lastInput = input
        let batchSize = input.shape[0]
        var output = [Float](repeating: 0, count: batchSize * numFeatures)
        var batchMean = [Float](repeating: 0, count: numFeatures)
        var batchVar = [Float](repeating: 0, count: numFeatures)

        for feature in 0..<numFeatures {
            var mean: Float = 0
            for b in 0..<batchSize {
                mean += input.data[b * numFeatures + feature]
            }
            mean /= Float(batchSize)
            batchMean[feature] = mean

            var variance: Float = 0
            for b in 0..<batchSize {
                let diff = input.data[b * numFeatures + feature] - mean
                variance += diff * diff
            }
            variance /= Float(batchSize)
            batchVar[feature] = variance
        }

        if trackRunningStats, let rm = runningMean, let rv = runningVar {
            numBatchesTracked += 1
            let newMomentum = momentum / (1 - pow(1 - momentum, Float(numBatchesTracked)))
            for i in 0..<numFeatures {
                rm.data[i] = (1 - newMomentum) * rm.data[i] + newMomentum * batchMean[i]
                rv.data[i] = (1 - newMomentum) * rv.data[i] + newMomentum * batchVar[i]
            }
        }

        for b in 0..<batchSize {
            for f in 0..<numFeatures {
                let mean = batchMean[f]
                let varVal = batchVar[f]
                let invStd = 1 / sqrt(varVal + eps)
                var normalized = (input.data[b * numFeatures + f] - mean) * invStd

                if affine, let w = weight, let b = bias {
                    normalized = w.data[f] * normalized + b.data[f]
                }
                output[b * numFeatures + f] = normalized
            }
        }

        lastNormalized = Tensor(data: output, shape: input.shape)
        lastMean = Tensor(data: batchMean, shape: [numFeatures])
        lastVar = Tensor(data: batchVar, shape: [numFeatures])

        var invStd = [Float](repeating: 0, count: numFeatures)
        for f in 0..<numFeatures {
            invStd[f] = 1 / sqrt(batchVar[f] + eps)
        }
        lastInvStd = Tensor(data: invStd, shape: [numFeatures])

        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let input = lastInput, input.shape.count == 2, input.shape[1] == numFeatures else { return gradient }
        let batchSize = input.shape[0]
        var gradInput = [Float](repeating: 0, count: batchSize * numFeatures)

        for f in 0..<numFeatures {
            let invStd = lastInvStd?.data[f] ?? 1
            var sumGrad: Float = 0
            var sumGradInput: Float = 0
            for b in 0..<batchSize {
                sumGrad += gradient.data[b * numFeatures + f]
                sumGradInput += gradient.data[b * numFeatures + f] * input.data[b * numFeatures + f]
            }
            let mean = lastMean?.data[f] ?? 0
            for b in 0..<batchSize {
                let g = gradient.data[b * numFeatures + f]
                let inputVal = input.data[b * numFeatures + f]
                var grad = invStd * (g - sumGrad / Float(batchSize) - (inputVal - mean) * invStd * invStd * sumGradInput / Float(batchSize))

                if affine, let w = weight {
                    grad *= w.data[f]
                }
                gradInput[b * numFeatures + f] = grad
            }
        }

        if affine, trainable {
            if let w = weight, var wGrad = weight.grad {
                var bGrad = [Float](repeating: 0, count: numFeatures])
                for f in 0..<numFeatures {
                    var sum: Float = 0
                    for b in 0..<batchSize {
                        sum += lastNormalized?.data[b * numFeatures + f] ?? 0
                    }
                    wGrad[f] += sum / Float(batchSize) * gradInput[f]
                    bGrad[f] += gradInput[f]
                }
                weight.grad = wGrad
                if let b = bias, var bGradExisting = bias.grad {
                    bias.grad = bGradExisting.adding(bGrad, count: bGradExisting.count)
                } else {
                    bias?.grad = bGrad
                }
            }
        }

        return Tensor(data: gradInput, shape: input.shape)
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(BatchNormalization.self, from: data)
        self.weight = decoded.weight
        self.bias = decoded.bias
        self.runningMean = decoded.runningMean
        self.runningVar = decoded.runningVar
        self.numBatchesTracked = decoded.numBatchesTracked
    }

    public func eval() {
        trainable = false
    }

    public func train() {
        trainable = true
    }

    public func getRunningStats() -> (mean: [Float], variance: [Float]) {
        let mean = runningMean?.data ?? [Float](repeating: 0, count: numFeatures)
        let variance = runningVar?.data ?? [Float](repeating: 1, count: numFeatures)
        return (mean, variance)
    }

    public func setRunningStats(mean: [Float], variance: [Float]) {
        if var rm = runningMean { rm.data = mean; runningMean = rm }
        if var rv = runningVar { rv.data = variance; runningVar = rv }
    }
}
