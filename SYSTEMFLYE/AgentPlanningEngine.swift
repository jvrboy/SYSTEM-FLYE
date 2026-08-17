import Foundation
import Accelerate
import Combine

// MARK: - Planning Types

public struct Goal: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var priority: GoalPriority
    public var status: GoalStatus
    public var parentGoalID: UUID?
    public var subGoals: [UUID]
    public var requiredCapabilities: [String]
    public var constraints: [PlanningConstraint]
    public var successCriteria: [SuccessCriterion]
    public var estimatedEffort: Double
    public var deadline: Date?
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var assignedAgentID: UUID?
    public var context: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        priority: GoalPriority = .medium,
        status: GoalStatus = .pending,
        parentGoalID: UUID? = nil,
        subGoals: [UUID] = [],
        requiredCapabilities: [String] = [],
        constraints: [PlanningConstraint] = [],
        successCriteria: [SuccessCriterion] = [],
        estimatedEffort: Double = 1,
        deadline: Date? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        assignedAgentID: UUID? = nil,
        context: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.status = status
        self.parentGoalID = parentGoalID
        self.subGoals = subGoals
        self.requiredCapabilities = requiredCapabilities
        self.constraints = constraints
        self.successCriteria = successCriteria
        self.estimatedEffort = estimatedEffort
        self.deadline = deadline
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.assignedAgentID = assignedAgentID
        self.context = context
    }
}

public enum GoalPriority: Int, Codable, Sendable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: GoalPriority, rhs: GoalPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum GoalStatus: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case planning = "PLANNING"
    case executing = "EXECUTING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case blocked = "BLOCKED"
    case cancelled = "CANCELLED"
}

public struct PlanningConstraint: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var type: ConstraintType
    public var expression: String
    public var severity: ConstraintSeverity
    public var metadata: [String: String]

    public init(id: UUID = UUID(), type: ConstraintType, expression: String, severity: ConstraintSeverity = .hard, metadata: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.expression = expression
        self.severity = severity
        self.metadata = metadata
    }
}

public enum ConstraintType: String, Codable, Sendable, CaseIterable {
    case temporal = "TEMPORAL"
    case resource = "RESOURCE"
    case dependency = "DEPENDENCY"
    case capability = "CAPABILITY"
    case safety = "SAFETY"
    case budget = "BUDGET"
    case custom = "CUSTOM"
}

public enum ConstraintSeverity: String, Codable, Sendable, CaseIterable {
    case soft = "SOFT"
    case hard = "HARD"
    case critical = "CRITICAL"
}

public struct SuccessCriterion: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var metric: String
    public var operator: ComparisonOperator
    public var threshold: Double
    public var weight: Double
    public var isMandatory: Bool

    public init(id: UUID = UUID(), name: String, metric: String, operator: ComparisonOperator = .greaterThanOrEqual, threshold: Double = 1, weight: Double = 1, isMandatory: Bool = true) {
        self.id = id
        self.name = name
        self.metric = metric
        self.operator = operator
        self.threshold = threshold
        self.weight = weight
        self.isMandatory = isMandatory
    }
}

public enum ComparisonOperator: String, Codable, Sendable, CaseIterable {
    case equals = "=="
    case notEquals = "!="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="
    case lessThan = "<"
    case lessThanOrEqual = "<="
}

public struct PlanStep: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var goalID: UUID
    public var name: String
    public var description: String
    public var action: String
    public var parameters: [String: String]
    public var preconditions: [String]
    public var effects: [String]
    public var ordering: [UUID]
    public var assignedAgentID: UUID?
    public var status: StepStatus
    public var estimatedDuration: TimeInterval
    public var actualDuration: TimeInterval?
    public var retryCount: Int
    public var maxRetries: Int
    public var priority: GoalPriority
    public var dependencies: [UUID]
    public var results: [String: String]
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        goalID: UUID,
        name: String,
        description: String,
        action: String,
        parameters: [String: String] = [:],
        preconditions: [String] = [],
        effects: [String] = [],
        ordering: [UUID] = [],
        assignedAgentID: UUID? = nil,
        status: StepStatus = .pending,
        estimatedDuration: TimeInterval = 1,
        actualDuration: TimeInterval? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        priority: GoalPriority = .medium,
        dependencies: [UUID] = [],
        results: [String: String] = [:],
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.goalID = goalID
        self.name = name
        self.description = description
        self.action = action
        self.parameters = parameters
        self.preconditions = preconditions
        self.effects = effects
        self.ordering = ordering
        self.assignedAgentID = assignedAgentID
        self.status = status
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.priority = priority
        self.dependencies = dependencies
        self.results = results
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

