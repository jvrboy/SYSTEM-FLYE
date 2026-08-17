import Foundation
import Accelerate

// MARK: - Embedding Layer

public struct EmbeddingLayer: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let vocabSize: Int
    public let embedDim: Int
    public let paddingIdx: Int?
    public let maxNorm: Float?
    public let normType: Float
    public let scaleGradByFreq: Bool
    public let sparse: Bool
    public var weight: Tensor
    public var lastIndices: [Int32]?
    public var lastInputShape: [Int]?
    public var weightGrad: [Float]?
    public var freqScale: [Float]?
    public var l2Penalty: Float
    public var embeddingDropout: DropoutLayer
    public var sparseGradAccumulator: [Int: Float]?

    public init(vocabSize: Int, embedDim: Int, paddingIdx: Int? = nil, maxNorm: Float? = nil, normType: Float = 2, scaleGradByFreq: Bool = false, sparse: Bool = false, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu, l2Penalty: Float = 0) {
        self.id = UUID()
        self.vocabSize = vocabSize
        self.embedDim = embedDim
        self.paddingIdx = paddingIdx
        self.maxNorm = maxNorm
        self.normType = normType
        self.scaleGradByFreq = scaleGradByFreq
        self.sparse = sparse
        self.trainable = trainable
        self.device = device
        self.l2Penalty = l2Penalty

        let weightData = initializer.initialize(size: vocabSize * embedDim, fanIn: vocabSize, fanOut: embedDim)
        self.weight = Tensor(data: weightData, shape: [vocabSize, embedDim], requiresGrad: trainable, device: device)
        if let padIdx = paddingIdx, padIdx >= 0, padIdx < vocabSize {
            for i in 0..<embedDim {
                weight.data[padIdx * embedDim + i] = 0
            }
        }

        self.parameters = [weight]
        self.lastIndices = nil
        self.lastInputShape = nil
        self.weightGrad = nil
        self.freqScale = nil
        self.embeddingDropout = DropoutLayer(dropoutProbability: 0.1, training: trainable, trainable: false, device: device)
        self.sparseGradAccumulator = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vocabSize = try container.decode(Int.self, forKey: .vocabSize)
        embedDim = try container.decode(Int.self, forKey: .embedDim)
        paddingIdx = try container.decodeIfPresent(Int.self, forKey: .paddingIdx)
        maxNorm = try container.decodeIfPresent(Float.self, forKey: .maxNorm)
        normType = try container.decode(Float.self, forKey: .normType)
        scaleGradByFreq = try container.decode(Bool.self, forKey: .scaleGradByFreq)
        sparse = try container.decode(Bool.self, forKey: .sparse)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weight = try container.decode(Tensor.self, forKey: .weight)
        l2Penalty = try container.decodeIfPresent(Float.self, forKey: .l2Penalty) ?? 0
        parameters = [weight]
        lastIndices = nil
        lastInputShape = nil
        weightGrad = nil
        freqScale = nil
        embeddingDropout = DropoutLayer(dropoutProbability: 0.1, training: trainable, trainable: false, device: device)
        sparseGradAccumulator = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(vocabSize, forKey: .vocabSize)
        try container.encode(embedDim, forKey: .embedDim)
        try container.encodeIfPresent(paddingIdx, forKey: .paddingIdx)
        try container.encodeIfPresent(maxNorm, forKey: .maxNorm)
        try container.encode(normType, forKey: .normType)
        try container.encode(scaleGradByFreq, forKey: .scaleGradByFreq)
        try container.encode(sparse, forKey: .sparse)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(weight, forKey: .weight)
        try container.encode(l2Penalty, forKey: .l2Penalty)
    }

    enum CodingKeys: String, CodingKey {
        case id, vocabSize, embedDim, paddingIdx, maxNorm, normType, scaleGradByFreq, sparse, trainable, device, weight, l2Penalty
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count <= 2 else { return Tensor(data: [], shape: [0, 0]) }
        lastInputShape = input.shape
        let indices: [Int32]
        if input.shape.count == 1 {
            indices = input.data.map { Int32($0) }
        } else {
            indices = input.data.map { Int32($0) }
        }
        lastIndices = indices

        let outputShape: [Int]
        if input.shape.count == 1 {
            outputShape = [input.shape[0], embedDim]
        } else {
            outputShape = [input.shape[0], input.shape[1], embedDim]
        }

        var output = [Float](repeating: 0, count: outputShape.reduce(1, *))
        for (outputIdx, index) in indices.enumerated() {
            let safeIndex = max(0, min(Int(index), vocabSize - 1))
            if let pad = paddingIdx, safeIndex == pad {
                continue
            }
            for d in 0..<embedDim {
                output[outputIdx * embedDim + d] = weight.data[safeIndex * embedDim + d]
            }
            if let maxN = maxNorm {
                var norm: Float = 0
                vDSP_svesq(Array(output[outputIdx * embedDim..<outputIdx * embedDim + embedDim]), 1, &norm, vDSP_Length(embedDim))
                let normVal = pow(norm, 1 / normType)
                if normVal > maxN {
                    let scale = maxN / normVal
                    for d in 0..<embedDim {
                        output[outputIdx * embedDim + d] *= scale
                    }
                }
            }
        }

        if trainable {
            var weightGrad = [Float](repeating: 0, count: vocabSize * embedDim)
            for (outputIdx, index) in indices.enumerated() {
                let safeIndex = max(0, min(Int(index), vocabSize - 1))
                for d in 0..<embedDim {
                    weightGrad[safeIndex * embedDim + d] += output[outputIdx * embedDim + d]
                }
            }
            if scaleGradByFreq, let fs = freqScale {
                for i in 0..<weightGrad.count {
                    weightGrad[i] *= fs[i / embedDim]
                }
            }
            if l2Penalty > 0 {
                for i in 0..<weightGrad.count {
                    weightGrad[i] += l2Penalty * weight.data[i]
                }
            }
            if let existing = weight.grad {
                weight.grad = existing.adding(weightGrad, count: existing.count)
            } else {
                weight.grad = weightGrad
            }
        }

        return Tensor(data: output, shape: outputShape, requiresGrad: trainable)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let indices = lastIndices else { return Tensor(data: [], shape: [0]) }
        let totalIndices = indices.count
        var gradInput = [Float](repeating: 0, count: totalIndices)

        if trainable {
            var weightGrad = [Float](repeating: 0, count: vocabSize * embedDim)
            for (outputIdx, index) in indices.enumerated() {
                let safeIndex = max(0, min(Int(index), vocabSize - 1))
                let gradStart = outputIdx * embedDim
                if gradStart < gradient.data.count {
                    for d in 0..<min(embedDim, gradient.data.count - gradStart) {
                        weightGrad[safeIndex * embedDim + d] += gradient.data[gradStart + d]
                    }
                }
            }
            if let existing = weight.grad {
                weight.grad = existing.adding(weightGrad, count: existing.count)
            } else {
                weight.grad = weightGrad
            }
        }

        return Tensor(data: gradInput, shape: [totalIndices])
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(EmbeddingLayer.self, from: data)
        self.weight = decoded.weight
    }

    public func lookup(_ indices: [Int]) -> Tensor {
        let input = Tensor(data: indices.map { Float($0) }, shape: [indices.count])
        return forward(input)
    }

    public func getEmbedding(for index: Int) -> [Float] {
        let safeIndex = max(0, min(index, vocabSize - 1))
        return Array(weight.data[safeIndex * embedDim..<safeIndex * embedDim + embedDim])
    }

    public func getNorm() -> Float {
        var norm: Float = 0
        vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
        return sqrt(norm)
    }

    public func prune(frequencyThreshold: Float) {
        var newWeight = [Float](repeating: 0, count: vocabSize * embedDim)
        var newVocabSize = 0
        for i in 0..<vocabSize {
            let start = i * embedDim
            let end = start + embedDim
            let row = Array(weight.data[start..<end])
            let freq = row.reduce(0, +) / Float(embedDim)
            if abs(freq) > frequencyThreshold {
                for j in 0..<embedDim {
                    newWeight[newVocabSize * embedDim + j] = weight.data[start + j]
                }
                newVocabSize += 1
            }
        }
        weight = Tensor(data: newWeight, shape: [newVocabSize, embedDim], requiresGrad: trainable, device: device)
    }

    public func updateFrequencyScale() {
        freqScale = [Float](repeating: 1, count: vocabSize)
    }

    public func reset() {
        lastIndices = nil
        lastInputShape = nil
        weightGrad = nil
        sparseGradAccumulator = nil
    }
}

