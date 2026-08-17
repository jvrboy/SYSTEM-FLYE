import Foundation
import Accelerate

// MARK: - Dropout Layer

public struct DropoutLayer: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let dropoutProbability: Float
    public let inplace: Bool
    public var training: Bool
    public var lastMask: [Float]?
    public var lastInputShape: [Int]?
    public var scale: Float

    public init(dropoutProbability: Float = 0.5, inplace: Bool = false, training: Bool = true, trainable: Bool = false, device: Device = .cpu) {
        self.id = UUID()
        self.dropoutProbability = dropoutProbability
        self.inplace = inplace
        self.training = training
        self.trainable = trainable
        self.device = device
        self.scale = 1 / (1 - dropoutProbability)
        self.parameters = []
        self.lastMask = nil
        self.lastInputShape = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dropoutProbability = try container.decode(Float.self, forKey: .dropoutProbability)
        inplace = try container.decode(Bool.self, forKey: .inplace)
        training = try container.decode(Bool.self, forKey: .training)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        scale = 1 / (1 - dropoutProbability)
        parameters = []
        lastMask = nil
        lastInputShape = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dropoutProbability, forKey: .dropoutProbability)
        try container.encode(inplace, forKey: .inplace)
        try container.encode(training, forKey: .training)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
    }

    enum CodingKeys: String, CodingKey {
        case id, dropoutProbability, inplace, training, trainable, device
    }

    public func forward(_ input: Tensor) -> Tensor {
        lastInputShape = input.shape
        guard training && dropoutProbability > 0 else { return input }
        var mask = [Float](repeating: 0, count: input.data.count)
        for i in 0..<mask.count {
            mask[i] = Float.random(in: 0...1) > dropoutProbability ? scale : 0
        }
        lastMask = mask
        var output = [Float](repeating: 0, count: input.data.count)
        vDSP_vmul(mask, 1, input.data, 1, &output, 1, vDSP_Length(output.count))
        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard training && dropoutProbability > 0, let mask = lastMask else { return gradient }
        var gradInput = [Float](repeating: 0, count: gradient.data.count)
        vDSP_vmul(mask, 1, gradient.data, 1, &gradInput, 1, vDSP_Length(gradInput.count))
        return Tensor(data: gradInput, shape: gradient.shape)
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(DropoutLayer.self, from: data)
        self.dropoutProbability = decoded.dropoutProbability
        self.inplace = decoded.inplace
        self.training = decoded.training
    }

    public func eval() {
        training = false
    }

    public func train() {
        training = true
    }
}

// MARK: - Spatial Dropout

public struct SpatialDropout: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let dropoutProbability: Float
    public let numChannels: Int
    public var training: Bool
    public var lastMask: [Float]?

    public init(numChannels: Int, dropoutProbability: Float = 0.2, training: Bool = true, trainable: Bool = false, device: Device = .cpu) {
        self.id = UUID()
        self.numChannels = numChannels
        self.dropoutProbability = dropoutProbability
        self.training = training
        self.trainable = trainable
        self.device = device
        self.parameters = []
        self.lastMask = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        numChannels = try container.decode(Int.self, forKey: .numChannels)
        dropoutProbability = try container.decode(Float.self, forKey: .dropoutProbability)
        training = try container.decode(Bool.self, forKey: .training)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        parameters = []
        lastMask = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(numChannels, forKey: .numChannels)
        try container.encode(dropoutProbability, forKey: .dropoutProbability)
        try container.encode(training, forKey: .training)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
    }

    enum CodingKeys: String, CodingKey {
        case id, numChannels, dropoutProbability, training, trainable, device
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard training && dropoutProbability > 0 else { return input }
        guard input.shape.count == 3 else { return input }
        let batchSize = input.shape[0]
        var mask = [Float](repeating: 0, count: numChannels)
        for i in 0..<numChannels {
            mask[i] = Float.random(in: 0...1) > dropoutProbability ? 1 : 0
        }
        lastMask = mask
        var output = input.data
        for b in 0..<batchSize {
            for c in 0..<numChannels {
                let scale = mask[c]
                for l in 0..<input.shape[2] {
                    output[b * numChannels * input.shape[2] + c * input.shape[2] + l] *= scale
                }
            }
        }
        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard training && dropoutProbability > 0, let mask = lastMask else { return gradient }
        var gradInput = gradient.data
        for b in 0..<gradient.shape[0] {
            for c in 0..<numChannels {
                let scale = mask[c]
                for l in 0..<gradient.shape[2] {
                    gradInput[b * numChannels * gradient.shape[2] + c * gradient.shape[2] + l] *= scale
                }
            }
        }
        return Tensor(data: gradInput, shape: gradient.shape)
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(SpatialDropout.self, from: data)
        self.numChannels = decoded.numChannels
        self.dropoutProbability = decoded.dropoutProbability
        self.training = decoded.training
    }
}

// MARK: - Alpha Dropout

