import Foundation
import Accelerate

// MARK: - Tensor

public struct Tensor: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var data: [Float]
    public var shape: [Int]
    public var strides: [Int]
    public var requiresGrad: Bool
    public var grad: [Float]?
    public var op: Operation?
    public var device: Device

    public init(data: [Float], shape: [Int], requiresGrad: Bool = false, device: Device = .cpu) {
        self.id = UUID()
        self.data = data
        self.shape = shape
        self.strides = computeStrides(shape: shape)
        self.requiresGrad = requiresGrad
        self.grad = nil
        self.op = nil
        self.device = device
    }

    public init(shape: [Int], requiresGrad: Bool = false, device: Device = .cpu) {
        self.id = UUID()
        self.data = Array(repeating: 0, count: shape.reduce(1, *))
        self.shape = shape
        self.strides = computeStrides(shape: shape)
        self.requiresGrad = requiresGrad
        self.grad = nil
        self.op = nil
        self.device = device
    }

    public init(scalar: Float, requiresGrad: Bool = false) {
        self.init(data: [scalar], shape: [1], requiresGrad: requiresGrad)
    }

    public var count: Int { data.count }
    public var rank: Int { shape.count }
    public var isScalar: Bool { shape.count == 1 && shape[0] == 1 }

    public subscript(_ indices: Int...) -> Float {
        get {
            let index = computeFlatIndex(indices)
            return data[index]
        }
        set {
            let index = computeFlatIndex(indices)
            data[index] = newValue
        }
    }

    public func reshape(_ newShape: [Int]) -> Tensor {
        let totalElements = shape.reduce(1, *)
        let newTotal = newShape.reduce(1, *)
        guard totalElements == newTotal else {
            return self
        }
        return Tensor(data: data, shape: newShape, requiresGrad: requiresGrad, device: device)
    }

    public func transpose() -> Tensor {
        guard shape.count == 2 else { return self }
        var newData = data
        vDSP_mtrans(data, 1, &newData, 1, vDSP_Length(shape[1]), vDSP_Length(shape[0]))
        return Tensor(data: newData, shape: [shape[1], shape[0]], requiresGrad: requiresGrad, device: device)
    }

    public func matmul(_ other: Tensor) -> Tensor {
        guard shape.count == 2, other.shape.count == 2, shape[1] == other.shape[0] else {
            return Tensor(data: [], shape: [0, 0], requiresGrad: requiresGrad && other.requiresGrad)
        }

        let m = shape[0]
        let n = shape[1]
        let p = other.shape[1]
        var result = [Float](repeating: 0, count: m * p)

        let alpha: Float = 1
        let beta: Float = 0
        vDSP_mmul(Data(data).withUnsafeBufferPointer { $0 }, 1, Data(other.data).withUnsafeBufferPointer { $0 }, 1, &result, 1, vDSP_Length(m), vDSP_Length(n), vDSP_Length(p))

        var output = Tensor(data: result, shape: [m, p], requiresGrad: requiresGrad && other.requiresGrad)
        if requiresGrad && other.requiresGrad {
            output.op = MatrixMultiplyOp(a: self, b: other)
        }
        return output
    }

    public func add(_ other: Tensor) -> Tensor {
        guard shape == other.shape else { return self }
        var result = data
        vDSP_vadd(other.data, 1, result, 1, &result, 1, vDSP_Length(result.count))

        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad || other.requiresGrad)
        if requiresGrad || other.requiresGrad {
            output.op = AddOp(a: self, b: other)
        }
        return output
    }

    public func subtract(_ other: Tensor) -> Tensor {
        guard shape == other.shape else { return self }
        var result = data
        vDSP_vsub(other.data, 1, result, 1, &result, 1, vDSP_Length(result.count))

        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad || other.requiresGrad)
        if requiresGrad || other.requiresGrad {
            output.op = SubtractOp(a: self, b: other)
        }
        return output
    }

    public func multiply(_ other: Tensor) -> Tensor {
        guard shape == other.shape else { return self }
        var result = [Float](repeating: 0, count: data.count)
        vDSP_vmul(other.data, 1, data, 1, &result, 1, vDSP_Length(result.count))

        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad || other.requiresGrad)
        if requiresGrad || other.requiresGrad {
            output.op = MultiplyOp(a: self, b: other)
        }
        return output
    }

    public func sum() -> Tensor {
        var sum: Float = 0
        vDSP_sve(data, 1, &sum, vDSP_Length(data.count))
        return Tensor(data: [sum], shape: [1], requiresGrad: requiresGrad)
    }

    public func mean() -> Tensor {
        var mean: Float = 0
        vDSP_meanv(data, 1, &mean, vDSP_Length(data.count))
        return Tensor(data: [mean], shape: [1], requiresGrad: requiresGrad)
    }

    public func variance() -> Tensor {
        let m = mean()
        let diff = subtract(m.broadcast(to: shape))
        let squared = diff.multiply(diff)
        return squared.sum()
    }

    public func broadcast(to shape: [Int]) -> Tensor {
        guard self.shape != shape else { return self }
        let totalElements = shape.reduce(1, *)
        var newData = [Float](repeating: data[0], count: totalElements)
        let strides = computeStrides(shape: shape)
        for i in 0..<totalElements {
            var indices = [Int](repeating: 0, count: shape.count)
            var remaining = i
            for d in (0..<shape.count).reversed() {
                indices[d] = remaining % shape[d]
                remaining /= shape[d]
            }
            var sourceIndex = 0
            for d in 0..<shape.count {
                if indices[d] >= self.shape[d] {
                    sourceIndex = 0
                    break
                }
            }
            newData[i] = data[sourceIndex]
        }
        return Tensor(data: newData, shape: shape, requiresGrad: requiresGrad)
    }

    public func relu() -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        vDSP_vmax(data, 1, [Float](repeating: 0, count: data.count), 1, &result, 1, vDSP_Length(result.count))

        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
        if requiresGrad { output.op = ReLUOp(input: self) }
        return output
    }

    public func sigmoid() -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = 1 / (1 + exp(-data[i]))
        }
        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
        if requiresGrad { output.op = SigmoidOp(input: self) }
        return output
    }

    public func tanh() -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = tanh(data[i])
        }
        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
        if requiresGrad { output.op = TanhOp(input: self) }
        return output
    }

    public func softmax() -> Tensor {
        var maxVal: Float = 0
        vDSP_maxv(data, 1, &maxVal, vDSP_Length(data.count))
        var shifted = [Float](repeating: 0, count: data.count)
        vDSP_vsadd(data, 1, [-maxVal], &shifted, 1, vDSP_Length(data.count))
        var expValues = [Float](repeating: 0, count: data.count)
        for i in 0..<shifted.count { expValues[i] = exp(shifted[i]) }
        var sum: Float = 0
        vDSP_sve(expValues, 1, &sum, vDSP_Length(expValues.count))
        var result = [Float](repeating: 0, count: data.count)
        vDSP_vdiv(expValues, 1, [sum], &result, 1, vDSP_Length(result.count))
        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
        if requiresGrad { output.op = SoftmaxOp(input: self) }
        return output
    }

    public func log() -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = log(max(data[i], 1e-7))
        }
        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
        if requiresGrad { output.op = LogOp(input: self) }
        return output
    }

    public func exp() -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = exp(data[i])
        }
        let output = Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
        if requiresGrad { output.op = ExpOp(input: self) }
        return output
    }

    public func clamp(min: Float = -1e6, max: Float = 1e6) -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = max(min, min(max, data[i]))
        }
        return Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
    }

    public func sqrt() -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = sqrt(max(data[i], 0))
        }
        return Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
    }

    public func pow(_ exponent: Float) -> Tensor {
        var result = [Float](repeating: 0, count: data.count)
        for i in 0..<data.count {
            result[i] = pow(data[i], exponent)
        }
        return Tensor(data: result, shape: shape, requiresGrad: requiresGrad)
    }

    public func zeroGrad() {
        guard requiresGrad else { return }
        grad = Array(repeating: 0, count: data.count)
    }

    public func backward() {
        guard requiresGrad, var gradient = grad else { return }
        var current: Tensor? = self
        while let node = current {
            if let operation = node.op {
                operation.backward(gradient: &gradient)
            }
            current = operation?.inputs.first
        }
    }

    private func computeStrides(shape: [Int]) -> [Int] {
        var strides = [Int](repeating: 0, count: shape.count)
        var stride = 1
        for i in (0..<shape.count).reversed() {
            strides[i] = stride
            stride *= shape[i]
        }
        return strides
    }

    private func computeFlatIndex(_ indices: [Int]) -> Int {
        var index = 0
        for i in 0..<indices.count {
            index += indices[i] * strides[i]
        }
        return index
    }
}