public enum StepStatus: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case ready = "READY"
    case running = "RUNNING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case skipped = "SKIPPED"
    case blocked = "BLOCKED"
}

public struct Plan: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var goalID: UUID
    public var steps: [PlanStep]
    public var ordering: [UUID]
    public var estimatedTotalDuration: TimeInterval
    public var estimatedTotalCost: Double
    public var confidence: Double
    public var status: PlanStatus
    public var createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        goalID: UUID,
        steps: [PlanStep] = [],
        ordering: [UUID] = [],
        estimatedTotalDuration: TimeInterval = 0,
        estimatedTotalCost: Double = 0,
        confidence: Double = 0,
        status: PlanStatus = .draft,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.goalID = goalID
        self.steps = steps
        self.ordering = ordering
        self.estimatedTotalDuration = estimatedTotalDuration
        self.estimatedTotalCost = estimatedTotalCost
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.metadata = metadata
    }
}

public enum PlanStatus: String, Codable, Sendable, CaseIterable {
    case draft = "DRAFT"
    case validated = "VALIDATED"
    case executing = "EXECUTING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
    case replanning = "REPLANNING"
}

public struct PlanValidationResult: Sendable {
    public let isValid: Bool
    public var errors: [String]
    public var warnings: [String]
    public var estimatedSuccessRate: Double
    public var riskFactors: [String]

    public init(isValid: Bool = true, errors: [String] = [], warnings: [String] = [], estimatedSuccessRate: Double = 1, riskFactors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.estimatedSuccessRate = estimatedSuccessRate
        self.riskFactors = riskFactors
    }
}

// MARK: - Planning Engine

@MainActor
public final class AgentPlanningEngine: ObservableObject {
    public static let shared = AgentPlanningEngine()

    @Published public private(set) var goals: [UUID: Goal] = [:]
    @Published public private(set) var plans: [UUID: Plan] = [:]
    @Published public private(set) var planSteps: [UUID: PlanStep] = [:]
    @Published public private(set) var activePlans: [UUID: Plan] = []
    @Published public private(set) var completedPlans: [Plan] = []
    @Published public private(set) var statistics: PlanningStatistics
    @Published public private(set) var isProcessing: Bool = false

    public private(set) var actionLibrary: [String: ActionDefinition] = [:]
    public private(set) var dependencyGraph: [UUID: Set<UUID>] = [:]
    public private(set) var goalHierarchy: [UUID: [UUID]] = [:]
    public private(set) var replanTriggers: [UUID: ReplanTrigger] = [:]
    public private(set) var planningHistory: [PlanExecutionRecord] = []

    public private let lock = NSLock()
    public private var planningTask: Task<Void, Never>?
    public private var executionTask: Task<Void, Never>?
    public private var totalGoalsCreated: Int = 0
    public private var totalPlansCreated: Int = 0

    public init(statistics: PlanningStatistics = .init()) {
        self.statistics = statistics
        super.init()
        loadDefaultActions()
    }

    deinit {
        planningTask?.cancel()
        executionTask?.cancel()
    }
}

// MARK: - Goal Management

extension AgentPlanningEngine {
    public func createGoal(name: String, description: String, priority: GoalPriority = .medium, parentGoalID: UUID? = nil, requiredCapabilities: [String] = [], estimatedEffort: Double = 1) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let goal = Goal(
            name: name,
            description: description,
            priority: priority,
            parentGoalID: parentGoalID,
            requiredCapabilities: requiredCapabilities,
            estimatedEffort: estimatedEffort
        )
        goals[goal.id] = goal
        totalGoalsCreated += 1

        if let parentID = parentGoalID {
            goalHierarchy[parentID, default: []].append(goal.id)
        }

