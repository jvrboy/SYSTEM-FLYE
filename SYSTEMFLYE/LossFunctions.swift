import Foundation
import Accelerate

// MARK: - Loss Functions

public protocol LossFunction: Sendable {
    func forward(predictions: Tensor, targets: Tensor) -> Tensor
    func backward(predictions: Tensor, targets: Tensor) -> Tensor
    func toJSON() -> Data
    func fromJSON(_ data: Data) throws
}

// MARK: - Reduction Type

public enum ReductionType: String, Codable, Sendable, CaseIterable {
    case none = "NONE"
    case mean = "MEAN"
    case sum = "SUM"
}

// MARK: - MSE Loss

public struct MSELoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let reduction: ReductionType

    public init(reduction: ReductionType = .mean) {
        self.id = UUID()
        self.reduction = reduction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reduction, forKey: .reduction)
    }

    enum CodingKeys: String, CodingKey { case id, reduction }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        var diff = [Float](repeating: 0, count: predictions.data.count)
        vDSP_vsub(targets.data, 1, predictions.data, 1, &diff, 1, vDSP_Length(diff.count))
        var squared = [Float](repeating: 0, count: diff.count)
        vDSP_vsq(diff, 1, &squared, 1, vDSP_Length(squared.count))
        var sum: Float = 0
        vDSP_sve(squared, 1, &sum, vDSP_Length(squared.count))
        let n = Float(predictions.data.count)
        let value = reduction == .mean ? sum / n : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        var diff = [Float](repeating: 0, count: predictions.data.count)
        vDSP_vsub(targets.data, 1, predictions.data, 1, &diff, 1, vDSP_Length(diff.count))
        let n = Float(predictions.data.count)
        let scale = reduction == .mean ? 2 / n : 2
        vDSP_vsmul(diff, 1, [scale], &diff, 1, vDSP_Length(diff.count))
        return Tensor(data: diff, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - MAE Loss

public struct MAELoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let reduction: ReductionType

    public init(reduction: ReductionType = .mean) {
        self.id = UUID()
        self.reduction = reduction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reduction, forKey: .reduction)
    }

    enum CodingKeys: String, CodingKey { case id, reduction }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        var diff = [Float](repeating: 0, count: predictions.data.count)
        vDSP_vsub(targets.data, 1, predictions.data, 1, &diff, 1, vDSP_Length(diff.count))
        var absDiff = [Float](repeating: 0, count: diff.count)
        vDSP_vabs(diff, 1, &absDiff, 1, vDSP_Length(absDiff.count))
        var sum: Float = 0
        vDSP_sve(absDiff, 1, &sum, vDSP_Length(absDiff.count))
        let n = Float(predictions.data.count)
        let value = reduction == .mean ? sum / n : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        var diff = [Float](repeating: 0, count: predictions.data.count)
        vDSP_vsub(targets.data, 1, predictions.data, 1, &diff, 1, vDSP_Length(diff.count))
        var sign = [Float](repeating: 0, count: diff.count)
        for i in 0..<diff.count {
            sign[i] = diff[i] > 0 ? 1 : (diff[i] < 0 ? -1 : 0)
        }
        let n = Float(predictions.data.count)
        let scale = reduction == .mean ? 1 / n : 1
        vDSP_vsmul(sign, 1, [-scale], &sign, 1, vDSP_Length(sign.count))
        return Tensor(data: sign, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Cross Entropy Loss

public struct CrossEntropyLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let reduction: ReductionType
    public let labelSmoothing: Float
    public let weight: [Float]?

    public init(reduction: ReductionType = .mean, labelSmoothing: Float = 0, weight: [Float]? = nil) {
        self.id = UUID()
        self.reduction = reduction
        self.labelSmoothing = labelSmoothing
        self.weight = weight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
        labelSmoothing = try container.decode(Float.self, forKey: .labelSmoothing)
        weight = try container.decodeIfPresent([Float].self, forKey: .weight)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reduction, forKey: .reduction)
        try container.encode(labelSmoothing, forKey: .labelSmoothing)
        try container.encodeIfPresent(weight, forKey: .weight)
    }

    enum CodingKeys: String, CodingKey { case id, reduction, labelSmoothing, weight }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        let numClasses = predictions.shape.count > 1 ? predictions.shape[1] : predictions.shape.first ?? 1

        var loss = [Float](repeating: 0, count: batchSize)
        for b in 0..<batchSize {
            var classLoss: Float = 0
            for c in 0..<numClasses {
                let predIdx = b * numClasses + c
                let pred = max(min(predictions.data[predIdx], 1 - 1e-7), 1e-7)
                let targetIdx = b * numClasses + Int(targets.data[b])
                let target = targets.data[targetIdx]
                let smoothTarget = target * (1 - labelSmoothing) + labelSmoothing / Float(numClasses)
                classLoss -= smoothTarget * log(pred)
            }
            loss[b] = classLoss
        }

        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let value = reduction == .mean ? sum / Float(batchSize) : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        let numClasses = predictions.shape.count > 1 ? predictions.shape[1] : predictions.shape.first ?? 1
        var grad = predictions.data

        for b in 0..<batchSize {
            for c in 0..<numClasses {
                let predIdx = b * numClasses + c
                let pred = max(min(predictions.data[predIdx], 1 - 1e-7), 1e-7)
                let targetIdx = b * numClasses + Int(targets.data[b])
                let target = targets.data[targetIdx]
                let smoothTarget = target * (1 - labelSmoothing) + labelSmoothing / Float(numClasses)
                grad[predIdx] = -smoothTarget / pred
            }
        }

        let scale = reduction == .mean ? 1 / Float(batchSize) : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Binary Cross Entropy Loss

