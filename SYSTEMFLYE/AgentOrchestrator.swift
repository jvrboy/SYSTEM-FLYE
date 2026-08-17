import Foundation
import Accelerate
import Combine

// MARK: - Agent Orchestrator

public struct AgentDefinition: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var role: String
    public var capabilities: [String]
    public var status: AgentStatus
    public var load: Double
    public var successRate: Double
    public var averageLatency: TimeInterval
    public var maxConcurrency: Int
    public var currentConcurrency: Int
    public var lastHeartbeat: Date
    public var failureCount: Int
    public var totalTasks: Int
    public var completedTasks: Int
    public var accentColor: String

    public init(
        id: UUID = UUID(),
        name: String,
        role: String,
        capabilities: [String] = [],
        status: AgentStatus = .ready,
        load: Double = 0,
        successRate: Double = 1,
        averageLatency: TimeInterval = 0,
        maxConcurrency: Int = 4,
        currentConcurrency: Int = 0,
        lastHeartbeat: Date = Date(),
        failureCount: Int = 0,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        accentColor: String = "#00D4FF"
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.capabilities = capabilities
        self.status = status
        self.load = load
        self.successRate = successRate
        self.averageLatency = averageLatency
        self.maxConcurrency = maxConcurrency
        self.currentConcurrency = currentConcurrency
        self.lastHeartbeat = lastHeartbeat
        self.failureCount = failureCount
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.accentColor = accentColor
    }
}

public enum AgentStatus: String, Codable, Sendable, CaseIterable {
    case ready = "READY"
    case running = "RUNNING"
    case paused = "PAUSED"
    case failed = "FAILED"
    case retiring = "RETIRING"
}

public struct TaskDefinition: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var requiredCapabilities: [String]
    public var priority: TaskPriority
    public var estimatedDuration: TimeInterval
    public var estimatedComplexity: Double
    public var retryCount: Int
    public var maxRetries: Int
    public var timeout: TimeInterval
    public var dependencies: [UUID]
    public var payload: Data
    public var createdAt: Date
    public var scheduledAt: Date?
    public var assignedTo: UUID?
    public var status: TaskStatus
    public var result: Data?
    public var error: String?
    public var startedAt: Date?
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        requiredCapabilities: [String] = [],
        priority: TaskPriority = .medium,
        estimatedDuration: TimeInterval = 1,
        estimatedComplexity: Double = 1,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        timeout: TimeInterval = 30,
        dependencies: [UUID] = [],
        payload: Data = Data(),
        createdAt: Date = Date(),
        scheduledAt: Date? = nil,
        assignedTo: UUID? = nil,
        status: TaskStatus = .pending,
        result: Data? = nil,
        error: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.requiredCapabilities = requiredCapabilities
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.estimatedComplexity = estimatedComplexity
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.dependencies = dependencies
        self.payload = payload
        self.createdAt = createdAt
        self.scheduledAt = scheduledAt
        self.assignedTo = assignedTo
        self.status = status
        self.result = result
        self.error = error
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

public enum TaskPriority: Int, Codable, Sendable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum TaskStatus: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case queued = "QUEUED"
    case scheduled = "SCHEDULED"
    case running = "RUNNING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
    case retrying = "RETRYING"
}

public struct LoadBalanceStrategy: Hashable, Codable, Sendable {
    public let type: StrategyType
    public let weights: [UUID: Double]

    public enum StrategyType: String, Codable, Sendable, CaseIterable {
        case roundRobin = "ROUND_ROBIN"
        case leastLoaded = "LEAST_LOADED"
        case fastestResponse = "FASTEST_RESPONSE"
        case capabilityMatch = "CAPABILITY_MATCH"
        case weighted = "WEIGHTED"
        case predictive = "PREDICTIVE"
    }

    public init(type: StrategyType, weights: [UUID: Double] = [:]) {
        self.type = type
        self.weights = weights
    }
}

public struct OrchestratorMetrics: Sendable {
    public var totalTasks: Int
    public var completedTasks: Int
    public var failedTasks: Int
    public var averageLatency: TimeInterval
    public var throughput: Double
    public var activeAgents: Int
    public var queueDepth: Int
    public var failoverCount: Int
    public var retryCount: Int
    public var systemLoad: Double

