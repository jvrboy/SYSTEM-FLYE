import Foundation
import Accelerate
import Combine

// MARK: - Memory Entry Types

public struct MemoryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var key: String
    public var value: Data
    public var embedding: [Float]?
    public var tags: [String]
    public var timestamp: Date
    public var accessCount: Int
    public var lastAccessed: Date
    public var decayFactor: Double
    public var importance: Double
    public var memoryType: MemoryType
    public var associations: [UUID]
    public var context: [String: String]
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        key: String,
        value: Data,
        embedding: [Float]? = nil,
        tags: [String] = [],
        timestamp: Date = Date(),
        accessCount: Int = 0,
        lastAccessed: Date = Date(),
        decayFactor: Double = 0.95,
        importance: Double = 1,
        memoryType: MemoryType = .episodic,
        associations: [UUID] = [],
        context: [String: String] = [:],
        confidence: Double = 1
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.embedding = embedding
        self.tags = tags
        self.timestamp = timestamp
        self.accessCount = accessCount
        self.lastAccessed = lastAccessed
        self.decayFactor = decayFactor
        self.importance = importance
        self.memoryType = memoryType
        self.associations = associations
        self.context = context
        self.confidence = confidence
    }
}

public enum MemoryType: String, Codable, Sendable, CaseIterable {
    case sensory = "SENSORY"
    case working = "WORKING"
    case shortTerm = "SHORT_TERM"
    case longTerm = "LONG_TERM"
    case episodic = "EPISODIC"
    case semantic = "SEMANTIC"
    case procedural = "PROCEDURAL"
    case emotional = "EMOTIONAL"
}

public struct MemoryFragment: Sendable {
    public let key: String
    public var content: Data
    public var relevanceScore: Double
    public var recencyScore: Double
    public var confidence: Double

    public init(key: String, content: Data, relevanceScore: Double, recencyScore: Double, confidence: Double) {
        self.key = key
        self.content = content
        self.relevanceScore = relevanceScore
        self.recencyScore = recencyScore
        self.confidence = confidence
    }
}