public struct BinaryCrossEntropyLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let reduction: ReductionType
    public let posWeight: Float

    public init(reduction: ReductionType = .mean, posWeight: Float = 1) {
        self.id = UUID()
        self.reduction = reduction
        self.posWeight = posWeight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
        posWeight = try container.decode(Float.self, forKey: .posWeight)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reduction, forKey: .reduction)
        try container.encode(posWeight, forKey: .posWeight)
    }

    enum CodingKeys: String, CodingKey { case id, reduction, posWeight }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        var loss = [Float](repeating: 0, count: predictions.data.count)
        for i in 0..<predictions.data.count {
            let pred = max(min(predictions.data[i], 1 - 1e-7), 1e-7)
            let target = targets.data[i]
            loss[i] = -posWeight * target * log(pred) - (1 - target) * log(1 - pred)
        }
        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let n = Float(predictions.data.count)
        let value = reduction == .mean ? sum / n : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        var grad = [Float](repeating: 0, count: predictions.data.count)
        for i in 0..<predictions.data.count {
            let pred = max(min(predictions.data[i], 1 - 1e-7), 1e-7)
            let target = targets.data[i]
            grad[i] = (pred - target) / (pred * (1 - pred))
        }
        let n = Float(predictions.data.count)
        let scale = reduction == .mean ? 1 / n : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Huber Loss

public struct HuberLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let delta: Float
    public let reduction: ReductionType

    public init(delta: Float = 1, reduction: ReductionType = .mean) {
        self.id = UUID()
        self.delta = delta
        self.reduction = reduction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        delta = try container.decode(Float.self, forKey: .delta)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(delta, forKey: .delta)
        try container.encode(reduction, forKey: .reduction)
    }

    enum CodingKeys: String, CodingKey { case id, delta, reduction }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        var loss = [Float](repeating: 0, count: predictions.data.count)
        for i in 0..<predictions.data.count {
            let diff = abs(predictions.data[i] - targets.data[i])
            loss[i] = diff <= delta ? 0.5 * diff * diff : delta * (diff - 0.5 * delta)
        }
        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let n = Float(predictions.data.count)
        let value = reduction == .mean ? sum / n : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        var grad = [Float](repeating: 0, count: predictions.data.count)
        for i in 0..<predictions.data.count {
            let diff = predictions.data[i] - targets.data[i]
            grad[i] = abs(diff) <= delta ? diff : delta * (diff > 0 ? 1 : -1)
        }
        let n = Float(predictions.data.count)
        let scale = reduction == .mean ? 1 / n : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Focal Loss

