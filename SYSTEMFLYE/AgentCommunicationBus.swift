import Foundation
import Accelerate
import Combine

// MARK: - Message Types

public struct AgentMessage: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var senderID: UUID
    public var recipientID: UUID
    public var topic: MessageTopic
    public var payload: Data
    public var headers: [String: String]
    public var priority: MessagePriority
    public var ttl: TimeInterval
    public var timestamp: Date
    public var correlationID: UUID?
    public var replyTo: UUID?
    public var status: MessageStatus
    public var attempts: Int
    public var maxAttempts: Int
    public var encoding: MessageEncoding
    public var compression: CompressionType
    public var routingHints: [String]

    public init(
        id: UUID = UUID(),
        senderID: UUID,
        recipientID: UUID,
        topic: MessageTopic,
        payload: Data = Data(),
        headers: [String: String] = [:],
        priority: MessagePriority = .normal,
        ttl: TimeInterval = 30,
        timestamp: Date = Date(),
        correlationID: UUID? = nil,
        replyTo: UUID? = nil,
        status: MessageStatus = .pending,
        attempts: Int = 0,
        maxAttempts: Int = 3,
        encoding: MessageEncoding = .json,
        compression: CompressionType = .none,
        routingHints: [String] = []
    ) {
        self.id = id
        self.senderID = senderID
        self.recipientID = recipientID
        self.topic = topic
        self.payload = payload
        self.headers = headers
        self.priority = priority
        self.ttl = ttl
        self.timestamp = timestamp
        self.correlationID = correlationID
        self.replyTo = replyTo
        self.status = status
        self.attempts = attempts
        self.maxAttempts = maxAttempts
        self.encoding = encoding
        self.compression = compression
        self.routingHints = routingHints
    }
}

public enum MessageTopic: String, Codable, Sendable, CaseIterable {
    case taskAssignment = "TASK_ASSIGNMENT"
    case taskResult = "TASK_RESULT"
    case taskFailure = "TASK_FAILURE"
    case heartbeat = "HEARTBEAT"
    case coordination = "COORDINATION"
    case negotiation = "NEGOTIATION"
    case broadcast = "BROADCAST"
    case system = "SYSTEM"
    case memory = "MEMORY"
    case neural = "NEURAL"
    case forex = "FOREX"
    case music = "MUSIC"
    case analytics = "ANALYTICS"
    case error = "ERROR"
    case log = "LOG"
}

public enum MessagePriority: Int, Codable, Sendable, CaseIterable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: MessagePriority, rhs: MessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum MessageStatus: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case queued = "QUEUED"
    case delivered = "DELIVERED"
    case processed = "PROCESSED"
    case failed = "FAILED"
    case expired = "EXPIRED"
    case acknowledged = "ACKNOWLEDGED"
    case rejected = "REJECTED"
}

public enum MessageEncoding: String, Codable, Sendable, CaseIterable {
    case json = "JSON"
    case protobuf = "PROTOBUF"
    case msgPack = "MSGPACK"
    case binary = "BINARY"
    case flatbuffers = "FLATBUFFERS"
}

public enum CompressionType: String, Codable, Sendable, CaseIterable {
    case none = "NONE"
    case gzip = "GZIP"
    case lz4 = "LZ4"
    case zstd = "ZSTD"
    case brotli = "BROTLI"
}

public struct SubscriptionRule: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var subscriberID: UUID
    public var topics: [MessageTopic]
    public var filterExpression: String?
    public var priority: MessagePriority
    public var isActive: Bool
    public var createdAt: Date
    public var lastMessageAt: Date?
    public var messageCount: Int

    public init(
        id: UUID = UUID(),
        subscriberID: UUID,
        topics: [MessageTopic],
        filterExpression: String? = nil,
        priority: MessagePriority = .normal,
        isActive: Bool = true
    ) {
        self.id = id
        self.subscriberID = subscriberID
        self.topics = topics
        self.filterExpression = filterExpression
        self.priority = priority
        self.isActive = isActive
        self.createdAt = Date()
        self.lastMessageAt = nil
        self.messageCount = 0
    }
}