// MARK: - Device

public enum Device: Codable, Sendable, Hashable {
    case cpu
    case gpu
    case neuralEngine
    case custom(String)

    public var description: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .neuralEngine: return "Neural Engine"
        case .custom(let name): return name
        }
    }
}

// MARK: - Operation Protocols

public protocol Operation: Sendable {
    var inputs: [Tensor] { get }
    func backward(gradient: inout [Float])
}

public struct AddOp: Operation {
    public let inputs: [Tensor]
    private let a: Tensor
    private let b: Tensor

    public init(a: Tensor, b: Tensor) {
        self.a = a
        self.b = b
        self.inputs = [a, b]
    }

    public func backward(gradient: inout [Float]) {
        if a.requiresGrad {
            a.grad = (a.grad ?? [Float](repeating: 0, count: a.data.count)).adding(gradient, count: a.data.count)
        }
        if b.requiresGrad {
            b.grad = (b.grad ?? [Float](repeating: 0, count: b.data.count)).adding(gradient, count: b.data.count)
        }
    }
}

public struct SubtractOp: Operation {
    public let inputs: [Tensor]
    private let a: Tensor
    private let b: Tensor

    public init(a: Tensor, b: Tensor) {
        self.a = a
        self.b = b
        self.inputs = [a, b]
    }