    public init(
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        failedTasks: Int = 0,
        averageLatency: TimeInterval = 0,
        throughput: Double = 0,
        activeAgents: Int = 0,
        queueDepth: Int = 0,
        failoverCount: Int = 0,
        retryCount: Int = 0,
        systemLoad: Double = 0
    ) {
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.failedTasks = failedTasks
        self.averageLatency = averageLatency
        self.throughput = throughput
        self.activeAgents = activeAgents
        self.queueDepth = queueDepth
        self.failoverCount = failoverCount
        self.retryCount = retryCount
        self.systemLoad = systemLoad
    }
}

public struct FailoverPolicy: Hashable, Codable, Sendable {
    public let maxRetries: Int
    public let retryDelay: TimeInterval
    public let backoffMultiplier: Double
    public let circuitBreakerThreshold: Int
    public let circuitBreakerResetTime: TimeInterval
    public let fallbackAgentID: UUID?
    public let escalationThreshold: Int

    public init(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1,
        backoffMultiplier: Double = 2,
        circuitBreakerThreshold: Int = 5,
        circuitBreakerResetTime: TimeInterval = 60,
        fallbackAgentID: UUID? = nil,
        escalationThreshold: Int = 10
    ) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.backoffMultiplier = backoffMultiplier
        self.circuitBreakerThreshold = circuitBreakerThreshold
        self.circuitBreakerResetTime = circuitBreakerResetTime
        self.fallbackAgentID = fallbackAgentID
        self.escalationThreshold = escalationThreshold
    }
}

public struct AgentHealthReport: Sendable {
    public let agentID: UUID
    public let isHealthy: Bool
    public let lastHeartbeat: Date
    public let responseLatency: TimeInterval
    public let consecutiveFailures: Int
    public let circuitBreakerState: CircuitBreakerState
    public let recommendation: HealthRecommendation

    public enum CircuitBreakerState: String, Sendable {
        case closed = "CLOSED"
        case open = "OPEN"
        case halfOpen = "HALF_OPEN"
    }

    public enum HealthRecommendation: String, Sendable {
        case healthy = "HEALTHY"
        case degraded = "DEGRADED"
        case restart = "RESTART"
        case retire = "RETIRE"
    }
}

// MARK: - Orchestrator Core

@MainActor
public final class AgentOrchestrator: ObservableObject {
    public static let shared = AgentOrchestrator()

    @Published public private(set) var agents: [UUID: AgentDefinition] = [:]
    @Published public private(set) var taskQueue: [TaskDefinition] = []
    @Published public private(set) var activeTasks: [UUID: TaskDefinition] = [:]
    @Published public private(set) var completedTasks: [TaskDefinition] = []
    @Published public private(set) var failedTasks: [TaskDefinition] = []
    @Published public private(set) var metrics: OrchestratorMetrics
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var strategy: LoadBalanceStrategy

    public private(set) var circuitBreakers: [UUID: CircuitBreaker] = [:]
    public private(set) var roundRobinIndex: Int = 0
    public private(set) var taskHistory: [TaskDefinition] = []
    public private(set) var heartbeatTimers: [UUID: Timer] = [:]
    public private(set) var retryQueues: [UUID: [TaskDefinition]] = [:]

    public private let failoverPolicy: FailoverPolicy
    public private let healthCheckInterval: TimeInterval = 5
    public private let heartbeatTimeout: TimeInterval = 15
    public private var processingTask: Task<Void, Never>?
    public private var healthCheckTask: Task<Void, Never>?
    public private let metricsBuffer = MetricsBuffer(windowSize: 100)
    public private let taskLock = NSLock()
    public private let agentLock = NSLock()
    public private var cancellables = Set<AnyCancellable>()

    public init(
        strategy: LoadBalanceStrategy = .init(type: .leastLoaded),
        failoverPolicy: FailoverPolicy = .init()
    ) {
        self.strategy = strategy
        self.failoverPolicy = failoverPolicy
        self.metrics = OrchestratorMetrics()
        super.init()
        self.setupDefaults()
    }

    deinit {
        processingTask?.cancel()
        healthCheckTask?.cancel()
        heartbeatTimers.values.forEach { $0.invalidate() }
    }
}

// MARK: - Agent Management

extension AgentOrchestrator {
    public func registerAgent(_ agent: AgentDefinition) {
        agentLock.lock()
        defer { agentLock.unlock() }
        agents[agent.id] = agent
        circuitBreakers[agent.id] = CircuitBreaker(
            threshold: failoverPolicy.circuitBreakerThreshold,
            resetTime: failoverPolicy.circuitBreakerResetTime
        )
        startHeartbeatMonitor(for: agent.id)
    }