public struct MessageRoute: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var source: UUID
    public var destination: UUID
    public var intermediateHops: [UUID]
    public var estimatedLatency: TimeInterval
    public var cost: Double
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        source: UUID,
        destination: UUID,
        intermediateHops: [UUID] = [],
        estimatedLatency: TimeInterval = 0,
        cost: Double = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.intermediateHops = intermediateHops
        self.estimatedLatency = estimatedLatency
        self.cost = cost
        self.isActive = isActive
        self.createdAt = Date()
    }
}

public struct SerializedMessage: Sendable {
    public let data: Data
    public let encoding: MessageEncoding
    public let size: Int
    public let checksum: UInt32

    public init(data: Data, encoding: MessageEncoding) {
        self.data = data
        self.encoding = encoding
        self.size = data.count
        var hash: UInt32 = 0
        for byte in data { hash = hash &* 31 &+ UInt32(byte) }
        self.checksum = hash
    }
}

// MARK: - Bus Configuration

public struct BusConfiguration: Codable, Sendable {
    public let maxQueueSize: Int
    public let defaultTTL: TimeInterval
    public let retryDelay: TimeInterval
    public let maxRetries: Int
    public let batchSize: Int
    public let flushInterval: TimeInterval
    public let enablePersistence: Bool
    public let enableCompression: Bool
    public let compressionThreshold: Int
    public let maxMessageSize: Int
    public let deadLetterQueueEnabled: Bool

    public init(
        maxQueueSize: Int = 10000,
        defaultTTL: TimeInterval = 30,
        retryDelay: TimeInterval = 1,
        maxRetries: Int = 3,
        batchSize: Int = 100,
        flushInterval: TimeInterval = 1,
        enablePersistence: Bool = false,
        enableCompression: Bool = true,
        compressionThreshold: Int = 1024,
        maxMessageSize: Int = 10485760,
        deadLetterQueueEnabled: Bool = true
    ) {
        self.maxQueueSize = maxQueueSize
        self.defaultTTL = defaultTTL
        self.retryDelay = retryDelay
        self.maxRetries = maxRetries
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.enablePersistence = enablePersistence
        self.enableCompression = enableCompression
        self.compressionThreshold = compressionThreshold
        self.maxMessageSize = maxMessageSize
        self.deadLetterQueueEnabled = deadLetterQueueEnabled
    }
}

// MARK: - Communication Bus

@MainActor
public final class AgentCommunicationBus: ObservableObject {
    public static let shared = AgentCommunicationBus()

    @Published public private(set) var messageQueue: [AgentMessage] = []
    @Published public private(set) var deadLetterQueue: [AgentMessage] = []
    @Published public private(set) var subscriptions: [UUID: SubscriptionRule] = [:]
    @Published public private(set) var routes: [UUID: MessageRoute] = [:]
    @Published public private(set) var statistics: BusStatistics
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var messageLog: [AgentMessage] = []

    public private(set) var messageHandlers: [MessageTopic: [(AgentMessage) -> Void]] = [:]
    public private(set) var subscriberBuffers: [UUID: [AgentMessage]] = [:]
    public private(set) var serializationCache: [UUID: SerializedMessage] = [:]
    public private(set) var routingTable: [UUID: [UUID]] = [:]
    public private(set) var pendingAcknowledgments: [UUID: Date] = [:]

    public private let config: BusConfiguration
    public private let lock = NSLock()
    public private var processingTask: Task<Void, Never>?
    public private var flushTask: Task<Void, Never>?
    public private var totalSent: Int64 = 0
    public private var totalReceived: Int64 = 0
    public private var totalBytes: Int64 = 0
    public private var startTime: Date = Date()

    public init(config: BusConfiguration = .init()) {
        self.config = config
        self.statistics = BusStatistics()
        super.init()
    }

    deinit {
        processingTask?.cancel()
        flushTask?.cancel()
    }
}

// MARK: - Publishing

