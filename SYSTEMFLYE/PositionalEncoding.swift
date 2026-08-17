import Foundation
import Accelerate

// MARK: - Positional Encoding

public struct PositionalEncoding: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let maxSeqLen: Int
    public let embedDim: Int
    public let encodingType: EncodingType
    public let dropout: Float
    public let learned: Bool
    public let relativePositionBias: Bool
    public let maxRelativePosition: Int
    public var positionalEmbedding: Tensor?
    public var relativePositionTable: Tensor?
    public var lastInputShape: [Int]?
    public var lastEncoding: Tensor?
    public var lastInput: Tensor?
    private var scale: Float = 1

    public enum EncodingType: String, Codable, Sendable, CaseIterable {
        case sinusoidal = "SINUSOIDAL"
        case learned = "LEARNED"
        case rotary = "ROTARY"
        case alibi = "ALIBI"
        case relative = "RELATIVE"
        case t5 = "T5"
        case alibiLearnable = "ALIBI_LEARNABLE"
    }

    public init(maxSeqLen: Int = 5000, embedDim: Int = 512, encodingType: EncodingType = .sinusoidal, dropout: Float = 0.1, learned: Bool = false, relativePositionBias: Bool = false, maxRelativePosition: Int = 128, trainable: Bool = true, device: Device = .cpu, scale: Float = 1) {
        self.id = UUID()
        self.maxSeqLen = maxSeqLen
        self.embedDim = embedDim
        self.encodingType = encodingType
        self.dropout = dropout
        self.learned = learned
        self.relativePositionBias = relativePositionBias
        self.maxRelativePosition = maxRelativePosition
        self.trainable = trainable
        self.device = device
        self.scale = scale

        if learned {
            let embedData = [Float](repeating: 0, count: maxSeqLen * embedDim)
            self.positionalEmbedding = Tensor(data: embedData, shape: [maxSeqLen, embedDim], requiresGrad: trainable, device: device)
        } else {
            self.positionalEmbedding = nil
        }

        if relativePositionBias {
            let tableSize = 2 * maxRelativePosition + 1
            let tableData = [Float](repeating: 0, count: tableSize * embedDim)
            self.relativePositionTable = Tensor(data: tableData, shape: [tableSize, embedDim], requiresGrad: trainable, device: device)
        } else {
            self.relativePositionTable = nil
        }

        self.parameters = positionalEmbedding.map { [$0] } ?? [] + relativePositionTable.map { [$0] } ?? []
        self.lastInputShape = nil
        self.lastEncoding = nil
        self.lastInput = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        maxSeqLen = try container.decode(Int.self, forKey: .maxSeqLen)
        embedDim = try container.decode(Int.self, forKey: .embedDim)
        encodingType = try container.decode(EncodingType.self, forKey: .encodingType)
        dropout = try container.decode(Float.self, forKey: .dropout)
        learned = try container.decode(Bool.self, forKey: .learned)
        relativePositionBias = try container.decode(Bool.self, forKey: .relativePositionBias)
        maxRelativePosition = try container.decode(Int.self, forKey: .maxRelativePosition)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        positionalEmbedding = try container.decodeIfPresent(Tensor.self, forKey: .positionalEmbedding)
        relativePositionTable = try container.decodeIfPresent(Tensor.self, forKey: .relativePositionTable)
        scale = try container.decodeIfPresent(Float.self, forKey: .scale) ?? 1
        parameters = positionalEmbedding.map { [$0] } ?? [] + relativePositionTable.map { [$0] } ?? []
        lastInputShape = nil
        lastEncoding = nil
        lastInput = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(maxSeqLen, forKey: .maxSeqLen)
        try container.encode(embedDim, forKey: .embedDim)
        try container.encode(encodingType, forKey: .encodingType)
        try container.encode(dropout, forKey: .dropout)
        try container.encode(learned, forKey: .learned)
        try container.encode(relativePositionBias, forKey: .relativePositionBias)
        try container.encode(maxRelativePosition, forKey: .maxRelativePosition)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encodeIfPresent(positionalEmbedding, forKey: .positionalEmbedding)
        try container.encodeIfPresent(relativePositionTable, forKey: .relativePositionTable)
        try container.encode(scale, forKey: .scale)
    }

    enum CodingKeys: String, CodingKey {
        case id, maxSeqLen, embedDim, encodingType, dropout, learned, relativePositionBias, maxRelativePosition, trainable, device, positionalEmbedding, relativePositionTable, scale
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count == 3, input.shape[2] == embedDim else { return input }
        lastInputShape = input.shape
        lastInput = input
        let batchSize = input.shape[0]
        let seqLen = input.shape[1]

        var encoding: [Float]

        switch encodingType {
        case .sinusoidal:
            encoding = generateSinusoidal(seqLen: seqLen, embedDim: embedDim)
        case .learned:
            encoding = generateLearned(seqLen: seqLen)
        case .rotary:
            encoding = generateRotary(seqLen: seqLen, embedDim: embedDim)
        case .alibi:
            encoding = generateALiBi(seqLen: seqLen, embedDim: embedDim, numHeads: embedDim / 64)
        case .relative:
            encoding = generateRelative(seqLen: seqLen, embedDim: embedDim)
        case .t5:
            encoding = generateT5(seqLen: seqLen, embedDim: embedDim)
        case .alibiLearnable:
            encoding = generateALiBiLearnable(seqLen: seqLen, embedDim: embedDim, numHeads: embedDim / 64)
        }

        var output = input.data
        for i in 0..<output.count {
            output[i] += encoding[i % encoding.count] * scale
        }

        lastEncoding = Tensor(data: encoding, shape: [seqLen, embedDim])
        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let inputShape = lastInputShape else { return gradient }
        if learned, let posEmbed = positionalEmbedding, trainable {
            if let existing = posEmbed.grad {
                posEmbed.grad = existing.adding(gradient.data, count: existing.count)
            } else {
                posEmbed.grad = gradient.data
            }
        }
        return gradient
    }

    private func generateSinusoidal(seqLen: Int, embedDim: Int) -> [Float] {
        var encoding = [Float](repeating: 0, count: seqLen * embedDim)
        for pos in 0..<seqLen {
            for i in 0..<embedDim / 2 {
                let angle = Float(pos) / pow(10000, Float(2 * i) / Float(embedDim))
                encoding[pos * embedDim + 2 * i] = sin(angle)
                encoding[pos * embedDim + 2 * i + 1] = cos(angle)
            }
        }
        return encoding
    }

    private func generateLearned(seqLen: Int) -> [Float] {
        guard let posEmbed = positionalEmbedding else { return [Float](repeating: 0, count: seqLen * embedDim) }
        var result = [Float](repeating: 0, count: seqLen * embedDim)
        let count = min(seqLen, maxSeqLen)
        for i in 0..<count {
            for j in 0..<embedDim {
                result[i * embedDim + j] = posEmbed.data[i * embedDim + j]
            }
        }
        return result
    }

    private func generateRotary(seqLen: Int, embedDim: Int) -> [Float] {
        var encoding = [Float](repeating: 0, count: seqLen * embedDim)
        for pos in 0..<seqLen {
            for i in 0..<embedDim / 2 {
                let angle = Float(pos) / pow(10000, Float(2 * i) / Float(embedDim))
                let cosVal = cos(angle)
                let sinVal = sin(angle)
                encoding[pos * embedDim + 2 * i] = cosVal
                encoding[pos * embedDim + 2 * i + 1] = sinVal
            }
        }
        return encoding
    }

    private func generateALiBi(seqLen: Int, embedDim: Int, numHeads: Int) -> [Float] {
        var encoding = [Float](repeating: 0, count: seqLen * embedDim)
        for head in 0..<numHeads {
            let slope = pow(2, Float(-8 * head / numHeads))
            for pos in 0..<seqLen {
                for i in 0..<seqLen {
                    let bias = -abs(Float(pos) - Float(i)) * slope
                    encoding[pos * embedDim + head * (seqLen / numHeads) + (i % (seqLen / numHeads))] = bias
                }
            }
        }
        return encoding
    }

    private func generateRelative(seqLen: Int, embedDim: Int) -> [Float] {
        var encoding = [Float](repeating: 0, count: seqLen * embedDim)
        for pos in 0..<seqLen {
            for i in 0..<embedDim {
                let relativePos = pos - i
                let clamped = max(-maxRelativePosition, min(maxRelativePosition, relativePos))
                let index = clamped + maxRelativePosition
                if let table = relativePositionTable {
                    encoding[pos * embedDim + i] = table.data[index * embedDim + i]
                }
            }
        }
        return encoding
    }

    private func generateT5(seqLen: Int, embedDim: Int) -> [Float] {
        var encoding = [Float](repeating: 0, count: seqLen * embedDim)
        for pos in 0..<seqLen {
            for i in 0..<embedDim / 2 {
                let angle = Float(pos) / pow(10000, Float(2 * i) / Float(embedDim))
                encoding[pos * embedDim + 2 * i] = sin(angle)
                encoding[pos * embedDim + 2 * i + 1] = cos(angle)
            }
        }
        for pos in 0..<seqLen {
            for i in embedDim / 2..<embedDim {
                encoding[pos * embedDim + i] = 0
            }
        }
        return encoding
    }

    private func generateALiBiLearnable(seqLen: Int, embedDim: Int, numHeads: Int) -> [Float] {
        var encoding = [Float](repeating: 0, count: seqLen * embedDim)
        for head in 0..<numHeads {
            let slope = pow(2, Float(-8 * head / numHeads))
            for pos in 0..<seqLen {
                for i in 0..<seqLen {
                    let bias = -abs(Float(pos) - Float(i)) * slope
                    encoding[pos * embedDim + head * (seqLen / numHeads) + (i % (seqLen / numHeads))] = bias
                }
            }
        }
        return encoding
    }

    public func getEncoding(for position: Int) -> [Float] {
        let encoding: [Float]
        switch encodingType {
        case .sinusoidal:
            var result = [Float](repeating: 0, count: embedDim)
            for i in 0..<embedDim / 2 {
                let angle = Float(position) / pow(10000, Float(2 * i) / Float(embedDim))
                result[2 * i] = sin(angle)
                result[2 * i + 1] = cos(angle)
            }
            encoding = result
        case .learned:
            guard let posEmbed = positionalEmbedding else { return [Float](repeating: 0, count: embedDim) }
            encoding = Array(posEmbed.data[position * embedDim..<min((position + 1) * embedDim, posEmbed.data.count)])
        default:
            encoding = [Float](repeating: 0, count: embedDim)
        }
        return encoding
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(PositionalEncoding.self, from: data)
        self.positionalEmbedding = decoded.positionalEmbedding
        self.relativePositionTable = decoded.relativePositionTable
    }

    public func reset() {
        lastInputShape = nil
        lastEncoding = nil
        lastInput = nil
    }
    public func clone() -> PositionalEncoding {
        var pe = self
        pe.id = UUID()
        return pe
    }
}