    public func unregisterAgent(_ id: UUID) {
        agentLock.lock()
        defer { agentLock.unlock() }
        agents.removeValue(forKey: id)
        circuitBreakers.removeValue(forKey: id)
        heartbeatTimers[id]?.invalidate()
        heartbeatTimers.removeValue(forKey: id)
    }

    public func updateAgentStatus(_ id: UUID, status: AgentStatus) {
        agentLock.lock()
        defer { agentLock.unlock() }
        guard var agent = agents[id] else { return }
        agent.status = status
        agent.lastHeartbeat = Date()
        agents[id] = agent
    }

    public func reportAgentHeartbeat(_ id: UUID, latency: TimeInterval) {
        agentLock.lock()
        defer { agentLock.unlock() }
        guard var agent = agents[id] else { return }
        agent.lastHeartbeat = Date()
        agent.averageLatency = (agent.averageLatency + latency) / 2
        agents[id] = agent
        circuitBreakers[id]?.recordSuccess()
    }

    public func getHealthyAgents() -> [AgentDefinition] {
        agentLock.lock()
        defer { agentLock.unlock() }
        return agents.values.filter { agent in
            agent.status != .failed &&
            agent.status != .retiring &&
            Date().timeIntervalSince(agent.lastHeartbeat) < heartbeatTimeout
        }.sorted { $0.load < $1.load }
    }

    public func getAgentsByCapability(_ capability: String) -> [AgentDefinition] {
        agentLock.lock()
        defer { agentLock.unlock() }
        return agents.values.filter { agent in
            agent.capabilities.contains(capability) &&
            agent.status != .failed &&
            Date().timeIntervalSince(agent.lastHeartbeat) < heartbeatTimeout
        }.sorted { $0.load < $1.load }
    }
}

// MARK: - Task Management

extension AgentOrchestrator {
    public func submitTask(_ task: TaskDefinition) -> UUID {
        taskLock.lock()
        defer { taskLock.unlock() }
        var mutableTask = task
        mutableTask.status = .pending
        taskQueue.append(mutableTask)
        metricsBuffer.recordTaskSubmission()
        updateMetrics()
        return task.id
    }

    public func submitBatch(_ tasks: [TaskDefinition]) -> [UUID] {
        tasks.map { submitTask($0) }
    }

    public func cancelTask(_ id: UUID) {
        taskLock.lock()
        defer { taskLock.unlock() }
        if let index = taskQueue.firstIndex(where: { $0.id == id }) {
            var task = taskQueue[index]
            task.status = .cancelled
            task.completedAt = Date()
            taskQueue.remove(at: index)
            completedTasks.append(task)
            metricsBuffer.recordTaskCancellation()
        }
        if var task = activeTasks[id] {
            task.status = .cancelled
            task.completedAt = Date()
            activeTasks[id] = task
            completedTasks.append(task)
            metricsBuffer.recordTaskCancellation()
        }
        updateMetrics()
    }

    public func getTaskStatus(_ id: UUID) -> TaskStatus? {
        taskLock.lock()
        defer { taskLock.unlock() }
        if let task = taskQueue.first(where: { $0.id == id }) { return task.status }
        if let task = activeTasks[id] { return task.status }
        return completedTasks.first(where: { $0.id == id })?.status
    }

    public func requeueTask(_ id: UUID) {
        taskLock.lock()
        defer { taskLock.unlock() }
        guard let index = taskQueue.firstIndex(where: { $0.id == id }) else { return }
        var task = taskQueue[index]
        task.status = .pending
        task.assignedTo = nil
        task.retryCount += 1
        task.startedAt = nil
        taskQueue[index] = task
        metricsBuffer.recordTaskRetry()
        updateMetrics()
    }
}

// MARK: - Task Distribution

extension AgentOrchestrator {
    private func distributeTask(_ task: TaskDefinition) {
        taskLock.lock()
        defer { taskLock.unlock() }

        guard task.dependencies.allSatisfy({ dependency in
            completedTasks.contains(where: { $0.id == dependency }) ||
            activeTasks.values.contains(where: { $0.id == dependency && $0.status == .completed })
        }) else {
            return
        }

        guard let agent = selectAgent(for: task) else {
            scheduleForRetry(task)
            return
        }

        guard assignTaskToAgent(task, agent: agent) else {
            scheduleForRetry(task)
            return
        }

        if let index = taskQueue.firstIndex(where: { $0.id == task.id }) {
            taskQueue.remove(at: index)
        }
    }

