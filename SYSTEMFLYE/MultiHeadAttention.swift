import Foundation
import Accelerate

// MARK: - Multi-Head Attention

public struct MultiHeadAttention: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let embedDim: Int
    public let numHeads: Int
    public let headDim: Int
    public let dropout: Float
    public let causal: Bool
    public let scale: Float
    public let attentionDropout: Float
    public let projectionDropout: Float
    public let qkvBias: Bool
    public let outBias: Bool
    public var weightQ: Tensor
    public var weightK: Tensor
    public var weightV: Tensor
    public var weightO: Tensor
    public var biasQ: Tensor?
    public var biasK: Tensor?
    public var biasV: Tensor?
    public var biasO: Tensor?
    public var weightQGrad: [Float]?
    public var weightKGrad: [Float]?
    public var weightVGrad: [Float]?
    public var weightOGrad: [Float]?

    private var query: Tensor?
    private var key: Tensor?
    private var value: Tensor?
    private var attentionWeights: Tensor?
    private var maskedAttentionWeights: Tensor?
    private var context: Tensor?
    private var lastInputShape: [Int]?
    private var lastInput: Tensor?
    private var lastQ: Tensor?
    private var lastK: Tensor?
    private var lastV: Tensor?
    private var dropoutMask: [Float]?
    private var scaleFactor: Float
    private var attnScale: Float

    public init(embedDim: Int, numHeads: Int, dropout: Float = 0.1, causal: Bool = true, qkvBias: Bool = true, outBias: Bool = true, attentionDropout: Float = 0.1, projectionDropout: Float = 0.1, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu, attnScale: Float = 1) {
        self.id = UUID()
        self.embedDim = embedDim
        self.numHeads = numHeads
        self.headDim = embedDim / numHeads
        self.dropout = dropout
        self.causal = causal
        self.attentionDropout = attentionDropout
        self.projectionDropout = projectionDropout
        self.qkvBias = qkvBias
        self.outBias = outBias
        self.trainable = trainable
        self.device = device
        self.scaleFactor = 1 / sqrt(Float(headDim))
        self.attnScale = attnScale

        let qData = initializer.initialize(size: embedDim * embedDim, fanIn: embedDim, fanOut: embedDim)
        self.weightQ = Tensor(data: qData, shape: [embedDim, embedDim], requiresGrad: trainable, device: device)

        let kData = initializer.initialize(size: embedDim * embedDim, fanIn: embedDim, fanOut: embedDim)
        self.weightK = Tensor(data: kData, shape: [embedDim, embedDim], requiresGrad: trainable, device: device)

        let vData = initializer.initialize(size: embedDim * embedDim, fanIn: embedDim, fanOut: embedDim)
        self.weightV = Tensor(data: vData, shape: [embedDim, embedDim], requiresGrad: trainable, device: device)

        let oData = initializer.initialize(size: embedDim * embedDim, fanIn: embedDim, fanOut: embedDim)
        self.weightO = Tensor(data: oData, shape: [embedDim, embedDim], requiresGrad: trainable, device: device)

        if qkvBias {
            let biasQData = [Float](repeating: 0, count: embedDim)
            self.biasQ = Tensor(data: biasQData, shape: [embedDim], requiresGrad: trainable, device: device)
            let biasKData = [Float](repeating: 0, count: embedDim)
            self.biasK = Tensor(data: biasKData, shape: [embedDim], requiresGrad: trainable, device: device)
            let biasVData = [Float](repeating: 0, count: embedDim)
            self.biasV = Tensor(data: biasVData, shape: [embedDim], requiresGrad: trainable, device: device)
        } else {
            self.biasQ = nil
            self.biasK = nil
            self.biasV = nil
        }

        if outBias {
            let biasOData = [Float](repeating: 0, count: embedDim)
            self.biasO = Tensor(data: biasOData, shape: [embedDim], requiresGrad: trainable, device: device)
        } else {
            self.biasO = nil
        }

        self.parameters = [weightQ, weightK, weightV, weightO] + (biasQ.map { [$0] } ?? []) + (biasK.map { [$0] } ?? []) + (biasV.map { [$0] } ?? []) + (biasO.map { [$0] } ?? [])
        self.query = nil
        self.key = nil
        self.value = nil
        self.attentionWeights = nil
        self.maskedAttentionWeights = nil
        self.context = nil
        self.lastInputShape = nil
        self.lastInput = nil
        self.lastQ = nil
        self.lastK = nil
        self.lastV = nil
        self.dropoutMask = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        embedDim = try container.decode(Int.self, forKey: .embedDim)
        numHeads = try container.decode(Int.self, forKey: .numHeads)
        headDim = embedDim / numHeads
        dropout = try container.decode(Float.self, forKey: .dropout)
        causal = try container.decode(Bool.self, forKey: .causal)
        attentionDropout = try container.decode(Float.self, forKey: .attentionDropout)
        projectionDropout = try container.decode(Float.self, forKey: .projectionDropout)
        qkvBias = try container.decode(Bool.self, forKey: .qkvBias)
        outBias = try container.decode(Bool.self, forKey: .outBias)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weightQ = try container.decode(Tensor.self, forKey: .weightQ)
        weightK = try container.decode(Tensor.self, forKey: .weightK)
        weightV = try container.decode(Tensor.self, forKey: .weightV)
        weightO = try container.decode(Tensor.self, forKey: .weightO)
        biasQ = try container.decodeIfPresent(Tensor.self, forKey: .biasQ)
        biasK = try container.decodeIfPresent(Tensor.self, forKey: .biasK)
        biasV = try container.decodeIfPresent(Tensor.self, forKey: .biasV)
        biasO = try container.decodeIfPresent(Tensor.self, forKey: .biasO)
        attnScale = try container.decodeIfPresent(Float.self, forKey: .attnScale) ?? 1
        scaleFactor = 1 / sqrt(Float(headDim))
        parameters = [weightQ, weightK, weightV, weightO] + (biasQ.map { [$0] } ?? []) + (biasK.map { [$0] } ?? []) + (biasV.map { [$0] } ?? []) + (biasO.map { [$0] } ?? [])
        query = nil
        key = nil
        value = nil
        attentionWeights = nil
        maskedAttentionWeights = nil
        context = nil
        lastInputShape = nil
        lastInput = nil
        lastQ = nil
        lastK = nil
        lastV = nil
        dropoutMask = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(embedDim, forKey: .embedDim)
        try container.encode(numHeads, forKey: .numHeads)
        try container.encode(dropout, forKey: .dropout)
        try container.encode(causal, forKey: .causal)
        try container.encode(attentionDropout, forKey: .attentionDropout)
        try container.encode(projectionDropout, forKey: .projectionDropout)
        try container.encode(qkvBias, forKey: .qkvBias)
        try container.encode(outBias, forKey: .outBias)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(weightQ, forKey: .weightQ)
        try container.encode(weightK, forKey: .weightK)
        try container.encode(weightV, forKey: .weightV)
        try container.encode(weightO, forKey: .weightO)
        try container.encodeIfPresent(biasQ, forKey: .biasQ)
        try container.encodeIfPresent(biasK, forKey: .biasK)
        try container.encodeIfPresent(biasV, forKey: .biasV)
        try container.encodeIfPresent(biasO, forKey: .biasO)
        try container.encode(attnScale, forKey: .attnScale)
    }

    enum CodingKeys: String, CodingKey {
        case id, embedDim, numHeads, dropout, causal, attentionDropout, projectionDropout, qkvBias, outBias, trainable, device, weightQ, weightK, weightV, weightO, biasQ, biasK, biasV, biasO, attnScale
    }

    public func forward(_ input: Tensor) -> Tensor {
        lastInputShape = input.shape
        let batchSize = input.shape[0]
        let seqLen = input.shape.count > 1 ? input.shape[1] : 1
        lastInput = input

        var q = [Float](repeating: 0, count: batchSize * seqLen * embedDim)
        var k = [Float](repeating: 0, count: batchSize * seqLen * embedDim)
        var v = [Float](repeating: 0, count: batchSize * seqLen * embedDim)

        vDSP_mmul(input.data, 1, weightQ.data, 1, &q, 1, vDSP_Length(batchSize * seqLen), vDSP_Length(embedDim), vDSP_Length(embedDim))
        vDSP_mmul(input.data, 1, weightK.data, 1, &k, 1, vDSP_Length(batchSize * seqLen), vDSP_Length(embedDim), vDSP_Length(embedDim))
        vDSP_mmul(input.data, 1, weightV.data, 1, &v, 1, vDSP_Length(batchSize * seqLen), vDSP_Length(embedDim), vDSP_Length(embedDim))

        if let bq = biasQ {
            for i in 0..<batchSize * seqLen {
                vDSP_vadd(bq.data, 1, &q[i * embedDim], 1, &q[i * embedDim], 1, vDSP_Length(embedDim))
            }
        }
        if let bk = biasK {
            for i in 0..<batchSize * seqLen {
                vDSP_vadd(bk.data, 1, &k[i * embedDim], 1, &k[i * embedDim], 1, vDSP_Length(embedDim))
            }
        }
        if let bv = biasV {
            for i in 0..<batchSize * seqLen {
                vDSP_vadd(bv.data, 1, &v[i * embedDim], 1, &v[i * embedDim], 1, vDSP_Length(embedDim))
            }
        }

        var qMultiHead = [Float](repeating: 0, count: batchSize * numHeads * seqLen * headDim)
        var kMultiHead = [Float](repeating: 0, count: batchSize * numHeads * seqLen * headDim)
        var vMultiHead = [Float](repeating: 0, count: batchSize * numHeads * seqLen * headDim)

        for b in 0..<batchSize {
            for h in 0..<numHeads {
                for s in 0..<seqLen {
                    for d in 0..<headDim {
                        let srcIdx = b * seqLen * embedDim + s * embedDim + h * headDim + d
                        let dstIdx = b * numHeads * seqLen * headDim + h * seqLen * headDim + s * headDim + d
                        qMultiHead[dstIdx] = q[srcIdx] * scaleFactor * attnScale
                        kMultiHead[dstIdx] = k[srcIdx]
                        vMultiHead[dstIdx] = v[srcIdx]
                    }
                }
            }
        }

        var attention = [Float](repeating: 0, count: batchSize * numHeads * seqLen * seqLen)
        for b in 0..<batchSize {
            for h in 0..<numHeads {
                for i in 0..<seqLen {
                    for j in 0..<seqLen {
                        if causal && j > i {
                            attention[b * numHeads * seqLen * seqLen + h * seqLen * seqLen + i * seqLen + j] = -1e9
                        } else {
                            var dot: Float = 0
                            for d in 0..<headDim {
                                let qIdx = b * numHeads * seqLen * headDim + h * seqLen * headDim + i * headDim + d
                                let kIdx = b * numHeads * seqLen * headDim + h * seqLen * headDim + j * headDim + d
                                dot += qMultiHead[qIdx] * kMultiHead[kIdx]
                            }
                            attention[b * numHeads * seqLen * seqLen + h * seqLen * seqLen + i * seqLen + j] = dot
                        }
                    }
                }
            }
        }

        var softmaxAttention = [Float](repeating: 0, count: attention.count)
        for b in 0..<batchSize {
            for h in 0..<numHeads {
                for i in 0..<seqLen {
                    var rowStart = b * numHeads * seqLen * seqLen + h * seqLen * seqLen + i * seqLen
                    var row = Array(attention[rowStart..<rowStart + seqLen])
                    var maxVal: Float = 0
                    vDSP_maxv(row, 1, &maxVal, vDSP_Length(seqLen))
                    var shifted = row.map { $0 - maxVal }
                    var expValues = shifted.map { exp($0) }
                    var sum: Float = 0
                    vDSP_sve(expValues, 1, &sum, vDSP_Length(seqLen))
                    var softmax = expValues.map { $0 / sum }

                    if trainable && Float.random(in: 0...1) < attentionDropout {
                        let scale = 1 / (1 - attentionDropout)
                        softmax = softmax.map { $0 * (Float.random(in: 0...1) > attentionDropout ? scale : 0) }
                    }

                    for j in 0..<seqLen {
                        softmaxAttention[rowStart + j] = softmax[j]
                    }
                }
            }
        }

        self.attentionWeights = Tensor(data: softmaxAttention, shape: [batchSize, numHeads, seqLen, seqLen])
        self.maskedAttentionWeights = Tensor(data: attention, shape: [batchSize, numHeads, seqLen, seqLen])

        var contextMultiHead = [Float](repeating: 0, count: batchSize * numHeads * seqLen * headDim)
        for b in 0..<batchSize {
            for h in 0..<numHeads {
                for i in 0..<seqLen {
                    for d in 0..<headDim {
                        var sum: Float = 0
                        for j in 0..<seqLen {
                            let attnIdx = b * numHeads * seqLen * seqLen + h * seqLen * seqLen + i * seqLen + j
                            let vIdx = b * numHeads * seqLen * headDim + h * seqLen * headDim + j * headDim + d
                            sum += softmaxAttention[attnIdx] * vMultiHead[vIdx]
                        }
                        contextMultiHead[b * numHeads * seqLen * headDim + h * seqLen * headDim + i * headDim + d] = sum
                    }
                }
            }
        }

        var context = [Float](repeating: 0, count: batchSize * seqLen * embedDim)
        for b in 0..<batchSize {
            for s in 0..<seqLen {
                for h in 0..<numHeads {
                    for d in 0..<headDim {
                        let srcIdx = b * numHeads * seqLen * headDim + h * seqLen * headDim + s * headDim + d
                        let dstIdx = b * seqLen * embedDim + s * embedDim + h * headDim + d
                        context[dstIdx] += contextMultiHead[srcIdx]
                    }
                }
            }
        }

        var output = [Float](repeating: 0, count: batchSize * seqLen * embedDim)
        vDSP_mmul(context, 1, weightO.data, 1, &output, 1, vDSP_Length(batchSize * seqLen), vDSP_Length(embedDim), vDSP_Length(embedDim))

        if let bo = biasO {
            for i in 0..<batchSize * seqLen {
                vDSP_vadd(bo.data, 1, &output[i * embedDim], 1, &output[i * embedDim], 1, vDSP_Length(embedDim))
            }
        }

        self.context = Tensor(data: output, shape: [batchSize, seqLen, embedDim])
        self.query = Tensor(data: q, shape: [batchSize, seqLen, embedDim])
        self.key = Tensor(data: k, shape: [batchSize, seqLen, embedDim])
        self.value = Tensor(data: v, shape: [batchSize, seqLen, embedDim])
        self.lastQ = Tensor(data: qMultiHead, shape: [batchSize, numHeads, seqLen, headDim])
        self.lastK = Tensor(data: kMultiHead, shape: [batchSize, numHeads, seqLen, headDim])
        self.lastV = Tensor(data: vMultiHead, shape: [batchSize, numHeads, seqLen, headDim])

        return Tensor(data: output, shape: [batchSize, seqLen, embedDim], requiresGrad: trainable)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let q = query, let k = key, let v = value, let inputShape = lastInputShape else { return gradient }
        let batchSize = inputShape[0]
        let seqLen = inputShape.count > 1 ? inputShape[1] : 1

        if trainable {
            var weightQGrad = [Float](repeating: 0, count: embedDim * embedDim)
            var weightKGrad = [Float](repeating: 0, count: embedDim * embedDim)
            var weightVGrad = [Float](repeating: 0, count: embedDim * embedDim)
            var weightOGrad = [Float](repeating: 0, count: embedDim * embedDim)

            if let existing = weightQ.grad {
                weightQ.grad = existing.adding(weightQGrad, count: existing.count)
            } else {
                weightQ.grad = weightQGrad
            }
            if let existing = weightK.grad {
                weightK.grad = existing.adding(weightKGrad, count: existing.count)
            } else {
                weightK.grad = weightKGrad
            }
            if let existing = weightV.grad {
                weightV.grad = existing.adding(weightVGrad, count: existing.count)
            } else {
                weightV.grad = weightVGrad
            }
            if let existing = weightO.grad {
                weightO.grad = existing.adding(weightOGrad, count: existing.count)
            } else {
                weightO.grad = weightOGrad
            }
        }

        var gradInput = [Float](repeating: 0, count: batchSize * seqLen * embedDim)
        vDSP_mmul(gradient.data, 1, weightQ.data, 1, &gradInput, 1, vDSP_Length(batchSize * seqLen), vDSP_Length(embedDim), vDSP_Length(embedDim))
        return Tensor(data: gradInput, shape: inputShape)
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(MultiHeadAttention.self, from: data)
        self.weightQ = decoded.weightQ
        self.weightK = decoded.weightK
        self.weightV = decoded.weightV
        self.weightO = decoded.weightO
        self.biasQ = decoded.biasQ
        self.biasK = decoded.biasK
        self.biasV = decoded.biasV
        self.biasO = decoded.biasO
    }

    public func getAttentionWeights() -> Tensor? { attentionWeights }
    public func getContext() -> Tensor? { context }
    public func getQuery() -> Tensor? { query }
    public func getKey() -> Tensor? { key }
    public func getValue() -> Tensor? { value }
    public func getHeadOutputs() -> Tensor? { lastQ }
    public func reset() {
        query = nil
        key = nil
        value = nil
        attentionWeights = nil
        maskedAttentionWeights = nil
        context = nil
        lastInput = nil
        lastQ = nil
        lastK = nil
        lastV = nil
        dropoutMask = nil
    }
    public func clone() -> MultiHeadAttention {
        var attn = self
        attn.id = UUID()
        return attn
    }
}
