import Foundation
import Accelerate

// MARK: - Pattern Matching Models
enum PatternCategory: String, Codable, CaseIterable {
    case shape = "SHAPE"
    case event = "EVENT"
    case behavior = "BEHAVIOR"
    case marketStructure = "MARKET_STRUCTURE"
    case indicatorSignal = "INDICATOR_SIGNAL"
    case candlestick = "CANDLESTICK"
    case harmonic = "HARMONIC"
    case elliottWave = "ELLIOTT_WAVE"
}

struct PatternTemplate: Codable, Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var data: [Double]
    var length: Int
    var category: PatternCategory
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var normalizedData: [Double] {
        let mean = data.reduce(0, +) / Double(max(1, data.count))
        let std = sqrt(data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, data.count)))
        return std > 0 ? data.map { ($0 - mean) / std } : data
    }
    var statisticalProperties: StatisticalProperties {
        let mean = data.reduce(0, +) / Double(max(1, data.count))
        let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, data.count))
        let skewness = data.map { pow($0 - mean, 3) }.reduce(0, +) / Double(max(1, data.count)) / pow(variance, 1.5)
        let kurtosis = data.map { pow($0 - mean, 4) }.reduce(0, +) / Double(max(1, data.count)) / pow(variance, 2) - 3
        return StatisticalProperties(mean: mean, variance: variance, stdDev: sqrt(max(0, variance)), skewness: skewness, kurtosis: kurtosis, min: data.min() ?? 0, max: data.max() ?? 0)
    }

    struct StatisticalProperties: Codable {
        let mean: Double
        let variance: Double
        let stdDev: Double
        let skewness: Double
        let kurtosis: Double
        let min: Double
        let max: Double
    }

    init(id: UUID = UUID(), name: String, description: String, data: [Double], length: Int, category: PatternCategory = .shape, tags: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.data = data
        self.length = max(1, length)
        self.category = category
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct MatchResult: Codable, Identifiable {
    let id = UUID()
    var templateId: UUID
    var templateName: String
    var matchScore: Double
    var startIndex: Int
    var endIndex: Int
    var matchedData: [Double]
    var alignment: Alignment
    var confidence: Double
    var distance: Double
    var warpPath: [Int]
    var similarityMetrics: SimilarityMetrics
    var timestamp: Date

    struct Alignment: Codable {
        var type: AlignmentType
        var offset: Int
        var scale: Double
        var rotation: Double
        var shear: Double

        enum AlignmentType: String, Codable { case none = "NONE", translation = "TRANSLATION", scale = "SCALE", affine = "AFFINE", elastic = "ELASTIC", dynamicTimeWarping = "DTW" }
    }

    struct SimilarityMetrics: Codable {
        let euclideanDistance: Double
        let cosineSimilarity: Double
        let correlationCoefficient: Double
        let dynamicTimeWarpingDistance: Double
        let longestCommonSubsequence: Int
        let editDistance: Int
        let frechetDistance: Double
        let shapeBasedDistance: Double
    }

    init(templateId: UUID, templateName: String, matchScore: Double, startIndex: Int, endIndex: Int, matchedData: [Double] = [], alignment: Alignment = Alignment(type: .none, offset: 0, scale: 1.0, rotation: 0, shear: 0), confidence: Double = 0, distance: Double = 0, warpPath: [Int] = [], similarityMetrics: SimilarityMetrics = SimilarityMetrics(euclideanDistance: 0, cosineSimilarity: 0, correlationCoefficient: 0, dynamicTimeWarpingDistance: 0, longestCommonSubsequence: 0, editDistance: 0, frechetDistance: 0, shapeBasedDistance: 0), timestamp: Date = Date()) {
        self.id = UUID()
        self.templateId = templateId
        self.templateName = templateName
        self.matchScore = max(0, min(1, matchScore))
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.matchedData = matchedData
        self.alignment = alignment
        self.confidence = max(0, min(1, confidence))
        self.distance = max(0, distance)
        self.warpPath = warpPath
        self.similarityMetrics = similarityMetrics
        self.timestamp = timestamp
    }
}

struct SearchQuery: Codable, Identifiable {
    let id = UUID()
    var queryData: [Double]
    var queryName: String
    var maxMatches: Int
    var distanceThreshold: Double
    var algorithms: [MatchingAlgorithm]
    var constraints: SearchConstraints
    var createdAt: Date

    struct SearchConstraints: Codable {
        var minLength: Int
        var maxLength: Int
        var allowedCategories: [PatternCategory]
        var requireExactLength: Bool
        var normalize: Bool
        var requireMinimumConfidence: Double
        var maxDistance: Double
        var allowPartialMatches: Bool

        static let `default` = SearchConstraints(minLength: 5, maxLength: 200, allowedCategories: [], requireExactLength: false, normalize: true, requireMinimumConfidence: 0.5, maxDistance: 1.0, allowPartialMatches: true)
    }

    init(id: UUID = UUID(), queryData: [Double], queryName: String, maxMatches: Int = 10, distanceThreshold: Double = 1.0, algorithms: [MatchingAlgorithm] = [.dtw, .euclidean], constraints: SearchConstraints = .default, createdAt: Date = Date()) {
        self.id = id
        self.queryData = queryData
        self.queryName = queryName
        self.maxMatches = max(1, maxMatches)
        self.distanceThreshold = max(0, distanceThreshold)
        self.algorithms = algorithms
        self.constraints = constraints
        self.createdAt = createdAt
    }
}

enum MatchingAlgorithm: String, Codable, CaseIterable {
    case dtw = "DTW"
    case euclidean = "EUCLIDEAN"
    case manhattan = "MANHATTAN"
    case cosine = "COSINE"
    case correlation = "CORRELATION"
    case frechet = "FRECHET"
    case softdtw = "SOFTDTW"
    case shapeBased = "SHAPE_BASED"
    case crossCorrelation = "CROSS_CORRELATION"
    case longestCommonSubsequence = "LCS"
    case editDistance = "EDIT_DISTANCE"
    case hausdorff = "HAUSDORFF"
    case laconic = "LACONIC"
}

// MARK: - Pattern Matcher Engine
@MainActor
final class PatternMatcher: ObservableObject {
    static let shared = PatternMatcher()
    @Published private(set) var templates: [PatternTemplate] = []
    @Published private(set) var searchResults: [MatchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchHistory: [SearchQuery] = []
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 200
    private let maxHistory = 100

    func search(query: SearchQuery, in data: [Double]) async -> [MatchResult] {
        guard !isSearching else { return [] }
        isSearching = true
        defer { isSearching = false }
        let startTime = Date()
        var results: [MatchResult] = []
        let queryData = query.constraints.normalize ? normalize(query.queryData) : query.queryData
        let maxWindow = min(query.queryData.count + 100, data.count)
        for windowSize in query.constraints.minLength...maxWindow {
            if query.constraints.requireExactLength && windowSize != query.queryData.count { continue }
            for start in 0...(data.count - windowSize) {
                let end = min(data.count, start + windowSize)
                let window = Array(data[start..<end])
                let normalizedWindow = query.constraints.normalize ? normalize(window) : window
                for template in templates {
                    guard query.constraints.allowedCategories.isEmpty || query.constraints.allowedCategories.contains(template.category) else { continue }
                    let match = evaluateMatch(queryData: queryData, templateData: template.normalizedData, windowData: normalizedWindow, query: query, template: template, startIndex: start, endIndex: end)
                    if match.matchScore >= (1 - query.distanceThreshold) && match.confidence >= query.constraints.requireMinimumConfidence {
                        results.append(match)
                    }
                }
            }
        }
        let sortedResults = results.sorted { $0.matchScore > $1.matchScore }.prefix(query.maxMatches)
        if sortedResults.count > maxResults {
            searchResults = Array(sortedResults.prefix(maxResults))
        } else {
            searchResults = Array(sortedResults)
        }
        if searchHistory.count >= maxHistory { searchHistory.removeFirst() }
        searchHistory.append(query)
        return Array(sortedResults)
    }

    func addTemplate(_ template: PatternTemplate) {
        templates.append(template)
    }

    func removeTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
    }

    func findSimilar(data: [Double], referenceData: [Double], algorithm: MatchingAlgorithm = .dtw) async -> MatchResult? {
        let normalizedData = normalize(data)
        let normalizedReference = normalize(referenceData)
        let distance = calculateDistance(data1: normalizedData, data2: normalizedReference, algorithm: algorithm)
        let similarity = 1.0 / (1.0 + distance)
        let metrics = MatchResult.SimilarityMetrics(euclideanDistance: euclideanDistance(normalizedData, normalizedReference), cosineSimilarity: 1.0 - cosineDistance(normalizedData, normalizedReference), correlationCoefficient: pearsonCorrelation(normalizedData, normalizedReference), dynamicTimeWarpingDistance: algorithm == .dtw ? distance : 0, longestCommonSubsequence: 0, editDistance: 0, frechetDistance: algorithm == .frechet ? distance : 0, shapeBasedDistance: algorithm == .shapeBased ? distance : 0)
        return MatchResult(templateId: UUID(), templateName: "Reference", matchScore: similarity, startIndex: 0, endIndex: data.count, matchedData: data, confidence: similarity, distance: distance, similarityMetrics: metrics)
    }

    func findSimilarInHistory(history: [PriceData], referenceData: [Double], algorithm: MatchingAlgorithm = .dtw) async -> [MatchResult] {
        guard !history.isEmpty else { return [] }
        let prices = history.map { $0.close }
        let normalizedHistory = normalize(prices)
        let normalizedReference = normalize(referenceData)
        var results: [MatchResult] = []
        for windowSize in 10..<min(100, prices.count) {
            for start in 0...(prices.count - windowSize) {
                let end = min(prices.count, start + windowSize)
                let window = Array(normalizedHistory[start..<end])
                let distance = calculateDistance(data1: normalizedReference, data2: window, algorithm: algorithm)
                let similarity = 1.0 / (1.0 + distance)
                if similarity > 0.6 {
                    let metrics = MatchResult.SimilarityMetrics(euclideanDistance: euclideanDistance(normalizedReference, window), cosineSimilarity: 1.0 - cosineDistance(normalizedReference, window), correlationCoefficient: pearsonCorrelation(normalizedReference, window), dynamicTimeWarpingDistance: algorithm == .dtw ? distance : 0, longestCommonSubsequence: 0, editDistance: 0, frechetDistance: algorithm == .frechet ? distance : 0, shapeBasedDistance: algorithm == .shapeBased ? distance : 0)
                    results.append(MatchResult(templateId: UUID(), templateName: "Historical Pattern", matchScore: similarity, startIndex: start, endIndex: end, matchedData: window, confidence: similarity, distance: distance, similarityMetrics: metrics, timestamp: history[start].timestamp))
                }
            }
        }
        return results.sorted { $0.matchScore > $1.matchScore }.prefix(20).map { $0 }
    }

    func performDTW(query: [Double], template: [Double]) -> (distance: Double, warpPath: [Int], normalizedDistance: Double) {
        let n = query.count
        let m = template.count
        var costMatrix = Array(repeating: Array(repeating: Double.infinity, count: m + 1), count: n + 1)
        costMatrix[0][0] = 0
        for i in 1...n {
            for j in 1...m {
                let cost = pow(query[i - 1] - template[j - 1], 2)
                costMatrix[i][j] = cost + min(costMatrix[i - 1][j], costMatrix[i][j - 1], costMatrix[i - 1][j - 1])
            }
        }
        var warpPath: [Int] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            warpPath.append(i - 1)
            let minPrev = min(costMatrix[i - 1][j], costMatrix[i][j - 1], costMatrix[i - 1][j - 1])
            if minPrev == costMatrix[i - 1][j - 1] { i -= 1; j -= 1 }
            else if minPrev == costMatrix[i - 1][j] { i -= 1 }
            else { j -= 1 }
        }
        let normalizedDistance = costMatrix[n][m] / Double(max(n, m))
        return (costMatrix[n][m], warpPath.reversed(), normalizedDistance)
    }

    func calculateFastDTW(query: [Double], template: [Double], radius: Int = 5) -> (distance: Double, warpPath: [Int]) {
        let n = query.count
        let m = template.count
        let windowSize = max(2 * radius + 1, abs(n - m) + 2 * radius + 1)
        var costMatrix = Array(repeating: Array(repeating: Double.infinity, count: m + 1), count: n + 1)
        costMatrix[0][0] = 0
        for i in 1...n {
            let jStart = max(1, i - radius - abs(n - m))
            let jEnd = min(m, i + radius + abs(n - m))
            for j in jStart...jEnd {
                let cost = pow(query[i - 1] - template[j - 1], 2)
                costMatrix[i][j] = cost + min(costMatrix[i - 1][j], costMatrix[i][j - 1], costMatrix[i - 1][j - 1])
            }
        }
        var warpPath: [Int] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            warpPath.append(i - 1)
            let minPrev = min(costMatrix[i - 1][j], costMatrix[i][j - 1], costMatrix[i - 1][j - 1])
            if minPrev == costMatrix[i - 1][j - 1] { i -= 1; j -= 1 }
            else if minPrev == costMatrix[i - 1][j] { i -= 1 }
            else { j -= 1 }
        }
        return (costMatrix[n][m], warpPath.reversed())
    }

    private func evaluateMatch(queryData: [Double], templateData: [Double], windowData: [Double], query: SearchQuery, template: PatternTemplate, startIndex: Int, endIndex: Int) -> MatchResult {
        var bestScore = 0.0
        var bestDistance = Double.greatestFiniteMagnitude
        var bestWarpPath: [Int] = []
        var bestConfidence = 0.0
        var similarityMetrics = MatchResult.SimilarityMetrics(euclideanDistance: 0, cosineSimilarity: 0, correlationCoefficient: 0, dynamicTimeWarpingDistance: 0, longestCommonSubsequence: 0, editDistance: 0, frechetDistance: 0, shapeBasedDistance: 0)
        for algorithm in query.algorithms {
            let distance = calculateDistance(data1: queryData, data2: windowData, algorithm: algorithm)
            let similarity = 1.0 / (1.0 + distance)
            if similarity > bestScore {
                bestScore = similarity
                bestDistance = distance
                bestConfidence = similarity * template.normalizedData.count / Double(max(1, queryData.count))
                if algorithm == .dtw {
                    let dtwResult = performDTW(query: queryData, template: windowData)
                    bestWarpPath = dtwResult.warpPath
                    bestDistance = dtwResult.distance
                    bestScore = 1.0 / (1.0 + dtwResult.distance)
                    bestConfidence = bestScore * 0.9
                }
                if algorithm == .euclidean { similarityMetrics.euclideanDistance = distance }
                if algorithm == .cosine { similarityMetrics.cosineSimilarity = 1.0 - distance }
                if algorithm == .correlation { similarityMetrics.correlationCoefficient = 1.0 - distance }
            }
        }
        let alignment = MatchResult.Alignment(type: query.algorithms.contains(.dtw) ? .dynamicTimeWarping : .none, offset: 0, scale: 1.0, rotation: 0, shear: 0)
        return MatchResult(templateId: template.id, templateName: template.name, matchScore: bestScore, startIndex: startIndex, endIndex: endIndex, matchedData: windowData, alignment: alignment, confidence: bestConfidence, distance: bestDistance, warpPath: bestWarpPath, similarityMetrics: similarityMetrics)
    }

    private func calculateDistance(data1: [Double], data2: [Double], algorithm: MatchingAlgorithm) -> Double {
        guard data1.count == data2.count, !data1.isEmpty else { return Double.greatestFiniteMagnitude }
        switch algorithm {
        case .dtw: return performDTW(query: data1, template: data2).distance
        case .euclidean: return euclideanDistance(data1, data2)
        case .manhattan: return manhattanDistance(data1, data2)
        case .cosine: return cosineDistance(data1, data2)
        case .correlation: return 1.0 - pearsonCorrelation(data1, data2)
        case .frechet: return frechetDistance(data1, data2)
        case .shapeBased: return shapeBasedDistance(data1, data2)
        case .crossCorrelation: return 1.0 - maxCrossCorrelation(data1, data2)
        default: return euclideanDistance(data1, data2)
        }
    }

    private func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        return zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +)
    }

    private func manhattanDistance(_ a: [Double], _ b: [Double]) -> Double {
        return zip(a, b).map { abs($0 - $1) }.reduce(0, +)
    }

    private func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        let dotProduct = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        let similarity = (normA > 0 && normB > 0) ? dotProduct / (normA * normB) : 0
        return 1.0 - similarity
    }

    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var num = 0.0, denX = 0.0, denY = 0.0
        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }
        let den = sqrt(max(0, denX * denY))
        return den == 0 ? 0 : num / den
    }

    private func frechetDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return Double.greatestFiniteMagnitude }
        let n = a.count
        let m = b.count
        var ca = Array(repeating: Array(repeating: -1.0, count: m), count: n)
        func rec(i: Int, j: Int) -> Double {
            if ca[i][j] > -1 { return ca[i][j] }
            var d = hypot(Double(a[i]) - Double(b[j]), 0)
            if i > 0 && j > 0 { d = max(d, rec(i: i - 1, j: j - 1)) }
            else if i > 0 { d = max(d, rec(i: i - 1, j: j)) }
            else if j > 0 { d = max(d, rec(i: i, j: j - 1)) }
            else { d = max(d, 0) }
            ca[i][j] = d
            return d
        }
        return rec(i: n - 1, j: m - 1)
    }

    private func shapeBasedDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, a.count > 2 else { return Double.greatestFiniteMagnitude }
        let slopeA = (a.last! - a.first!) / Double(a.count - 1)
        let slopeB = (b.last! - b.first!) / Double(b.count - 1)
        let slopeDiff = abs(slopeA - slopeB)
        let curvatureA = zip(a, a.dropFirst()).map { abs($1 - $0) }.reduce(0, +)
        let curvatureB = zip(b, b.dropFirst()).map { abs($1 - $0) }.reduce(0, +)
        let curvatureDiff = abs(curvatureA - curvatureB)
        return slopeDiff * 0.5 + curvatureDiff * 0.5
    }

    private func maxCrossCorrelation(_ a: [Double], _ b: [Double]) -> Double {
        var maxCorr = 0.0
        for lag in -min(a.count, b.count) + 1..<min(a.count, b.count) {
            let shiftedA = lag >= 0 ? Array(a.dropFirst(lag)) : a
            let shiftedB = lag < 0 ? Array(b.dropFirst(-lag)) : b
            let length = min(shiftedA.count, shiftedB.count)
            if length > 1 {
                let corr = pearsonCorrelation(Array(shiftedA.prefix(length)), Array(shiftedB.prefix(length)))
                maxCorr = max(maxCorr, corr)
            }
        }
        return maxCorr
    }

    private func normalize(_ data: [Double]) -> [Double] {
        guard !data.isEmpty else { return [] }
        let mean = data.reduce(0, +) / Double(data.count)
        let std = sqrt(data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count))
        return std > 0 ? data.map { ($0 - mean) / std } : data
    }
}