    private func selectAgent(for task: TaskDefinition) -> AgentDefinition? {
        let candidates = getCandidates(for: task)
        guard !candidates.isEmpty else { return nil }

        switch strategy.type {
        case .roundRobin:
            return selectRoundRobin(candidates)
        case .leastLoaded:
            return selectLeastLoaded(candidates)
        case .fastestResponse:
            return selectFastestResponse(candidates)
        case .capabilityMatch:
            return selectBestCapabilityMatch(candidates, task: task)
        case .weighted:
            return selectWeighted(candidates)
        case .predictive:
            return selectPredictive(candidates, task: task)
        }
    }

    private func getCandidates(for task: TaskDefinition) -> [AgentDefinition] {
        guard !task.requiredCapabilities.isEmpty else {
            return getHealthyAgents()
        }
        var candidates: [AgentDefinition] = []
        for capability in task.requiredCapabilities {
            candidates.append(contentsOf: getAgentsByCapability(capability))
        }
        return Array(Set(candidates)).filter { agent in
            agent.currentConcurrency < agent.maxConcurrency
        }
    }

    private func selectRoundRobin(_ candidates: [AgentDefinition]) -> AgentDefinition? {
        guard !candidates.isEmpty else { return nil }
        let index = roundRobinIndex % candidates.count
        roundRobinIndex += 1
        return candidates[index]
    }

    private func selectLeastLoaded(_ candidates: [AgentDefinition]) -> AgentDefinition? {
        candidates.min { $0.load < $1.load }
    }

    private func selectFastestResponse(_ candidates: [AgentDefinition]) -> AgentDefinition? {
        candidates.min { $0.averageLatency < $1.averageLatency }
    }

    private func selectBestCapabilityMatch(_ candidates: [AgentDefinition], task: TaskDefinition) -> AgentDefinition? {
        candidates.max { agent in
            let matchCount = Set(agent.capabilities).intersection(Set(task.requiredCapabilities)).count
            return matchCount
        }
    }

    private func selectWeighted(_ candidates: [AgentDefinition]) -> AgentDefinition? {
        guard !candidates.isEmpty else { return nil }
        let totalWeight = candidates.reduce(0) { sum, agent in
            sum + (strategy.weights[agent.id] ?? 1)
        }
        var random = Double.random(in: 0...totalWeight)
        for agent in candidates {
            random -= strategy.weights[agent.id] ?? 1
            if random <= 0 { return agent }
        }
        return candidates.last
    }

    private func selectPredictive(_ candidates: [AgentDefinition], task: TaskDefinition) -> AgentDefinition? {
        candidates.min { agent in
            let loadScore = agent.load * 0.3
            let latencyScore = agent.averageLatency * 0.2
            let reliabilityScore = (1 - agent.successRate) * 0.3
            let complexityFit = max(0, task.estimatedComplexity - Double(agent.maxConcurrency - agent.currentConcurrency)) * 0.2
            return loadScore + latencyScore + reliabilityScore + complexityFit < 0.5
        }
    }

    private func assignTaskToAgent(_ task: TaskDefinition, agent: AgentDefinition) -> Bool {
        guard var mutableAgent = agents[agent.id] else { return false }
        guard mutableAgent.currentConcurrency < mutableAgent.maxConcurrency else { return false }

        mutableAgent.currentConcurrency += 1
        mutableAgent.load = min(1, mutableAgent.load + (task.estimatedComplexity / Double(mutableAgent.maxConcurrency)))
        agents[agent.id] = mutableAgent

        var mutableTask = task
        mutableTask.status = .running
        mutableTask.assignedTo = agent.id
        mutableTask.startedAt = Date()
        activeTasks[task.id] = mutableTask
        taskQueue.removeAll { $0.id == task.id }

        executeTaskAsync(mutableTask, agent: mutableAgent)
        updateMetrics()
        return true
    }