        updateStatistics()
        return goal.id
    }

    public func decomposeGoal(_ goalID: UUID) -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        guard let goal = goals[goalID] else { return [] }

        let subGoalIDs = decomposeIntoSelfgoals(goal)
        if var mutableGoal = goals[goalID] {
            mutableGoal.subGoals = subGoalIDs
            mutableGoal.status = .planning
            goals[goalID] = mutableGoal
        }

        for subGoalID in subGoalIDs {
            if var subGoal = goals[subGoalID] {
                subGoal.parentGoalID = goalID
                goals[subGoalID] = subGoal
            }
        }

        updateStatistics()
        return subGoalIDs
    }

    private func decomposeIntoSelfgoals(_ goal: Goal) -> [UUID] {
        let keywords = goal.name.lowercased().split(separator: " ")
        var subGoals: [UUID] = []
        let count = min(max(keywords.count, 2), 8)

        for i in 0..<count {
            let keyword = keywords[i % keywords.count]
            let subGoal = Goal(
                name: "\(goal.name) - \(keyword)",
                description: "Subtask for \(goal.name) involving \(keyword)",
                priority: goal.priority,
                parentGoalID: goal.id,
                requiredCapabilities: goal.requiredCapabilities,
                estimatedEffort: goal.estimatedEffort / Double(count)
            )
            goals[subGoal.id] = subGoal
            subGoals.append(subGoal.id)
        }
        return subGoals
    }

    public func updateGoalStatus(_ goalID: UUID, status: GoalStatus) {
        lock.lock()
        defer { lock.unlock() }
        guard var goal = goals[goalID] else { return }
        goal.status = status
        switch status {
        case .executing: goal.startedAt = Date()
        case .completed: goal.completedAt = Date()
        default: break
        }
        goals[goalID] = goal
        updateStatistics()
    }

    public func assignGoal(_ goalID: UUID, agentID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard var goal = goals[goalID] else { return }
        goal.assignedAgentID = agentID
        goals[goalID] = goal
    }
}

// MARK: - Plan Generation

extension AgentPlanningEngine {
    public func generatePlan(for goalID: UUID) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        guard let goal = goals[goalID] else { return UUID() }

        let steps = generateSteps(for: goal)
        let ordering = topologicalSort(steps: steps)
        let estimatedDuration = steps.reduce(0) { $0 + $1.estimatedDuration }
        let confidence = calculatePlanConfidence(steps: steps)

        let plan = Plan(
            goalID: goalID,
            steps: steps,
            ordering: ordering,
            estimatedTotalDuration: estimatedDuration,
            confidence: confidence
        )

        plans[plan.id] = plan
        for step in steps {
            planSteps[step.id] = step
        }

        if var mutableGoal = goals[goalID] {
            mutableGoal.status = .planning
            goals[goalID] = mutableGoal
        }

        totalPlansCreated += 1
        activePlans.append(plan)
        updateStatistics()
        return plan.id
    }

    private func generateSteps(for goal: Goal) -> [PlanStep] {
        var steps: [PlanStep] = []
        let actionCount = max(3, Int(goal.estimatedEffort * 2))

        for i in 0..<actionCount {
            let actionName = actionLibrary.keys.randomElement() ?? "execute_task"
            let actionDef = actionLibrary[actionName] ?? ActionDefinition(name: actionName, description: "Execute task", parameters: [:])

            let step = PlanStep(
                goalID: goal.id,
                name: "Step \(i + 1): \(actionDef.name)",
                description: actionDef.description,
                action: actionDef.name,
                parameters: actionDef.parameters,
                preconditions: actionDef.preconditions,
                effects: actionDef.effects,
                priority: goal.priority
            )
            steps.append(step)
        }

        for i in 1..<steps.count {
            steps[i].dependencies = [steps[i - 1].id]
        }

        return steps
    }

    private func topologicalSort(steps: [PlanStep]) -> [UUID] {
        var graph: [UUID: Set<UUID>] = [:]
        var inDegree: [UUID: Int] = [:]
        var result: [UUID] = []

        for step in steps {
            graph[step.id, default: []].formUnion(step.dependencies)
            inDegree[step.id, default: 0] = step.dependencies.count
        }

        var queue: [UUID] = inDegree.filter { $0.value == 0 }.map { $0.key }
        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)

            for step in steps where step.dependencies.contains(current) {
                inDegree[step.id] = (inDegree[step.id] ?? 1) - 1
                if inDegree[step.id] == 0 {
                    queue.append(step.id)
                }
            }
        }

        return result
    }

    private func calculatePlanConfidence(steps: [PlanStep]) -> Double {
        guard !steps.isEmpty else { return 0 }
        let totalRetries = steps.reduce(0) { $0 + $1.maxRetries }
        let averageRetries = Double(totalRetries) / Double(steps.count)
        return max(0, 1 - averageRetries * 0.1)
    }
}

