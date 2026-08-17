import Foundation
import Accelerate

// MARK: - Ensemble Models
struct BaseModel: Codable, Identifiable {
    let id = UUID()
    var name: String
    var type: ModelType
    var weights: [Double]
    var bias: Double
    var trainingScore: Double
    var validationScore: Double
    var isTrained: Bool
    var createdAt: Date
    var metadata: [String: String]

    enum ModelType: String, Codable, CaseIterable {
        case linear = "LINEAR"
        case polynomial = "POLYNOMIAL"
        case decisionTree = "DECISION_TREE"
        case randomForest = "RANDOM_FOREST"
        case gradientBoosting = "GRADIENT_BOOSTING"
        case svm = "SVM"
        case knn = "KNN"
        case naiveBayes = "NAIVE_BAYES"
        case neuralNetwork = "NEURAL_NETWORK"
        case lstm = "LSTM"
        case transformer = "TRANSFORMER"
        case xgboost = "XGBOOST"
        case lightGBM = "LIGHTGBM"
        case prophet = "PROPHET"
        case arima = "ARIMA"
        case custom = "CUSTOM"
    }

    init(name: String, type: ModelType, weights: [Double] = [], bias: Double = 0, trainingScore: Double = 0, validationScore: Double = 0, isTrained: Bool = false, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.weights = weights
        self.bias = bias
        self.trainingScore = trainingScore
        self.validationScore = validationScore
        self.isTrained = isTrained
        self.createdAt = Date()
        self.metadata = metadata
    }
}

struct StackingModel: Codable, Identifiable {
    let id = UUID()
    var baseModels: [BaseModel]
    var metaModel: BaseModel
    var crossValidationFolds: Int
    var useProbabilities: Bool
    var trainingData: [[Double]]
    var trainingTargets: [Double]
    var metaFeatures: [[Double]]
    var timestamp: Date
}

struct BlendingModel: Codable, Identifiable {
    let id = UUID()
    var baseModels: [BaseModel]
    var blendingWeights: [Double]
    var validationData: [[Double]]
    var validationTargets: [Double]
    var blendingFeatures: [[Double]]
    var timestamp: Date
}

struct VotingClassifier: Codable, Identifiable {
    let id = UUID()
    var baseModels: [BaseModel]
    var votingStrategy: VotingStrategy
    var weights: [Double]
    var classes: [String]
    var timestamp: Date

    enum VotingStrategy: String, Codable, CaseIterable {
        case hard = "HARD"
        case soft = "SOFT"
        case weighted = "WEIGHTED"
        case threshold = "THRESHOLD"
    }
}

struct EnsembleResult: Codable, Identifiable {
    let id = UUID()
    var predictions: [Double]
    var probabilities: [[Double]]
    var confidenceIntervals: [(lower: Double, upper: Double)]
    var modelContributions: [String: Double]
    var diversityMetrics: DiversityMetrics
    var overallConfidence: Double
    var timestamp: Date

    struct DiversityMetrics: Codable {
        let pairwiseDisagreement: Double
        let entropy: Double
        var kappaStatistic: Double
        let qStatistic: Double
        let correlationCoefficient: Double
        let difficulty: Double
        let generalizedDiversity: Double
    }

    init(predictions: [Double] = [], probabilities: [[Double]] = [], confidenceIntervals: [(Double, Double)] = [], modelContributions: [String: Double] = [:], diversityMetrics: DiversityMetrics = DiversityMetrics(pairwiseDisagreement: 0, entropy: 0, kappaStatistic: 0, qStatistic: 0, correlationCoefficient: 0, difficulty: 0, generalizedDiversity: 0), overallConfidence: Double = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.predictions = predictions
        self.probabilities = probabilities
        self.confidenceIntervals = confidenceIntervals
        self.modelContributions = modelContributions
        self.diversityMetrics = diversityMetrics
        self.overallConfidence = overallConfidence
        self.timestamp = timestamp
    }
}

// MARK: - Ensemble Predictor Engine
@MainActor
final class EnsemblePredictor: ObservableObject {
    static let shared = EnsemblePredictor()
    @Published private(set) var models: [BaseModel] = []
    @Published private(set) var results: [EnsembleResult] = []
    @Published private(set) var isPredicting = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func addModel(_ model: BaseModel) {
        models.append(model)
    }

    func removeModel(id: UUID) {
        models.removeAll { $0.id == id }
    }

    func trainStacking(features: [[Double]], targets: [Double], folds: Int = 5, metaModelType: BaseModel.ModelType = .linear) async -> StackingModel? {
        guard features.count == targets.count, features.count >= folds * 2, models.count >= 2 else { return nil }
        var baseModels = models
        var metaFeatures: [[Double]] = Array(repeating: Array(repeating: 0, count: baseModels.count), count: features.count)
        for (foldIndex, baseModel) in baseModels.enumerated() {
            for (sampleIndex, feature) in features.enumerated() {
                let validationFold = sampleIndex % folds
                var trainingFoldFeatures: [[Double]] = []
                var trainingFoldTargets: [Double] = []
                for (i, f) in features.enumerated() where i % folds != validationFold { trainingFoldFeatures.append(f); trainingFoldTargets.append(targets[i]) }
                var model = baseModel
                model.weights = trainLinearModel(features: trainingFoldFeatures, targets: trainingFoldTargets)
                metaFeatures[sampleIndex][foldIndex] = predictLinear(features: [feature], weights: model.weights, bias: model.bias).first ?? 0
            }
        }
        let metaModel = trainMetaModel(metaFeatures: metaFeatures, targets: targets, modelType: metaModelType)
        return StackingModel(baseModels: baseModels, metaModel: metaModel, crossValidationFolds: folds, useProbabilities: false, trainingData: features, trainingTargets: targets, metaFeatures: metaFeatures, timestamp: Date())
    }