    public func backward(gradient: inout [Float]) {
        if a.requiresGrad {
            a.grad = (a.grad ?? [Float](repeating: 0, count: a.data.count)).adding(gradient, count: a.data.count)
        }
        if b.requiresGrad {
            var negGradient = gradient.map { -$0 }
            b.grad = (b.grad ?? [Float](repeating: 0, count: b.data.count)).adding(negGradient, count: b.data.count)
        }
    }
}

public struct MultiplyOp: Operation {
    public let inputs: [Tensor]
    private let a: Tensor
    private let b: Tensor

    public init(a: Tensor, b: Tensor) {
        self.a = a
        self.b = b
        self.inputs = [a, b]
    }

    public func backward(gradient: inout [Float]) {
        if a.requiresGrad {
            var gradA = [Float](repeating: 0, count: a.data.count)
            vDSP_vmul(b.data, 1, gradient, 1, &gradA, 1, vDSP_Length(gradA.count))
            a.grad = (a.grad ?? [Float](repeating: 0, count: a.data.count)).adding(gradA, count: a.data.count)
        }
        if b.requiresGrad {
            var gradB = [Float](repeating: 0, count: b.data.count)
            vDSP_vmul(a.data, 1, gradient, 1, &gradB, 1, vDSP_Length(gradB.count))
            b.grad = (b.grad ?? [Float](repeating: 0, count: b.data.count)).adding(gradB, count: b.data.count)
        }
    }
}

public struct MatrixMultiplyOp: Operation {
    public let inputs: [Tensor]
    private let a: Tensor
    private let b: Tensor