public struct MemoryCluster: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var centroid: [Float]
    public var members: [UUID]
    public var label: String?
    public var createdAt: Date
    public var lastModified: Date

    public init(id: UUID = UUID(), centroid: [Float], members: [UUID], label: String? = nil) {
        self.id = id
        self.centroid = centroid
        self.members = members
        self.label = label
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

public struct MemoryTrace: Sendable {
    public let entryID: UUID
    public let agentID: UUID
    public let action: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(entryID: UUID, agentID: UUID, action: String, metadata: [String: String] = [:]) {
        self.entryID = entryID
        self.agentID = agentID
        self.action = action
        self.timestamp = Date()
        self.metadata = metadata
    }
}

public struct MemoryStatistics: Sendable {
    public var totalEntries: Int
    public var shortTermCount: Int
    public var longTermCount: Int
    public var averageAccessCount: Double
    public var averageDecay: Double
    public var clusterCount: Int
    public var associativeLinks: Int
    public var hitRate: Double
    public var missRate: Double

    public init(
        totalEntries: Int = 0,
        shortTermCount: Int = 0,
        longTermCount: Int = 0,
        averageAccessCount: Double = 0,
        averageDecay: Double = 0,
        clusterCount: Int = 0,
        associativeLinks: Int = 0,
        hitRate: Double = 0,
        missRate: Double = 0
    ) {
        self.totalEntries = totalEntries
        self.shortTermCount = shortTermCount
        self.longTermCount = longTermCount
        self.averageAccessCount = averageAccessCount
        self.averageDecay = averageDecay
        self.clusterCount = clusterCount
        self.associativeLinks = associativeLinks
        self.hitRate = hitRate
        self.missRate = missRate
    }
}

// MARK: - Memory Configuration

public struct MemoryConfiguration: Codable, Sendable {
    public let shortTermCapacity: Int
    public let longTermCapacity: Int
    public let consolidationInterval: TimeInterval
    public let decayInterval: TimeInterval
    public let minImportanceThreshold: Double
    public let maxAssociationsPerEntry: Int
    public let embeddingDimension: Int
    public let clusterSimilarityThreshold: Double
    public let consolidationTriggerCount: Int

    public init(
        shortTermCapacity: Int = 1024,
        longTermCapacity: Int = 10000,
        consolidationInterval: TimeInterval = 60,
        decayInterval: TimeInterval = 300,
        minImportanceThreshold: Double = 0.1,
        maxAssociationsPerEntry: Int = 50,
        embeddingDimension: Int = 128,
        clusterSimilarityThreshold: Double = 0.85,
        consolidationTriggerCount: Int = 100
    ) {
        self.shortTermCapacity = shortTermCapacity
        self.longTermCapacity = longTermCapacity
        self.consolidationInterval = consolidationInterval
        self.decayInterval = decayInterval
        self.minImportanceThreshold = minImportanceThreshold
        self.maxAssociationsPerEntry = maxAssociationsPerEntry
        self.embeddingDimension = embeddingDimension
        self.clusterSimilarityThreshold = clusterSimilarityThreshold
        self.consolidationTriggerCount = consolidationTriggerCount
    }
}

// MARK: - Agent Memory Bank

@MainActor
public final class AgentMemoryBank: ObservableObject {
    public static let shared = AgentMemoryBank()

    @Published public private(set) var shortTermMemory: [UUID: MemoryEntry] = [:]
    @Published public private(set) var longTermMemory: [UUID: MemoryEntry] = [:]
    @Published public private(set) var memoryClusters: [UUID: MemoryCluster] = [:]
    @Published public private(set) var accessLog: [MemoryTrace] = []
    @Published public private(set) var statistics: MemoryStatistics
    @Published public private(set) var isProcessing: Bool = false

    public private(set) var workingMemoryBuffer: [UUID: MemoryEntry] = [:]
    public private(set) var associativeIndex: [String: [UUID]] = [:]
    public private(set) var embeddingStore: [UUID: [Float]] = [:]
    public private(set) var consolidationQueue: [UUID] = []
    public private(set) var decayQueue: [UUID] = []

    public private let config: MemoryConfiguration
    public private let lock = NSLock()
    public private var consolidationTask: Task<Void, Never>?
    public private var decayTask: Task<Void, Never>?
    public private var hitCount: Int = 0
    public private var missCount: Int = 0

    public init(config: MemoryConfiguration = .init()) {
        self.config = config
        self.statistics = MemoryStatistics()
        super.init()
        startBackgroundTasks()
    }

    deinit {
        consolidationTask?.cancel()
        decayTask?.cancel()
    }
}

// MARK: - Memory Operations

extension AgentMemoryBank {
    public func store(
        key: String,
        value: Data,
        memoryType: MemoryType = .episodic,
        tags: [String] = [],
        importance: Double = 1,
        context: [String: String] = [:]
    ) -> UUID {
        lock.lock()
        defer { lock.unlock() }

        let entry = MemoryEntry(
            key: key,
            value: value,
            tags: tags,
            importance: importance,
            memoryType: memoryType,
            context: context
        )

        let targetMemory: [UUID: MemoryEntry]
        if [.sensory, .working, .shortTerm].contains(memoryType) {
            targetMemory = shortTermMemory
        } else {
            targetMemory = longTermMemory
        }

        if targetMemory.count >= config.shortTermCapacity && memoryType != .longTerm {
            evictLeastImportant(from: &shortTermMemory)
        }

        if memoryType == .longTerm && targetMemory.count >= config.longTermCapacity {
            evictOldest(from: &longTermMemory)
        }

        switch memoryType {
        case .working:
            workingMemoryBuffer[entry.id] = entry
        case .shortTerm:
            shortTermMemory[entry.id] = entry
        case .longTerm, .episodic, .semantic, .procedural, .emotional:
            longTermMemory[entry.id] = entry
        default:
            break
        }

        for tag in tags {
            associativeIndex[tag, default: []].append(entry.id)
        }

        updateStatistics()
        return entry.id
    }

    public func retrieve(_ key: String) -> MemoryEntry? {
        lock.lock()
        defer { lock.unlock() }
        let entry = shortTermMemory.values.first { $0.key == key } ??
                   longTermMemory.values.first { $0.key == key } ??
                   workingMemoryBuffer.values.first { $0.key == key }

        if let found = entry {
            hitCount += 1
            var mutableEntry = found
            mutableEntry.accessCount += 1
            mutableEntry.lastAccessed = Date()
            let target: inout [UUID: MemoryEntry]
            if workingMemoryBuffer[found.id] != nil {
                target = &workingMemoryBuffer
            } else if shortTermMemory[found.id] != nil {
                target = &shortTermMemory
            } else {
                target = &longTermMemory
            }
            target[found.id] = mutableEntry
            accessLog.append(MemoryTrace(entryID: found.id, agentID: UUID(), action: "RETRIEVE"))
        } else {
            missCount += 1
        }
        updateStatistics()
        return entry
    }

    public func retrieveByTags(_ tags: [String], limit: Int = 10) -> [MemoryFragment] {
        lock.lock()
        defer { lock.unlock() }
        var candidateIDs: Set<UUID> = []
        for tag in tags {
            candidateIDs.formUnion(associativeIndex[tag] ?? [])
        }

        let candidates = Array(candidateIDs).compactMap { id in
            shortTermMemory[id] ?? longTermMemory[id] ?? workingMemoryBuffer[id]
        }

        let sorted = candidates.sorted { a, b in
            let scoreA = calculateRelevanceScore(a)
            let scoreB = calculateRelevanceScore(b)
            return scoreA > scoreB
        }

        return sorted.prefix(limit).map { entry in
            MemoryFragment(
                key: entry.key,
                content: entry.value,
                relevanceScore: calculateRelevanceScore(entry),
                recencyScore: calculateRecencyScore(entry),
                confidence: entry.confidence
            )
        }
    }

    public func retrieveByEmbedding(_ queryEmbedding: [Float], limit: Int = 10) -> [MemoryFragment] {
        lock.lock()
        defer { lock.unlock() }
        var scored: [(entry: MemoryEntry, score: Double)] = []

        let allEntries = shortTermMemory.values + longTermMemory.values + workingMemoryBuffer.values
        for entry in allEntries {
            guard let embedding = entry.embedding else { continue }
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            let recency = calculateRecencyScore(entry)
            let importance = entry.importance
            let combinedScore = similarity * 0.5 + recency * 0.3 + importance * 0.2
            scored.append((entry, combinedScore))
        }

        return scored.sorted { $0.score > $1.score }.prefix(limit).map { pair in
            MemoryFragment(
                key: pair.entry.key,
                content: pair.entry.value,
                relevanceScore: pair.score,
                recencyScore: calculateRecencyScore(pair.entry),
                confidence: pair.entry.confidence
            )
        }
    }

    public func forget(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        shortTermMemory.removeValue(forKey: id)
        longTermMemory.removeValue(forKey: id)
        workingMemoryBuffer.removeValue(forKey: id)
        associativeIndex = associativeIndex.mapValues { $0.filter { $0 != id } }
        embeddingStore.removeValue(forKey: id)
        memoryClusters.values.forEach { cluster in
            cluster.members.removeAll { $0 == id }
        }
    }

    public func consolidate() {
        lock.lock()
        defer { lock.unlock() }
        let candidates = shortTermMemory.values.filter { $0.importance > config.minImportanceThreshold }
        for entry in candidates {
            var mutableEntry = entry
            mutableEntry.memoryType = .longTerm
            longTermMemory[entry.id] = mutableEntry
            shortTermMemory.removeValue(forKey: entry.id)
        }
        buildClusters()
        updateStatistics()
    }

    public func clearWorkingMemory() {
        lock.lock()
        defer { lock.unlock() }
        workingMemoryBuffer.removeAll()
    }
}

// MARK: - Associative Recall

extension AgentMemoryBank {
    public func associate(_ idA: UUID, with idB: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if var entry = shortTermMemory[idA] {
            if !entry.associations.contains(idB) && entry.associations.count < config.maxAssociationsPerEntry {
                entry.associations.append(idB)
                shortTermMemory[idA] = entry
            }
        }
        if var entry = longTermMemory[idA] {
            if !entry.associations.contains(idB) && entry.associations.count < config.maxAssociationsPerEntry {
                entry.associations.append(idB)
                longTermMemory[idA] = entry
            }
        }
    }

    public func recallAssociations(of id: UUID, depth: Int = 2) -> [MemoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = shortTermMemory[id] ?? longTermMemory[id] ?? workingMemoryBuffer[id] else {
            return []
        }
        var result: [MemoryEntry] = [entry]
        var currentIDs: [UUID] = entry.associations
        var visited: Set<UUID> = [id]

        for _ in 0..<depth {
            var nextIDs: [UUID] = []
            for currentID in currentIDs {
                guard !visited.contains(currentID) else { continue }
                visited.insert(currentID)
                if let found = shortTermMemory[currentID] ?? longTermMemory[currentID] ?? workingMemoryBuffer[currentID] {
                    result.append(found)
                    nextIDs.append(contentsOf: found.associations)
                }
            }
            currentIDs = nextIDs
        }
        return result
    }

    public func buildClusters() {
        lock.lock()
        defer { lock.unlock() }
        let allEntries = longTermMemory.values.filter { $0.embedding != nil }
        guard allEntries.count > 1 else { return }

        memoryClusters.removeAll()
        var unclustered = Set(allEntries.map(\.id))
        var clusters: [MemoryCluster] = []

        while let firstID = unclustered.first, let firstEntry = allEntries.first(where: { $0.id == firstID }) {
            var clusterMembers: [UUID] = [firstID]
            var centroid = firstEntry.embedding ?? Array(repeating: 0, count: config.embeddingDimension)

            for entry in allEntries where entry.id != firstID && unclustered.contains(entry.id) {
                guard let embedding = entry.embedding else { continue }
                let similarity = cosineSimilarity(centroid, embedding)
                if similarity > config.clusterSimilarityThreshold {
                    clusterMembers.append(entry.id)
                    unclustered.remove(entry.id)
                    for i in 0..<centroid.count {
                        centroid[i] = (centroid[i] + embedding[i]) / 2
                    }
                }
            }

            unclustered.remove(firstID)
            clusters.append(MemoryCluster(centroid: centroid, members: clusterMembers))
        }

        for cluster in clusters {
            memoryClusters[cluster.id] = cluster
        }
    }

    public func getCluster(for id: UUID) -> MemoryCluster? {
        lock.lock()
        defer { lock.unlock() }
        return memoryClusters.values.first { $0.members.contains(id) }
    }
}

// MARK: - Decay and Forgetting

extension AgentMemoryBank {
    public func applyDecay() {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()

        for (id, var entry) in shortTermMemory {
            let age = now.timeIntervalSince(entry.timestamp)
            let accessRecency = now.timeIntervalSince(entry.lastAccessed)
            let decay = pow(entry.decayFactor, age / config.decayInterval)
            entry.importance *= decay
            entry.confidence *= decay
            if entry.importance < config.minImportanceThreshold {
                shortTermMemory.removeValue(forKey: id)
            } else {
                shortTermMemory[id] = entry
            }
        }

        for (id, var entry) in longTermMemory {
            let age = now.timeIntervalSince(entry.timestamp)
            let decay = pow(entry.decayFactor * 0.99, age / (config.decayInterval * 10))
            entry.importance *= decay
            entry.confidence *= decay
            if entry.importance < config.minImportanceThreshold * 0.5 {
                longTermMemory.removeValue(forKey: id)
            } else {
                longTermMemory[id] = entry
            }
        }
    }

    public func forgetUnused(maxAge: TimeInterval = 86400) {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-maxAge)
        shortTermMemory = shortTermMemory.filter { $0.value.lastAccessed > cutoff }
        longTermMemory = longTermMemory.filter { $0.value.lastAccessed > cutoff }
        workingMemoryBuffer = workingMemoryBuffer.filter { $0.value.lastAccessed > cutoff }
        updateStatistics()
    }

    public func reinforce(_ id: UUID, factor: Double = 1.2) {
        lock.lock()
        defer { lock.unlock() }
        if var entry = shortTermMemory[id] {
            entry.importance = min(2, entry.importance * factor)
            entry.decayFactor = min(0.99, entry.decayFactor * 1.01)
            entry.lastAccessed = Date()
            entry.accessCount += 1
            shortTermMemory[id] = entry
        }
        if var entry = longTermMemory[id] {
            entry.importance = min(2, entry.importance * factor)
            entry.lastAccessed = Date()
            entry.accessCount += 1
            longTermMemory[id] = entry
        }
    }
}