// MARK: - Plan Execution

extension AgentPlanningEngine {
    public func executePlan(_ planID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard var plan = plans[planID] else { return }
        plan.status = .executing
        plan.startedAt = Date()
        plans[planID] = plan

        if let index = activePlans.firstIndex(where: { $0.id == planID }) {
            activePlans[index] = plan
        }

        executionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.executePlanSteps(planID)
        }
    }

    private func executePlanSteps(_ planID: UUID) async {
        guard var plan = plans[planID] else { return }
        let steps = plan.steps.sorted { stepA, stepB in
            let indexA = plan.ordering.firstIndex(of: stepA.id) ?? Int.max
            let indexB = plan.ordering.firstIndex(of: stepB.id) ?? Int.max
            return indexA < indexB
        }

        for step in steps {
            await executeStep(step)
        }

        await MainActor.run {
            guard var completedPlan = self.plans[planID] else { return }
            completedPlan.status = .completed
            completedPlan.completedAt = Date()
            self.plans[planID] = completedPlan

            if let index = self.activePlans.firstIndex(where: { $0.id == planID }) {
                self.activePlans.remove(at: index)
            }
            self.completedPlans.append(completedPlan)
            self.planningHistory.append(PlanExecutionRecord(planID: planID, duration: Date().timeIntervalSince(completedPlan.startedAt ?? Date()), success: true))
            self.updateStatistics()
        }
    }

    private func executeStep(_ step: PlanStep) async {
        await MainActor.run {
            guard var mutableStep = self.planSteps[step.id] else { return }
            mutableStep.status = .running
            mutableStep.startedAt = Date()
            self.planSteps[step.id] = mutableStep
        }

        try? await Task.sleep(nanoseconds: UInt64(step.estimatedDuration * 1_000_000_000))

        let success = Bool.random() > 0.2
        await MainActor.run {
            guard var mutableStep = self.planSteps[step.id] else { return }
            mutableStep.status = success ? .completed : .failed
            mutableStep.completedAt = Date()
            mutableStep.actualDuration = step.estimatedDuration
            self.planSteps[step.id] = mutableStep
        }
    }

    public func cancelPlan(_ planID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard var plan = plans[planID] else { return }
        plan.status = .cancelled
        plan.completedAt = Date()
        plans[planID] = plan
        executionTask?.cancel()
        executionTask = nil

        for step in plan.steps {
            if var mutableStep = planSteps[step.id] {
                mutableStep.status = .cancelled
                planSteps[step.id] = mutableStep
            }
        }

        if let index = activePlans.firstIndex(where: { $0.id == planID }) {
            activePlans.remove(at: index)
        }
        updateStatistics()
    }

    public func replan(_ goalID: UUID) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        guard let existingPlan = plans.values.first(where: { $0.goalID == goalID }) else {
            return generatePlan(for: goalID)
        }

        var newPlan = existingPlan
        newPlan.status = .replanning
        newPlan.steps = generateSteps(for: goals[goalID] ?? Goal(name: "Unknown", description: "Unknown"))
        newPlan.ordering = topologicalSort(steps: newPlan.steps)
        newPlan.estimatedTotalDuration = newPlan.steps.reduce(0) { $0 + $1.estimatedDuration }
        newPlan.confidence = calculatePlanConfidence(steps: newPlan.steps)

        plans[existingPlan.id] = newPlan
        for step in newPlan.steps {
            planSteps[step.id] = step
        }

        planningHistory.append(PlanExecutionRecord(planID: newPlan.id, duration: 0, success: false, reason: "REPLAN"))
        updateStatistics()
        return newPlan.id
    }
}