    public init(a: Tensor, b: Tensor) {
        self.a = a
        self.b = b
        self.inputs = [a, b]
    }

    public func backward(gradient: inout [Float]) {
        guard a.shape.count == 2, b.shape.count == 2 else { return }
        let m = a.shape[0]
        let n = a.shape[1]
        let p = b.shape[1]

        if a.requiresGrad {
            var gradA = [Float](repeating: 0, count: m * n)
            let bt = b.transpose()
            vDSP_mmul(gradient, 1, bt.data, 1, &gradA, 1, vDSP_Length(m), vDSP_Length(n), vDSP_Length(p))
            a.grad = (a.grad ?? [Float](repeating: 0, count: a.data.count)).adding(gradA, count: a.data.count)
        }
        if b.requiresGrad {
            var gradB = [Float](repeating: 0, count: n * p)
            let at = a.transpose()
            vDSP_mmul(at.data, 1, gradient, 1, &gradB, 1, vDSP_Length(m), vDSP_Length(n), vDSP_Length(p))
            b.grad = (b.grad ?? [Float](repeating: 0, count: b.data.count)).adding(gradB, count: b.data.count)
        }
    }
}

public struct ReLUOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor

    public init(input: Tensor) {
        self.input = input
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        var mask = [Float](repeating: 0, count: input.data.count)
        for i in 0..<input.data.count {
            mask[i] = input.data[i] > 0 ? 1 : 0
        }
        vDSP_vmul(mask, 1, gradient, 1, &gradient, 1, vDSP_Length(gradient.count))
        input.grad = (input.grad ?? [Float](repeating: 0, count: input.data.count)).adding(gradient, count: input.data.count)
    }
}

public struct SigmoidOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor

    public init(input: Tensor) {
        self.input = input
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        var sig = [Float](repeating: 0, count: input.data.count)
        for i in 0..<input.data.count {
            sig[i] = 1 / (1 + exp(-input.data[i]))
        }
        var deriv = [Float](repeating: 0, count: sig.count)
        vDSP_vmul(sig, 1, [Float](repeating: 1, count: sig.count).map { $0 - sig[0] }, 1, &deriv, 1, vDSP_Length(deriv.count))
        vDSP_vmul(deriv, 1, gradient, 1, &gradient, 1, vDSP_Length(gradient.count))
        input.grad = (input.grad ?? [Float](repeating: 0, count: input.data.count)).adding(gradient, count: input.data.count)
    }
}

public struct TanhOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor

    public init(input: Tensor) {
        self.input = input
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        var deriv = [Float](repeating: 0, count: input.data.count)
        for i in 0..<input.data.count {
            let t = tanh(input.data[i])
            deriv[i] = 1 - t * t
        }
        vDSP_vmul(deriv, 1, gradient, 1, &gradient, 1, vDSP_Length(gradient.count))
        input.grad = (input.grad ?? [Float](repeating: 0, count: input.data.count)).adding(gradient, count: input.data.count)
    }
}

public struct SoftmaxOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor

    public init(input: Tensor) {
        self.input = input
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        var softmax = [Float](repeating: 0, count: input.data.count)
        var sum: Float = 0
        vDSP_sve(input.data, 1, &sum, vDSP_Length(input.data.count))
        var expValues = [Float](repeating: 0, count: input.data.count)
        vDSP_vsadd(input.data, 1, [-sum], &expValues, 1, vDSP_Length(expValues.count))
        for i in 0..<expValues.count { expValues[i] = exp(expValues[i]) }
        vDSP_vdiv(expValues, 1, [sum], &softmax, 1, vDSP_Length(softmax.count))

        var deriv = [Float](repeating: 0, count: input.data.count)
        for i in 0..<input.data.count {
            var s = softmax[i]
            var g = gradient[i]
            for j in 0..<input.data.count {
                let delta = (i == j ? 1 : 0)
                deriv[j] += g * s * (delta - softmax[j])
            }
        }
        input.grad = (input.grad ?? [Float](repeating: 0, count: input.data.count)).adding(deriv, count: input.data.count)
    }
}