// MARK: - Query and Search

extension AgentMemoryBank {
    public func query(_ query: String, limit: Int = 10) -> [MemoryFragment] {
        lock.lock()
        defer { lock.unlock() }
        let allEntries = shortTermMemory.values + longTermMemory.values + workingMemoryBuffer.values
        let queryLower = query.lowercased()

        let scored = allEntries.map { entry -> (MemoryEntry, Double) in
            let keyMatch = entry.key.lowercased().contains(queryLower) ? 1 : 0
            let tagMatch = Double(entry.tags.filter { $0.lowercased().contains(queryLower) }.count) / Double(max(entry.tags.count, 1))
            let contextMatch = Double(entry.context.values.filter { $0.lowercased().contains(queryLower) }.count) / Double(max(entry.context.count, 1))
            let recency = calculateRecencyScore(entry)
            let importance = entry.importance
            let score = (keyMatch * 0.3 + tagMatch * 0.3 + contextMatch * 0.2 + recency * 0.1 + importance * 0.1)
            return (entry, score)
        }

        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { pair in
            MemoryFragment(
                key: pair.0.key,
                content: pair.0.value,
                relevanceScore: pair.1,
                recencyScore: calculateRecencyScore(pair.0),
                confidence: pair.0.confidence
            )
        }
    }