public struct FocalLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let alpha: Float
    public let gamma: Float
    public let reduction: ReductionType
    public let numClasses: Int

    public init(alpha: Float = 0.25, gamma: Float = 2, reduction: ReductionType = .mean, numClasses: Int = 2) {
        self.id = UUID()
        self.alpha = alpha
        self.gamma = gamma
        self.reduction = reduction
        self.numClasses = numClasses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        alpha = try container.decode(Float.self, forKey: .alpha)
        gamma = try container.decode(Float.self, forKey: .gamma)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
        numClasses = try container.decode(Int.self, forKey: .numClasses)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(alpha, forKey: .alpha)
        try container.encode(gamma, forKey: .gamma)
        try container.encode(reduction, forKey: .reduction)
        try container.encode(numClasses, forKey: .numClasses)
    }

    enum CodingKeys: String, CodingKey { case id, alpha, gamma, reduction, numClasses }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        var loss = [Float](repeating: 0, count: batchSize)
        for b in 0..<batchSize {
            let pred = max(min(predictions.data[b], 1 - 1e-7), 1e-7)
            let target = targets.data[b]
            let pt = target * pred + (1 - target) * (1 - pred)
            let alphaWeight = target * alpha + (1 - target) * (1 - alpha)
            loss[b] = -alphaWeight * pow(1 - pt, gamma) * log(pt)
        }
        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let value = reduction == .mean ? sum / Float(batchSize) : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        var grad = [Float](repeating: 0, count: predictions.data.count)
        for b in 0..<batchSize {
            let pred = predictions.data[b]
            let target = targets.data[b]
            let pt = target * pred + (1 - target) * (1 - pred)
            let alphaWeight = target * alpha + (1 - target) * (1 - alpha)
            let modulating = pow(1 - pt, gamma - 1)
            grad[b] = alphaWeight * (gamma * modulating * (target - pred) * log(pt) - modulating * (target / pred - (1 - target) / (1 - pred)))
        }
        let scale = reduction == .mean ? 1 / Float(batchSize) : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Contrastive Loss

public struct ContrastiveLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let margin: Float
    public let reduction: ReductionType

    public init(margin: Float = 1, reduction: ReductionType = .mean) {
        self.id = UUID()
        self.margin = margin
        self.reduction = reduction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        margin = try container.decode(Float.self, forKey: .margin)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(margin, forKey: .margin)
        try container.encode(reduction, forKey: .reduction)
    }

    enum CodingKeys: String, CodingKey { case id, margin, reduction }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        var loss = [Float](repeating: 0, count: batchSize)
        for b in 0..<batchSize {
            let pred = predictions.data[b]
            let target = targets.data[b]
            if target == 1 {
                loss[b] = 0.5 * pow(pred, 2)
            } else {
                let d = max(margin - pred, 0)
                loss[b] = 0.5 * pow(d, 2)
            }
        }
        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let value = reduction == .mean ? sum / Float(batchSize) : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        var grad = [Float](repeating: 0, count: predictions.data.count)
        for b in 0..<batchSize {
            let pred = predictions.data[b]
            let target = targets.data[b]
            if target == 1 {
                grad[b] = pred
            } else if pred < margin {
                grad[b] = pred - margin
            } else {
                grad[b] = 0
            }
        }
        let scale = reduction == .mean ? 1 / Float(batchSize) : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - KL Divergence Loss