public struct LogOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor

    public init(input: Tensor) {
        self.input = input
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        var mask = [Float](repeating: 0, count: input.data.count)
        for i in 0..<input.data.count {
            mask[i] = 1 / max(input.data[i], 1e-7)
        }
        vDSP_vmul(mask, 1, gradient, 1, &gradient, 1, vDSP_Length(gradient.count))
        input.grad = (input.grad ?? [Float](repeating: 0, count: input.data.count)).adding(gradient, count: input.data.count)
    }
}

public struct ExpOp: Operation {
    public let inputs: [Tensor]
    private let input: Tensor

    public init(input: Tensor) {
        self.input = input
        self.inputs = [input]
    }

    public func backward(gradient: inout [Float]) {
        var expValues = [Float](repeating: 0, count: input.data.count)
        for i in 0..<input.data.count {
            expValues[i] = exp(input.data[i])
        }
        vDSP_vmul(expValues, 1, gradient, 1, &gradient, 1, vDSP_Length(gradient.count))
        input.grad = (input.grad ?? [Float](repeating: 0, count: input.data.count)).adding(gradient, count: input.data.count)
    }
}

// MARK: - Layer Protocol

public protocol Layer: Sendable {
    var parameters: [Tensor] { get }
    var trainable: Bool { get set }
    var device: Device { get set }

    func forward(_ input: Tensor) -> Tensor
    func backward(_ gradient: Tensor) -> Tensor
    func update(learningRate: Float)
    func zeroGrad()
    func toJSON() -> Data
    func fromJSON(_ data: Data) throws
}

public extension Layer {
    public func update(learningRate: Float) {
        for param in parameters where param.requiresGrad {
            if var grad = param.grad {
                for i in 0..<param.data.count {
                    param.data[i] -= learningRate * grad[i]
                }
            }
        }
    }

    public func zeroGrad() {
        for param in parameters {
            param.zeroGrad()
        }
    }
}

// MARK: - Parameter Initialization

public enum InitializationScheme: String, Codable, Sendable, CaseIterable {
    case xavier = "XAVIER"
    case he = "HE"
    case orthogonal = "ORTHOGONAL"
    case uniform = "UNIFORM"
    case normal = "NORMAL"
    case zeros = "ZEROS"
    case ones = "ONES"
    case constant = "CONSTANT"
    case eye = "EYE"
}

public struct Initializer: Sendable {
    public let scheme: InitializationScheme
    public let gain: Float
    public let mean: Float
    public let std: Float
    public let lowerBound: Float
    public let upperBound: Float
    public let constant: Float

    public init(scheme: InitializationScheme = .xavier, gain: Float = 1, mean: Float = 0, std: Float = 0.02, lowerBound: Float = -0.05, upperBound: Float = 0.05, constant: Float = 0) {
        self.scheme = scheme
        self.gain = gain
        self.mean = mean
        self.std = std
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.constant = constant
    }

    public func initialize(size: Int, fanIn: Int = 1, fanOut: Int = 1) -> [Float] {
        var weights = [Float](repeating: 0, count: size)
        let scale: Float

        switch scheme {
        case .xavier:
            scale = gain * sqrt(2.0 / Float(fanIn + fanOut))
            for i in 0..<weights.count {
                weights[i] = Float.random(in: -scale...scale)
            }
        case .he:
            scale = gain * sqrt(2.0 / Float(fanIn))
            for i in 0..<weights.count {
                weights[i] = Float.random(in: -scale...scale)
            }
        case .orthogonal:
            var qr = [Float](repeating: 0, count: size)
            for i in 0..<size {
                qr[i] = Float.random(in: -1...1)
            }
            vDSP_vsmul(qr, 1, [gain], &weights, 1, vDSP_Length(size))
        case .uniform:
            for i in 0..<weights.count {
                weights[i] = Float.random(in: lowerBound...upperBound)
            }
        case .normal:
            for i in 0..<weights.count {
                weights[i] = normalRandom(mean: mean, std: std)
            }
        case .zeros:
            break
        case .ones:
            weights = Array(repeating: 1, count: size)
        case .constant:
            weights = Array(repeating: constant, count: size)
        case .eye:
            let dim = Int(sqrt(Float(size)))
            for i in 0..<size {
                weights[i] = i % (dim + 1) == 0 ? gain : 0
            }
        }
        return weights
    }