    public func getSimilarEntries(to id: UUID, limit: Int = 10) -> [MemoryFragment] {
        lock.lock()
        defer { lock.unlock() }
        guard let targetEntry = shortTermMemory[id] ?? longTermMemory[id] ?? workingMemoryBuffer[id],
              let targetEmbedding = targetEntry.embedding else {
            return []
        }

        let allEntries = shortTermMemory.values + longTermMemory.values + workingMemoryBuffer.values
        let scored = allEntries.compactMap { entry -> (MemoryEntry, Double)? in
            guard entry.id != id, let embedding = entry.embedding else { return nil }
            let similarity = cosineSimilarity(targetEmbedding, embedding)
            return (entry, similarity)
        }

        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { pair in
            MemoryFragment(
                key: pair.0.key,
                content: pair.0.value,
                relevanceScore: pair.1,
                recencyScore: calculateRecencyScore(pair.0),
                confidence: pair.0.confidence
            )
        }
    }

    public func contextualRecall(context: [String: String], limit: Int = 10) -> [MemoryFragment] {
        lock.lock()
        defer { lock.unlock() }
        let allEntries = shortTermMemory.values + longTermMemory.values + workingMemoryBuffer.values

        let scored = allEntries.map { entry -> (MemoryEntry, Double) in
            var matchCount = 0
            for (key, value) in context {
                if entry.context[key] == value {
                    matchCount += 1
                }
                if entry.tags.contains(value) {
                    matchCount += 1
                }
            }
            let matchScore = matchCount == 0 ? 0 : Double(matchCount) / Double(context.count + value.count)
            let recency = calculateRecencyScore(entry)
            let combined = matchScore * 0.6 + recency * 0.4
            return (entry, combined)
        }

        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { pair in
            MemoryFragment(
                key: pair.0.key,
                content: pair.0.value,
                relevanceScore: pair.1,
                recencyScore: calculateRecencyScore(pair.0),
                confidence: pair.0.confidence
            )
        }
    }
}