    private func scheduleForRetry(_ task: TaskDefinition) {
        guard task.retryCount < task.maxRetries else {
            markTaskFailed(task, error: "No available agents after retries")
            return
        }

        let delay = failoverPolicy.retryDelay * pow(failoverPolicy.backoffMultiplier, Double(task.retryCount))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.taskLock.lock()
            defer { self.taskLock.unlock() }
            if var task = self.taskQueue.first(where: { $0.id == task.id }) {
                task.status = .retrying
                self.taskQueue.removeAll { $0.id == task.id }
                self.submitTask(task)
                self.metricsBuffer.recordTaskRetry()
                self.updateMetrics()
            }
        }
    }

    private func executeTaskAsync(_ task: TaskDefinition, agent: AgentDefinition) {
        Task { [weak self] in
            guard let self = self else { return }
            let startTime = Date()
            do {
                let result = try await self.performTaskExecution(task, agent: agent)
                let latency = Date().timeIntervalSince(startTime)
                self.completeTask(task, result: result, latency: latency)
            } catch {
                let latency = Date().timeIntervalSince(startTime)
                self.failTask(task, error: error.localizedDescription, latency: latency)
            }
        }
    }

    private func performTaskExecution(_ task: TaskDefinition, agent: AgentDefinition) async throws -> Data {
        try await Task.sleep(nanoseconds: UInt64(task.estimatedDuration * 1_000_000_000))
        return task.payload
    }

    private func completeTask(_ task: TaskDefinition, result: Data, latency: TimeInterval) {
        taskLock.lock()
        defer { taskLock.unlock() }
        agentLock.lock()
        defer { agentLock.unlock() }

        guard var completed = activeTasks[task.id] else { return }
        completed.status = .completed
        completed.result = result
        completed.completedAt = Date()
        activeTasks.removeValue(forKey: task.id)
        completedTasks.append(completed)
        taskHistory.append(completed)

        if let agentID = completed.assignedTo, var agent = agents[agentID] {
            agent.completedTasks += 1
            agent.totalTasks += 1
            agent.currentConcurrency = max(0, agent.currentConcurrency - 1)
            agent.load = max(0, agent.load - (task.estimatedComplexity / Double(agent.maxConcurrency)))
            agent.successRate = Double(agent.completedTasks) / Double(agent.totalTasks)
            agents[agentID] = agent
        }

        metricsBuffer.recordTaskCompletion(latency: latency)
        updateMetrics()
    }

    private func failTask(_ task: TaskDefinition, error: String, latency: TimeInterval) {
        taskLock.lock()
        defer { taskLock.unlock() }
        agentLock.lock()
        defer { agentLock.unlock() }

        guard var failed = activeTasks[task.id] else { return }
        failed.status = .failed
        failed.error = error
        failed.completedAt = Date()
        activeTasks.removeValue(forKey: task.id)
        failedTasks.append(failed)
        taskHistory.append(failed)

        if let agentID = failed.assignedTo {
            if let cb = circuitBreakers[agentID] {
                cb.recordFailure()
                if cb.state == .open {
                    markAgentFailed(agentID)
                }
            }
            if var agent = agents[agentID] {
                agent.totalTasks += 1
                agent.currentConcurrency = max(0, agent.currentConcurrency - 1)
                agent.failureCount += 1
                agent.load = max(0, agent.load - (task.estimatedComplexity / Double(agent.maxConcurrency)))
                agents[agentID] = agent
            }
        }

        metricsBuffer.recordTaskFailure(latency: latency)
        updateMetrics()
    }

    private func markTaskFailed(_ task: TaskDefinition, error: String) {
        taskLock.lock()
        defer { taskLock.unlock() }
        var failed = task
        failed.status = .failed
        failed.error = error
        failed.completedAt = Date()
        taskQueue.removeAll { $0.id == task.id }
        failedTasks.append(failed)
        taskHistory.append(failed)
        metricsBuffer.recordTaskFailure(latency: task.estimatedDuration)
        updateMetrics()
    }

    private func markAgentFailed(_ id: UUID) {
        guard var agent = agents[id] else { return }
        agent.status = .failed
        agents[id] = agent
        metrics.failoverCount += 1
        failoverAgentTasks(from: id)
        updateMetrics()
    }

    private func failoverAgentTasks(from agentID: UUID) {
        taskLock.lock()
        defer { taskLock.unlock() }
        let failedTasks = activeTasks.values.filter { $0.assignedTo == agentID }
        for task in failedTasks {
            var mutableTask = task
            mutableTask.assignedTo = nil
            mutableTask.status = .pending
            mutableTask.startedAt = nil
            activeTasks.removeValue(forKey: task.id)
            taskQueue.append(mutableTask)
        }
    }
}