// MARK: - Validation

extension AgentPlanningEngine {
    public func validatePlan(_ planID: UUID) -> PlanValidationResult {
        lock.lock()
        defer { lock.unlock() }
        guard let plan = plans[planID] else {
            return PlanValidationResult(isValid: false, errors: ["Plan not found"])
        }

        var errors: [String] = []
        var warnings: [String] = []
        var riskFactors: [String] = []

        if plan.steps.isEmpty {
            errors.append("Plan has no steps")
        }

        for step in plan.steps {
            if step.dependencies.isEmpty && !plan.ordering.contains(step.id) && plan.ordering.first != step.id {
                warnings.append("Step \(step.name) may have unmet dependencies")
            }
            if step.estimatedDuration <= 0 {
                errors.append("Step \(step.name) has invalid duration")
            }
            if step.maxRetries < 0 {
                warnings.append("Step \(step.name) has negative retry count")
            }
        }

        let cycleResult = detectCycles(in: plan.steps)
        if !cycleResult.isEmpty {
            errors.append("Cyclic dependency detected: \(cycleResult.joined(separator: ", "))")
            riskFactors.append("Cyclic dependencies")
        }

        let estimatedSuccessRate = plan.confidence
        if estimatedSuccessRate < 0.5 {
            warnings.append("Plan confidence is low")
            riskFactors.append("Low confidence")
        }

        return PlanValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            estimatedSuccessRate: estimatedSuccessRate,
            riskFactors: riskFactors
        )
    }

    private func detectCycles(in steps: [PlanStep]) -> [String] {
        var visited: Set<UUID> = []
        var recursionStack: Set<UUID> = []
        var cycles: [String] = []
        let stepMap = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })

        func dfs(_ stepID: UUID) -> Bool {
            visited.insert(stepID)
            recursionStack.insert(stepID)

            guard let step = stepMap[stepID] else { return false }
            for depID in step.dependencies {
                if !visited.contains(depID) {
                    if dfs(depID) { return true }
                } else if recursionStack.contains(depID) {
                    cycles.append("\(stepID)")
                    return true
                }
            }

            recursionStack.remove(stepID)
            return false
        }

        for step in steps {
            if !visited.contains(step.id) {
                _ = dfs(step.id)
            }
        }

        return cycles
    }
}

// MARK: - Action Library

extension AgentPlanningEngine {
    private func loadDefaultActions() {
        let defaultActions: [ActionDefinition] = [
            ActionDefinition(name: "analyze_data", description: "Analyze input data and extract insights", parameters: ["input": "string", "mode": "string"], preconditions: ["data_available"], effects: ["analysis_complete"]),
            ActionDefinition(name: "fetch_telemetry", description: "Fetch real-time telemetry data", parameters: ["symbol": "string", "interval": "string"], preconditions: ["network_available"], effects: ["telemetry_fetched"]),
            ActionDefinition(name: "run_inference", description: "Run neural network inference", parameters: ["model_id": "string", "input_data": "binary"], preconditions: ["model_loaded"], effects: ["inference_complete"]),
            ActionDefinition(name: "validate_output", description: "Validate output against schema", parameters: ["schema": "string", "data": "binary"], preconditions: ["schema_available"], effects: ["validation_complete"]),
            ActionDefinition(name: "send_notification", description: "Send notification to user", parameters: ["channel": "string", "message": "string"], preconditions: ["user_configured"], effects: ["notification_sent"]),
            ActionDefinition(name: "update_model", description: "Update model with new weights", parameters: ["model_id": "string", "weights": "binary"], preconditions: ["training_complete"], effects: ["model_updated"]),
            ActionDefinition(name: "check_risk", description: "Check portfolio risk metrics", parameters: ["portfolio_id": "string"], preconditions: ["portfolio_loaded"], effects: ["risk_checked"]),
            ActionDefinition(name: "execute_trade", description: "Execute trade on exchange", parameters: ["pair": "string", "size": "double", "side": "string"], preconditions: ["risk_approved", "exchange_connected"], effects: ["trade_executed"])
        ]

        for action in defaultActions {
            actionLibrary[action.name] = action
        }
    }