// MARK: - Background Processing

extension AgentMemoryBank {
    private func startBackgroundTasks() {
        consolidationTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(config.consolidationInterval))
                await MainActor.run {
                    if shortTermMemory.count > config.consolidationTriggerCount {
                        self.consolidate()
                    }
                }
            }
        }

        decayTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(config.decayInterval))
                await MainActor.run {
                    self.applyDecay()
                }
            }
        }
    }
}

// MARK: - Statistics and Helpers

extension AgentMemoryBank {
    private func updateStatistics() {
        let totalEntries = shortTermMemory.count + longTermMemory.count + workingMemoryBuffer.count
        let shortTermCount = shortTermMemory.count + workingMemoryBuffer.count
        let longTermCount = longTermMemory.count
        let avgAccess = totalEntries > 0 ?
            Double(shortTermMemory.values.map(\.accessCount).reduce(0, +) + longTermMemory.values.map(\.accessCount).reduce(0, +)) / Double(totalEntries) : 0
        let avgDecay = totalEntries > 0 ?
            (shortTermMemory.values.map(\.decayFactor).reduce(0, +) + longTermMemory.values.map(\.decayFactor).reduce(0, +)) / Double(totalEntries) : 0
        let totalAssociations = shortTermMemory.values.map(\.associations.count).reduce(0, +) +
                               longTermMemory.values.map(\.associations.count).reduce(0, +)
        let total = hitCount + missCount

        statistics = MemoryStatistics(
            totalEntries: totalEntries,
            shortTermCount: shortTermCount,
            longTermCount: longTermCount,
            averageAccessCount: avgAccess,
            averageDecay: avgDecay,
            clusterCount: memoryClusters.count,
            associativeLinks: totalAssociations,
            hitRate: total > 0 ? Double(hitCount) / Double(total) : 0,
            missRate: total > 0 ? Double(missCount) / Double(total) : 0
        )
    }

