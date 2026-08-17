import Foundation
import Accelerate

// MARK: - Expert System Models
struct KnowledgeBase: Codable, Identifiable {
    let id = UUID()
    var facts: [Fact]
    var rules: [Rule]
    var goals: [Goal]
    var heuristics: [Heuristic]
    var timestamp: Date
    var version: String

    struct Fact: Codable, Identifiable {
        let id = UUID()
        var name: String
        var value: AnyCodable
        var confidence: Double
        var source: FactSource
        var timestamp: Date
        var expiry: Date?
        var tags: [String]
        var context: [String: String]
        var priority: Int

        enum FactSource: String, Codable { case user, sensor, inferred, rule, external, calculated }
    }

    struct Rule: Codable, Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var conditions: [Condition]
        var actions: [Action]
        var certaintyFactor: Double
        var priority: Int
        var active: Bool
        var tags: [String]
        var timestamp: Date
        var executionCount: Int
        var lastTriggered: Date?
        var effectivenessScore: Double

        struct Condition: Codable, Identifiable {
            let id = UUID()
            var factName: String
            var operator: ConditionOperator
            var value: AnyCodable
            var negation: Bool
            var weight: Double
            var context: [String: String]

            enum ConditionOperator: String, Codable, CaseIterable {
                case equals = "EQUALS"
                case notEquals = "NOT_EQUALS"
                case greaterThan = "GREATER_THAN"
                case lessThan = "LESS_THAN"
                case greaterThanOrEqual = "GREATER_THAN_OR_EQUAL"
                case lessThanOrEqual = "LESS_THAN_OR_EQUAL"
                case contains = "CONTAINS"
                case matches = "MATCHES"
                case exists = "EXISTS"
                case notExists = "NOT_EXISTS"
                case between = "BETWEEN"
                case inSet = "IN_SET"
                case fuzzyMatch = "FUZZY_MATCH"
            }
        }

        struct Action: Codable, Identifiable {
            let id = UUID()
            var type: ActionType
            var parameters: [String: AnyCodable]
            var priority: Int
            var condition: ActionCondition

            enum ActionType: String, Codable, CaseIterable {
                case assert = "ASSERT"
                case retract = "RETRACT"
                case modify = "MODIFY"
                case execute = "EXECUTE"
                case notify = "NOTIFY"
                case calculate = "CALCULATE"
                case log = "LOG"
                case query = "QUERY"
                case defer = "DEFER"
                case halt = "HALT"
            }

            enum ActionCondition: String, Codable { case always = "ALWAYS", onSuccess = "ON_SUCCESS", onFailure = "ON_FAILURE", conditional = "CONDITIONAL" }
        }
    }

    struct Goal: Codable, Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var conditions: [Rule.Condition]
        var priority: Int
        var active: Bool
        var parentGoal: UUID?
        var subgoals: [UUID]
        var completionCriteria: [String: AnyCodable]
        var deadline: Date?
    }

    struct Heuristic: Codable, Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var applicabilityCondition: Rule.Condition
        var advice: String
        var confidence: Double
        var source: String
        var priority: Int
    }
}

struct InferenceResult: Codable, Identifiable {
    let id = UUID()
    var conclusion: String
    var confidence: Double
    var supportingFacts: [String]
    var triggeredRules: [String]
    var inferencePath: [String]
    var timestamp: Date
    var explanation: String
    var alternatives: [AlternativeConclusion]

    struct AlternativeConclusion: Codable, Identifiable {
        let id = UUID()
        var conclusion: String
        var confidence: Double
        var reasoning: String
        var rejectedReason: String
    }

    init(conclusion: String, confidence: Double = 0, supportingFacts: [String] = [], triggeredRules: [String] = [], inferencePath: [String] = [], explanation: String = "", alternatives: [AlternativeConclusion] = [], timestamp: Date = Date()) {
        self.id = UUID()
        self.conclusion = conclusion
        self.confidence = max(0, min(1, confidence))
        self.supportingFacts = supportingFacts
        self.triggeredRules = triggeredRules
        self.inferencePath = inferencePath
        self.timestamp = timestamp
        self.explanation = explanation
        self.alternatives = alternatives
    }
}

struct ExpertSystemReport: Codable, Identifiable {
    let id = UUID()
    var inferences: [InferenceResult]
    var factsEvaluated: Int
    var rulesTriggered: Int
    var executionTimeMs: Double
    var conflicts: [ConflictResolution]
    var explanations: [String]
    var recommendations: [String]
    var timestamp: Date

    struct ConflictResolution: Codable, Identifiable {
        let id = UUID()
        var rule1: String
        var rule2: String
        var resolution: String
        var strategy: ResolutionStrategy
        var confidence: Double
        var timestamp: Date

        enum ResolutionStrategy: String, Codable { case priority, specificity, recency, certainty, none }
    }