    func trainBlending(features: [[Double]], targets: [Double], validationSplit: Double = 0.2) async -> BlendingModel? {
        guard features.count == targets.count, features.count > 10, models.count >= 2 else { return nil }
        let validationSize = Int(Double(features.count) * validationSplit)
        let trainingFeatures = Array(features.prefix(features.count - validationSize))
        let trainingTargets = Array(targets.prefix(targets.count - validationSize))
        let validationFeatures = Array(features.suffix(validationSize))
        let validationTargets = Array(targets.suffix(validationSize))
        var baseModels = models
        var blendingFeatures: [[Double]] = Array(repeating: Array(repeating: 0, count: baseModels.count), count: validationFeatures.count)
        for (foldIndex, baseModel) in baseModels.enumerated() {
            var model = baseModel
            model.weights = trainLinearModel(features: trainingFeatures, targets: trainingTargets)
            for (sampleIndex, feature) in validationFeatures.enumerated() {
                blendingFeatures[sampleIndex][foldIndex] = predictLinear(features: [feature], weights: model.weights, bias: model.bias).first ?? 0
            }
        }
        var blendingWeights = trainLinearModel(features: blendingFeatures, targets: validationTargets)
        if blendingWeights.count < baseModels.count { blendingWeights.append(contentsOf: Array(repeating: 1.0 / Double(baseModels.count), count: baseModels.count - blendingWeights.count)) }
        return BlendingModel(baseModels: baseModels, blendingWeights: blendingWeights, validationData: validationFeatures, validationTargets: validationTargets, blendingFeatures: blendingFeatures, timestamp: Date())
    }

    func createVotingClassifier(strategy: VotingClassifier.VotingStrategy = .soft, weights: [Double] = []) async -> VotingClassifier {
        let normalizedWeights = weights.isEmpty ? Array(repeating: 1.0 / Double(max(1, models.count)), count: models.count) : weights
        let classes = ["buy", "sell", "neutral"]
        return VotingClassifier(baseModels: models, votingStrategy: strategy, weights: normalizedWeights, classes: classes, timestamp: Date())
    }

    func predict(features: [[Double]], stackingModel: StackingModel? = nil, blendingModel: BlendingModel? = nil, votingClassifier: VotingClassifier? = nil) async -> EnsembleResult {
        guard !isPredicting else { return EnsembleResult() }
        isPredicting = true
        defer { isPredicting = false }
        var predictions: [Double] = []
        var probabilities: [[Double]] = []
        var confidenceIntervals: [(Double, Double)] = []
        var modelContributions: [String: Double] = [:]
        if let stackingModel = stackingModel {
            for feature in features {
                var metaInput: [Double] = []
                for baseModel in stackingModel.baseModels {
                    let pred = predictLinear(features: [feature], weights: baseModel.weights, bias: baseModel.bias).first ?? 0
                    metaInput.append(pred)
                }
                let prediction = predictLinear(features: [metaInput], weights: stackingModel.metaModel.weights, bias: stackingModel.metaModel.bias).first ?? 0
                predictions.append(prediction)
                let std = metaInput.reduce(0, +) / Double(max(1, metaInput.count))
                confidenceIntervals.append((prediction - 1.96 * std, prediction + 1.96 * std))
            }
        } else if let blendingModel = blendingModel {
            for feature in features {
                var blendInput: [Double] = []
                for baseModel in blendingModel.baseModels {
                    let pred = predictLinear(features: [feature], weights: baseModel.weights, bias: baseModel.bias).first ?? 0
                    blendInput.append(pred)
                }
                let prediction = zip(blendInput, blendingModel.blendingWeights).map { $0 * $1 }.reduce(0, +)
                predictions.append(prediction)
                confidenceIntervals.append((prediction * 0.9, prediction * 1.1))
            }
        } else if let votingClassifier = votingClassifier {
            for feature in features {
                var votes: [String: Double] = [:]
                var classProbabilities: [String: Double] = [:]
                for (index, baseModel) in votingClassifier.baseModels.enumerated() {
                    let pred = predictLinear(features: [feature], weights: baseModel.weights, bias: baseModel.bias).first ?? 0
                    let weight = votingClassifier.weights.indices.contains(index) ? votingClassifier.weights[index] : 1.0
                    let className = pred > 0.1 ? "buy" : pred < -0.1 ? "sell" : "neutral"
                    votes[className, default: 0] += weight
                    classProbabilities[className, default: 0] += weight * (abs(pred) > 0.1 ? 0.8 : 0.5)
                }
                let totalWeight = votes.values.reduce(0, +)
                let bestClass = votes.max { $0.value < $1.value }?.key ?? "neutral"
                let prediction = bestClass == "buy" ? 1 : bestClass == "sell" ? -1 : 0
                predictions.append(prediction)
                probabilities.append(votingClassifier.classes.map { classProbabilities[$0] ?? 0 })
                confidenceIntervals.append((-1, 1))
                for (className, vote) in votes { modelContributions[className] = vote / max(totalWeight, 0.0001) }
            }
        } else {
            for feature in features {
                var ensemblePred = 0.0
                var modelProbs: [Double] = []
                for baseModel in models {
                    let pred = predictLinear(features: [feature], weights: baseModel.weights, bias: baseModel.bias).first ?? 0
                    ensemblePred += pred / Double(max(1, models.count))
                    modelProbs.append(pred)
                    modelContributions[baseModel.name] = (modelContributions[baseModel.name] ?? 0) + abs(pred)
                }
                predictions.append(ensemblePred)
                probabilities.append(modelProbs)
                let std = modelProbs.reduce(0, +) / Double(max(1, modelProbs.count))
                confidenceIntervals.append((ensemblePred - 1.96 * std, ensemblePred + 1.96 * std))
            }
        }
        let pairwiseDisagreement = calculatePairwiseDisagreement(predictions: predictions)
        let diversityMetrics = EnsembleResult.DiversityMetrics(pairwiseDisagreement: pairwiseDisagreement, entropy: calculateEntropy(predictions: predictions), kappaStatistic: 0, qStatistic: 0, correlationCoefficient: 0, difficulty: 0, generalizedDiversity: pairwiseDisagreement)
        let overallConfidence = predictions.map { abs($0) }.reduce(0, +) / Double(max(1, predictions.count))
        let result = EnsembleResult(predictions: predictions, probabilities: probabilities, confidenceIntervals: confidenceIntervals, modelContributions: modelContributions, diversityMetrics: diversityMetrics, overallConfidence: overallConfidence)
        if self.results.count >= maxResults { self.results.removeFirst() }
        self.results.append(result)
        return result
    }

