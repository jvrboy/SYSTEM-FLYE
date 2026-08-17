import Foundation
import Accelerate

// MARK: - LSTM Cell

public struct LSTMCell: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let inputSize: Int
    public let hiddenSize: Int
    public let usePeephole: Bool
    public let forgetBias: Float
    public let useLayerNorm: Bool
    public var weight: Tensor
    public var bias: Tensor
    public var weightGrad: [Float]?
    public var biasGrad: [Float]?
    public var weightIH: Tensor
    public var weightHH: Tensor
    public var weightIHGrad: [Float]?
    public var weightHHGrad: [Float]?
    public var peepholeWeight: Tensor?
    public var peepholeWeightGrad: [Float]?
    public var gammaF: Tensor?
    public var gammaI: Tensor?
    public var gammaC: Tensor?
    public var gammaO: Tensor?
    public var betaF: Tensor?
    public var betaI: Tensor?
    public var betaC: Tensor?
    public var betaO: Tensor?
    public var runningMeanF: Tensor?
    public var runningVarF: Tensor?
    public var runningMeanI: Tensor?
    public var runningVarI: Tensor?
    public var runningMeanC: Tensor?
    public var runningVarC: Tensor?
    public var runningMeanO: Tensor?
    public var runningVarO: Tensor?

    private var hPrev: Tensor?
    private var cPrev: Tensor?
    private var gates: Tensor?
    private var candidate: Tensor?
    private var cellState: Tensor?
    private var hiddenState: Tensor?
    private var forgetGate: Tensor?
    private var inputGate: Tensor?
    private var outputGate: Tensor?
    private var candidateGate: Tensor?
    private var lastInput: Tensor?
    private var lastHidden: Tensor?
    private var eps: Float = 1e-5
    private var momentum: Float = 0.1
    private var clipValue: Float = 5

    public init(inputSize: Int, hiddenSize: Int, usePeephole: Bool = true, forgetBias: Float = 1, useLayerNorm: Bool = false, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu, clipValue: Float = 5) {
        self.id = UUID()
        self.inputSize = inputSize
        self.hiddenSize = hiddenSize
        self.usePeephole = usePeephole
        self.forgetBias = forgetBias
        self.useLayerNorm = useLayerNorm
        self.trainable = trainable
        self.device = device
        self.clipValue = clipValue

        let weightIHData = initializer.initialize(size: 4 * hiddenSize * inputSize, fanIn: inputSize, fanOut: hiddenSize)
        self.weightIH = Tensor(data: weightIHData, shape: [4 * hiddenSize, inputSize], requiresGrad: trainable, device: device)

        let weightHHData = initializer.initialize(size: 4 * hiddenSize * hiddenSize, fanIn: hiddenSize, fanOut: hiddenSize)
        self.weightHH = Tensor(data: weightHHData, shape: [4 * hiddenSize, hiddenSize], requiresGrad: trainable, device: device)

        let biasIHData = [Float](repeating: 0, count: 4 * hiddenSize)
        self.bias = Tensor(data: biasIHData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)

        if usePeephole {
            let peepholeData = initializer.initialize(size: 3 * hiddenSize, fanIn: hiddenSize, fanOut: hiddenSize)
            self.peepholeWeight = Tensor(data: peepholeData, shape: [3 * hiddenSize], requiresGrad: trainable, device: device)
        } else {
            self.peepholeWeight = nil
        }

        if useLayerNorm {
            let gammaData = [Float](repeating: 1, count: 4 * hiddenSize)
            self.gammaF = Tensor(data: gammaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)
            self.gammaI = Tensor(data: gammaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)
            self.gammaC = Tensor(data: gammaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)
            self.gammaO = Tensor(data: gammaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)

            let betaData = [Float](repeating: 0, count: 4 * hiddenSize)
            self.betaF = Tensor(data: betaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)
            self.betaI = Tensor(data: betaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)
            self.betaC = Tensor(data: betaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)
            self.betaO = Tensor(data: betaData, shape: [4 * hiddenSize], requiresGrad: trainable, device: device)

            let runningMeanData = [Float](repeating: 0, count: 4 * hiddenSize)
            let runningVarData = [Float](repeating: 1, count: 4 * hiddenSize)
            self.runningMeanF = Tensor(data: runningMeanData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningVarF = Tensor(data: runningVarData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningMeanI = Tensor(data: runningMeanData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningVarI = Tensor(data: runningVarData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningMeanC = Tensor(data: runningMeanData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningVarC = Tensor(data: runningVarData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningMeanO = Tensor(data: runningMeanData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
            self.runningVarO = Tensor(data: runningVarData, shape: [4 * hiddenSize], requiresGrad: false, device: device)
        }

        var allParams: [Tensor] = [weightIH, weightHH, bias]
        if let peephole = peepholeWeight { allParams.append(peephole) }
        if let gF = gammaF { allParams.append(gF) }
        if let gI = gammaI { allParams.append(gI) }
        if let gC = gammaC { allParams.append(gC) }
        if let gO = gammaO { allParams.append(gO) }
        if let bF = betaF { allParams.append(bF) }
        if let bI = betaI { allParams.append(bI) }
        if let bC = betaC { allParams.append(bC) }
        if let bO = betaO { allParams.append(bO) }
        self.parameters = allParams
        self.weight = weightIH
        self.weightGrad = nil
        self.biasGrad = nil
        self.weightIHGrad = nil
        self.weightHHGrad = nil
        self.peepholeWeightGrad = nil
        self.hPrev = nil
        self.cPrev = nil
        self.gates = nil
        self.candidate = nil
        self.cellState = nil
        self.hiddenState = nil
        self.forgetGate = nil
        self.inputGate = nil
        self.outputGate = nil
        self.candidateGate = nil
        self.lastInput = nil
        self.lastHidden = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inputSize = try container.decode(Int.self, forKey: .inputSize)
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        usePeephole = try container.decode(Bool.self, forKey: .usePeephole)
        forgetBias = try container.decode(Float.self, forKey: .forgetBias)
        useLayerNorm = try container.decode(Bool.self, forKey: .useLayerNorm)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weightIH = try container.decode(Tensor.self, forKey: .weightIH)
        weightHH = try container.decode(Tensor.self, forKey: .weightHH)
        bias = try container.decode(Tensor.self, forKey: .bias)
        peepholeWeight = try container.decodeIfPresent(Tensor.self, forKey: .peepholeWeight)
        gammaF = try container.decodeIfPresent(Tensor.self, forKey: .gammaF)
        gammaI = try container.decodeIfPresent(Tensor.self, forKey: .gammaI)
        gammaC = try container.decodeIfPresent(Tensor.self, forKey: .gammaC)
        gammaO = try container.decodeIfPresent(Tensor.self, forKey: .gammaO)
        betaF = try container.decodeIfPresent(Tensor.self, forKey: .betaF)
        betaI = try container.decodeIfPresent(Tensor.self, forKey: .betaI)
        betaC = try container.decodeIfPresent(Tensor.self, forKey: .betaC)
        betaO = try container.decodeIfPresent(Tensor.self, forKey: .betaO)
        runningMeanF = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanF)
        runningVarF = try container.decodeIfPresent(Tensor.self, forKey: .runningVarF)
        runningMeanI = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanI)
        runningVarI = try container.decodeIfPresent(Tensor.self, forKey: .runningVarI)
        runningMeanC = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanC)
        runningVarC = try container.decodeIfPresent(Tensor.self, forKey: .runningVarC)
        runningMeanO = try container.decodeIfPresent(Tensor.self, forKey: .runningMeanO)
        runningVarO = try container.decodeIfPresent(Tensor.self, forKey: .runningVarO)
        clipValue = try container.decodeIfPresent(Float.self, forKey: .clipValue) ?? 5
        weight = weightIH
        var allParams: [Tensor] = [weightIH, weightHH, bias]
        if let peephole = peepholeWeight { allParams.append(peephole) }
        if let gF = gammaF { allParams.append(gF) }
        if let gI = gammaI { allParams.append(gI) }
        if let gC = gammaC { allParams.append(gC) }
        if let gO = gammaO { allParams.append(gO) }
        if let bF = betaF { allParams.append(bF) }
        if let bI = betaI { allParams.append(bI) }
        if let bC = betaC { allParams.append(bC) }
        if let bO = betaO { allParams.append(bO) }
        parameters = allParams
        weightGrad = nil
        biasGrad = nil
        weightIHGrad = nil
        weightHHGrad = nil
        peepholeWeightGrad = nil
        hPrev = nil
        cPrev = nil
        gates = nil
        candidate = nil
        cellState = nil
        hiddenState = nil
        forgetGate = nil
        inputGate = nil
        outputGate = nil
        candidateGate = nil
        lastInput = nil
        lastHidden = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(inputSize, forKey: .inputSize)
        try container.encode(hiddenSize, forKey: .hiddenSize)
        try container.encode(usePeephole, forKey: .usePeephole)
        try container.encode(forgetBias, forKey: .forgetBias)
        try container.encode(useLayerNorm, forKey: .useLayerNorm)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(weightIH, forKey: .weightIH)
        try container.encode(weightHH, forKey: .weightHH)
        try container.encode(bias, forKey: .bias)
        try container.encodeIfPresent(peepholeWeight, forKey: .peepholeWeight)
        try container.encodeIfPresent(gammaF, forKey: .gammaF)
        try container.encodeIfPresent(gammaI, forKey: .gammaI)
        try container.encodeIfPresent(gammaC, forKey: .gammaC)
        try container.encodeIfPresent(gammaO, forKey: .gammaO)
        try container.encodeIfPresent(betaF, forKey: .betaF)
        try container.encodeIfPresent(betaI, forKey: .betaI)
        try container.encodeIfPresent(betaC, forKey: .betaC)
        try container.encodeIfPresent(betaO, forKey: .betaO)
        try container.encodeIfPresent(runningMeanF, forKey: .runningMeanF)
        try container.encodeIfPresent(runningVarF, forKey: .runningVarF)
        try container.encodeIfPresent(runningMeanI, forKey: .runningMeanI)
        try container.encodeIfPresent(runningVarI, forKey: .runningVarI)
        try container.encodeIfPresent(runningMeanC, forKey: .runningMeanC)
        try container.encodeIfPresent(runningVarC, forKey: .runningVarC)
        try container.encodeIfPresent(runningMeanO, forKey: .runningMeanO)
        try container.encodeIfPresent(runningVarO, forKey: .runningVarO)
        try container.encode(clipValue, forKey: .clipValue)
    }

    enum CodingKeys: String, CodingKey {
        case id, inputSize, hiddenSize, usePeephole, forgetBias, useLayerNorm, trainable, device, weightIH, weightHH, bias, peepholeWeight, gammaF, gammaI, gammaC, gammaO, betaF, betaI, betaC, betaO, runningMeanF, runningVarF, runningMeanI, runningVarI, runningMeanC, runningVarC, runningMeanO, runningVarO, clipValue
    }

    public func forward(_ input: Tensor) -> Tensor {
        let batchSize = input.shape.count > 1 ? input.shape[0] : 1
        let inputData = input.shape.count > 1 ? input : input.reshape([1, input.shape.first ?? 1])
        lastInput = inputData

        let h = hPrev?.data ?? [Float](repeating: 0, count: batchSize * hiddenSize)
        let c = cPrev?.data ?? [Float](repeating: 0, count: batchSize * hiddenSize)

        var gates = [Float](repeating: 0, count: batchSize * 4 * hiddenSize)
        var combinedIH = [Float](repeating: 0, count: batchSize * 4 * hiddenSize)
        var combinedHH = [Float](repeating: 0, count: batchSize * 4 * hiddenSize)

        vDSP_mmul(inputData.data, 1, weightIH.data, 1, &combinedIH, 1, vDSP_Length(batchSize), vDSP_Length(inputSize), vDSP_Length(4 * hiddenSize))
        vDSP_mmul(h, 1, weightHH.data, 1, &combinedHH, 1, vDSP_Length(batchSize), vDSP_Length(hiddenSize), vDSP_Length(4 * hiddenSize))

        for i in 0..<batchSize * 4 * hiddenSize {
            gates[i] = combinedIH[i] + combinedHH[i] + bias.data[i]
        }

        if let peephole = peepholeWeight {
            for i in 0..<batchSize * hiddenSize {
                gates[i] += peephole.data[i] * c[i]
            }
        }

        for i in 0..<batchSize * hiddenSize {
            gates[i] += forgetBias
        }

        if useLayerNorm {
            for gate in 0..<4 {
                let start = gate * hiddenSize
                for b in 0..<batchSize {
                    let offset = b * 4 * hiddenSize + start
                    var mean: Float = 0
                    vDSP_meanv(Array(gates[offset..<offset + hiddenSize]), 1, &mean, vDSP_Length(hiddenSize))
                    var centered = [Float](repeating: 0, count: hiddenSize)
                    vDSP_vsub(Array(repeating: mean, count: hiddenSize), 1, Array(gates[offset..<offset + hiddenSize]), 1, &centered, 1, vDSP_Length(hiddenSize))
                    var varVal: Float = 0
                    vDSP_svesq(centered, 1, &varVal, vDSP_Length(hiddenSize))
                    let std = sqrt(varVal / Float(hiddenSize) + eps)
                    var normalized = centered.map { $0 / std }
                    let gamma = [Float](repeating: 1, count: hiddenSize)
                    let beta = [Float](repeating: 0, count: hiddenSize)
                    vDSP_vmul(gamma, 1, normalized, 1, &normalized, 1, vDSP_Length(normalized.count))
                    vDSP_vadd(beta, 1, normalized, 1, &normalized, 1, vDSP_Length(normalized.count))
                    for k in 0..<hiddenSize {
                        gates[offset + k] = normalized[k]
                    }
                }
            }
        }

        var f = [Float](repeating: 0, count: batchSize * hiddenSize)
        var i = [Float](repeating: 0, count: batchSize * hiddenSize)
        var cHat = [Float](repeating: 0, count: batchSize * hiddenSize)
        var o = [Float](repeating: 0, count: batchSize * hiddenSize)
        var newC = [Float](repeating: 0, count: batchSize * hiddenSize)
        var newH = [Float](repeating: 0, count: batchSize * hiddenSize)

        for b in 0..<batchSize {
            for h in 0..<hiddenSize {
                let idx = b * 4 * hiddenSize + h
                f[b * hiddenSize + h] = 1 / (1 + exp(-gates[idx]))
                i[b * hiddenSize + h] = 1 / (1 + exp(-gates[hiddenSize + idx]))
                cHat[b * hiddenSize + h] = tanh(gates[2 * hiddenSize + idx])
                o[b * hiddenSize + h] = 1 / (1 + exp(-gates[3 * hiddenSize + idx]))
                newC[b * hiddenSize + h] = f[b * hiddenSize + h] * c[b * hiddenSize + h] + i[b * hiddenSize + h] * cHat[b * hiddenSize + h]
                newH[b * hiddenSize + h] = o[b * hiddenSize + h] * tanh(newC[b * hiddenSize + h])
            }
        }

        for i in 0..<newH.count {
            newH[i] = max(-clipValue, min(clipValue, newH[i]))
        }

        self.hPrev = Tensor(data: newH, shape: [batchSize, hiddenSize], requiresGrad: trainable, device: device)
        self.cPrev = Tensor(data: newC, shape: [batchSize, hiddenSize], requiresGrad: trainable, device: device)
        self.gates = Tensor(data: gates, shape: [batchSize, 4, hiddenSize])
        self.forgetGate = Tensor(data: f, shape: [batchSize, hiddenSize])
        self.inputGate = Tensor(data: i, shape: [batchSize, hiddenSize])
        self.candidateGate = Tensor(data: cHat, shape: [batchSize, hiddenSize])
        self.outputGate = Tensor(data: o, shape: [batchSize, hiddenSize])
        self.cellState = Tensor(data: newC, shape: [batchSize, hiddenSize])
        self.hiddenState = Tensor(data: newH, shape: [batchSize, hiddenSize])
        self.lastHidden = Tensor(data: h, shape: [batchSize, hiddenSize])

        return Tensor(data: newH, shape: [batchSize, hiddenSize], requiresGrad: trainable)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let input = lastInput else { return gradient }
        let batchSize = input.shape.count > 1 ? input.shape[0] : 1
        var gradInput = [Float](repeating: 0, count: batchSize * inputSize)
        var gradH = gradient.data
        var gradC = [Float](repeating: 0, count: batchSize * hiddenSize)

        if let c = cPrev?.data {
            for i in 0..<batchSize * hiddenSize {
                gradC[i] += gradH[i] * (1 - pow(tanh(c[i]), 2))
            }
        }

        if trainable {
            var weightIHGrad = [Float](repeating: 0, count: 4 * hiddenSize * inputSize)
            var weightHHGrad = [Float](repeating: 0, count: 4 * hiddenSize * hiddenSize)
            var biasGrad = [Float](repeating: 0, count: 4 * hiddenSize)

            if let peephole = peepholeWeight {
                var peepholeGrad = [Float](repeating: 0, count: 3 * hiddenSize)
                for i in 0..<batchSize * hiddenSize {
                    peepholeGrad[i] += gradC[i] * (cPrev?.data[i] ?? 0)
                }
                if let existing = peepholeWeight?.grad {
                    peepholeWeight?.grad = existing.adding(peepholeGrad, count: existing.count)
                } else {
                    peepholeWeight?.grad = peepholeGrad
                }
            }

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
        let decoded = try JSONDecoder().decode(LSTMCell.self, from: data)
        self.weightIH = decoded.weightIH
        self.weightHH = decoded.weightHH
        self.bias = decoded.bias
        self.peepholeWeight = decoded.peepholeWeight
    }

    public func resetState() {
        hPrev = nil
        cPrev = nil
        gates = nil
        candidate = nil
        cellState = nil
        hiddenState = nil
        forgetGate = nil
        inputGate = nil
        outputGate = nil
        candidateGate = nil
        lastInput = nil
        lastHidden = nil
    }

    public func getState() -> (h: Tensor?, c: Tensor?) {
        return (hPrev, cPrev)
    }

    public func setState(h: Tensor?, c: Tensor?) {
        self.hPrev = h
        self.cPrev = c
    }

    public func getForgetGate() -> Tensor? { forgetGate }
    public func getInputGate() -> Tensor? { inputGate }
    public func getOutputGate() -> Tensor? { outputGate }
    public func getCandidateGate() -> Tensor? { candidateGate }
    public func getCellState() -> Tensor? { cellState }
    public func getHiddenState() -> Tensor? { hiddenState }
    public func clone() -> LSTMCell {
        var cell = self
        cell.id = UUID()
        return cell
    }
}