    public func registerAction(_ action: ActionDefinition) {
        lock.lock()
        defer { lock.unlock() }
        actionLibrary[action.name] = action
    }

    public func getAction(_ name: String) -> ActionDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return actionLibrary[name]
    }

    public func getAllActions() -> [ActionDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return Array(actionLibrary.values)
    }
}

public struct ActionDefinition: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var parameters: [String: String]
    public var preconditions: [String]
    public var effects: [String]
    public var estimatedDuration: TimeInterval
    public var retryable: Bool

    public init(id: UUID = UUID(), name: String, description: String, parameters: [String: String] = [:], preconditions: [String] = [], effects: [String] = [], estimatedDuration: TimeInterval = 1, retryable: Bool = true) {
        self.id = id
        self.name = name
        self.description = description
        self.parameters = parameters
        self.preconditions = preconditions
        self.effects = effects
        self.estimatedDuration = estimatedDuration
        self.retryable = retryable
    }
}

// MARK: - Statistics

extension AgentPlanningEngine {
    private func updateStatistics() {
        let totalDuration = completedPlans.compactMap { plan in
            guard let end = plan.completedAt, let start = plan.startedAt else { return nil }
            return end.timeIntervalSince(start)
        }
        let avgDuration = totalDuration.isEmpty ? 0 : totalDuration.reduce(0, +) / Double(totalDuration.count)

        let totalSteps = planSteps.values.reduce(0) { $0 + $1.retryCount }
        let avgStepsPerPlan = plans.isEmpty ? 0 : Double(planSteps.count) / Double(plans.count)

        statistics = PlanningStatistics(
            totalGoals: goals.count,
            totalPlans: plans.count,
            activePlans: activePlans.count,
            completedPlans: completedPlans.count,
            averagePlanDuration: avgDuration,
            averageStepsPerPlan: avgStepsPerPlan,
            totalActionsDefined: actionLibrary.count,
            totalReplans: planningHistory.filter { $0.reason?.contains("REPLAN") == true }.count,
            successRate: completedPlans.isEmpty ? 0 : Double(completedPlans.filter { $0.status == .completed }.count) / Double(completedPlans.count)
        )
    }
}

public struct PlanningStatistics: Sendable {
    public var totalGoals: Int
    public var totalPlans: Int
    public var activePlans: Int
    public var completedPlans: Int
    public var averagePlanDuration: TimeInterval
    public var averageStepsPerPlan: Double
    public var totalActionsDefined: Int
    public var totalReplans: Int
    public var successRate: Double

    public init(totalGoals: Int = 0, totalPlans: Int = 0, activePlans: Int = 0, completedPlans: Int = 0, averagePlanDuration: TimeInterval = 0, averageStepsPerPlan: Double = 0, totalActionsDefined: Int = 0, totalReplans: Int = 0, successRate: Double = 0) {
        self.totalGoals = totalGoals
        self.totalPlans = totalPlans
        self.activePlans = activePlans
        self.completedPlans = completedPlans
        self.averagePlanDuration = averagePlanDuration
        self.averageStepsPerPlan = averageStepsPerPlan
        self.totalActionsDefined = totalActionsDefined
        self.totalReplans = totalReplans
        self.successRate = successRate
    }
}

public struct PlanExecutionRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let planID: UUID
    public let duration: TimeInterval
    public let success: Bool
    public var reason: String?
    public let timestamp: Date

    public init(id: UUID = UUID(), planID: UUID, duration: TimeInterval, success: Bool, reason: String? = nil) {
        self.id = id
        self.planID = planID
        self.duration = duration
        self.success = success
        self.reason = reason
        self.timestamp = Date()
    }
}

public struct ReplanTrigger: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var goalID: UUID
    public var planID: UUID
    public var reason: String
    public var timestamp: Date
    public var isActive: Bool

    public init(id: UUID = UUID(), goalID: UUID, planID: UUID, reason: String) {
        self.id = id
        self.goalID = goalID
        self.planID = planID
        self.reason = reason
        self.timestamp = Date()
        self.isActive = true
    }
}
