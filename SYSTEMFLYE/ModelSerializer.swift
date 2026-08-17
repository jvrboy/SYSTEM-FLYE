import Foundation
import Accelerate
import CoreML

// MARK: - Model Serializer

public struct ModelSerializer {
    public static let shared = ModelSerializer()

    public let version: String
    public let format: SerializationFormat
    public var metadata: [String: String]
    public var compressionEnabled: Bool
    public var quantizationEnabled: Bool
    public var versioningEnabled: Bool
    public var coreMLConversionEnabled: Bool

    public init(version: String = "1.0.0", format: SerializationFormat = .json, compressionEnabled: Bool = true, quantizationEnabled: Bool = true, versioningEnabled: Bool = true, coreMLConversionEnabled: Bool = true) {
        self.version = version
        self.format = format
        self.metadata = [:]
        self.compressionEnabled = compressionEnabled
        self.quantizationEnabled = quantizationEnabled
        self.versioningEnabled = versioningEnabled
        self.coreMLConversionEnabled = coreMLConversionEnabled
    }

    public func save(model: NeuralNetworkCore, to url: URL) throws {
        var checkpoint = ModelCheckpoint(
            version: version,
            timestamp: Date(),
            layers: [:],
            metadata: metadata,
            trainingState: model.trainingState,
            optimizerState: nil,
            lossHistory: model.lossHistory,
            epoch: model.epoch
        )

        for (id, layer) in model.layers {
            let layerData = try layer.toJSON()
            checkpoint.layers[id.uuidString] = layerData
        }

        let data = try JSONEncoder().encode(checkpoint)
        try data.write(to: url)
    }

    public func loadModel(from url: URL) throws -> NeuralNetworkCore {
        let data = try Data(contentsOf: url)
        let checkpoint = try JSONDecoder().decode(ModelCheckpoint.self, from: data)
        let model = NeuralNetworkCore()
        model.epoch = checkpoint.epoch
        model.lossHistory = checkpoint.lossHistory
        model.trainingState = checkpoint.trainingState
        model.layers.removeAll()

        for (idString, layerData) in checkpoint.layers {
            guard let id = UUID(uuidString: idString) else { continue }
            let layerType = try JSONDecoder().decode(LayerTypeWrapper.self, from: layerData)
            let layer = try createLayer(from: layerData, type: layerType.type)
            model.layers[id] = layer
        }
        model.parameterCount = model.layers.values.reduce(0) { $0 + $1.parameters.reduce(0) { sum, param in sum + param.data.count } }
        return model
    }

    public func saveCheckpoint(model: NeuralNetworkCore, to url: URL) throws {
        try save(model: model, to: url)
    }

