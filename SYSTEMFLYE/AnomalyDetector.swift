import Foundation
import Accelerate
import CoreML

// MARK: - Anomaly Models
enum AnomalyType: String, Codable, CaseIterable {
    case point = "POINT"
    case contextual = "CONTEXTUAL"
    case collective = "COLLECTIVE"
    case trend = "TREND"
    case seasonal = "SEASONAL"
    case structural = "STRUCTURAL"
    case volatility = "VOLATILITY"
    case volume = "VOLUME"
    case correlation = "CORRELATION"
    case regime = "REGIME"
}

struct AnomalyRecord: Codable, Identifiable {
    let id = UUID()
    var timestamp: Date
    var index: Int
    var value: Double
    var expectedValue: Double
    var deviation: Double
    var zScore: Double
    var anomalyScore: Double
    var confidence: Double
    var type: AnomalyType
    var severity: Severity
    var description: String
    var features: [String: Double]
    var context: [String: String]

    enum Severity: String, Codable, CaseIterable { case low = "LOW", medium = "MEDIUM", high = "HIGH", critical = "CRITICAL" }

    init(timestamp: Date = Date(), index: Int, value: Double, expectedValue: Double, deviation: Double, zScore: Double, anomalyScore: Double, confidence: Double, type: AnomalyType = .point, severity: Severity = .medium, description: String = "", features: [String: Double] = [:], context: [String: String] = [:]) {
        self.id = UUID()
        self.timestamp = timestamp
        self.index = index
        self.value = value
        self.expectedValue = expectedValue
        self.deviation = deviation
        self.zScore = zScore
        self.anomalyScore = anomalyScore
        self.confidence = confidence
        self.type = type
        self.severity = severity
        self.description = description
        self.features = features
        self.context = context
    }
}

struct AnomalyDetectionResult: Codable, Identifiable {
    let id = UUID()
    var anomalies: [AnomalyRecord]
    var summary: Summary
    var timestamp: Date

    struct Summary: Codable {
        let totalAnomalies: Int
        let highSeverityCount: Int
        let mediumSeverityCount: Int
        let lowSeverityCount: Int
        let averageScore: Double
        let maxScore: Double
        let anomalyDensity: Double
        var severityBreakdown: [Severity: Int] { [.high: highSeverityCount, .medium: mediumSeverityCount, .low: lowSeverityCount] }

        init(totalAnomalies: Int, highSeverityCount: Int, mediumSeverityCount: Int, lowSeverityCount: Int, averageScore: Double, maxScore: Double, anomalyDensity: Double) {
            self.totalAnomalies = totalAnomalies
            self.highSeverityCount = highSeverityCount
            self.mediumSeverityCount = mediumSeverityCount
            self.lowSeverityCount = lowSeverityCount
            self.averageScore = averageScore
            self.maxScore = maxScore
            self.anomalyDensity = anomalyDensity
        }
    }

    init(anomalies: [AnomalyRecord] = [], summary: Summary = Summary(totalAnomalies: 0, highSeverityCount: 0, mediumSeverityCount: 0, lowSeverityCount: 0, averageScore: 0, maxScore: 0, anomalyDensity: 0), timestamp: Date = Date()) {
        self.id = UUID()
        self.anomalies = anomalies
        self.summary = summary
        self.timestamp = timestamp
    }
}

// MARK: - Isolation Forest Node
struct IsolationTreeNode: Codable {
    var splitFeature: Int
    var splitValue: Double
    var left: IsolationTreeNode?
    var right: IsolationTreeNode?
    var size: Int
    var depth: Int
    var isLeaf: Bool
    var prediction: Double

    init(splitFeature: Int, splitValue: Double, left: IsolationTreeNode? = nil, right: IsolationTreeNode? = nil, size: Int, depth: Int, isLeaf: Bool = false, prediction: Double = 0) {
        self.splitFeature = splitFeature
        self.splitValue = splitValue
        self.left = left
        self.right = right
        self.size = size
        self.depth = depth
        self.isLeaf = isLeaf
        self.prediction = prediction
    }
}

// MARK: - Anomaly Detector Engine
@MainActor
final class AnomalyDetector: ObservableObject {
    static let shared = AnomalyDetector()
    @Published private(set) var detectionResults: [AnomalyDetectionResult] = []
    @Published private(set) var isDetecting = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50
    private var isolationForests: [String: IsolationForest] = [:]