public struct KLDivergenceLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let reduction: ReductionType
    public let logTarget: Bool

    public init(reduction: ReductionType = .mean, logTarget: Bool = false) {
        self.id = UUID()
        self.reduction = reduction
        self.logTarget = logTarget
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
        logTarget = try container.decode(Bool.self, forKey: .logTarget)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reduction, forKey: .reduction)
        try container.encode(logTarget, forKey: .logTarget)
    }

    enum CodingKeys: String, CodingKey { case id, reduction, logTarget }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        var loss = [Float](repeating: 0, count: predictions.data.count)
        for i in 0..<predictions.data.count {
            let p = max(min(predictions.data[i], 1 - 1e-7), 1e-7)
            let q = logTarget ? max(min(exp(targets.data[i]), 1 - 1e-7), 1e-7) : max(min(targets.data[i], 1 - 1e-7), 1e-7)
            loss[i] = q * (log(q) - log(p))
        }
        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let n = Float(predictions.data.count)
        let value = reduction == .mean ? sum / n : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        var grad = [Float](repeating: 0, count: predictions.data.count)
        for i in 0..<predictions.data.count {
            let p = max(min(predictions.data[i], 1 - 1e-7), 1e-7)
            let q = logTarget ? exp(targets.data[i]) : targets.data[i]
            grad[i] = -q / p
        }
        let n = Float(predictions.data.count)
        let scale = reduction == .mean ? 1 / n : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Cosine Embedding Loss

public struct CosineEmbeddingLoss: LossFunction, Identifiable, Codable, Sendable {
    public let id: UUID
    public let margin: Float
    public let reduction: ReductionType

    public init(margin: Float = 0, reduction: ReductionType = .mean) {
        self.id = UUID()
        self.margin = margin
        self.reduction = reduction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        margin = try container.decode(Float.self, forKey: .margin)
        reduction = try container.decode(ReductionType.self, forKey: .reduction)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(margin, forKey: .margin)
        try container.encode(reduction, forKey: .reduction)
    }

    enum CodingKeys: String, CodingKey { case id, margin, reduction }

    public func forward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        var loss = [Float](repeating: 0, count: batchSize)
        for b in 0..<batchSize {
            let pred = predictions.data[b]
            let target = targets.data[b]
            if target == 1 {
                loss[b] = 1 - pred
            } else {
                loss[b] = max(0, pred + margin)
            }
        }
        var sum: Float = 0
        vDSP_sve(loss, 1, &sum, vDSP_Length(loss.count))
        let value = reduction == .mean ? sum / Float(batchSize) : sum
        return Tensor(data: [value], shape: [1], requiresGrad: predictions.requiresGrad)
    }

    public func backward(predictions: Tensor, targets: Tensor) -> Tensor {
        let batchSize = predictions.shape.count > 1 ? predictions.shape[0] : 1
        var grad = [Float](repeating: 0, count: predictions.data.count)
        for b in 0..<batchSize {
            let pred = predictions.data[b]
            let target = targets.data[b]
            if target == 1 {
                grad[b] = -1
            } else if pred > -margin {
                grad[b] = 1
            } else {
                grad[b] = 0
            }
        }
        let scale = reduction == .mean ? 1 / Float(batchSize) : 1
        vDSP_vsmul(grad, 1, [scale], &grad, 1, vDSP_Length(grad.count))
        return Tensor(data: grad, shape: predictions.shape, requiresGrad: predictions.requiresGrad)
    }

    public func toJSON() -> Data { return try! JSONEncoder().encode(self) }
    public func fromJSON(_ data: Data) throws {}
}

// MARK: - Loss Factory

public struct LossFactory {
    public static func create(_ type: String, parameters: [String: Any] = [:]) -> any LossFunction {
        switch type {
        case "mse": return MSELoss()
        case "mae": return MAELoss()
        case "cross_entropy": return CrossEntropyLoss()
        case "binary_cross_entropy": return BinaryCrossEntropyLoss()
        case "huber": return HuberLoss(delta: parameters["delta"] as? Float ?? 1)
        case "focal": return FocalLoss(alpha: parameters["alpha"] as? Float ?? 0.25, gamma: parameters["gamma"] as? Float ?? 2)
        case "contrastive": return ContrastiveLoss(margin: parameters["margin"] as? Float ?? 1)
        case "kl_divergence": return KLDivergenceLoss()
        case "cosine_embedding": return CosineEmbeddingLoss(margin: parameters["margin"] as? Float ?? 0)
        default: return MSELoss()
        }
    }
}