// MARK: - Processing Loop

extension AgentOrchestrator {
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        processingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                self.processTick()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        healthCheckTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                self.performHealthChecks()
                try? await Task.sleep(for: .seconds(healthCheckInterval))
            }
        }
    }

    public func stop() {
        isRunning = false
        processingTask?.cancel()
        healthCheckTask?.cancel()
        processingTask = nil
        healthCheckTask = nil
    }

    private func processTick() {
        taskLock.lock()
        defer { taskLock.unlock() }

        let pendingTasks = taskQueue.filter { $0.status == .pending || $0.status == .queued }
        for task in pendingTasks {
            distributeTask(task)
        }

        let retryingTasks = taskQueue.filter { $0.status == .retrying }
        for task in retryingTasks {
            distributeTask(task)
        }
    }

    private func performHealthChecks() {
        let now = Date()
        for (id, agent) in agents {
            if agent.status == .failed || agent.status == .retiring { continue }
            if now.timeIntervalSince(agent.lastHeartbeat) > heartbeatTimeout {
                agentLock.lock()
                var failedAgent = agents[id] ?? agent
                failedAgent.status = .failed
                failedAgent.failureCount += 1
                agents[id] = failedAgent
                agentLock.unlock()
                circuitBreakers[id]?.recordFailure()
                failoverAgentTasks(from: id)
                metrics.failoverCount += 1
            }
        }
        updateMetrics()
    }

    private func startHeartbeatMonitor(for id: UUID) {
        heartbeatTimers[id]?.invalidate()
        heartbeatTimers[id] = Timer.scheduledTimer(withTimeInterval: heartbeatTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.agentLock.lock()
            var agent = self.agents[id]
            agent?.status = .failed
            self.agents[id] = agent
            self.agentLock.unlock()
            self.circuitBreakers[id]?.recordFailure()
            self.failoverAgentTasks(from: id)
        }
    }
}

// MARK: - Metrics

extension AgentOrchestrator {
    private func updateMetrics() {
        taskLock.lock()
        agentLock.lock()
        defer { taskLock.unlock(); agentLock.unlock() }

        let totalLatency = taskHistory.compactMap { task in
            guard let start = task.startedAt, let end = task.completedAt else { return nil }
            return end.timeIntervalSince(start)
        }
        let avgLatency = totalLatency.isEmpty ? 0 : totalLatency.reduce(0, +) / Double(totalLatency.count)

        metrics = OrchestratorMetrics(
            totalTasks: taskHistory.count,
            completedTasks: completedTasks.count,
            failedTasks: failedTasks.count,
            averageLatency: avgLatency,
            throughput: metricsBuffer.calculateThroughput(),
            activeAgents: agents.values.filter { $0.status == .running || $0.status == .ready }.count,
            queueDepth: taskQueue.count,
            failoverCount: metrics.failoverCount,
            retryCount: taskHistory.filter { $0.retryCount > 0 }.count,
            systemLoad: agents.values.map(\.load).reduce(0, +) / Double(max(agents.count, 1))
        )
    }

    public func getAgentMetrics() -> [UUID: AgentDefinition] {
        agentLock.lock()
        defer { agentLock.unlock() }
        return agents
    }

    public func getTaskMetrics() -> OrchestratorMetrics {
        metrics
    }

    public func getPendingTaskCount() -> Int {
        taskLock.lock()
        defer { taskLock.unlock() }
        return taskQueue.count
    }

    public func getActiveTaskCount() -> Int {
        activeTasks.count
    }

    public func getSystemHealth() -> SystemHealth {
        agentLock.lock()
        defer { agentLock.unlock() }
        let total = agents.count
        let healthy = agents.values.filter { $0.status == .ready || $0.status == .running }.count
        let failed = agents.values.filter { $0.status == .failed }.count
        let avgSuccessRate = agents.values.map(\.successRate).reduce(0, +) / Double(max(total, 1))
        return SystemHealth(
            totalAgents: total,
            healthyAgents: healthy,
            failedAgents: failed,
            averageSuccessRate: avgSuccessRate,
            systemLoad: metrics.systemLoad,
            status: failed > total / 2 ? .critical : (avgSuccessRate < 0.8 ? .degraded : .healthy)
        )
    }
}

