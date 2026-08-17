import Foundation
import Accelerate

// MARK: - Fuzzy Logic Models
enum FuzzyNorm: String, Codable, CaseIterable {
    case min = "MIN"
    case product = "PRODUCT"
    case lukasiewicz = "LUKASIEWICZ"
    case drastic = "DRAMATIC"
    case einstein = "EINSTEIN"
    case hamacher = "HAMACHER"
    case yager = "YAGER"
    case sugeno = "SUGENO"
}

enum FuzzyImplication: String, Codable, CaseIterable {
    case mamdani = "MAMDANI"
    case Larsen = "LARSEN"
    case lukasiewicz = "LUKASIEWICZ"
    case goedel = "GOEDEL"
    case gain = "GAIN"
    case boudelleBratley = "BODELLE_BRATLEY"
}

enum DefuzzificationMethod: String, Codable, CaseIterable {
    case centroid = "CENTROID"
    case bisector = "BISECTOR"
    case meanOfMaximum = "MOM"
    case largestOfMaximum = "LOM"
    case smallestOfMaximum = "SOM"
    case weightedAverage = "WEIGHTED_AVERAGE"
}

struct FuzzyVariable: Codable, Identifiable {
    let id = UUID()
    var name: String
    var domain: ClosedRange<Double>
    var linguisticTerms: [LinguisticTerm]
    var timestamp: Date

    struct LinguisticTerm: Codable, Identifiable {
        let id = UUID()
        var name: String
        var membershipFunction: MembershipFunction
        var priority: Int

        func membership(at value: Double) -> Double {
            membershipFunction.computeMembership(at: value)
        }
    }

    struct MembershipFunction: Codable, Identifiable {
        let id = UUID()
        var type: MembershipType
        var parameters: [Double]

        enum MembershipType: String, Codable, CaseIterable {
            case triangular = "TRIANGULAR"
            case trapezoidal = "TRAPEZOIDAL"
            case gaussian = "GAUSSIAN"
            case generalizedBell = "GENERALIZED_BELL"
            case sigmoid = "SIGMOID"
            case zShape = "Z_SHAPE"
            case sShape = "S_SHAPE"
            case piShape = "PI_SHAPE"
            case pointSet = "POINT_SET"
        }

        func computeMembership(at value: Double) -> Double {
            guard !parameters.isEmpty else { return 0 }
            switch type {
            case .triangular:
                let a = parameters[0], b = parameters[1], c = parameters[2]
                if value <= a || value >= c { return 0 }
                if value <= b { return (value - a) / max(b - a, 0.0001) }
                return (c - value) / max(c - b, 0.0001)
            case .trapezoidal:
                let a = parameters[0], b = parameters[1], c = parameters[2], d = parameters[3]
                if value <= a || value >= d { return 0 }
                if value <= b { return (value - a) / max(b - a, 0.0001) }
                if value <= c { return 1 }
                return (d - value) / max(d - c, 0.0001)
            case .gaussian:
                let sigma = max(parameters[1], 0.0001)
                return exp(-pow(value - parameters[0], 2) / (2 * sigma * sigma))
            case .generalizedBell:
                let a = max(parameters[0], 0.0001)
                let b = max(parameters[1], 0.0001)
                let c = parameters[2]
                return 1.0 / (1.0 + pow(abs((value - c) / a), 2.0 * b))
            case .sigmoid:
                let a = max(parameters[0], 0.0001)
                let c = parameters[1]
                return 1.0 / (1.0 + exp(-a * (value - c)))
            case .zShape:
                let a = parameters[0], b = parameters[1]
                if value <= a { return 1 }
                if value >= b { return 0 }
                return 1.0 - pow((value - a) / max(b - a, 0.0001), 2)
            case .sShape:
                let a = parameters[0], b = parameters[1]
                if value <= a { return 0 }
                if value >= b { return 1 }
                return pow((value - a) / max(b - a, 0.0001), 2)
            case .piShape:
                let a = parameters[0], b = parameters[1]
                if value <= a { return 0 }
                if value >= b { return 1 }
                let mid = (a + b) / 2
                if value <= mid { return pow((value - a) / (mid - a), 2) }
                return 1.0 - pow((value - mid) / (b - mid), 2)
            case .pointSet:
                return parameters.contains { abs($0 - value) < 0.0001 } ? 1.0 : 0.0
            }
        }
    }
}

struct FuzzyRule: Codable, Identifiable {
    let id = UUID()
    var name: String
    var antecedent: [Antecedent]
    var consequent: Consequent
    var weight: Double
    var priority: Int
    var active: Bool
    var timestamp: Date

    struct Antecedent: Codable, Identifiable {
        let id = UUID()
        var variable: String
        var term: String
        var connector: Connector?

        enum Connector: String, Codable { case and = "AND", or = "OR" }
    }