    init(inferences: [InferenceResult] = [], factsEvaluated: Int = 0, rulesTriggered: Int = 0, executionTimeMs: Double = 0, conflicts: [ConflictResolution] = [], explanations: [String] = [], recommendations: [String] = [], timestamp: Date = Date()) {
        self.id = UUID()
        self.inferences = inferences
        self.factsEvaluated = factsEvaluated
        self.rulesTriggered = rulesTriggered
        self.executionTimeMs = executionTimeMs
        self.conflicts = conflicts
        self.explanations = explanations
        self.recommendations = recommendations
        self.timestamp = timestamp
    }
}

// MARK: - Expert System Engine
@MainActor
final class ExpertSystem: ObservableObject {
    static let shared = ExpertSystem()
    @Published private(set) var knowledgeBase: KnowledgeBase = KnowledgeBase(facts: [], rules: [], goals: [], heuristics: [], timestamp: Date(), version: "1.0")
    @Published private(set) var results: [ExpertSystemReport] = []
    @Published private(set) var isInferencing = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50
    private var inferenceCache: [String: InferenceResult] = [:]

    func loadKnowledgeBase(_ kb: KnowledgeBase) {
        knowledgeBase = kb
        inferenceCache.removeAll()
    }

    func addFact(_ fact: KnowledgeBase.Fact) {
        knowledgeBase.facts.append(fact)
        inferenceCache.removeAll()
    }

    func addRule(_ rule: KnowledgeBase.Rule) {
        knowledgeBase.rules.append(rule)
        inferenceCache.removeAll()
    }

    func addHeuristic(_ heuristic: KnowledgeBase.Heuristic) {
        knowledgeBase.heuristics.append(heuristic)
    }

    func forwardChain(query: String, maxDepth: Int = 10) async -> [InferenceResult] {
        guard !isInferencing else { return [] }
        isInferencing = true
        defer { isInferencing = false }
        let startTime = Date()
        var inferences: [InferenceResult] = []
        var workingMemory = knowledgeBase.facts
        var triggeredRules: Set<String> = []
        var changed = true
        var depth = 0
        while changed && depth < maxDepth {
            changed = false
            depth += 1
            for rule in knowledgeBase.rules.sorted(by: { $0.priority > $1.priority }) where rule.active && !triggeredRules.contains(rule.id.uuidString) {
                if evaluateConditions(rule.conditions, facts: workingMemory) {
                    triggeredRules.insert(rule.id.uuidString)
                    let newFacts = executeActions(rule.actions, facts: workingMemory)
                    for newFact in newFacts where !workingMemory.contains(where: { $0.name == newFact.name }) {
                        workingMemory.append(newFact)
                        changed = true
                    }
                    let confidence = rule.certaintyFactor * workingMemory.filter { triggeredRules.contains($0.id.uuidString) }.map { $0.confidence }.reduce(1, *)
                    let explanation = generateExplanation(rule: rule, facts: workingMemory)
                    inferences.append(InferenceResult(conclusion: rule.name, confidence: confidence, supportingFacts: rule.conditions.map { $0.factName }, triggeredRules: [rule.id.uuidString], inferencePath: Array(triggeredRules), explanation: explanation))
                }
            }
            for heuristic in knowledgeBase.heuristics.sorted(by: { $0.priority > $1.priority }) {
                if evaluateConditions([heuristic.applicabilityCondition], facts: workingMemory) {
                    inferences.append(InferenceResult(conclusion: heuristic.advice, confidence: heuristic.confidence, supportingFacts: [], triggeredRules: [], inferencePath: ["heuristic: \(heuristic.name)"], explanation: heuristic.description))
                }
            }
        }
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let recommendations = generateRecommendations(inferences: inferences)
        let report = ExpertSystemReport(inferences: inferences, factsEvaluated: workingMemory.count, rulesTriggered: triggeredRules.count, executionTimeMs: executionTime, recommendations: recommendations)
        if results.count >= maxResults { results.removeFirst() }
        results.append(report)
        inferenceCache[query] = inferences.last
        return inferences
    }

    func backwardChain(goal: String, maxDepth: Int = 5) async -> InferenceResult? {
        guard !isInferencing else { return nil }
        isInferencing = true
        defer { isInferencing = false }
        let startTime = Date()
        let supportingFacts = knowledgeBase.facts.filter { fact in
            knowledgeBase.rules.contains { rule in rule.conditions.contains { $0.factName == fact.name } && rule.name == goal }
        }
        let rules = knowledgeBase.rules.filter { $0.name == goal || $0.conditions.contains { $0.factName == goal } }
        guard !rules.isEmpty else { return nil }
        let bestRule = rules.max { $0.certaintyFactor < $1.certaintyFactor } ?? rules[0]
        let confidence = bestRule.certaintyFactor * supportingFacts.map { $0.confidence }.reduce(1, *)
        let explanation = "Backward chaining from goal '\(goal)' using rule '\(bestRule.name)' with \(supportingFacts.count) supporting facts."
        let inference = InferenceResult(conclusion: goal, confidence: confidence, supportingFacts: supportingFacts.map { $0.name }, triggeredRules: [bestRule.id.uuidString], inferencePath: [goal], explanation: explanation)
        let executionTime = Date().timeIntervalSince(startTime) * 1000
        let report = ExpertSystemReport(inferences: [inference], factsEvaluated: knowledgeBase.facts.count, rulesTriggered: 1, executionTimeMs: executionTime)
        results.append(report)
        return inference
    }