    public func saveVersionedCheckpoint(model: NeuralNetworkCore, to directory: URL, name: String = "checkpoint") throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let versionedName = "\(name)_v\(version)_\(timestamp).json"
        let url = directory.appendingPathComponent(versionedName)
        try save(model: model, to: url)
        return url
    }

    public func listCheckpoints(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    public func loadLatestCheckpoint(from directory: URL) throws -> NeuralNetworkCore? {
        let checkpoints = listCheckpoints(in: directory).sorted { $0.lastPathComponent > $1.lastPathComponent }
        guard let latest = checkpoints.first else { return nil }
        return try loadModel(from: latest)
    }

    public func quantize(model: NeuralNetworkCore, bits: Int = 8) throws -> NeuralNetworkCore {
        guard quantizationEnabled else { return model }
        let quantizedModel = model
        for (id, layer) in quantizedModel.layers {
            var mutableLayer = layer
            for param in mutableLayer.parameters {
                let min = param.data.min() ?? 0
                let max = param.data.max() ?? 1
                let scale = Float(bits - 1) / (max - min)
                var quantized = param.data.map { round(($0 - min) * scale) / scale + min }
                param.data = quantized
            }
            quantizedModel.layers[id] = mutableLayer
        }
        return quantizedModel
    }

    public func convertToCoreML(model: NeuralNetworkCore, name: String = "Model") throws -> MLModel {
        guard coreMLConversionEnabled else {
            throw NSError(domain: "ModelSerializer", code: 1, userInfo: [NSLocalizedDescriptionKey: "CoreML conversion disabled"])
        }

        var layers: [MLNeuralNetworkLayer] = []
        for (id, layer) in model.layers {
            guard let denseLayer = layer as? DenseLayer else { continue }
            let weight = try MLMultiArray(shape: [NSNumber(value: denseLayer.inputSize), NSNumber(value: denseLayer.outputSize)], dataType: .float32)
            try weight.setData(denseLayer.weight.data.map { NSNumber(value: $0) })

            let bias = try MLMultiArray(shape: [NSNumber(value: denseLayer.outputSize)], dataType: .float32)
            try bias.setData(denseLayer.bias.data.map { NSNumber(value: $0) })

            let layerDesc = MLNeuralNetworkLayer(
                name: id.uuidString,
                type: .innerProduct,
                inputDescriptions: ["input": MLFeatureDescription(name: "input", type: .multiArray, shape: [NSNumber(value: denseLayer.inputSize)] as [NSNumber], isOptional: false)],
                outputDescriptions: ["output": MLFeatureDescription(name: "output", type: .multiArray, shape: [NSNumber(value: denseLayer.outputSize)] as [NSNumber], isOptional: false)],
                innerProduct: MLNeuralNetworkLayerInnerProduct(
                    inputSize: denseLayer.inputSize,
                    outputSize: denseLayer.outputSize,
                    weight: weight,
                    bias: bias
                )
            )
            layers.append(layerDesc)
        }

        let modelDesc = try MLModelDescription(inputs: ["input": MLFeatureDescription(name: "input", type: .multiArray)], outputs: ["output": MLFeatureDescription(name: "output", type: .multiArray)], predictedFeatureName: "output")
        let compiledUrl = try MLModel.compileModel(at: URL(fileURLWithPath: "/tmp/\(name).mlmodel"))
        let mlModel = try MLModel(contentsOf: compiledUrl, configuration: MLModelConfiguration())
        return mlModel
    }

    public func exportToONNX(model: NeuralNetworkCore, to url: URL) throws {
        var onnxModel = ONNXModel(irVersion: 8, producerName: "SYSTEM-FLYE")
        for (id, layer) in model.layers {
            if let denseLayer = layer as? DenseLayer {
                let node = ONNXNode(
                    opType: "Gemm",
                    inputs: ["input", denseLayer.weight.id.uuidString, denseLayer.bias.id.uuidString],
                    outputs: [id.uuidString],
                    attributes: ["alpha": 1.0, "beta": 1.0, "transB": 0]
                )
                onnxModel.graph.nodes.append(node)
            }
        }
        let data = try JSONEncoder().encode(onnxModel)
        try data.write(to: url)
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
        case "PositionalEncoding": return try JSONDecoder().decode(PositionalEncoding.self, from: data)
        case "EmbeddingLayer": return try JSONDecoder().decode(EmbeddingLayer.self, from: data)
        case "SpatialDropout": return try JSONDecoder().decode(SpatialDropout.self, from: data)
        case "AlphaDropout": return try JSONDecoder().decode(AlphaDropout.self, from: data)
        case "VariationalDropout": return try JSONDecoder().decode(VariationalDropout.self, from: data)
        default: throw NSError(domain: "ModelSerializer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown layer type: \(type)"])
        }
    }
}

// MARK: - Serialization Format

public enum SerializationFormat: String, Codable, Sendable, CaseIterable {
    case json = "JSON"
    case binary = "BINARY"
    case proto = "PROTO"
    case msgPack = "MSGPACK"
}

// MARK: - Model Checkpoint

public struct ModelCheckpoint: Codable, Identifiable, Sendable {
    public let id: UUID
    public let version: String
    public let timestamp: Date
    public var layers: [String: Data]
    public var metadata: [String: String]
    public var trainingState: TrainingState
    public var optimizerState: Data?
    public var lossHistory: [Float]
    public var epoch: Int