    private func normalRandom(mean: Float, std: Float) -> Float {
        var u1 = Float.random(in: 0...1)
        var u2 = Float.random(in: 0...1)
        while u1 == 0 { u1 = Float.random(in: 0...1) }
        return mean + std * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}

// MARK: - Gradient Tape

public class GradientTape: Sendable {
    public private(set) var recordedOps: [Operation] = []
    public private(set) var variables: [UUID: Tensor] = [:]
    public private(set) var isRecording: Bool = true

    public init(isRecording: Bool = true) {
        self.isRecording = isRecording
    }

    public func watch(_ tensor: Tensor) {
        guard isRecording else { return }
        variables[tensor.id] = tensor
    }

    public func record(_ operation: Operation) {
        guard isRecording else { return }
        recordedOps.append(operation)
    }

    public func backward(_ output: Tensor) {
        guard output.requiresGrad else { return }
        var gradient = output.grad ?? [Float](repeating: 1, count: output.data.count)
        for operation in recordedOps.reversed() {
            operation.backward(gradient: &gradient)
        }
    }

    public func reset() {
        recordedOps.removeAll()
        variables.removeAll()
    }
}

// MARK: - Neural Network Core

@MainActor
public final class NeuralNetworkCore: ObservableObject {
    public static let shared = NeuralNetworkCore()

    @Published public private(set) var layers: [UUID: any Layer] = [:]
    @Published public private(set) var isTraining: Bool = false
    @Published public private(set) var epoch: Int = 0
    @Published public private(set) var lossHistory: [Float] = []
    @Published public private(set) var currentLoss: Float = 0
    @Published public private(set) var gradientNorm: Float = 0
    @Published public private(set) var parameterCount: Int = 0

    public private(set) var gradientTape: GradientTape = GradientTape()
    public private(set) var optimizer: (any Optimizer)?
    public private(set) var lossFunction: any LossFunction
    public private(set) var trainingState: TrainingState
    public private(set) var forwardPassCache: [UUID: Tensor] = [:]

    public private let lock = NSLock()
    public private var trainingTask: Task<Void, Never>?

    public init(optimizer: (any Optimizer)? = nil, lossFunction: (any LossFunction)? = nil) {
        self.optimizer = optimizer
        self.lossFunction = lossFunction ?? MSELoss()
        self.trainingState = TrainingState()
        super.init()
    }
}

// MARK: - Forward Pass

extension NeuralNetworkCore {
    public func forward(_ input: Tensor) -> Tensor {
        var current = input
        forwardPassCache.removeAll()

        let layerIDs = layers.keys.sorted { idA, idB in
            guard let layerA = layers[idA], let layerB = layers[idB] else { return false }
            return layerA.hashValue < layerB.hashValue
        }

        for layerID in layerIDs {
            guard let layer = layers[layerID] else { continue }
            current = layer.forward(current)
            forwardPassCache[layerID] = current
        }

        return current
    }

    public func predict(_ input: Tensor) -> Tensor {
        var previousTraining = trainingState.isTraining
        trainingState.isTraining = false
        let output = forward(input)
        trainingState.isTraining = previousTraining
        return output
    }
}

// MARK: - Backward Pass

extension NeuralNetworkCore {
    public func backward(_ loss: Tensor) {
        guard loss.requiresGrad else { return }
        var gradient = loss.grad ?? [Float](repeating: 1, count: loss.data.count)

        let layerIDs = layers.keys.sorted { idA, idB in
            guard let layerA = layers[idA], let layerB = layers[idB] else { return false }
            return layerA.hashValue > layerB.hashValue
        }

        for layerID in layerIDs.reversed() {
            guard let layer = layers[layerID] else { continue }
            gradient = layer.backward(Tensor(data: gradient, shape: loss.shape))
        }
    }