    func explain(inference: InferenceResult) -> String {
        var explanation = "Conclusion: \(inference.conclusion) with confidence \(String(format: "%.2f", inference.confidence))\n"
        explanation += "Supporting facts: \(inference.supportingFacts.joined(separator: ", "))\n"
        explanation += "Triggered rules: \(inference.triggeredRules.joined(separator: ", "))\n"
        explanation += "Inference path: \(inference.inferencePath.joined(separator: " -> "))\n"
        if !inference.alternatives.isEmpty {
            explanation += "Alternatives considered:\n"
            for alt in inference.alternatives { explanation += "  - \(alt.conclusion): \(alt.reasoning) (rejected: \(alt.rejectedReason))\n" }
        }
        return explanation
    }

    func getRecommendations(context: [String: Double]) -> [String] {
        var recommendations: [String] = []
        let facts = knowledgeBase.facts.filter { context.keys.contains($0.name) }
        for heuristic in knowledgeBase.heuristics {
            let applicable = evaluateConditions([heuristic.applicabilityCondition], facts: facts)
            if applicable { recommendations.append(heuristic.advice) }
        }
        return recommendations
    }

    private func evaluateConditions(_ conditions: [KnowledgeBase.Rule.Condition], facts: [KnowledgeBase.Fact]) -> Bool {
        for condition in conditions {
            guard let fact = facts.first(where: { $0.name == condition.factName }) else {
                if condition.operator == .exists { continue } else { return false }
            }
            let match: Bool
            switch condition.operator {
            case .equals: match = "\(fact.value)" == "\(condition.value)"
            case .notEquals: match = "\(fact.value)" != "\(condition.value)"
            case .greaterThan: match = (fact.value as? Double ?? 0) > (condition.value as? Double ?? 0)
            case .lessThan: match = (fact.value as? Double ?? 0) < (condition.value as? Double ?? 0)
            case .greaterThanOrEqual: match = (fact.value as? Double ?? 0) >= (condition.value as? Double ?? 0)
            case .lessThanOrEqual: match = (fact.value as? Double ?? 0) <= (condition.value as? Double ?? 0)
            case .contains: match = "\(fact.value)".contains("\(condition.value)")
            case .matches: match = "\(fact.value)".range(of: "\(condition.value)", options: .regularExpression) != nil
            case .exists: match = true
            case .notExists: match = false
            case .between:
                let val = fact.value as? Double ?? 0
                let minVal = condition.value as? Double ?? 0
                let maxVal = condition.parameters["max"] as? Double ?? 0
                match = val >= minVal && val <= maxVal
            case .inSet:
                let setValues = condition.value as? [String] ?? []
                match = setValues.contains("\(fact.value)")
            case .fuzzyMatch:
                let target = condition.value as? Double ?? 0
                let current = fact.value as? Double ?? 0
                match = abs(target - current) < 0.1
            }
            if condition.negation { if match { return false } }
            else { if !match { return false } }
        }
        return true
    }

    private func executeActions(_ actions: [KnowledgeBase.Rule.Action], facts: [KnowledgeBase.Fact]) -> [KnowledgeBase.Fact] {
        var newFacts: [KnowledgeBase.Fact] = []
        for action in actions.sorted(by: { $0.priority > $1.priority }) {
            switch action.type {
            case .assert:
                if let name = action.parameters["name"], let value = action.parameters["value"] {
                    newFacts.append(KnowledgeBase.Fact(name: "\(name)", value: value, confidence: 0.9, source: .inferred))
                }
            case .retract:
                continue
            case .modify:
                continue
            case .execute:
                continue
            case .notify:
                continue
            case .calculate:
                continue
            case .log:
                continue
            case .query:
                continue
            case .defer:
                continue
            case .halt:
                break
            }
        }
        return newFacts
    }

    private func generateExplanation(rule: KnowledgeBase.Rule, facts: [KnowledgeBase.Fact]) -> String {
        var explanation = "Rule '\(rule.name)' fired with certainty factor \(String(format: "%.2f", rule.certaintyFactor)).\n"
        explanation += "Conditions satisfied: \(rule.conditions.map { "\($0.factName) \($0.operator.rawValue) \($0.value)" }.joined(separator: ", "))\n"
        explanation += "Supporting facts: \(rule.conditions.compactMap { cond in facts.first(where: { $0.name == cond.factName })?.name }.joined(separator: ", "))"
        return explanation
    }

    private func generateRecommendations(inferences: [InferenceResult]) -> [String] {
        return inferences.map { "Based on \($0.conclusion): \($0.explanation)" }
    }
}

struct AnyCodable: Codable {
    var value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value } }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool { try container.encode(bool) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let string = value as? String { try container.encode(string) }
        else if let array = value as? [Any] { try container.encode(array.map { AnyCodable($0) }) }
        else if let dict = value as? [String: Any] { try container.encode(dict.mapValues { AnyCodable($0) }) }
        else { try container.encodeNil() }
    }
}
