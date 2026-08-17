import Foundation
import Accelerate

// MARK: - Transformer Block

public struct TransformerBlock: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let embedDim: Int
    public let numHeads: Int
    public let ffDim: Int
    public let dropout: Float
    public let causal: Bool
    public let usePreNorm: Bool
    public let activation: ActivationType
    public let useGatedFFN: Bool
    public let attention: MultiHeadAttention
    public var linear1: DenseLayer
    public var linear2: DenseLayer
    public var gateLayer: DenseLayer?
    public var norm1: LayerNorm?
    public var norm2: LayerNorm?
    public var norm3: LayerNorm?
    public var dropoutLayer: DropoutLayer
    public var attentionDropout: DropoutLayer
    public var lastInput: Tensor?
    public var lastAttended: Tensor?
    public var lastFFN: Tensor?
    public var lastNorm1: Tensor?
    public var lastNorm2: Tensor?
    public var lastNorm3: Tensor?

    public init(embedDim: Int, numHeads: Int, ffDim: Int, dropout: Float = 0.1, causal: Bool = true, usePreNorm: Bool = true, activation: ActivationType = .gelu, useGatedFFN: Bool = false, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu) {
        self.id = UUID()
        self.embedDim = embedDim
        self.numHeads = numHeads
        self.ffDim = ffDim
        self.dropout = dropout
        self.causal = causal
        self.usePreNorm = usePreNorm
        self.activation = activation
        self.useGatedFFN = useGatedFFN
        self.trainable = trainable
        self.device = device

        self.attention = MultiHeadAttention(embedDim: embedDim, numHeads: numHeads, dropout: dropout, causal: causal, useBias: true, attentionDropout: dropout, projectionDropout: dropout, initializer: initializer, trainable: trainable, device: device)

        if useGatedFFN {
            self.gateLayer = DenseLayer(inputSize: ffDim, outputSize: ffDim, activation: activation, useBias: true, initializer: initializer, trainable: trainable, device: device)
            self.linear1 = DenseLayer(inputSize: embedDim, outputSize: ffDim, activation: .linear, useBias: true, initializer: initializer, trainable: trainable, device: device)
            self.linear2 = DenseLayer(inputSize: ffDim, outputSize: embedDim, activation: .linear, useBias: true, initializer: initializer, trainable: trainable, device: device)
        } else {
            self.gateLayer = nil
            self.linear1 = DenseLayer(inputSize: embedDim, outputSize: ffDim, activation: activation, useBias: true, initializer: initializer, trainable: trainable, device: device)
            self.linear2 = DenseLayer(inputSize: ffDim, outputSize: embedDim, activation: .linear, useBias: true, initializer: initializer, trainable: trainable, device: device)
        }

        self.norm1 = LayerNorm(featureDim: embedDim, trainable: trainable, device: device)
        self.norm2 = LayerNorm(featureDim: embedDim, trainable: trainable, device: device)
        self.norm3 = useGatedFFN ? LayerNorm(featureDim: embedDim, trainable: trainable, device: device) : nil
        self.dropoutLayer = DropoutLayer(dropoutProbability: dropout, training: trainable, trainable: false, device: device)
        self.attentionDropout = DropoutLayer(dropoutProbability: dropout, training: trainable, trainable: false, device: device)

        var allParams: [any Layer] = [attention, linear1, linear2, norm1!, norm2!]
        if let gate = gateLayer { allParams.append(gate) }
        if let norm3 = norm3 { allParams.append(norm3) }
        self.parameters = allParams.flatMap { $0.parameters }
        self.lastInput = nil
        self.lastAttended = nil
        self.lastFFN = nil
        self.lastNorm1 = nil
        self.lastNorm2 = nil
        self.lastNorm3 = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        embedDim = try container.decode(Int.self, forKey: .embedDim)
        numHeads = try container.decode(Int.self, forKey: .numHeads)
        ffDim = try container.decode(Int.self, forKey: .ffDim)
        dropout = try container.decode(Float.self, forKey: .dropout)
        causal = try container.decode(Bool.self, forKey: .causal)
        usePreNorm = try container.decode(Bool.self, forKey: .usePreNorm)
        activation = try container.decode(ActivationType.self, forKey: .activation)
        useGatedFFN = try container.decode(Bool.self, forKey: .useGatedFFN)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        attention = try container.decode(MultiHeadAttention.self, forKey: .attention)
        linear1 = try container.decode(DenseLayer.self, forKey: .linear1)
        linear2 = try container.decode(DenseLayer.self, forKey: .linear2)
        gateLayer = try container.decodeIfPresent(DenseLayer.self, forKey: .gateLayer)
        norm1 = try container.decodeIfPresent(LayerNorm.self, forKey: .norm1)
        norm2 = try container.decodeIfPresent(LayerNorm.self, forKey: .norm2)
        norm3 = try container.decodeIfPresent(LayerNorm.self, forKey: .norm3)
        dropoutLayer = try container.decode(DropoutLayer.self, forKey: .dropoutLayer)
        attentionDropout = try container.decode(DropoutLayer.self, forKey: .attentionDropout)
        var allParams: [any Layer] = [attention, linear1, linear2, norm1!, norm2!]
        if let gate = gateLayer { allParams.append(gate) }
        if let norm3 = norm3 { allParams.append(norm3) }
        parameters = allParams.flatMap { $0.parameters }
        lastInput = nil
        lastAttended = nil
        lastFFN = nil
        lastNorm1 = nil
        lastNorm2 = nil
        lastNorm3 = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(embedDim, forKey: .embedDim)
        try container.encode(numHeads, forKey: .numHeads)
        try container.encode(ffDim, forKey: .ffDim)
        try container.encode(dropout, forKey: .dropout)
        try container.encode(causal, forKey: .causal)
        try container.encode(usePreNorm, forKey: .usePreNorm)
        try container.encode(activation, forKey: .activation)
        try container.encode(useGatedFFN, forKey: .useGatedFFN)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(attention, forKey: .attention)
        try container.encode(linear1, forKey: .linear1)
        try container.encode(linear2, forKey: .linear2)
        try container.encodeIfPresent(gateLayer, forKey: .gateLayer)
        try container.encodeIfPresent(norm1, forKey: .norm1)
        try container.encodeIfPresent(norm2, forKey: .norm2)
        try container.encodeIfPresent(norm3, forKey: .norm3)
        try container.encode(dropoutLayer, forKey: .dropoutLayer)
        try container.encode(attentionDropout, forKey: .attentionDropout)
    }

    enum CodingKeys: String, CodingKey {
        case id, embedDim, numHeads, ffDim, dropout, causal, usePreNorm, activation, useGatedFFN, trainable, device, attention, linear1, linear2, gateLayer, norm1, norm2, norm3, dropoutLayer, attentionDropout
    }

    public func forward(_ input: Tensor) -> Tensor {
        lastInput = input
        var x = input

        if usePreNorm {
            if let norm1 = norm1 { x = norm1.forward(x); lastNorm1 = x }
        }

        let attended = attention.forward(x)
        lastAttended = attended
        x = attentionDropout.forward(attended)

        if !usePreNorm {
            x = x.add(input)
            if let norm1 = norm1 { x = norm1.forward(x); lastNorm1 = x }
        } else {
            x = x.add(input)
        }

        if usePreNorm {
            if let norm2 = norm2 { x = norm2.forward(x); lastNorm2 = x }
        }

        var ffned = linear1.forward(x)
        if let gate = gateLayer {
            let gateValues = gate.forward(x)
            ffned = ffned.multiply(gateValues)
        }
        let ffned2 = linear2.forward(ffned)
        lastFFN = ffned2
        x = dropoutLayer.forward(ffned2)

        if !usePreNorm {
            x = x.add(input)
            if let norm2 = norm2 { x = norm2.forward(x); lastNorm2 = x }
        } else {
            x = x.add(input)
        }

        if useGatedFFN, let norm3 = norm3 {
            if usePreNorm {
                x = norm3.forward(x)
                lastNorm3 = x
            }
        }

        return x
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        var grad = gradient

        if useGatedFFN, let norm3 = norm3 {
            grad = norm3.backward(grad)
        }

        grad = dropoutLayer.backward(grad)
        grad = linear2.backward(grad)

        if useGatedFFN, let gate = gateLayer {
            let gateGrad = gate.backward(linear1.lastOutput?.multiply(grad) ?? grad)
            grad = grad.add(gateGrad)
        }

        grad = linear1.backward(grad)

        if usePreNorm, let norm2 = norm2 {
            grad = norm2.backward(grad)
        }

        grad = attentionDropout.backward(grad)
        grad = attention.backward(grad)

        if !usePreNorm, let norm1 = norm1 {
            grad = norm1.backward(grad)
        } else if usePreNorm, let norm1 = norm1 {
            grad = norm1.backward(grad)
        }

        return grad
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(TransformerBlock.self, from: data)
        self.attention = decoded.attention
        self.linear1 = decoded.linear1
        self.linear2 = decoded.linear2
        self.gateLayer = decoded.gateLayer
        self.norm1 = decoded.norm1
        self.norm2 = decoded.norm2
        self.norm3 = decoded.norm3
        self.dropoutLayer = decoded.dropoutLayer
        self.attentionDropout = decoded.attentionDropout
    }

    public func reset() {
        lastInput = nil
        lastAttended = nil
        lastFFN = nil
        lastNorm1 = nil
        lastNorm2 = nil
        lastNorm3 = nil
        attention.reset()
    }
}