    public func computeLoss(predictions: Tensor, targets: Tensor) -> Tensor {
        let loss = lossFunction.forward(predictions: predictions, targets: targets)
        currentLoss = loss.data.first ?? 0
        return loss
    }
}

// MARK: - Training Step

extension NeuralNetworkCore {
    public func trainingStep(input: Tensor, target: Tensor) -> Float {
        var previousTraining = trainingState.isTraining
        trainingState.isTraining = true

        zeroGrad()
        let predictions = forward(input)
        let loss = computeLoss(predictions: predictions, targets: target)
        backward(loss)

        if let optimizer = optimizer {
            optimizer.step(layers: Array(layers.values))
            computeGradientNorm()
        }

        trainingState.isTraining = previousTraining
        trainingState.step += 1

        return currentLoss
    }

    public func fit(inputs: [Tensor], targets: [Tensor], epochs: Int, batchSize: Int = 32, validationSplit: Double = 0.1) async {
        isTraining = true
        for epoch in 1...epochs {
            self.epoch = epoch
            var epochLoss: Float = 0
            let batchCount = max(1, inputs.count / batchSize)

            for batch in 0..<batchCount {
                let startIndex = batch * batchSize
                let endIndex = min(startIndex + batchSize, inputs.count)
                guard startIndex < inputs.count else { break }

                for i in startIndex..<endIndex {
                    let loss = trainingStep(input: inputs[i], target: targets[i])
                    epochLoss += loss
                }
            }

            let averageLoss = epochLoss / Float(batchCount)
            lossHistory.append(averageLoss)
            currentLoss = averageLoss

            if epoch % 10 == 0 {
                await MainActor.run {
                    print("Epoch \(epoch): loss = \(averageLoss)")
                }
            }
        }
        isTraining = false
    }

    public func evaluate(inputs: [Tensor], targets: [Tensor]) -> Float {
        var previousTraining = trainingState.isTraining
        trainingState.isTraining = false
        var totalLoss: Float = 0

        for i in 0..<inputs.count {
            zeroGrad()
            let predictions = forward(inputs[i])
            let loss = computeLoss(predictions: predictions, targets: targets[i])
            totalLoss += loss.data.first ?? 0
        }

        trainingState.isTraining = previousTraining
        return totalLoss / Float(inputs.count)
    }
}

// MARK: - Layer Management

extension NeuralNetworkCore {
    public func addLayer<T: Layer>(_ layer: T) {
        lock.lock()
        defer { lock.unlock() }
        var mutableLayer = layer
        mutableLayer.device = .cpu
        layers[mutableLayer.id] = mutableLayer
        parameterCount = layers.values.reduce(0) { $0 + $1.parameters.reduce(0) { sum, param in sum + param.data.count } }
    }

    public func removeLayer(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        layers.removeValue(forKey: id)
        parameterCount = layers.values.reduce(0) { $0 + $1.parameters.reduce(0) { sum, param in sum + param.data.count } }
    }

    public func getLayer<T: Layer>(_ id: UUID) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return layers[id] as? T
    }

    public func zeroGrad() {
        lock.lock()
        defer { lock.unlock() }
        for layer in layers.values {
            layer.zeroGrad()
        }
    }

    public func setTrainable(_ trainable: Bool) {
        lock.lock()
        defer { lock.unlock() }
        for (id, var layer) in layers {
            layer.trainable = trainable
            layers[id] = layer
        }
    }