    func detectAnomalies(timeSeries: [Double], timestamps: [Date] = [], algorithm: DetectionAlgorithm = .zscore, threshold: Double = 3.0) async -> AnomalyDetectionResult {
        guard !isDetecting else { return AnomalyDetectionResult() }
        isDetecting = true
        defer { isDetecting = false }
        var anomalies: [AnomalyRecord] = []
        switch algorithm {
        case .zscore: anomalies = detectWithZScore(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .iqr: anomalies = detectWithIQR(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .isolationForest: anomalies = detectWithIsolationForest(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .oneClassSVM: anomalies = detectWithOneClassSVM(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .localOutlierFactor: anomalies = detectWithLOF(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .movingAverage: anomalies = detectWithMovingAverage(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .seasonalHybridESD: anomalies = detectWithSHEsd(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        case .dbscan: anomalies = detectWithDBSCAN(timeSeries: timeSeries, timestamps: timestamps, threshold: threshold)
        }
        let highCount = anomalies.filter { $0.severity == .high || $0.severity == .critical }.count
        let mediumCount = anomalies.filter { $0.severity == .medium }.count
        let lowCount = anomalies.filter { $0.severity == .low }.count
        let avgScore = anomalies.map { $0.anomalyScore }.reduce(0, +) / Double(max(1, anomalies.count))
        let maxScore = anomalies.map { $0.anomalyScore }.max() ?? 0
        let density = timeSeries.count > 0 ? Double(anomalies.count) / Double(timeSeries.count) : 0
        let summary = AnomalyDetectionResult.Summary(totalAnomalies: anomalies.count, highSeverityCount: highCount, mediumSeverityCount: mediumCount, lowSeverityCount: lowCount, averageScore: avgScore, maxScore: maxScore, anomalyDensity: density)
        let result = AnomalyDetectionResult(anomalies: anomalies, summary: summary)
        if detectionResults.count >= maxResults { detectionResults.removeFirst() }
        detectionResults.append(result)
        return result
    }

    func detectMultivariateAnomalies(data: [[Double]], algorithm: DetectionAlgorithm = .isolationForest, threshold: Double = 3.0) async -> AnomalyDetectionResult {
        guard !data.isEmpty else { return AnomalyDetectionResult() }
        var anomalies: [AnomalyRecord] = []
        switch algorithm {
        case .isolationForest:
            let forest = IsolationForest(numTrees: 100, subsampleSize: 256, maxDepth: 10)
            forest.fit(data)
            for (index, row) in data.enumerated() {
                let score = forest.anomalyScore(row)
                let severity: AnomalyRecord.Severity = score > 0.7 ? .critical : score > 0.5 ? .high : score > 0.3 ? .medium : .low
                anomalies.append(AnomalyRecord(index: index, value: row.first ?? 0, expectedValue: 0, deviation: score, zScore: score, anomalyScore: score, confidence: 1 - score, type: .collective, severity: severity))
            }
        case .oneClassSVM:
            for (index, row) in data.enumerated() {
                let score = oneClassSVMScore(row)
                let severity: AnomalyRecord.Severity = score > 2 ? .critical : score > 1.5 ? .high : score > 1 ? .medium : .low
                anomalies.append(AnomalyRecord(index: index, value: row.first ?? 0, expectedValue: 0, deviation: score, zScore: score, anomalyScore: score, confidence: max(0, 1 - score / 3), type: .point, severity: severity))
            }
        default:
            for (index, row) in data.enumerated() {
                let mean = row.reduce(0, +) / Double(row.count)
                let variance = row.map { pow($0 - mean, 2) }.reduce(0, +) / Double(row.count)
                let zScore = variance > 0 ? (row.first ?? 0 - mean) / sqrt(variance) : 0
                let score = abs(zScore)
                let severity: AnomalyRecord.Severity = score > 3 ? .critical : score > 2 ? .high : score > 1.5 ? .medium : .low
                anomalies.append(AnomalyRecord(index: index, value: row.first ?? 0, expectedValue: mean, deviation: abs(row.first ?? 0 - mean), zScore: zScore, anomalyScore: score, confidence: min(1, score / 3), type: .point, severity: severity))
            }
        }
        return AnomalyDetectionResult(anomalies: anomalies, summary: AnomalyDetectionResult.Summary(totalAnomalies: anomalies.count, highSeverityCount: anomalies.filter { $0.severity == .high || $0.severity == .critical }.count, mediumSeverityCount: anomalies.filter { $0.severity == .medium }.count, lowSeverityCount: anomalies.filter { $0.severity == .low }.count, averageScore: anomalies.map { $0.anomalyScore }.reduce(0, +) / Double(max(1, anomalies.count)), maxScore: anomalies.map { $0.anomalyScore }.max() ?? 0, anomalyDensity: Double(anomalies.count) / Double(max(1, data.count))))
    }

    private func detectWithZScore(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        guard timeSeries.count > 2 else { return [] }
        let mean = timeSeries.reduce(0, +) / Double(timeSeries.count)
        let variance = timeSeries.map { pow($0 - mean, 2) }.reduce(0, +) / Double(timeSeries.count)
        let std = sqrt(max(0, variance))
        var anomalies: [AnomalyRecord] = []
        for (index, value) in timeSeries.enumerated() {
            let zScore = std > 0 ? abs(value - mean) / std : 0
            if zScore > threshold {
                let severity: AnomalyRecord.Severity = zScore > 4 ? .critical : zScore > 3 ? .high : zScore > 2 ? .medium : .low
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(index) ? timestamps[index] : Date(), index: index, value: value, expectedValue: mean, deviation: abs(value - mean), zScore: zScore, anomalyScore: zScore / threshold, confidence: min(1, zScore / (threshold * 2)), type: .point, severity: severity))
            }
        }
        return anomalies
    }

    private func detectWithIQR(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        guard timeSeries.count > 4 else { return [] }
        let sorted = timeSeries.sorted()
        let q1 = sorted[timeSeries.count / 4]
        let q3 = sorted[3 * timeSeries.count / 4]
        let iqr = q3 - q1
        let lowerFence = q1 - threshold * iqr
        let upperFence = q3 + threshold * iqr
        var anomalies: [AnomalyRecord] = []
        for (index, value) in timeSeries.enumerated() {
            if value < lowerFence || value > upperFence {
                let deviation = value < lowerFence ? lowerFence - value : value - upperFence
                let severity: AnomalyRecord.Severity = deviation > 2 * iqr ? .critical : deviation > iqr ? .high : .medium
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(index) ? timestamps[index] : Date(), index: index, value: value, expectedValue: (q1 + q3) / 2, deviation: deviation, zScore: deviation / max(iqr, 0.0001), anomalyScore: min(1, deviation / (iqr * 2)), confidence: min(1, deviation / (iqr * 3)), type: .point, severity: severity))
            }
        }
        return anomalies
    }

    private func detectWithIsolationForest(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        let data = timeSeries.map { [$0] }
        let forest = IsolationForest(numTrees: 50, subsampleSize: min(256, data.count), maxDepth: 8)
        forest.fit(data)
        var anomalies: [AnomalyRecord] = []
        for (index, value) in timeSeries.enumerated() {
            let score = forest.anomalyScore([value])
            if score > threshold * 0.3 {
                let severity: AnomalyRecord.Severity = score > 0.7 ? .critical : score > 0.5 ? .high : score > 0.3 ? .medium : .low
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(index) ? timestamps[index] : Date(), index: index, value: value, expectedValue: 0, deviation: score, zScore: score, anomalyScore: score, confidence: 1 - score, type: .point, severity: severity))
            }
        }
        return anomalies
    }

    private func detectWithOneClassSVM(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        var anomalies: [AnomalyRecord] = []
        let mean = timeSeries.reduce(0, +) / Double(max(1, timeSeries.count))
        let variance = timeSeries.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, timeSeries.count))
        let std = sqrt(max(0, variance))
        for (index, value) in timeSeries.enumerated() {
            let distance = std > 0 ? abs(value - mean) / std : 0
            if distance > threshold {
                let severity: AnomalyRecord.Severity = distance > 3 ? .critical : distance > 2 ? .high : distance > 1.5 ? .medium : .low
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(index) ? timestamps[index] : Date(), index: index, value: value, expectedValue: mean, deviation: distance, zScore: distance, anomalyScore: min(1, distance / 3), confidence: min(1, distance / 4), type: .point, severity: severity))
            }
        }
        return anomalies
    }

    private func detectWithLOF(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        var anomalies: [AnomalyRecord] = []
        let k = min(5, timeSeries.count - 1)
        for i in 0..<timeSeries.count {
            let distances = timeSeries.enumerated().filter { $0.offset != i }.map { abs(timeSeries[i] - $0.element) }.sorted()
            let kDist = distances.prefix(k).reduce(0, +) / Double(k)
            let reachDist = distances.prefix(k).map { max($0, kDist) }.reduce(0, +) / Double(k)
            let lrd = kDist > 0 ? 1.0 / (reachDist / Double(k)) : 0
            let avgLrd = distances.prefix(k).map { _ in lrd }.reduce(0, +) / Double(k)
            let lof = avgLrd > 0 ? lrd / avgLrd : 0
            if lof > threshold {
                let severity: AnomalyRecord.Severity = lof > 3 ? .critical : lof > 2 ? .high : lof > 1.5 ? .medium : .low
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(i) ? timestamps[i] : Date(), index: i, value: timeSeries[i], expectedValue: 0, deviation: lof, zScore: lof, anomalyScore: min(1, lof / 3), confidence: min(1, lof / 4), type: .point, severity: severity))
            }
        }
        return anomalies
    }

    private func detectWithMovingAverage(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        let windowSize = min(20, timeSeries.count / 2)
        guard windowSize > 2 else { return [] }
        var anomalies: [AnomalyRecord] = []
        for i in windowSize..<timeSeries.count {
            let window = Array(timeSeries[i - windowSize..<i])
            let mean = window.reduce(0, +) / Double(windowSize)
            let std = sqrt(window.map { pow($0 - mean, 2) }.reduce(0, +) / Double(windowSize))
            let zScore = std > 0 ? abs(timeSeries[i] - mean) / std : 0
            if zScore > threshold {
                let severity: AnomalyRecord.Severity = zScore > 3 ? .critical : zScore > 2 ? .high : zScore > 1.5 ? .medium : .low
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(i) ? timestamps[i] : Date(), index: i, value: timeSeries[i], expectedValue: mean, deviation: abs(timeSeries[i] - mean), zScore: zScore, anomalyScore: min(1, zScore / (threshold * 2)), confidence: min(1, zScore / (threshold * 3)), type: .contextual, severity: severity))
            }
        }
        return anomalies
    }

    private func detectWithSHEsd(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        var anomalies: [AnomalyRecord] = []
        let maxAnomalies = Int(Double(timeSeries.count) * 0.1)
        var remaining = timeSeries
        for _ in 0..<maxAnomalies {
            let mean = remaining.reduce(0, +) / Double(remaining.count)
            let std = sqrt(remaining.map { pow($0 - mean, 2) }.reduce(0, +) / Double(remaining.count))
            guard let (maxIndex, maxValue) = remaining.enumerated().max(by: { $0.element < $1.element }) else { break }
            let originalIndex = timeSeries.firstIndex(where: { abs($0 - maxValue) < 0.0001 }) ?? 0
            let zScore = std > 0 ? abs(maxValue - mean) / std : 0
            if zScore > threshold {
                let severity: AnomalyRecord.Severity = zScore > 3 ? .critical : zScore > 2 ? .high : zScore > 1.5 ? .medium : .low
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(originalIndex) ? timestamps[originalIndex] : Date(), index: originalIndex, value: maxValue, expectedValue: mean, deviation: abs(maxValue - mean), zScore: zScore, anomalyScore: min(1, zScore / 4), confidence: min(1, zScore / 5), type: .point, severity: severity))
                remaining.remove(at: maxIndex)
            } else { break }
        }
        return anomalies.sorted { $0.index < $1.index }
    }

    private func detectWithDBSCAN(timeSeries: [Double], timestamps: [Date], threshold: Double) -> [AnomalyRecord] {
        var anomalies: [AnomalyRecord] = []
        let eps = threshold * 0.1
        let minPts = 3
        var visited = Array(repeating: false, count: timeSeries.count)
        var cluster = Array(repeating: -1, count: timeSeries.count)
        var clusterId = 0
        for i in 0..<timeSeries.count {
            if visited[i] { continue }
            visited[i] = true
            let neighbors = (0..<timeSeries.count).filter { abs(timeSeries[$0] - timeSeries[i]) < eps }
            if neighbors.count < minPts {
                cluster[i] = -1
                let severity: AnomalyRecord.Severity = .high
                anomalies.append(AnomalyRecord(timestamp: timestamps.indices.contains(i) ? timestamps[i] : Date(), index: i, value: timeSeries[i], expectedValue: 0, deviation: abs(timeSeries[i]), zScore: 0, anomalyScore: 0.8, confidence: 0.8, type: .collective, severity: severity))
            } else {
                cluster[i] = clusterId
                expandCluster(i, neighbors: neighbors, clusterId: clusterId, cluster: &cluster, visited: &visited, eps: eps, minPts: minPts)
                clusterId += 1
            }
        }
        return anomalies
    }

    private func expandCluster(_ pointIndex: Int, neighbors: [Int], clusterId: Int, cluster: inout [Int], visited: inout [Bool], eps: Double, minPts: Int) {
        var queue = neighbors
        var i = 0
        while i < queue.count {
            let q = queue[i]
            if !visited[q] {
                visited[q] = true
                let qNeighbors = (0..<cluster.count).filter { abs($0 - q) < eps }
                if qNeighbors.count >= minPts {
                    queue.append(contentsOf: qNeighbors)
                }
            }
            if cluster[q] == -1 { cluster[q] = clusterId }
            i += 1
        }
    }

    private func oneClassSVMScore(_ sample: [Double]) -> Double {
        let mean = sample.reduce(0, +) / Double(max(1, sample.count))
        let variance = sample.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, sample.count))
        let std = sqrt(max(0, variance))
        return std
    }
}