    struct Consequent: Codable, Identifiable {
        let id = UUID()
        var variable: String
        var term: String
        var consequentType: ConsequentType

        enum ConsequentType: String, Codable { case is_ = "IS", then_ = "THEN" }
    }
}

struct FuzzyInferenceResult: Codable, Identifiable {
    let id = UUID()
    var inputValues: [String: Double]
    var fuzzifiedValues: [String: [String: Double]]
    var ruleActivations: [FuzzyRule: Double]
    var aggregatedOutput: [String: [Double]]
    var defuzzifiedOutputs: [String: Double]
    var crispOutput: [String: Double]
    var confidence: Double
    var timestamp: Date

    init(inputValues: [String: Double] = [:], fuzzifiedValues: [String: [String: Double]] = [:], ruleActivations: [FuzzyRule: Double] = [:], aggregatedOutput: [String: [Double]] = [:], defuzzifiedOutputs: [String: Double] = [:], crispOutput: [String: Double] = [:], confidence: Double = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.inputValues = inputValues
        self.fuzzifiedValues = fuzzifiedValues
        self.ruleActivations = ruleActivations
        self.aggregatedOutput = aggregatedOutput
        self.defuzzifiedOutputs = defuzzifiedOutputs
        self.crispOutput = crispOutput
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - Fuzzy Logic Engine
@MainActor
final class FuzzyLogicEngine: ObservableObject {
    static let shared = FuzzyLogicEngine()
    @Published private(set) var variables: [FuzzyVariable] = []
    @Published private(set) var rules: [FuzzyRule] = []
    @Published private(set) var inferenceResults: [FuzzyInferenceResult] = []
    @Published private(set) var isInferring = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func addVariable(_ variable: FuzzyVariable) {
        variables.append(variable)
    }

    func addRule(_ rule: FuzzyRule) {
        rules.append(rule)
    }

    func createDefaultTradingVariables() {
        let rsiVar = FuzzyVariable(name: "RSI", domain: 0...100, linguisticTerms: [
            FuzzyVariable.LinguisticTerm(name: "low", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [0, 0, 20, 40])),
            FuzzyVariable.LinguisticTerm(name: "medium", membershipFunction: FuzzyVariable.MembershipFunction(type: .triangular, parameters: [20, 50, 80])),
            FuzzyVariable.LinguisticTerm(name: "high", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [60, 80, 100, 100]))
        ])
        let macdVar = FuzzyVariable(name: "MACD", domain: -2...2, linguisticTerms: [
            FuzzyVariable.LinguisticTerm(name: "negative", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [-2, -2, -0.5, 0])),
            FuzzyVariable.LinguisticTerm(name: "zero", membershipFunction: FuzzyVariable.MembershipFunction(type: .gaussian, parameters: [0, 0.3])),
            FuzzyVariable.LinguisticTerm(name: "positive", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [0, 0.5, 2, 2]))
        ])
        let signalVar = FuzzyVariable(name: "Signal", domain: -1...1, linguisticTerms: [
            FuzzyVariable.LinguisticTerm(name: "strong_sell", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [-1, -1, -0.6, -0.3])),
            FuzzyVariable.LinguisticTerm(name: "sell", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [-0.5, -0.3, -0.1, 0])),
            FuzzyVariable.LinguisticTerm(name: "neutral", membershipFunction: FuzzyVariable.MembershipFunction(type: .triangular, parameters: [-0.1, 0, 0.1])),
            FuzzyVariable.LinguisticTerm(name: "buy", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [0, 0.1, 0.3, 0.5])),
            FuzzyVariable.LinguisticTerm(name: "strong_buy", membershipFunction: FuzzyVariable.MembershipFunction(type: .trapezoidal, parameters: [0.3, 0.6, 1, 1]))
        ])
        variables = [rsiVar, macdVar, signalVar]
        let rule1 = FuzzyRule(name: "RSI_Low_MACD_Positive_Buy", antecedent: [
            FuzzyRule.Antecedent(variable: "RSI", term: "low"),
            FuzzyRule.Antecedent(variable: "MACD", term: "positive", connector: .and)
        ], consequent: FuzzyRule.Consequent(variable: "Signal", term: "strong_buy", consequentType: .is_), weight: 1.0, priority: 10, active: true)
        let rule2 = FuzzyRule(name: "RSI_High_MACD_Negative_Sell", antecedent: [
            FuzzyRule.Antecedent(variable: "RSI", term: "high"),
            FuzzyRule.Antecedent(variable: "MACD", term: "negative", connector: .and)
        ], consequent: FuzzyRule.Consequent(variable: "Signal", term: "strong_sell", consequentType: .is_), weight: 1.0, priority: 10, active: true)
        let rule3 = FuzzyRule(name: "RSI_Medium_Neutral", antecedent: [
            FuzzyRule.Antecedent(variable: "RSI", term: "medium")
        ], consequent: FuzzyRule.Consequent(variable: "Signal", term: "neutral", consequentType: .is_), weight: 0.8, priority: 5, active: true)
        rules = [rule1, rule2, rule3]
    }

    func infer(inputs: [String: Double], method: FuzzyImplication = .mamdani, defuzzification: DefuzzificationMethod = .centroid) async -> FuzzyInferenceResult {
        guard !isInferring else { return FuzzyInferenceResult() }
        isInferring = true
        defer { isInferring = false }
        var fuzzifiedValues: [String: [String: Double]] = [:]
        for (varName, value) in inputs {
            guard let variable = variables.first(where: { $0.name == varName }) else { continue }
            var termValues: [String: Double] = [:]
            for term in variable.linguisticTerms { termValues[term.name] = term.membership(at: value) }
            fuzzifiedValues[varName] = termValues
        }
        var ruleActivations: [FuzzyRule: Double] = [:]
        for rule in rules where rule.active {
            var activations: [Double] = []
            var currentConnector: FuzzyRule.Antecedent.Connector = .and
            for (index, antecedent) in rule.antecedent.enumerated() {
                guard let varFuzzified = fuzzifiedValues[antecedent.variable], let membership = varFuzzified[antecedent.term] else { continue }
                if index > 0, let connector = antecedent.connector { currentConnector = connector }
                switch currentConnector {
                case .and: activations.append(membership)
                case .or: activations.append(max(activations.last ?? 0, membership))
                }
            }
            let ruleActivation = activations.min() ?? 0
            ruleActivations[rule] = ruleActivation * rule.weight
        }
        var aggregatedOutput: [String: [Double]] = [:]
        let outputVar = variables.first { $0.name == "Signal" } ?? variables.last
        if let outputVar = outputVar {
            for term in outputVar.linguisticTerms {
                let membershipValues = (Int(outputVar.domain.lowerBound * 100)...Int(outputVar.domain.upperBound * 100)).map { i in
                    let value = Double(i) / 100.0
                    let baseMembership = term.membership(at: value)
                    let maxActivation = ruleActivations.values.max() ?? 0
                    return min(baseMembership, maxActivation)
                }
                aggregatedOutput[term.name] = membershipValues
            }
        }
        var defuzzifiedOutputs: [String: Double] = [:]
        var crispOutput: [String: Double] = [:]
        if let outputVar = outputVar {
            for (termName, memberships) in aggregatedOutput {
                let domainPoints = (Int(outputVar.domain.lowerBound * 100)...Int(outputVar.domain.upperBound * 100)).map { Double($0) / 100.0 }
                let numerator = zip(domainPoints, memberships).map { $0 * $1 }.reduce(0, +)
                let denominator = memberships.reduce(0, +)
                defuzzifiedOutputs[termName] = denominator > 0 ? numerator / denominator : 0
                crispOutput[termName] = defuzzifiedOutputs[termName] ?? 0
            }
        }
        let confidence = ruleActivations.values.max() ?? 0
        let result = FuzzyInferenceResult(inputValues: inputs, fuzzifiedValues: fuzzifiedValues, ruleActivations: ruleActivations, aggregatedOutput: aggregatedOutput, defuzzifiedOutputs: defuzzifiedOutputs, crispOutput: crispOutput, confidence: confidence)
        if inferenceResults.count >= maxResults { inferenceResults.removeFirst() }
        inferenceResults.append(result)
        return result
    }

    func evaluateRule(rule: FuzzyRule, inputs: [String: Double]) -> Double {
        var activations: [Double] = []
        var currentConnector: FuzzyRule.Antecedent.Connector = .and
        for (index, antecedent) in rule.antecedent.enumerated() {
            guard let variable = variables.first(where: { $0.name == antecedent.variable }),
                  let inputValue = inputs[antecedent.variable],
                  let term = variable.linguisticTerms.first(where: { $0.name == antecedent.term }) else { continue }
            if index > 0, let connector = antecedent.connector { currentConnector = connector }
            let membership = term.membership(at: inputValue)
            switch currentConnector {
            case .and: activations.append(membership)
            case .or: activations.append(max(activations.last ?? 0, membership))
            }
        }
        return activations.min() ?? 0
    }

    func createFuzzyController(inputVariables: [FuzzyVariable], outputVariables: [FuzzyVariable], rules: [FuzzyRule]) -> FuzzyController {
        return FuzzyController(inputVariables: inputVariables, outputVariables: outputVariables, rules: rules, engine: self)
    }
}

struct FuzzyController: Codable, Identifiable {
    let id = UUID()
    let inputVariables: [FuzzyVariable]
    let outputVariables: [FuzzyVariable]
    let rules: [FuzzyRule]
    let engine: FuzzyLogicEngine

    func control(inputs: [String: Double]) async -> [String: Double] {
        let result = await engine.infer(inputs: inputs)
        return result.crispOutput
    }
}