// MARK: - Positional Embedding Layer

public struct PositionalEmbeddingLayer: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let maxSeqLen: Int
    public let embedDim: Int
    public var positionalEmbedding: Tensor
    public var lastInputShape: [Int]?
    public var weightGrad: [Float]?

    public init(maxSeqLen: Int = 5000, embedDim: Int = 512, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu) {
        self.id = UUID()
        self.maxSeqLen = maxSeqLen
        self.embedDim = embedDim
        self.trainable = trainable
        self.device = device

        let embedData = initializer.initialize(size: maxSeqLen * embedDim, fanIn: maxSeqLen, fanOut: embedDim)
        self.positionalEmbedding = Tensor(data: embedData, shape: [maxSeqLen, embedDim], requiresGrad: trainable, device: device)
        self.parameters = [positionalEmbedding]
        self.lastInputShape = nil
        self.weightGrad = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        maxSeqLen = try container.decode(Int.self, forKey: .maxSeqLen)
        embedDim = try container.decode(Int.self, forKey: .embedDim)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        positionalEmbedding = try container.decode(Tensor.self, forKey: .positionalEmbedding)
        parameters = [positionalEmbedding]
        lastInputShape = nil
        weightGrad = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(maxSeqLen, forKey: .maxSeqLen)
        try container.encode(embedDim, forKey: .embedDim)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(positionalEmbedding, forKey: .positionalEmbedding)
    }

    enum CodingKeys: String, CodingKey {
        case id, maxSeqLen, embedDim, trainable, device, positionalEmbedding
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count == 3 else { return input }
        lastInputShape = input.shape
        let batchSize = input.shape[0]
        let seqLen = input.shape[1]
        var output = input.data

        for b in 0..<batchSize {
            for s in 0..<seqLen {
                for d in 0..<embedDim {
                    output[b * seqLen * embedDim + s * embedDim + d] += positionalEmbedding.data[s * embedDim + d]
                }
            }
        }

        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard trainable else { return gradient }
        if let existing = positionalEmbedding.grad {
            positionalEmbedding.grad = existing.adding(gradient.data, count: existing.count)
        } else {
            positionalEmbedding.grad = gradient.data
        }
        return gradient
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(PositionalEmbeddingLayer.self, from: data)
        self.positionalEmbedding = decoded.positionalEmbedding
    }

    public func reset() {
        lastInputShape = nil
        weightGrad = nil
    }
}