    private func evictLeastImportant(from memory: inout [UUID: MemoryEntry]) {
        guard let minEntry = memory.values.min(by: { $0.importance < $1.importance }) else { return }
        memory.removeValue(forKey: minEntry.id)
    }

    private func evictOldest(from memory: inout [UUID: MemoryEntry]) {
        guard let oldestEntry = memory.values.min(by: { $0.timestamp < $1.timestamp }) else { return }
        memory.removeValue(forKey: oldestEntry.id)
    }

    private func calculateRelevanceScore(_ entry: MemoryEntry) -> Double {
        let recency = calculateRecencyScore(entry)
        let accessBonus = min(1, Double(entry.accessCount) / 10)
        let importance = entry.importance
        return recency * 0.5 + accessBonus * 0.3 + importance * 0.2
    }

    private func calculateRecencyScore(_ entry: MemoryEntry) -> Double {
        let age = Date().timeIntervalSince(entry.lastAccessed)
        let maxAge: TimeInterval = 86400 * 7
        return max(0, 1 - age / maxAge)
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom == 0 ? 0 : Double(dotProduct / denom)
    }
}

// MARK: - Embedding Generation

extension AgentMemoryBank {
    public func generateEmbedding(for data: Data, dimension: Int = 128) -> [Float] {
        var result = [Float](repeating: 0, count: dimension)
        let count = data.count
        let step = max(1, count / dimension)

        for i in 0..<dimension {
            let start = min(i * step, count - 1)
            let end = min(start + step, count)
            let slice = data[start..<end]
            var sum: UInt64 = 0
            for byte in slice { sum += UInt64(byte) }
            let normalized = Float(sum) / Float(max(UInt64(slice.count), 1))
            result[i] = normalized / 255.0
        }

        var mean: Float = 0
        for val in result { mean += val }
        mean /= Float(result.count)
        for i in 0..<result.count {
            result[i] -= mean
        }

        return result
    }

    public func updateEmbedding(for id: UUID, embedding: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        embeddingStore[id] = embedding
        if var entry = shortTermMemory[id] {
            entry.embedding = embedding
            shortTermMemory[id] = entry
        }
        if var entry = longTermMemory[id] {
            entry.embedding = embedding
            longTermMemory[id] = entry
        }
        if var entry = workingMemoryBuffer[id] {
            entry.embedding = embedding
            workingMemoryBuffer[id] = entry
        }
    }
}

// MARK: - Utility

extension AgentMemoryBank {
    public func getEntry(_ id: UUID) -> MemoryEntry? {
        lock.lock()
        defer { lock.unlock() }
        return shortTermMemory[id] ?? longTermMemory[id] ?? workingMemoryBuffer[id]
    }

    public func contains(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return shortTermMemory.values.contains { $0.key == key } ||
               longTermMemory.values.contains { $0.key == key } ||
               workingMemoryBuffer.values.contains { $0.key == key }
    }

    public func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return shortTermMemory.count + longTermMemory.count + workingMemoryBuffer.count
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        shortTermMemory.removeAll()
        longTermMemory.removeAll()
        workingMemoryBuffer.removeAll()
        associativeIndex.removeAll()
        embeddingStore.removeAll()
        memoryClusters.removeAll()
        accessLog.removeAll()
        updateStatistics()
    }
}