// MARK: - Layer Norm

public struct LayerNorm: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let featureDim: Int
    public let eps: Float
    public let momentum: Float
    public var gamma: Tensor
    public var beta: Tensor
    public var runningMean: Tensor?
    public var runningVar: Tensor?
    private var lastInput: Tensor?
    private var lastNormalized: Tensor?
    private var lastVar: Tensor?
    private var lastMean: Tensor?
    private var lastInvStd: Tensor?

    public init(featureDim: Int, eps: Float = 1e-5, momentum: Float = 0.1, trainable: Bool = true, device: Device = .cpu) {
        self.id = UUID()
        self.featureDim = featureDim
        self.eps = eps
        self.momentum = momentum
        self.trainable = trainable
        self.device = device

        let gammaData = [Float](repeating: 1, count: featureDim)
        self.gamma = Tensor(data: gammaData, shape: [featureDim], requiresGrad: trainable, device: device)

        let betaData = [Float](repeating: 0, count: featureDim)
        self.beta = Tensor(data: betaData, shape: [featureDim], requiresGrad: trainable, device: device)

        self.parameters = [gamma, beta]
        self.runningMean = Tensor(data: [Float](repeating: 0, count: featureDim), shape: [featureDim], requiresGrad: false, device: device)
        self.runningVar = Tensor(data: [Float](repeating: 1, count: featureDim), shape: [featureDim], requiresGrad: false, device: device)
        self.lastInput = nil
        self.lastNormalized = nil
        self.lastVar = nil
        self.lastMean = nil
        self.lastInvStd = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        featureDim = try container.decode(Int.self, forKey: .featureDim)
        eps = try container.decode(Float.self, forKey: .eps)
        momentum = try container.decode(Float.self, forKey: .momentum)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        gamma = try container.decode(Tensor.self, forKey: .gamma)
        beta = try container.decode(Tensor.self, forKey: .beta)
        runningMean = try container.decodeIfPresent(Tensor.self, forKey: .runningMean)
        runningVar = try container.decodeIfPresent(Tensor.self, forKey: .runningVar)
        parameters = [gamma, beta]
        lastInput = nil
        lastNormalized = nil
        lastVar = nil
        lastMean = nil
        lastInvStd = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(featureDim, forKey: .featureDim)
        try container.encode(eps, forKey: .eps)
        try container.encode(momentum, forKey: .momentum)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(gamma, forKey: .gamma)
        try container.encode(beta, forKey: .beta)
        try container.encodeIfPresent(runningMean, forKey: .runningMean)
        try container.encodeIfPresent(runningVar, forKey: .runningVar)
    }

    enum CodingKeys: String, CodingKey {
        case id, featureDim, eps, momentum, trainable, device, gamma, beta, runningMean, runningVar
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count == 2, input.shape[1] == featureDim else { return input }
        lastInput = input
        let batchSize = input.shape[0]
        var output = [Float](repeating: 0, count: batchSize * featureDim)
        var batchMean = [Float](repeating: 0, count: featureDim)
        var batchVar = [Float](repeating: 0, count: featureDim)

        for feature in 0..<featureDim {
            var mean: Float = 0
            for b in 0..<batchSize {
                mean += input.data[b * featureDim + feature]
            }
            mean /= Float(batchSize)
            batchMean[feature] = mean

            var variance: Float = 0
            for b in 0..<batchSize {
                let diff = input.data[b * featureDim + feature] - mean
                variance += diff * diff
            }
            variance /= Float(batchSize)
            batchVar[feature] = variance
        }

        if let rm = runningMean, let rv = runningVar {
            for i in 0..<featureDim {
                rm.data[i] = (1 - momentum) * rm.data[i] + momentum * batchMean[i]
                rv.data[i] = (1 - momentum) * rv.data[i] + momentum * batchVar[i]
            }
        }

        for b in 0..<batchSize {
            for f in 0..<featureDim {
                let mean = batchMean[f]
                let varVal = batchVar[f]
                let invStd = 1 / sqrt(varVal + eps)
                var normalized = (input.data[b * featureDim + f] - mean) * invStd
                normalized = gamma.data[f] * normalized + beta.data[f]
                output[b * featureDim + f] = normalized
            }
        }

        lastNormalized = Tensor(data: output, shape: input.shape)
        lastMean = Tensor(data: batchMean, shape: [featureDim])
        lastVar = Tensor(data: batchVar, shape: [featureDim])

        var invStd = [Float](repeating: 0, count: featureDim)
        for f in 0..<featureDim {
            invStd[f] = 1 / sqrt(batchVar[f] + eps)
        }
        lastInvStd = Tensor(data: invStd, shape: [featureDim])

        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let input = lastInput, input.shape.count == 2, input.shape[1] == featureDim else { return gradient }
        let batchSize = input.shape[0]
        var gradInput = [Float](repeating: 0, count: batchSize * featureDim)

        for f in 0..<featureDim {
            let invStd = lastInvStd?.data[f] ?? 1
            var sumGrad: Float = 0
            var sumGradInput: Float = 0
            for b in 0..<batchSize {
                sumGrad += gradient.data[b * featureDim + f]
                sumGradInput += gradient.data[b * featureDim + f] * input.data[b * featureDim + f]
            }
            let mean = lastMean?.data[f] ?? 0
            for b in 0..<batchSize {
                let g = gradient.data[b * featureDim + f]
                let inputVal = input.data[b * featureDim + f]
                var grad = invStd * (g - sumGrad / Float(batchSize) - (inputVal - mean) * invStd * invStd * sumGradInput / Float(batchSize))
                grad *= gamma.data[f]
                gradInput[b * featureDim + f] = grad
            }
        }

        if trainable {
            if let w = weight, var wGrad = weight.grad {
                var bGrad = [Float](repeating: 0, count: featureDim)
                for f in 0..<featureDim {
                    var sum: Float = 0
                    for b in 0..<batchSize {
                        sum += lastNormalized?.data[b * featureDim + f] ?? 0
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
        let decoded = try JSONDecoder().decode(LayerNorm.self, from: data)
        self.gamma = decoded.gamma
        self.beta = decoded.beta
        self.runningMean = decoded.runningMean
        self.runningVar = decoded.runningVar
    }

    public func eval() { trainable = false }
    public func train() { trainable = true }
    public func getRunningStats() -> (mean: [Float], variance: [Float]) {
        let mean = runningMean?.data ?? [Float](repeating: 0, count: featureDim)
        let variance = runningVar?.data ?? [Float](repeating: 1, count: featureDim)
        return (mean, variance)
    }
    public func setRunningStats(mean: [Float], variance: [Float]) {
        if var rm = runningMean { rm.data = mean; runningMean = rm }
        if var rv = runningVar { rv.data = variance; runningVar = rv }
    }
}