public struct SystemHealth: Sendable {
    public let totalAgents: Int
    public let healthyAgents: Int
    public let failedAgents: Int
    public let averageSuccessRate: Double
    public let systemLoad: Double
    public let status: HealthStatus

    public enum HealthStatus: String, Sendable {
        case healthy = "HEALTHY"
        case degraded = "DEGRADED"
        case critical = "CRITICAL"
    }
}

// MARK: - Circuit Breaker

public final class CircuitBreaker: Sendable {
    public private(set) var state: AgentHealthReport.CircuitBreakerState = .closed
    public private(set) var failureCount: Int = 0
    public private(set) var lastFailureTime: Date?
    public private(set) var successCount: Int = 0

    private let threshold: Int
    private let resetTime: TimeInterval
    private let lock = NSLock()

    public init(threshold: Int, resetTime: TimeInterval) {
        self.threshold = threshold
        self.resetTime = resetTime
    }

    public func recordFailure() {
        lock.lock()
        defer { lock.unlock() }
        failureCount += 1
        lastFailureTime = Date()
        if failureCount >= threshold {
            state = .open
        }
    }

    public func recordSuccess() {
        lock.lock()
        defer { lock.unlock() }
        if state == .halfOpen {
            successCount += 1
            if successCount >= 3 {
                state = .closed
                failureCount = 0
                successCount = 0
            }
        } else if state == .open {
            state = .halfOpen
            successCount = 1
        }
    }

    public func canExecute() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if state == .closed { return true }
        if state == .open, let lastFailure = lastFailureTime {
            if Date().timeIntervalSince(lastFailure) > resetTime {
                state = .halfOpen
                return true
            }
            return false
        }
        return state != .open
    }
}

// MARK: - Metrics Buffer

final class MetricsBuffer: Sendable {
    private let windowSize: Int
    private let lock = NSLock()
    private var completions: [(time: Date, latency: TimeInterval)] = []
    private var submissions: [Date] = []
    private var failures: [(time: Date, latency: TimeInterval)] = []

    init(windowSize: Int) {
        self.windowSize = windowSize
    }

    func recordTaskCompletion(latency: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        completions.append((time: Date(), latency: latency))
        if completions.count > windowSize {
            completions.removeFirst()
        }
    }

    func recordTaskSubmission() {
        lock.lock()
        defer { lock.unlock() }
        submissions.append(Date())
        if submissions.count > windowSize {
            submissions.removeFirst()
        }
    }

    func recordTaskFailure(latency: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        failures.append((time: Date(), latency: latency))
        if failures.count > windowSize {
            failures.removeFirst()
        }
    }

    func recordTaskRetry() {
        lock.lock()
        defer { lock.unlock() }
    }

    func recordTaskCancellation() {
        lock.lock()
        defer { lock.unlock() }
    }

    func calculateThroughput() -> Double {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        let recentSubmissions = submissions.filter { now.timeIntervalSince($0) < 60 }
        return Double(recentSubmissions.count) / 60
    }
}

// MARK: - Configuration

extension AgentOrchestrator {
    public func setStrategy(_ newStrategy: LoadBalanceStrategy) {
        strategy = newStrategy
    }

    public func updateFailoverPolicy(_ newPolicy: FailoverPolicy) {
        taskLock.lock()
        defer { taskLock.unlock() }
        failoverPolicy.maxRetries = newPolicy.maxRetries
    }

    public func pauseAgent(_ id: UUID) {
        updateAgentStatus(id, status: .paused)
    }

    public func resumeAgent(_ id: UUID) {
        updateAgentStatus(id, status: .ready)
    }

    public func retireAgent(_ id: UUID) {
        updateAgentStatus(id, status: .retiring)
        failoverAgentTasks(from: id)
        unregisterAgent(id)
    }

    public func drainQueue() {
        taskLock.lock()
        defer { taskLock.unlock() }
        taskQueue.removeAll()
    }

    public func getActiveTasks() -> [TaskDefinition] {
        Array(activeTasks.values)
    }

    public func getTaskHistory(limit: Int = 100) -> [TaskDefinition] {
        Array(taskHistory.suffix(limit))
    }

    public func getAgentsByLoad() -> [AgentDefinition] {
        agentLock.lock()
        defer { agentLock.unlock() }
        return agents.values.filter { $0.status != .failed }.sorted { $0.load < $1.load }
    }
}