    public init(version: String = "1.0.0", timestamp: Date = Date(), layers: [String: Data] = [:], metadata: [String: String] = [:], trainingState: TrainingState = .init(), optimizerState: Data? = nil, lossHistory: [Float] = [], epoch: Int = 0) {
        self.id = UUID()
        self.version = version
        self.timestamp = timestamp
        self.layers = layers
        self.metadata = metadata
        self.trainingState = trainingState
        self.optimizerState = optimizerState
        self.lossHistory = lossHistory
        self.epoch = epoch
    }
}

// MARK: - ONNX Types

public struct ONNXModel: Codable, Sendable {
    public let irVersion: Int
    public let producerName: String
    public var producerVersion: String?
    public var graph: ONNXGraph
    public var opsetImports: [ONNXOpSetImport]

    public init(irVersion: Int, producerName: String, producerVersion: String? = nil, graph: ONNXGraph = .init(), opsetImports: [ONNXOpSetImport] = []) {
        self.irVersion = irVersion
        self.producerName = producerName
        self.producerVersion = producerVersion
        self.graph = graph
        self.opsetImports = opsetImports
    }
}

public struct ONNXGraph: Codable, Sendable {
    public var name: String
    public var inputs: [ONNXValueInfo]
    public var outputs: [ONNXValueInfo]
    public var nodes: [ONNXNode]
    public var initializers: [ONNXInitializer]

    public init(name: String = "main_graph", inputs: [ONNXValueInfo] = [], outputs: [ONNXValueInfo] = [], nodes: [ONNXNode] = [], initializers: [ONNXInitializer] = []) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.nodes = nodes
        self.initializers = initializers
    }
}

public struct ONNXValueInfo: Codable, Sendable {
    public let name: String
    public var type: String
    public var shape: [Int]

    public init(name: String, type: String = "float", shape: [Int] = []) {
        self.name = name
        self.type = type
        self.shape = shape
    }
}

public struct ONNXNode: Codable, Sendable {
    public let name: String?
    public let opType: String
    public let inputs: [String]
    public let outputs: [String]
    public var attributes: [String: AnyCodable]

    public init(name: String? = nil, opType: String, inputs: [String], outputs: [String], attributes: [String: AnyCodable] = [:]) {
        self.name = name
        self.opType = opType
        self.inputs = inputs
        self.outputs = outputs
        self.attributes = attributes
    }
}

public struct ONNXInitializer: Codable, Sendable {
    public let name: String
    public var dataType: Int
    public var dims: [Int]
    public var data: Data

    public init(name: String, dataType: Int = 1, dims: [Int] = [], data: Data = Data()) {
        self.name = name
        self.dataType = dataType
        self.dims = dims
        self.data = data
    }
}

public struct ONNXOpSetImport: Codable, Sendable {
    public let domain: String?
    public let version: Int

    public init(domain: String? = nil, version: Int = 13) {
        self.domain = domain
        self.version = version
    }
}

// MARK: - AnyCodable

public struct AnyCodable: Codable, Sendable {
    public let value: Any
    public init(_ value: Any) { self.value = value }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int; return }
        if let double = try? container.decode(Double.self) { value = double; return }
        if let bool = try? container.decode(Bool.self) { value = bool; return }
        if let string = try? container.decode(String.self) { value = string; return }
        if let array = try? container.decode([AnyCodable].self) { value = array.map { $0.value }; return }
        if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value }; return }
        value = NSNull()
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

// MARK: - Model Versioning

public struct ModelVersion: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let modelID: UUID
    public let version: String
    public let createdAt: Date
    public let author: String
    public let description: String
    public let metrics: [String: Double]
    public let tags: [String]
    public let fileURL: URL

    public init(modelID: UUID, version: String, author: String = "SYSTEM-FLYE", description: String = "", metrics: [String: Double] = [:], tags: [String] = [], fileURL: URL) {
        self.id = UUID()
        self.modelID = modelID
        self.version = version
        self.createdAt = Date()
        self.author = author
        self.description = description
        self.metrics = metrics
        self.tags = tags
        self.fileURL = fileURL
    }
}