    func calculateDiversityMetrics(predictions: [[Double]]) -> EnsembleResult.DiversityMetrics {
        let pairwiseDisagreement = calculatePairwiseDisagreement(predictions: predictions.flatMap { $0 })
        return EnsembleResult.DiversityMetrics(pairwiseDisagreement: pairwiseDisagreement, entropy: calculateEntropy(predictions: predictions.flatMap { $0 }), kappaStatistic: 0, qStatistic: 0, correlationCoefficient: 0, difficulty: 0, generalizedDiversity: pairwiseDisagreement)
    }

    private func trainLinearModel(features: [[Double]], targets: [Double]) -> [Double] {
        let n = features.count
        let d = features.first?.count ?? 0
        guard n > d, d > 0 else { return Array(repeating: 0, count: d) }
        let learningRate = 0.01
        let iterations = 1000
        var weights = Array(repeating: 0.0, count: d)
        var bias = 0.0
        for _ in 0..<iterations {
            for (feature, target) in zip(features, targets) {
                let prediction = zip(feature, weights).map { $0 * $1 }.reduce(0, +) + bias
                let error = target - prediction
                for j in 0..<d { weights[j] += learningRate * error * feature[j] }
                bias += learningRate * error
            }
        }
        return weights
    }

    private func predictLinear(features: [[Double]], weights: [Double], bias: Double) -> [Double] {
        return features.map { zip($0, weights).map { $0 * $1 }.reduce(0, +) + bias }
    }

    private func trainMetaModel(metaFeatures: [[Double]], targets: [Double], modelType: BaseModel.ModelType) -> BaseModel {
        let weights = trainLinearModel(features: metaFeatures, targets: targets)
        return BaseModel(name: "MetaModel", type: modelType, weights: weights, bias: 0)
    }

    private func calculatePairwiseDisagreement(predictions: [Double]) -> Double {
        let threshold = 0.1
        let binaryPredictions = predictions.map { $0 > threshold ? 1 : 0 }
        let totalPairs = binaryPredictions.count * (binaryPredictions.count - 1) / 2
        guard totalPairs > 0 else { return 0 }
        var disagreements = 0
        for i in 0..<binaryPredictions.count {
            for j in i + 1..<binaryPredictions.count {
                if binaryPredictions[i] != binaryPredictions[j] { disagreements += 1 }
            }
        }
        return Double(disagreements) / Double(totalPairs)
    }

    private func calculateEntropy(predictions: [Double]) -> Double {
        let threshold = 0.1
        let binaryPredictions = predictions.map { $0 > threshold ? 1 : 0 }
        let total = Double(binaryPredictions.count)
        let ones = Double(binaryPredictions.filter { $0 == 1 }.count)
        let zeros = total - ones
        let p1 = ones / total
        let p0 = zeros / total
        return -p1 * log2(max(p1, 1e-10)) - p0 * log2(max(p0, 1e-10))
    }
}