public struct AlphaDropout: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let dropoutProbability: Float
    public let alpha: Float
    public let alphaPrime: Float
    public let training: Bool
    public var lastMask: [Float]?
    public var scale: Float
    public var shift: Float

    public init(dropoutProbability: Float = 0.1, alpha: Float = -1.7580993408473716, training: Bool = true, trainable: Bool = false, device: Device = .cpu) {
        self.id = UUID()
        self.dropoutProbability = dropoutProbability
        self.alpha = alpha
        self.alphaPrime = alpha * sqrt(alpha * alpha + 1)
        self.training = training
        self.trainable = trainable
        self.device = device
        self.scale = 1 / (1 - dropoutProbability)
        self.shift = -alpha * sqrt(alpha * alpha + 1)
        self.parameters = []
        self.lastMask = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dropoutProbability = try container.decode(Float.self, forKey: .dropoutProbability)
        alpha = try container.decode(Float.self, forKey: .alpha)
        training = try container.decode(Bool.self, forKey: .training)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        alphaPrime = alpha * sqrt(alpha * alpha + 1)
        scale = 1 / (1 - dropoutProbability)
        shift = -alpha * sqrt(alpha * alpha + 1)
        parameters = []
        lastMask = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dropoutProbability, forKey: .dropoutProbability)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(training, forKey: .training)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
    }

    enum CodingKeys: String, CodingKey {
        case id, dropoutProbability, alpha, training, trainable, device
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard training && dropoutProbability > 0 else { return input }
        var mask = [Float](repeating: 0, count: input.data.count)
        for i in 0..<mask.count {
            mask[i] = Float.random(in: 0...1) > dropoutProbability ? scale : 0
        }
        lastMask = mask
        var output = input.data
        for i in 0..<output.count {
            output[i] = mask[i] * (output[i] - shift) + shift
        }
        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard training && dropoutProbability > 0, let mask = lastMask else { return gradient }
        var gradInput = [Float](repeating: 0, count: gradient.data.count)
        for i in 0..<gradInput.count {
            gradInput[i] = mask[i] * gradient.data[i]
        }
        return Tensor(data: gradInput, shape: gradient.shape)
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(AlphaDropout.self, from: data)
        self.dropoutProbability = decoded.dropoutProbability
        self.alpha = decoded.alpha
        self.training = decoded.training
    }
}

// MARK: - Variational Dropout

public struct VariationalDropout: Layer, Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parameters: [Tensor]
    public var trainable: Bool
    public var device: Device

    public let dropoutProbability: Float
    public let inputSize: Int
    public var training: Bool
    public var lastMask: [Float]?
    public var scale: Float

    public init(inputSize: Int, dropoutProbability: Float = 0.1, training: Bool = true, trainable: Bool = false, device: Device = .cpu) {
        self.id = UUID()
        self.inputSize = inputSize
        self.dropoutProbability = dropoutProbability
        self.training = training
        self.trainable = trainable
        self.device = device
        self.scale = 1 / (1 - dropoutProbability)
        self.parameters = []
        self.lastMask = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inputSize = try container.decode(Int.self, forKey: .inputSize)
        dropoutProbability = try container.decode(Float.self, forKey: .dropoutProbability)
        training = try container.decode(Bool.self, forKey: .training)
        trainable = try container.decode(Bool.self, forKey: .trainable)
        device = try container.decode(Device.self, forKey: .device)
        scale = 1 / (1 - dropoutProbability)
        parameters = []
        lastMask = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(inputSize, forKey: .inputSize)
        try container.encode(dropoutProbability, forKey: .dropoutProbability)
        try container.encode(training, forKey: .training)
        try container.encode(trainable, forKey: .trainable)
        try container.encode(device, forKey: .device)
    }

    enum CodingKeys: String, CodingKey {
        case id, inputSize, dropoutProbability, training, trainable, device
    }

    public func forward(_ input: Tensor) -> Tensor {
        guard training && dropoutProbability > 0 else { return input }
        var mask = [Float](repeating: 0, count: inputSize)
        for i in 0..<mask.count {
            mask[i] = Float.random(in: 0...1) > dropoutProbability ? scale : 0
        }
        lastMask = mask
        var output = input.data
        for i in 0..<inputSize {
            for j in stride(from: i, to: output.count, by: inputSize) {
                output[j] *= mask[i]
            }
        }
        return Tensor(data: output, shape: input.shape, requiresGrad: input.requiresGrad)
    }

    public func backward(_ gradient: Tensor) -> Tensor {
        guard training && dropoutProbability > 0, let mask = lastMask else { return gradient }
        var gradInput = gradient.data
        for i in 0..<inputSize {
            for j in stride(from: i, to: gradInput.count, by: inputSize) {
                gradInput[j] *= mask[i]
            }
        }
        return Tensor(data: gradInput, shape: gradient.shape)
    }

    public func toJSON() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func fromJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(VariationalDropout.self, from: data)
        self.inputSize = decoded.inputSize
        self.dropoutProbability = decoded.dropoutProbability
        self.training = decoded.training
    }
}

// MARK: - Dropout Factory

public struct DropoutFactory {
    public static func create(_ type: String, probability: Float = 0.5, training: Bool = true) -> any Layer {
        switch type {
        case "spatial":
            return SpatialDropout(numChannels: 3, dropoutProbability: probability, training: training)
        case "alpha":
            return AlphaDropout(dropoutProbability: probability, training: training)
        case "variational":
            return VariationalDropout(inputSize: 256, dropoutProbability: probability, training: training)
        default:
            return DropoutLayer(dropoutProbability: probability, training: training)
        }
    }
}