extension AgentCommunicationBus {
    public func publish(_ message: AgentMessage) -> UUID {
        lock.lock()
        defer { lock.unlock() }

        guard messageQueue.count < config.maxQueueSize else {
            if config.deadLetterQueueEnabled {
                var dlqMessage = message
                dlqMessage.status = .failed
                deadLetterQueue.append(dlqMessage)
            }
            return message.id
        }

        var mutableMessage = message
        mutableMessage.status = .queued
        messageQueue.append(mutableMessage)
        totalSent += 1
        totalBytes += Int64(message.payload.count)

        statistics.totalPublished += 1
        updateStatistics()

        return message.id
    }

    public func publishToTopic(_ topic: MessageTopic, senderID: UUID, payload: Data = Data(), headers: [String: String] = [:]) -> [UUID] {
        let matchingSubscribers = subscriptions.values.filter {
            $0.isActive && $0.topics.contains(topic)
        }

        var messageIDs: [UUID] = []
        for subscriber in matchingSubscribers {
            let message = AgentMessage(
                senderID: senderID,
                recipientID: subscriber.subscriberID,
                topic: topic,
                payload: payload,
                headers: headers,
                priority: subscriber.priority
            )
            let id = publish(message)
            messageIDs.append(id)
        }
        return messageIDs
    }

    public func broadcast(_ message: AgentMessage) -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        let subscriberIDs = Set(subscriptions.values.map(\.subscriberID))
        var messageIDs: [UUID] = []

        for subscriberID in subscriberIDs {
            var broadcastMessage = message
            broadcastMessage.recipientID = subscriberID
            broadcastMessage.id = UUID()
            let id = publish(broadcastMessage)
            messageIDs.append(id)
        }
        return messageIDs
    }

    public func reply(to messageID: UUID, senderID: UUID, payload: Data = Data()) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        guard let original = messageQueue.first(where: { $0.id == messageID }) ??
                           messageLog.first(where: { $0.id == messageID }) else { return nil }

        let reply = AgentMessage(
            senderID: senderID,
            recipientID: original.senderID,
            topic: original.topic,
            payload: payload,
            priority: original.priority,
            correlationID: original.correlationID ?? original.id,
            replyTo: messageID
        )
        return publish(reply)
    }
}

// MARK: - Subscription Management

extension AgentCommunicationBus {
    public func subscribe(agentID: UUID, topics: [MessageTopic], filterExpression: String? = nil, priority: MessagePriority = .normal) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let subscription = SubscriptionRule(
            subscriberID: agentID,
            topics: topics,
            filterExpression: filterExpression,
            priority: priority
        )
        subscriptions[subscription.id] = subscription
        subscriberBuffers[agentID] = []
        return subscription.id
    }

    public func unsubscribe(_ subscriptionID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        subscriptions.removeValue(forKey: subscriptionID)
    }

    public func unsubscribeAll(for agentID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        subscriptions = subscriptions.filter { $0.value.subscriberID != agentID }
        subscriberBuffers.removeValue(forKey: agentID)
    }

    public func getSubscriptions(for agentID: UUID) -> [SubscriptionRule] {
        lock.lock()
        defer { lock.ununch() }
        return subscriptions.values.filter { $0.subscriberID == agentID }
    }
}

// MARK: - Message Processing

extension AgentCommunicationBus {
    private func processQueue() {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        var toProcess: [AgentMessage] = []
        var toExpire: [UUID] = []

        for message in messageQueue {
            if now.timeIntervalSince(message.timestamp) > message.ttl {
                toExpire.append(message.id)
                var expired = message
                expired.status = .expired
                deadLetterQueue.append(expired)
            } else {
                toProcess.append(message)
            }
        }

        messageQueue = toProcess.sorted { $0.priority > $1.priority }

        for message in messageQueue {
            deliverMessage(message)
        }
    }

    private func deliverMessage(_ message: AgentMessage) {
        guard let handler = messageHandlers[message.topic] else { return }

        for callback in handler {
            callback(message)
        }

        if var subscriberBuffer = subscriberBuffers[message.recipientID] {
            subscriberBuffer.append(message)
            subscriberBuffers[message.recipientID] = subscriberBuffer
        }

        var processed = message
        processed.status = .delivered
        if let index = messageQueue.firstIndex(where: { $0.id == message.id }) {
            messageQueue[index] = processed
        }
        messageLog.append(processed)
        totalReceived += 1
    }
}