enum DetectionAlgorithm: String, Codable, CaseIterable {
    case zscore = "ZSCORE"
    case iqr = "IQR"
    case isolationForest = "ISOLATION_FOREST"
    case oneClassSVM = "ONE_CLASS_SVM"
    case localOutlierFactor = "LOF"
    case movingAverage = "MOVING_AVERAGE"
    case seasonalHybridESD = "SHEsd"
    case dbscan = "DBSCAN"
}

// MARK: - Isolation Forest
class IsolationForest: Codable {
    let numTrees: Int
    let subsampleSize: Int
    let maxDepth: Int
    private var trees: [IsolationTreeNode] = []

    init(numTrees: Int = 100, subsampleSize: Int = 256, maxDepth: Int = 10) {
        self.numTrees = numTrees
        self.subsampleSize = subsampleSize
        self.maxDepth = maxDepth
    }

    func fit(_ data: [[Double]]) {
        trees.removeAll()
        let n = data.count
        for _ in 0..<numTrees {
            let sampleSize = min(subsampleSize, n)
            var sample = data.shuffled().prefix(sampleSize)
            let tree = buildTree(Array(sample), depth: 0)
            trees.append(tree)
        }
    }

    func anomalyScore(_ sample: [Double]) -> Double {
        guard !trees.isEmpty else { return 0 }
        var totalPathLength = 0.0
        for tree in trees {
            totalPathLength += pathLength(sample, node: tree)
        }
        let avgPathLength = totalPathLength / Double(trees.count)
        let n = Double(subsampleSize)
        let c = n > 1 ? 2.0 * (log(n - 1) + 0.5772156649) - 2.0 * (n - 1) / n : 1.0
        return pow(2, -avgPathLength / c)
    }