// MARK: - Model Registry

@MainActor
public final class ModelRegistry: ObservableObject {
    public static let shared = ModelRegistry()

    @Published public private(set) var versions: [UUID: ModelVersion] = [:]
    @Published public private(set) var activeVersion: ModelVersion?
    @Published public private(set) var modelCount: Int = 0

    public private(set) var modelDirectory: URL
    public private let lock = NSLock()

    public init(modelDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Models")) {
        self.modelDirectory = modelDirectory
        super.init()
        loadVersions()
    }

    public func register(model: NeuralNetworkCore, version: String, author: String = "SYSTEM-FLYE", description: String = "", metrics: [String: Double] = [:], tags: [String] = []) throws -> UUID {
        let fileURL = modelDirectory.appendingPathComponent("\(version).json")
        let serializer = ModelSerializer()
        try serializer.save(model: model, to: fileURL)

        let modelID = UUID()
        let modelVersion = ModelVersion(modelID: modelID, version: version, author: author, description: description, metrics: metrics, tags: tags, fileURL: fileURL)
        versions[modelVersion.id] = modelVersion
        activeVersion = modelVersion
        modelCount = versions.count
        return modelVersion.id
    }

    public func load(version: UUID) throws -> NeuralNetworkCore? {
        guard let modelVersion = versions[version] else { return nil }
        let serializer = ModelSerializer()
        return try serializer.loadModel(from: modelVersion.fileURL)
    }

    public func loadActive() throws -> NeuralNetworkCore? {
        guard let active = activeVersion else { return nil }
        return try load(version: active.id)
    }

    public func delete(version: UUID) throws {
        guard let modelVersion = versions[version] else { return }
        try FileManager.default.removeItem(at: modelVersion.fileURL)
        versions.removeValue(forKey: version)
        modelCount = versions.count
    }

    public func diff(from versionA: UUID, to versionB: UUID) -> [String] {
        guard let modelA = try? load(version: versionA), let modelB = try? load(version: versionB) else { return [] }
        var changes: [String] = []
        if modelA.layers.count != modelB.layers.count {
            changes.append("Layer count changed from \(modelA.layers.count) to \(modelB.layers.count)")
        }
        for (id, layerA) in modelA.layers {
            if let layerB = modelB.layers[id] {
                if type(of: layerA) != type(of: layerB) {
                    changes.append("Layer \(id) type changed")
                }
            } else {
                changes.append("Layer \(id) removed")
            }
        }
        return changes
    }

    private func loadVersions() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "json" {
            let data = try? Data(contentsOf: file)
            if let checkpoint = try? JSONDecoder().decode(ModelCheckpoint.self, from: data) {
                let version = ModelVersion(modelID: UUID(), version: file.deletingPathExtension().lastPathComponent, fileURL: file)
                versions[version.id] = version
            }
        }
        modelCount = versions.count
    }
}

// MARK: - Checkpoint Manager

public struct CheckpointManager {
    public static func saveCheckpoint(model: NeuralNetworkCore, optimizer: any Optimizer, epoch: Int, loss: Float, to directory: URL, name: String = "checkpoint") throws {
        let filename = "\(name)_epoch_\(epoch).json"
        let url = directory.appendingPathComponent(filename)
        let checkpoint = ModelCheckpoint(
            version: "1.0.0",
            timestamp: Date(),
            layers: [:],
            metadata: ["epoch": String(epoch), "loss": String(loss)],
            trainingState: model.trainingState,
            optimizerState: optimizer.saveState(),
            lossHistory: model.lossHistory,
            epoch: epoch
        )
        let data = try JSONEncoder().encode(checkpoint)
        try data.write(to: url)
    }

    public static func loadCheckpoint(from url: URL) throws -> ModelCheckpoint {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ModelCheckpoint.self, from: data)
    }
}