// MARK: - Serialization

extension AgentCommunicationBus {
    public func serialize(_ message: AgentMessage, encoding: MessageEncoding = .json) -> SerializedMessage {
        let payload: Data
        switch encoding {
        case .json:
            let encoder = JSONEncoder()
            payload = try! encoder.encode(message)
        case .binary:
            var mutableMessage = message
            mutableMessage.payload = compressIfNeeded(message.payload)
            payload = try! JSONEncoder().encode(mutableMessage)
        case .protobuf:
            payload = message.payload
        case .msgPack:
            payload = message.payload
        case .flatbuffers:
            payload = message.payload
        }
        return SerializedMessage(data: payload, encoding: encoding)
    }

    public func deserialize(_ serialized: SerializedMessage) -> AgentMessage? {
        guard let message = try? JSONDecoder().decode(AgentMessage.self, from: serialized.data) else {
            return nil
        }
        return message
    }

    public func cacheSerializedMessage(_ messageID: UUID, serialized: SerializedMessage) {
        serializationCache[messageID] = serialized
    }

    public func getCachedMessage(_ messageID: UUID) -> SerializedMessage? {
        serializationCache[messageID]
    }
}

// MARK: - Compression

extension AgentCommunicationBus {
    private func compressIfNeeded(_ data: Data) -> Data {
        guard config.enableCompression, data.count > config.compressionThreshold else { return data }
        return data
    }

    public func decompress(_ data: Data, compression: CompressionType) -> Data {
        switch compression {
        case .none: return data
        case .gzip: return data
        case .lz4: return data
        case .zstd: return data
        case .brotli: return data
        }
    }
}

// MARK: - Routing

extension AgentCommunicationBus {
    public func addRoute(_ route: MessageRoute) {
        lock.lock()
        defer { lock.unlock() }
        routes[route.id] = route
        updateRoutingTable()
    }

    public func removeRoute(_ routeID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        routes.removeValue(forKey: routeID)
        updateRoutingTable()
    }

    public func getRoute(from source: UUID, to destination: UUID) -> MessageRoute? {
        lock.lock()
        defer { lock.unlock() }
        return routes.values.first { $0.source == source && $0.destination == destination && $0.isActive }
    }

    public func findOptimalRoute(from source: UUID, to destination: UUID) -> MessageRoute? {
        lock.lock()
        defer { lock.unlock() }
        let direct = routes.values.first { $0.source == source && $0.destination == destination && $0.isActive }
        if let direct = direct { return direct }

        var visited: Set<UUID> = []
        var queue: [(UUID, [UUID], TimeInterval, Double)] = [(source, [], 0, 0)]

        while !queue.isEmpty {
            queue.sort { $0.2 < $1.2 }
            let (current, path, latency, cost) = queue.removeFirst()
            if current == destination {
                return MessageRoute(source: source, destination: destination, intermediateHops: Array(path.dropFirst()), estimatedLatency: latency, cost: cost)
            }
            if visited.contains(current) { continue }
            visited.insert(current)

            if let neighbors = routingTable[current] {
                for neighbor in neighbors {
                    if let route = routes.values.first(where: { $0.source == current && $0.destination == neighbor && $0.isActive }) {
                        queue.append((neighbor, path + [current], latency + route.estimatedLatency, cost + route.cost))
                    }
                }
            }
        }
        return nil
    }

    private func updateRoutingTable() {
        routingTable.removeAll()
        for route in routes.values where route.isActive {
            routingTable[route.source, default: []].append(route.destination)
            for hop in route.intermediateHops {
                routingTable[hop, default: []].append(route.destination)
            }
        }
    }
}

// MARK: - Handler Registration

extension AgentCommunicationBus {
    public func registerHandler(for topic: MessageTopic, handler: @escaping (AgentMessage) -> Void) {
        messageHandlers[topic, default: []].append(handler)
    }

    public func removeHandler(for topic: MessageTopic, handler: @escaping (AgentMessage) -> Void) {
        if var handlers = messageHandlers[topic] {
            handlers.removeAll { $0 as AnyObject === handler as AnyObject }
            messageHandlers[topic] = handlers.isEmpty ? nil : handlers
        }
    }