    private func buildTree(_ data: [[Double]], depth: Int) -> IsolationTreeNode {
        let n = data.count
        let size = max(1, n)
        if depth >= maxDepth || n <= 1 {
            return IsolationTreeNode(splitFeature: 0, splitValue: 0, size: n, depth: depth, isLeaf: true, prediction: data.map { $0.first ?? 0 }.reduce(0, +) / Double(max(1, n)))
        }
        let feature = Int.random(in: 0..<(data.first?.count ?? 1))
        let values = data.map { $0[feature] }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let splitValue = Double.random(in: minVal...maxVal)
        let leftData = data.filter { $0[feature] < splitValue }
        let rightData = data.filter { $0[feature] >= splitValue }
        let left = buildTree(leftData, depth: depth + 1)
        let right = buildTree(rightData, depth: depth + 1)
        return IsolationTreeNode(splitFeature: feature, splitValue: splitValue, left: left, right: right, size: n, depth: depth)
    }

    private func pathLength(_ sample: [Double], node: IsolationTreeNode) -> Double {
        if node.isLeaf { return node.depth + c(node.size) }
        if sample[node.splitFeature] < node.splitValue { return 1 + pathLength(sample, node: node.left!) }
        return 1 + pathLength(sample, node: node.right!)
    }

    private func c(_ size: Int) -> Double {
        let n = Double(size)
        return n > 1 ? 2.0 * (log(n - 1) + 0.5772156649) - 2.0 * (n - 1) / n : 0
    }
}

extension Array {
    func shuffled() -> [Element] {
        var array = self
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            array.swapAt(i, j)
        }
        return array
    }
}