    private func computeGradientNorm() {
        var totalNorm: Float = 0
        for layer in layers.values {
            for param in layer.parameters where param.requiresGrad {
                if let grad = param.grad {
                    var norm: Float = 0
                    vDSP_svesq(grad, 1, &norm, vDSP_Length(grad.count))
                    totalNorm += sqrt(norm)
                }
            }
        }
        gradientNorm = totalNorm
    }
}

// MARK: - Serialization

extension NeuralNetworkCore {
    public func saveModel(to url: URL) throws {
        var modelData: [String: Data] = [:]
        for (id, layer) in layers {
            modelData[id.uuidString] = try layer.toJSON()
        }
        let data = try JSONSerialization.data(withJSONObject: modelData, options: [])
        try data.write(to: url)
    }

    public func loadModel(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let modelData = try JSONSerialization.jsonObject(with: data) as? [String: Data] else {
            throw NSError(domain: "NeuralNetworkCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid model format"])
        }
        layers.removeAll()
        for (idString, layerData) in modelData {
            guard let id = UUID(uuidString: idString) else { continue }
            let layerType = try JSONDecoder().decode(LayerTypeWrapper.self, from: layerData)
            let layer = try createLayer(from: layerData, type: layerType.type)
            layers[id] = layer
        }
        parameterCount = layers.values.reduce(0) { $0 + $1.parameters.reduce(0) { sum, param in sum + param.data.count } }
    }

    private func createLayer(from data: Data, type: String) throws -> any Layer {
        switch type {
        case "DenseLayer": return try JSONDecoder().decode(DenseLayer.self, from: data)
        case "Conv1DLayer": return try JSONDecoder().decode(Conv1DLayer.self, from: data)
        case "LSTMCell": return try JSONDecoder().decode(LSTMCell.self, from: data)
        case "GRUCell": return try JSONDecoder().decode(GRUCell.self, from: data)
        case "BatchNormalization": return try JSONDecoder().decode(BatchNormalization.self, from: data)
        case "DropoutLayer": return try JSONDecoder().decode(DropoutLayer.self, from: data)
        case "MultiHeadAttention": return try JSONDecoder().decode(MultiHeadAttention.self, from: data)
        case "TransformerBlock": return try JSONDecoder().decode(TransformerBlock.self, from: data)
        default: throw NSError(domain: "NeuralNetworkCore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown layer type: \(type)"])
        }
    }
}

public struct LayerTypeWrapper: Codable {
    public let type: String
}

// MARK: - Optimizer Protocol

public protocol Optimizer: Sendable {
    func step(layers: [any Layer])
    func zeroGrad()
    func saveState() -> Data
    func loadState(_ data: Data) throws
}

// MARK: - Loss Function Protocol

public protocol LossFunction: Sendable {
    func forward(predictions: Tensor, targets: Tensor) -> Tensor
    func backward(predictions: Tensor, targets: Tensor) -> Tensor
}

// MARK: - Training State

public struct TrainingState: Sendable {
    public var isTraining: Bool
    public var step: Int
    public var epoch: Int
    public var bestLoss: Float

    public init(isTraining: Bool = false, step: Int = 0, epoch: Int = 0, bestLoss: Float = .infinity) {
        self.isTraining = isTraining
        self.step = step
        self.epoch = epoch
        self.bestLoss = bestLoss
    }
}

// MARK: - Helpers

extension Array where Element == Float {
    func adding(_ other: [Float], count: Int) -> [Float] {
        var result = Array(self.prefix(count))
        for i in 0..<min(count, other.count) {
            result[i] += other[i]
        }
        return result
    }
}

public struct DeviceMemoryInfo: Sendable {
    public let totalMemory: Int64
    public let availableMemory: Int64
    public let usedMemory: Int64
    public let utilization: Double

    public init(totalMemory: Int64 = 0, availableMemory: Int64 = 0, usedMemory: Int64 = 0, utilization: Double = 0) {
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
        self.usedMemory = usedMemory
        self.utilization = utilization
    }
}