    public func removeAllHandlers(for topic: MessageTopic) {
        messageHandlers.removeValue(forKey: topic)
    }
}

// MARK: - Acknowledgment

extension AgentCommunicationBus {
    public func acknowledge(_ messageID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if let index = messageQueue.firstIndex(where: { $0.id == messageID }) {
            var message = messageQueue[index]
            message.status = .acknowledged
            messageQueue[index] = message
        }
        pendingAcknowledgments.removeValue(forKey: messageID)
    }

    public func reject(_ messageID: UUID, reason: String) {
        lock.lock()
        defer { lock.unlock() }
        if let index = messageQueue.firstIndex(where: { $0.id == messageID }) {
            var message = messageQueue[index]
            message.status = .rejected
            message.headers["rejection_reason"] = reason
            messageQueue[index] = message
            deadLetterQueue.append(message)
        }
    }
}

// MARK: - Lifecycle

extension AgentCommunicationBus {
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()
        processingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                self.processQueue()
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
        flushTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(config.flushInterval))
                await MainActor.run {
                    self.flushSubscriberBuffers()
                }
            }
        }
    }

    public func stop() {
        isRunning = false
        processingTask?.cancel()
        flushTask?.cancel()
        processingTask = nil
        flushTask = nil
    }

    private func flushSubscriberBuffers() {
        lock.lock()
        defer { lock.unlock() }
        subscriberBuffers.removeAll()
    }
}

// MARK: - Statistics

extension AgentCommunicationBus {
    private func updateStatistics() {
        let elapsed = Date().timeIntervalSince(startTime)
        let throughput = elapsed > 0 ? Double(totalSent) / elapsed : 0
        let avgSize = totalSent > 0 ? Double(totalBytes) / Double(totalSent) : 0

        statistics = BusStatistics(
            totalPublished: Int(totalSent),
            totalReceived: Int(totalReceived),
            totalBytes: Int(totalBytes),
            queueDepth: messageQueue.count,
            deadLetterDepth: deadLetterQueue.count,
            subscriptionCount: subscriptions.count,
            throughput: throughput,
            averageMessageSize: avgSize,
            errorRate: totalSent > 0 ? Double(deadLetterQueue.count) / Double(totalSent) : 0
        )
    }

    public func getMessageLog(limit: Int = 100) -> [AgentMessage] {
        lock.lock()
        defer { lock.unlock() }
        return Array(messageLog.suffix(limit))
    }

    public func getDeadLetterMessages() -> [AgentMessage] {
        lock.lock()
        defer { lock.unlock() }
        return deadLetterQueue
    }

    public func retryDeadLetter(_ messageID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard let index = deadLetterQueue.firstIndex(where: { $0.id == messageID }) else { return }
        var message = deadLetterQueue[index]
        message.attempts += 1
        message.status = .pending
        deadLetterQueue.remove(at: index)
        messageQueue.append(message)
    }

    public func purgeDeadLetter() {
        lock.lock()
        defer { lock.unlock() }
        deadLetterQueue.removeAll()
    }
}

public struct BusStatistics: Sendable {
    public var totalPublished: Int
    public var totalReceived: Int
    public var totalBytes: Int
    public var queueDepth: Int
    public var deadLetterDepth: Int
    public var subscriptionCount: Int
    public var throughput: Double
    public var averageMessageSize: Double
    public var errorRate: Double

    public init(
        totalPublished: Int = 0,
        totalReceived: Int = 0,
        totalBytes: Int = 0,
        queueDepth: Int = 0,
        deadLetterDepth: Int = 0,
        subscriptionCount: Int = 0,
        throughput: Double = 0,
        averageMessageSize: Double = 0,
        errorRate: Double = 0
    ) {
        self.totalPublished = totalPublished
        self.totalReceived = totalReceived
        self.totalBytes = totalBytes
        self.queueDepth = queueDepth
        self.deadLetterDepth = deadLetterDepth
        self.subscriptionCount = subscriptionCount
        self.throughput = throughput
        self.averageMessageSize = averageMessageSize
        self.errorRate = errorRate
    }
}
