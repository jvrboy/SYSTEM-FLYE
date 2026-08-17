import Foundation
import Accelerate

// MARK: - Conv1D Layer

public struct Conv1DLayer: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let inChannels: Int
    public let outChannels: Int
    public let kernelSize: Int
    public let stride: Int
    public let padding: PaddingType
    public let dilation: Int
    public let groups: Int
    public let useBias: Bool
    public var weight: Tensor
    public var bias: Tensor?
    public var weightGrad: [Float]?
    public var biasGrad: [Float]?
    public var lastInput: Tensor?
    public var lastOutput: Tensor?
    public var lastPaddedInput: Tensor?
    public var lastDilatedInput: Tensor?
    public var weightNorm: Float?
    public var fanIn: Int
    public var fanOut: Int
    public var l2Penalty: Float
    public var initializer: Initializer

    public enum PaddingType: String, Codable, Sendable, CaseIterable {
        case valid = "VALID"
        case same = "SAME"
        case full = "FULL"
        case causal = "CAUSAL"
        case custom = "CUSTOM"
    }

    public init(inChannels: Int, outChannels: Int, kernelSize: Int, stride: Int = 1, padding: PaddingType = .same, dilation: Int = 1, groups: Int = 1, useBias: Bool = true, initializer: Initializer = .init(), trainable: Bool = true, device: Device = .cpu, l2Penalty: Float = 0) {
        self.id = UUID()
        self.inChannels = inChannels
        self.outChannels = outChannels
        self.kernelSize = kernelSize
        self.stride = stride
        self.padding = padding
        self.dilation = dilation
        self.groups = groups
        self.useBias = useBias
        self.trainable = trainable
        self.device = device
        self.l2Penalty = l2Penalty
        self.initializer = initializer
        self.fanIn = inChannels * kernelSize
        self.fanOut = outChannels * kernelSize

        let weightData = initializer.initialize(size: outChannels * inChannels * kernelSize, fanIn: fanIn, fanOut: fanOut)
        self.weight = Tensor(data: weightData, shape: [outChannels, inChannels, kernelSize], requiresGrad: trainable, device: device)

        let biasData = useBias ? [Float](repeating: 0, count: outChannels) : []
        self.bias = useBias ? Tensor(data: biasData, shape: [outChannels], requiresGrad: trainable, device: device) : nil

        self.parameters = [weight] + (bias.map { [$0] } ?? [])
        self.weightGrad = nil
        self.biasGrad = nil
        self.lastInput = nil
        self.lastOutput = nil
        self.lastPaddedInput = nil
        self.lastDilatedInput = nil
        self.weightNorm = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inChannels = try container.decode(Int.self, forKey: .inChannels)
        outChannels = try container.decode(Int.self, forKey: .outChannels)
        kernelSize = try container.decode(Int.self, forKey: .kernelSize)
        stride = try container.decode(Int.self, forKey: .stride)
        padding = try container.decode(PaddingType.self, forKey: .padding)
        dilation = try container.decode(Int.self, forKey: .dilation)
        groups = try container.decode(Int.self, forKey: .groups)
        useBias = try container.decode(Bool.self, forKey: .useBias)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        weight = try container.decode(Tensor.self, forKey: .weight)
        bias = try container.decodeIfPresent(Tensor.self, forKey: .bias)
        l2Penalty = try container.decodeIfPresent(Float.self, forKey: .l2Penalty) ?? 0
        initializer = try container.decodeIfPresent(Initializer.self, forKey: .initializer) ?? .init()
        fanIn = try container.decodeIfPresent(Int.self, forKey: .fanIn) ?? inChannels * kernelSize
        fanOut = try container.decodeIfPresent(Int.self, forKey: .fanOut) ?? outChannels * kernelSize
        parameters = [weight] + (bias.map { [$0] } ?? [])
        weightGrad = nil
        biasGrad = nil
        lastInput = nil
        lastOutput = nil
        lastPaddedInput = nil
        lastDilatedInput = nil
        weightNorm = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(inChannels, forKey: .inChannels)
        try container.encode(outChannels, forKey: .outChannels)
        try container.encode(kernelSize, forKey: .kernelSize)
        try container.encode(stride, forKey: .stride)
        try container.encode(padding, forKey: .padding)
        try container.encode(dilation, forKey: .dilation)
        try container.encode(groups, forKey: .groups)
        try container.encode(useBias, forKey: .useBias)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(bias, forKey: .bias)
        try container.encode(l2Penalty, forKey: .l2Penalty)
        try container.encode(initializer, forKey: .initializer)
        try container.encode(fanIn, forKey: .fanIn)
        try container.encode(fanOut, forKey: .fanOut)
    }

    enum CodingKeys: String, CodingKey {
        case id, inChannels, outChannels, kernelSize, stride, padding, dilation, groups, useBias, trainable, device, weight, bias, l2Penalty, initializer, fanIn, fanOut
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard input.shape.count == 3 else { return Tensor(data: [], shape: [0, 0, 0]) }
        lastInput = input
        let batchSize = input.shape[0]
        let length = input.shape[2]
        let paddedInput = applyPadding(input)
        lastPaddedInput = paddedInput

        let outputLength = computeOutputLength(inputLength: length, kernelSize: kernelSize, stride: stride, padding: padding)
        var output = [Float](repeating: 0, count: batchSize * outChannels * outputLength)

        for b in 0..<batchSize {
            for oc in 0..<outChannels {
                for l in 0..<outputLength {
                    var sum: Float = useBias ? (bias?.data[oc] ?? 0) : 0
                    let start = l * stride
                    for ic in 0..<inChannels {
                        let groupOffset = (oc * inChannels / groups) * kernelSize
                        for k in 0..<kernelSize {
                            let inputIndex = b * inChannels * paddedInput.shape[2] + ic * paddedInput.shape[2] + start + k * dilation
                            let weightIndex = groupOffset + k
                            sum += paddedInput.data[inputIndex] * weight.data[weightIndex]
                        }
                    }
                    output[b * outChannels * outputLength + oc * outputLength + l] = sum
                }
            }
        }

        let outputTensor = Tensor(data: output, shape: [batchSize, outChannels, outputLength], requiresGrad: trainable)
        lastOutput = outputTensor

        if l2Penalty > 0 {
            var norm: Float = 0
            vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
            for i in 0..<output.count {
                output[i] += l2Penalty * sqrt(norm)
            }
        }

        return Tensor(data: output, shape: [batchSize, outChannels, outputLength], requiresGrad: trainable)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard let input = lastInput, let paddedInput = lastPaddedInput else { return gradient }
        guard gradient.shape.count == 3, gradient.shape[1] == outChannels else { return gradient }

        let batchSize = input.shape[0]
        let length = input.shape[2]
        let outputLength = gradient.shape[2]
        var inputGrad = [Float](repeating: 0, count: batchSize * inChannels * paddedInput.shape[2])

        for b in 0..<batchSize {
            for ic in 0..<inChannels {
                for l in 0..<paddedInput.shape[2] {
                    var sum: Float = 0
                    for oc in 0..<outChannels {
                        for k in 0..<kernelSize {
                            let outputStart = l - k * dilation + kernelSize * dilation / 2
                            if outputStart >= 0, outputStart < outputLength, outputStart % stride == 0 {
                                let outputIndex = b * outChannels * outputLength + oc * outputLength + outputStart / stride
                                let weightIndex = oc * inChannels * kernelSize + ic * kernelSize + k
                                sum += gradient.data[outputIndex] * weight.data[weightIndex]
                            }
                        }
                    }
                    inputGrad[b * inChannels * paddedInput.shape[2] + ic * paddedInput.shape[2] + l] = sum
                }
            }
        }

        if trainable {
            var weightGrad = [Float](repeating: 0, count: outChannels * inChannels * kernelSize)
            for b in 0..<batchSize {
                for oc in 0..<outChannels {
                    for ic in 0..<inChannels {
                        for k in 0..<kernelSize {
                            let paddedIndex = b * inChannels * paddedInput.shape[2] + ic * paddedInput.shape[2] + k * dilation
                            let outputIndex = b * outChannels * outputLength + oc * outputLength
                            var sum: Float = 0
                            for l in 0..<outputLength {
                                sum += gradient.data[outputIndex + l] * paddedInput.data[paddedIndex + l * stride]
                            }
                            weightGrad[oc * inChannels * kernelSize + ic * kernelSize + k] += sum
                        }
                    }
                }
            }
            weightGrad = weightGrad.map { $0 / Float(batchSize) }
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

        var unpaddedGrad = [Float](repeating: 0, count: batchSize * inChannels * length)
        let padLeft = computePaddingAmount(inputLength: length, kernelSize: kernelSize, stride: stride, padding: padding).0
        for b in 0..<batchSize {
            for ic in 0..<inChannels {
                for l in 0..<length {
                    unpaddedGrad[b * inChannels * length + ic * length + l] = inputGrad[b * inChannels * paddedInput.shape[2] + ic * paddedInput.shape[2] + l + padLeft]
                }
            }
        }

        return Tensor(data: unpaddedGrad, shape: [batchSize, inChannels, length])
    }

    private func applyPadding(_ input: Tensor) -> Tensor {
        guard padding != .valid else { return input }
        let batchSize = input.shape[0]
        let channels = input.shape[1]
        let length = input.shape[2]
        var padLeft = 0, padRight = 0

        switch padding {
        case .same:
            let totalPad = max(0, (length - 1) * stride + kernelSize - length)
            padLeft = totalPad / 2
            padRight = totalPad - padLeft
        case .full:
            padLeft = kernelSize - 1
            padRight = kernelSize - 1
        case .causal:
            padLeft = (kernelSize - 1) * dilation
            padRight = 0
        case .custom:
            padLeft = 0
            padRight = 0
        case .valid:
            padLeft = 0
            padRight = 0
        }

        if padLeft == 0 && padRight == 0 { return input }
        let paddedLength = length + padLeft + padRight
        var paddedData = [Float](repeating: 0, count: batchSize * channels * paddedLength)

        for b in 0..<batchSize {
            for c in 0..<channels {
                for l in 0..<length {
                    paddedData[b * channels * paddedLength + c * paddedLength + l + padLeft] = input.data[b * channels * length + c * length + l]
                }
            }
        }
        return Tensor(data: paddedData, shape: [batchSize, channels, paddedLength])
    }

    private func computeOutputLength(inputLength: Int, kernelSize: Int, stride: Int, padding: PaddingType) -> Int {
        switch padding {
        case .full: return (inputLength - 1) * stride + kernelSize
        case .same: return max(1, (inputLength + stride - 1) / stride)
        default: return max(0, (inputLength - kernelSize) / stride + 1)
        }
    }

    private func computePaddingAmount(inputLength: Int, kernelSize: Int, stride: Int, padding: PaddingType) -> (Int, Int) {
        switch padding {
        case .same:
            let totalPad = max(0, (inputLength - 1) * stride + kernelSize - inputLength)
            return (totalPad / 2, totalPad - totalPad / 2)
        case .full:
            return (kernelSize - 1, kernelSize - 1)
        default:
            return (0, 0)
        }
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(Conv1DLayer.self, from: data)
        self.weight = decoded.weight
        self.bias = decoded.bias
    }

    public func getReceptiveField() -> Int {
        return (kernelSize - 1) * dilation + 1
    }

    public func getOutputLength(for inputLength: Int) -> Int {
        return computeOutputLength(inputLength: inputLength, kernelSize: kernelSize, stride: stride, padding: padding)
    }

    public func reset() {
        weightGrad = nil
        biasGrad = nil
        lastInput = nil
        lastOutput = nil
        lastPaddedInput = nil
        lastDilatedInput = nil
    }

    public func getWeightNorm() -> Float {
        var norm: Float = 0
        vDSP_svesq(weight.data, 1, &norm, vDSP_Length(weight.data.count))
        return sqrt(norm)
    }

    public func getParameterCount() -> Int {
        return weight.data.count + (bias?.data.count ?? 0)
    }

    public func getFlops() -> Int {
        let outputLength = computeOutputLength(inputLength: 100, kernelSize: kernelSize, stride: stride, padding: padding)
        return 2 * inChannels * outChannels * kernelSize * outputLength + outChannels * outputLength
    }
}
