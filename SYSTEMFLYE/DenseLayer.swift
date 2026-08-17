import Foundation
import Accelerate

// MARK: - Dense Layer

public struct DenseLayer: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let inputSize: Int
    public let outputSize: Int
    public var weight: Tensor
    public var bias: Tensor
    public var weightGrad: [Float]?
    public var biasGrad: [Float]?
    public let activation: ActivationType
    public let initializer: Initializer
    public let useBias: Bool
    public var lastInput: Tensor?
    public var lastPreActivation: Tensor?
    public var lastOutput: Tensor?
    public var weightNorm: Float?
    public var biasNorm: Float?
    public var fanIn: Int
    public var fanOut: Int
    public var l1Penalty: Float
    public var l2Penalty: Float
    public var spectralNorm: Bool
    public var unitNorm: Bool
    public var outputScale: Float
    public var outputShift: Float

    public enum ActivationType: String, Codable, Sendable, CaseIterable {
        case relu = "RELU"
        case sigmoid = "SIGMOID"
        case tanh = "TANH"
        case softmax = "SOFTMAX"
        case linear = "LINEAR"
        case leakyRelu = "LEAKY_RELU"
        case elu = "ELU"
        case swish = "SWISH"
        case gelu = "GELU"
        case none = "NONE"
        case hardSigmoid = "HARD_SIGMOID"
        case hardTanh = "HARD_TANH"
        case softsign = "SOFTSIGN"
        case softplus = "SOFTPLUS"
    }

    public init(inputSize: Int, outputSize: Int, activation: ActivationType = .relu, useBias: Bool = true, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu, l1Penalty: Float = 0, l2Penalty: Float = 0, spectralNorm: Bool = false, unitNorm: Bool = false, outputScale: Float = 1, outputShift: Float = 0) {
        self.id = UUID()
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.activation = activation
        self.useBias = useBias
        self.initializer = initializer
        self.trainable = trainable
        self.device = device
        self.l1Penalty = l1Penalty
        self.l2Penalty = l2Penalty
        self.spectralNorm = spectralNorm
        self.unitNorm = unitNorm
        self.outputScale = outputScale
        self.outputShift = outputShift
        self.fanIn = inputSize
        self.fanOut = outputSize

        let weightData = initializer.initialize(size: inputSize * outputSize, fanIn: inputSize, fanOut: outputSize)
        self.weight = Tensor(data: weightData, shape: [inputSize, outputSize], requiresGrad: trainable, device: device)

        let biasData = useBias ? [Float](repeating: 0, count: outputSize) : []
        self.bias = useBias ? Tensor(data: biasData, shape: [outputSize], requiresGrad: trainable, device: device) : Tensor(data: [], shape: [0], requiresGrad: false)

        if spectralNorm {
            var norm: Float = 0
            vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
            let scale = 1 / sqrt(max(norm, 1e-7))
            vDSP_vsmul(weight.data, 1, [scale], &weight.data, 1, vDSP_Length(weight.data.count))
        }

        if unitNorm {
            var norm: Float = 0
            vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
            let scale = 1 / sqrt(max(norm, 1e-7))
            vDSP_vsmul(weight.data, 1, [scale], &weight.data, 1, vDSP_Length(weight.data.count))
        }

        self.parameters = [weight, bias]
        self.weightGrad = nil
        self.biasGrad = nil
        self.lastInput = nil
        self.lastPreActivation = nil
        self.lastOutput = nil
        self.weightNorm = nil
        self.biasNorm = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inputSize = try container.decode(Int.self, forKey: .inputSize)
        outputSize = try container.decode(Int.self, forKey: .outputSize)
        activation = try container.decode(ActivationType.self, forKey: .activation)
        useBias = try container.decode(Bool.self, forKey: .useBias)
        initializer = try container.decode(Initializer.self, forKey: .initializer)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weight = try container.decode(Tensor.self, forKey: .weight)
        bias = try container.decode(Tensor.self, forKey: .bias)
        l1Penalty = try container.decodeIfPresent(Float.self, forKey: .l1Penalty) ?? 0
        l2Penalty = try container.decodeIfPresent(Float.self, forKey: .l2Penalty) ?? 0
        spectralNorm = try container.decodeIfPresent(Bool.self, forKey: .spectralNorm) ?? false
        unitNorm = try container.decodeIfPresent(Bool.self, forKey: .unitNorm) ?? false
        outputScale = try container.decodeIfPresent(Float.self, forKey: .outputScale) ?? 1
        outputShift = try container.decodeIfPresent(Float.self, forKey: .outputShift) ?? 0
        fanIn = try container.decodeIfPresent(Int.self, forKey: .fanIn) ?? inputSize
        fanOut = try container.decodeIfPresent(Int.self, forKey: .fanOut) ?? outputSize
        parameters = [weight, bias]
        weightGrad = nil
        biasGrad = nil
        lastInput = nil
        lastPreActivation = nil
        lastOutput = nil
        weightNorm = nil
        biasNorm = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(inputSize, forKey: .inputSize)
        try container.encode(outputSize, forKey: .outputSize)
        try container.encode(activation, forKey: .activation)
        try container.encode(useBias, forKey: .useBias)
        try container.encode(initializer, forKey: .initializer)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(weight, forKey: .weight)
        try container.encode(bias, forKey: .bias)
        try container.encode(l1Penalty, forKey: .l1Penalty)
        try container.encode(l2Penalty, forKey: .l2Penalty)
        try container.encode(spectralNorm, forKey: .spectralNorm)
        try container.encode(unitNorm, forKey: .unitNorm)
        try container.encode(outputScale, forKey: .outputScale)
        try container.encode(outputShift, forKey: .outputShift)
        try container.encode(fanIn, forKey: .fanIn)
        try container.encode(fanOut, forKey: .fanOut)
    }

    enum CodingKeys: String, CodingKey {
        case id, inputSize, outputSize, activation, useBias, initializer, trainable, device, weight, bias, l1Penalty, l2Penalty, spectralNorm, unitNorm, outputScale, outputShift, fanIn, fanOut
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count == 2, input.shape[1] == inputSize else {
            return Tensor(data: [], shape: [0, 0])
        }
        lastInput = input

        var output = input.matmul(weight)
        if useBias, bias.data.count == outputSize {
            var biasBroadcast = bias.data
            for _ in 0..<(output.shape[0] - 1) {
                biasBroadcast.append(contentsOf: bias.data)
            }
            vDSP_vadd(biasBroadcast, 1, output.data, 1, &output.data, 1, vDSP_Length(output.data.count))
        }

        lastPreActivation = output

        switch activation {
        case .relu:
            output = output.relu()
        case .sigmoid:
            output = output.sigmoid()
        case .tanh:
            output = output.tanh()
        case .softmax:
            output = output.softmax()
        case .linear:
            break
        case .leakyRelu:
            for i in 0..<output.data.count {
                output.data[i] = output.data[i] > 0 ? output.data[i] : 0.01 * output.data[i]
            }
        case .elu:
            for i in 0..<output.data.count {
                let x = output.data[i]
                output.data[i] = x > 0 ? x : exp(x) - 1
            }
        case .swish:
            for i in 0..<output.data.count {
                let x = output.data[i]
                output.data[i] = x / (1 + exp(-x))
            }
        case .gelu:
            for i in 0..<output.data.count {
                let x = output.data[i]
                let cdf = 0.5 * (1 + tanh(sqrt(2 / .pi) * (x + 0.044715 * pow(x, 3))))
                output.data[i] = x * cdf
            }
        case .hardSigmoid:
            for i in 0..<output.data.count {
                let x = output.data[i]
                output.data[i] = max(0, min(1, 0.2 * x + 0.5))
            }
        case .hardTanh:
            for i in 0..<output.data.count {
                output.data[i] = max(-1, min(1, output.data[i]))
            }
        case .softsign:
            for i in 0..<output.data.count {
                output.data[i] = output.data[i] / (1 + abs(output.data[i]))
            }
        case .softplus:
            for i in 0..<output.data.count {
                output.data[i] = log(1 + exp(output.data[i]))
            }
        case .none:
            break
        }

        var scale = outputScale
        var shift = outputShift
        if l2Penalty > 0 {
            var norm: Float = 0
            vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
            let reg = l2Penalty * sqrt(norm)
            shift += reg
        }
        if l1Penalty > 0 {
            var l1Norm: Float = 0
            for val in weight.data { l1Norm += abs(val) }
            shift += l1Penalty * l1Norm
        }

        if scale != 1 || shift != 0 {
            vDSP_vsmsa(output.data, 1, [scale], [shift], &output.data, 1, vDSP_Length(output.data.count))
        }

        lastOutput = output
        if trainable {
            output.op = DenseBackwardOp(input: input, layer: self)
        }
        return output
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let input = lastInput else { return gradient }

        var grad = gradient.data

        switch activation {
        case .relu:
            if let preAct = lastPreActivation {
                var mask = [Float](repeating: 0, count: preAct.data.count)
                for i in 0..<preAct.data.count {
                    mask[i] = preAct.data[i] > 0 ? 1 : 0
                }
                vDSP_vmul(mask, 1, grad, 1, &grad, 1, vDSP_Length(grad.count))
            }
        case .sigmoid:
            if let preAct = lastPreActivation {
                var sig = [Float](repeating: 0, count: preAct.data.count)
                for i in 0..<preAct.data.count {
                    sig[i] = 1 / (1 + exp(-preAct.data[i]))
                }
                var deriv = [Float](repeating: 0, count: sig.count)
                for i in 0..<sig.count {
                    deriv[i] = sig[i] * (1 - sig[i])
                }
                vDSP_vmul(deriv, 1, grad, 1, &grad, 1, vDSP_Length(grad.count))
            }
        case .tanh:
            if let preAct = lastPreActivation {
                var deriv = [Float](repeating: 0, count: preAct.data.count)
                for i in 0..<preAct.data.count {
                    let t = tanh(preAct.data[i])
                    deriv[i] = 1 - t * t
                }
                vDSP_vmul(deriv, 1, grad, 1, &grad, 1, vDSP_Length(grad.count))
            }
        case .hardSigmoid:
            if let preAct = lastPreActivation {
                var mask = [Float](repeating: 0, count: preAct.data.count)
                for i in 0..<preAct.data.count {
                    mask[i] = (preAct.data[i] > -2.5 && preAct.data[i] < 2.5) ? 0.2 : 0
                }
                vDSP_vmul(mask, 1, grad, 1, &grad, 1, vDSP_Length(grad.count))
            }
        case .hardTanh:
            if let preAct = lastPreActivation {
                var mask = [Float](repeating: 0, count: preAct.data.count)
                for i in 0..<preAct.data.count {
                    mask[i] = (preAct.data[i] >= -1 && preAct.data[i] <= 1) ? 1 : 0
                }
                vDSP_vmul(mask, 1, grad, 1, &grad, 1, vDSP_Length(grad.count))
            }
        default:
            break
        }

        let batchSize = input.shape[0]
        var weightGrad = [Float](repeating: 0, count: inputSize * outputSize)
        vDSP_mmul(grad, 1, input.data, 1, &weightGrad, 1, vDSP_Length(outputSize), vDSP_Length(batchSize), vDSP_Length(inputSize))

        if trainable {
            weightGrad = weightGrad.map { $0 / Float(batchSize) }
            if l2Penalty > 0 {
                for i in 0..<weightGrad.count {
                    weightGrad[i] += l2Penalty * weight.data[i]
                }
            }
            if l1Penalty > 0 {
                for i in 0..<weightGrad.count {
                    let sign = weight.data[i] > 0 ? 1 : (weight.data[i] < 0 ? -1 : 0)
                    weightGrad[i] += l1Penalty * sign
                }
            }
            if let existing = weight.grad {
                weight.grad = existing.adding(weightGrad, count: existing.count)
            } else {
                weight.grad = weightGrad
            }
        }

        if useBias {
            var biasGrad = [Float](repeating: 0, count: outputSize)
            for i in 0..<outputSize {
                var sum: Float = 0
                for b in 0..<batchSize {
                    sum += grad[b * outputSize + i]
                }
                biasGrad[i] = sum / Float(batchSize)
            }
            if trainable {
                if let existing = bias.grad {
                    bias.grad = existing.adding(biasGrad, count: existing.count)
                } else {
                    bias.grad = biasGrad
                }
            }
        }

        let inputGradM = inputSize
        let outputGradN = batchSize
        let weightK = outputSize
        var inputGrad = [Float](repeating: 0, count: inputGradM * outputGradN)
        vDSP_mmul(weight.data, 1, grad, 1, &inputGrad, 1, vDSP_Length(inputGradM), vDSP_Length(weightK), vDSP_Length(weightK))

        if outputScale != 1 {
            vDSP_vsmul(inputGrad, 1, [outputScale], &inputGrad, 1, vDSP_Length(inputGrad.count))
        }

        return Tensor(data: inputGrad, shape: [batchSize, inputSize])
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(DenseLayer.self, from: data)
        self.weight = decoded.weight
        self.bias = decoded.bias
    }

    public func reset() {
        weightGrad = nil
        biasGrad = nil
        lastInput = nil
        lastPreActivation = nil
        lastOutput = nil
    }

    public func getWeightNorm() -> Float {
        var norm: Float = 0
        vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
        return sqrt(norm)
    }

    public func getBiasNorm() -> Float {
        var norm: Float = 0
        vDSP_svesq(bias.data, 1, &norm, vDSP_Length(bias.data.count))
        return sqrt(norm)
    }

    public func getParameterCount() -> Int {
        return weight.data.count + bias.data.count
    }

    public func getFlops() -> Int {
        return 2 * inputSize * outputSize + outputSize
    }
}

public struct DenseBackwardOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor
    private let layer: DenseLayer

    public init(input: Tensor, layer: DenseLayer) {
        self.input = input
        self.layer = layer
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        let gradTensor = Tensor(data: gradient, shape: layer.lastPreActivation?.shape ?? [1, layer.outputSize])
        let result = layer.backward(gradTensor)
        gradient = result.data
    }
}
