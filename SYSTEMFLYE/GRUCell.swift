import Foundation
import Accelerate

// MARK: - GRU Cell

public struct GRUCell: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let inputSize: Int
    public let hiddenSize: Int
    public let useLayerNorm: Bool
    public let useResetAfter: Bool
    public var weight: Tensor
    public var bias: Tensor
    public var weightGrad: [Float]?
    public var biasGrad: [Float]?
    public var weightIH: Tensor
    public var weightHH: Tensor
    public var weightIHGrad: [Float]?
    public var weightHHGrad: [Float]?
    public var gammaZ: Tensor?
    public var gammaR: Tensor?
    public var gammaN: Tensor?
    public var betaZ: Tensor?
    public var betaR: Tensor?
    public var betaN: Tensor?
    public var runningMeanZ: Tensor?
    public var runningVarZ: Tensor?
    public var runningMeanR: Tensor?
    public var runningVarR: Tensor?
    public var runningMeanN: Tensor?
    public var runningVarN: Tensor?

    private var hPrev: Tensor?
    private var zGate: Tensor?
    private var rGate: Tensor?
    private var nGate: Tensor?
    private var hiddenState: Tensor?
    private var lastInput: Tensor?
    private var lastPreZ: Tensor?
    private var lastPreR: Tensor?
    private var lastPreN: Tensor?
    private var eps: Float = 1e-5
    private var momentum: Float = 0.1
    private var clipValue: Float = 5
    private var l2Penalty: Float = 0

    public init(inputSize: Int, hiddenSize: Int, useLayerNorm: Bool = false, useResetAfter: Bool = true, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu, clipValue: Float = 5, l2Penalty: Float = 0) {
        self.id = UUID()
        self.inputSize = inputSize
        self.hiddenSize = hiddenSize
        self.useLayerNorm = useLayerNorm
        self.useResetAfter = useResetAfter
        self.trainable = trainable
        self.device = device
        self.clipValue = clipValue
        self.l2Penalty = l2Penalty

        let weightIHData = initializer.initialize(size: 3 * hiddenSize * inputSize, fanIn: inputSize, fanOut: hiddenSize)
        self.weightIH = Tensor(data: weightIHData, shape: [3 * hiddenSize, inputSize], requiresGrad: trainable, device: device)

        let weightHHData = initializer.initialize(size: 3 * hiddenSize * hiddenSize, fanIn: hiddenSize, fanOut: hiddenSize)
        self.weightHH = Tensor(data: weightHHData, shape: [3 * hiddenSize, hiddenSize], requiresGrad: trainable, device: device)

        let biasIHData = [Float](repeating: 0, count: 3 * hiddenSize)
        self.bias = Tensor(data: biasIHData, shape: [3 * hiddenSize], requiresGrad: trainable, device: device)

        if useLayerNorm {
            let gammaData = [Float](repeating: 1, count: hiddenSize)
            self.gammaZ = Tensor(data: gammaData, shape: [hiddenSize], requiresGrad: trainable, device: device)
            self.gammaR = Tensor(data: gammaData, shape: [hiddenSize], requiresGrad: trainable, device: device)
            self.gammaN = Tensor(data: gammaData, shape: [hiddenSize], requiresGrad: trainable, device: device)

            let betaData = [Float](repeating: 0, count: hiddenSize)
            self.betaZ = Tensor(data: betaData, shape: [hiddenSize], requiresGrad: trainable, device: device)
            self.betaR = Tensor(data: betaData, shape: [hiddenSize], requiresGrad: trainable, device: device)
            self.betaN = Tensor(data: betaData, shape: [hiddenSize], requiresGrad: trainable, device: device)

            let runningMeanData = [Float](repeating: 0, count: hiddenSize)
            let runningVarData = [Float](repeating: 1, count: hiddenSize)
            self.runningMeanZ = Tensor(data: runningMeanData, shape: [hiddenSize], requiresGrad: false, device: device)
            self.runningVarZ = Tensor(data: runningVarData, shape: [hiddenSize], requiresGrad: false, device: device)
            self.runningMeanR = Tensor(data: runningMeanData, shape: [hiddenSize], requiresGrad: false, device: device)
            self.runningVarR = Tensor(data: runningVarData, shape: [hiddenSize], requiresGrad: false, device: device)
            self.runningMeanN = Tensor(data: runningMeanData, shape: [hiddenSize], requiresGrad: false, device: device)
            self.runningVarN = Tensor(data: runningVarData, shape: [hiddenSize], requiresGrad: false, device: device)
        }

        var allParams: [Tensor] = [weightIH, weightHH, bias]
        if let gZ = gammaZ { allParams.append(gZ) }
        if let gR = gammaR { allParams.append(gR) }
        if let gN = gammaN { allParams.append(gN) }
        if let bZ = betaZ { allParams.append(bZ) }
        if let bR = betaR { allParams.append(bR) }
        if let bN = betaN { allParams.append(bN) }
        self.parameters = allParams
        self.weight = weightIH
        self.weightGrad = nil
        self.biasGrad = nil
        self.weightIHGrad = nil
        self.weightHHGrad = nil
        self.hPrev = nil
        self.zGate = nil
        self.rGate = nil
        self.nGate = nil
        self.hiddenState = nil
        self.lastInput = nil
        self.lastPreZ = nil
        self.lastPreR = nil
        self.lastPreN = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inputSize = try container.decode(Int.self, forKey: .inputSize)
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        useLayerNorm = try container.decode(Bool.self, forKey: .useLayerNorm)
        useResetAfter = try container.decode(Bool.self, forKey: .useResetAfter)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weightIH = try container.decode(Tensor.self, forKey: .weightIH)
        weightHH = try container.decode(Tensor.self, forKey: .weightHH)
        bias = try container.decode(Tensor.self, forKey: .bias)
        gammaZ = try container.decodeIfPresent(Tensor.self, forKey: .gammaZ)
        gammaR = try container.decodeIfPresent(Tensor.self, forKey: .gammaR)
        gammaN = try container.decodeIfPresent(Tensor.self, forKey: .gammaN)
        betaZ = try container.decodeIfPresent(Tensor.self, forKey: .betaZ)
        betaR = try container.decodeIfPresent(Tensor.self, forKey: .betaR)
        betaN = try container.decodeIfPresent(Tensor.self, forKey: .betaN)
        runningMeanZ = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanZ)
        runningVarZ = try container.decodeIfPresent(Tensor.self, forKey: .runningVarZ)
        runningMeanR = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanR)
        runningVarR = try container.decodeIfPresent(Tensor.self, forKey: .runningVarR)
        runningMeanN = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanN)
        runningVarN = try container.decodeIfPresent(Tensor.self, forKey: .runningVarN)
        clipValue = try container.decodeIfPresent(Float.self, forKey: .clipValue) ?? 5
        l2Penalty = try container.decodeIfPresent(Float.self, forKey: .l2Penalty) ?? 0
        weight = weightIH
        var allParams: [Tensor] = [weightIH, weightHH, bias]
        if let gZ = gammaZ { allParams.append(gZ) }
        if let gR = gammaR { allParams.append(gR) }
        if let gN = gammaN { allParams.append(gN) }
        if let bZ = betaZ { allParams.append(bZ) }
        if let bR = betaR { allParams.append(bR) }
        if let bN = betaN { allParams.append(bN) }
        parameters = allParams
        weightGrad = nil
        biasGrad = nil
        weightIHGrad = nil
        weightHHGrad = nil
        hPrev = nil
        zGate = nil
        rGate = nil
        nGate = nil
        hiddenState = nil
        lastInput = nil
        lastPreZ = nil
        lastPreR = nil
        lastPreN = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(inputSize, forKey: .inputSize)
        try container.encode(hiddenSize, forKey: .hiddenSize)
        try container.encode(useLayerNorm, forKey: .useLayerNorm)
        try container.encode(useResetAfter, forKey: .useResetAfter)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(weightIH, forKey: .weightIH)
        try container.encode(weightHH, forKey: .weightHH)
        try container.encode(bias, forKey: .bias)
        try container.encodeIfPresent(gammaZ, forKey: .gammaZ)
        try container.encodeIfPresent(gammaR, forKey: .gammaR)
        try container.encodeIfPresent(gammaN, forKey: .gammaN)
        try container.encodeIfPresent(betaZ, forKey: .betaZ)
        try container.encodeIfPresent(betaR, forKey: .betaR)
        try container.encodeIfPresent(betaN, forKey: .betaN)
        try container.encodeIfPresent(runningMeanZ, forKey: .runningMeanZ)
        try container.encodeIfPresent(runningVarZ, forKey: .runningVarZ)
        try container.encodeIfPresent(runningMeanR, forKey: .runningMeanR)
        try container.encodeIfPresent(runningVarR, forKey: .runningVarR)
        try container.encodeIfPresent(runningMeanN, forKey: .runningMeanN)
        try container.encodeIfPresent(runningVarN, forKey: .runningVarN)
        try container.encode(clipValue, forKey: .clipValue)
        try container.encode(l2Penalty, forKey: .l2Penalty)
    }

    enum CodingKeys: String, CodingKey {
        case id, inputSize, hiddenSize, useLayerNorm, useResetAfter, trainable, device, weightIH, weightHH, bias, gammaZ, gammaR, gammaN, betaZ, betaR, betaN, runningMeanZ, runningVarZ, runningMeanR, runningVarR, runningMeanN, runningVarN, clipValue, l2Penalty
    }

    public func forward(_ input: Tensor) -> Tensor {
        let batchSize = input.shape.count > 1 ? input.shape[0] : 1
        let h = hPrev?.data ?? [Float](repeating: 0, count: batchSize * hiddenSize)
        lastInput = input

        var gates = [Float](repeating: 0, count: batchSize * 3 * hiddenSize)
        var combinedIH = [Float](repeating: 0, count: batchSize * 3 * hiddenSize)
        var combinedHH = [Float](repeating: 0, count: batchSize * 3 * hiddenSize)

        vDSP_mmul(input.data, 1, weightIH.data, 1, &combinedIH, 1, vDSP_Length(batchSize), vDSP_Length(inputSize), vDSP_Length(3 * hiddenSize))
        vDSP_mmul(h, 1, weightHH.data, 1, &combinedHH, 1, vDSP_Length(batchSize), vDSP_Length(hiddenSize), vDSP_Length(3 * hiddenSize))

        for i in 0..<batchSize * 3 * hiddenSize {
            gates[i] = combinedIH[i] + combinedHH[i] + bias.data[i]
        }

        if useLayerNorm {
            for gate in 0..<3 {
                let start = gate * hiddenSize
                for b in 0..<batchSize {
                    let offset = b * 3 * hiddenSize + start
                    var mean: Float = 0
                    vDSP_meanv(Array(gates[offset..<offset + hiddenSize]), 1, &mean, vDSP_Length(hiddenSize))
                    var centered = [Float](repeating: 0, count: hiddenSize)
                    vDSP_vsub(Array(repeating: mean, count: hiddenSize), 1, Array(gates[offset..<offset + hiddenSize]), 1, &centered, 1, vDSP_Length(hiddenSize))
                    var varVal: Float = 0
                    vDSP_svesq(centered, 1, &varVal, vDSP_Length(hiddenSize))
                    let std = sqrt(varVal / Float(hiddenSize) + eps)
                    var normalized = centered.map { $0 / std }
                    for k in 0..<hiddenSize {
                        gates[offset + k] = normalized[k]
                    }
                }
            }
        }

        var z = [Float](repeating: 0, count: batchSize * hiddenSize)
        var r = [Float](repeating: 0, count: batchSize * hiddenSize)
        var n = [Float](repeating: 0, count: batchSize * hiddenSize)
        var newH = [Float](repeating: 0, count: batchSize * hiddenSize)

        for b in 0..<batchSize {
            for h in 0..<hiddenSize {
                let idx = b * 3 * hiddenSize + h
                z[b * hiddenSize + h] = 1 / (1 + exp(-gates[idx]))
                r[b * hiddenSize + h] = 1 / (1 + exp(-gates[hiddenSize + idx]))
                let rApplied = useResetAfter ? r[b * hiddenSize + h] * h[b * hiddenSize + h] : h[b * hiddenSize + h]
                n[b * hiddenSize + h] = tanh(gates[2 * hiddenSize + idx] + rApplied * 0)
                newH[b * hiddenSize + h] = (1 - z[b * hiddenSize + h]) * h[b * hiddenSize + h] + z[b * hiddenSize + h] * n[b * hiddenSize + h]
            }
        }

        for i in 0..<newH.count {
            newH[i] = max(-clipValue, min(clipValue, newH[i]))
        }

        if l2Penalty > 0 {
            var norm: Float = 0
            vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
            for i in 0..<newH.count {
                newH[i] += l2Penalty * sqrt(norm)
            }
        }

        self.hPrev = Tensor(data: newH, shape: [batchSize, hiddenSize], requiresGrad: trainable, device: device)
        self.zGate = Tensor(data: z, shape: [batchSize, hiddenSize])
        self.rGate = Tensor(data: r, shape: [batchSize, hiddenSize])
        self.nGate = Tensor(data: n, shape: [batchSize, hiddenSize])
        self.hiddenState = Tensor(data: newH, shape: [batchSize, hiddenSize])
        self.lastPreZ = Tensor(data: Array(gates[0..<batchSize * hiddenSize]), shape: [batchSize, hiddenSize])
        self.lastPreR = Tensor(data: Array(gates[batchSize * hiddenSize..<2 * batchSize * hiddenSize]), shape: [batchSize, hiddenSize])
        self.lastPreN = Tensor(data: Array(gates[2 * batchSize * hiddenSize..<3 * batchSize * hiddenSize]), shape: [batchSize, hiddenSize])

        return Tensor(data: newH, shape: [batchSize, hiddenSize], requiresGrad: trainable)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let input = lastInput else { return gradient }
        let batchSize = input.shape.count > 1 ? input.shape[0] : 1
        var gradInput = [Float](repeating: 0, count: batchSize * inputSize)
        var gradH = gradient.data

        if trainable {
            var weightIHGrad = [Float](repeating: 0, count: 3 * hiddenSize * inputSize)
            var weightHHGrad = [Float](repeating: 0, count: 3 * hiddenSize * hiddenSize)
            var biasGrad = [Float](repeating: 0, count: 3 * hiddenSize)

            if let existing = weightIH.grad {
                weightIH.grad = existing.adding(weightIHGrad, count: existing.count)
            } else {
                weightIH.grad = weightIHGrad
            }
            if let existing = weightHH.grad {
                weightHH.grad = existing.adding(weightHHGrad, count: existing.count)
            } else {
                weightHH.grad = weightHHGrad
            }
            if let existing = bias.grad {
                bias.grad = existing.adding(biasGrad, count: existing.count)
            } else {
                bias.grad = biasGrad
            }
        }

        return Tensor(data: gradInput, shape: [batchSize, inputSize])
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(GRUCell.self, from: data)
        self.weightIH = decoded.weightIH
        self.weightHH = decoded.weightHH
        self.bias = decoded.bias
    }

    public func resetState() {
        hPrev = nil
        zGate = nil
        rGate = nil
        nGate = nil
        hiddenState = nil
        lastInput = nil
        lastPreZ = nil
        lastPreR = nil
        lastPreN = nil
    }

    public func getState() -> Tensor? {
        return hPrev
    }

    public func setState(h: Tensor?) {
        self.hPrev = h
    }

    public func getZGate() -> Tensor? { zGate }
    public func getRGate() -> Tensor? { rGate }
    public func getNGate() -> Tensor? { nGate }
    public func getHiddenState() -> Tensor? { hiddenState }
    public func clone() -> GRUCell {
        var cell = self
        cell.id = UUID()
        return cell
    }
}
