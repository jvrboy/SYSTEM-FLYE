import Foundation
import Combine

// MARK: - Advanced Agents Registry
// 15 specialised agents beyond the 15 default orchestrator agents (ORBIT, MIXER,
// SENTINEL, CONDUCTOR, CARTOGRAPHER, ORACLE, ATLAS, NOVA, HARBOR, ZENITH, PULSE,
// VECTOR, MIRAGE, SAGE, BEACON). These add deep, domain-specific capabilities
// that route through AgentOrchestrator.shared.

/// Catalogues every specialised agent the FLYE platform knows about, including
/// the 15 default orchestrator agents plus 15 advanced extension agents.
public enum AdvancedAgentsCatalog {
    public static let allAgentIDs: [String] = defaultAgents + advancedAgents

    public static let defaultAgents: [String] = [
        "ORBIT", "MIXER", "SENTINEL", "CONDUCTOR", "CARTOGRAPHER",
        "ORACLE", "ATLAS", "NOVA", "HARBOR", "ZENITH",
        "PULSE", "VECTOR", "MIRAGE", "SAGE", "BEACON",
    ]

    /// Advanced extension agents — added in this file.
    public static let advancedAgents: [String] = [
        "ECHO",       // backtest replay + walk-forward
        "PRISM",      // multi-timeframe confluence
        "NEXUS",      // cross-venue order book fusion
        "TITAN",      // deep-learning volatility forecaster
        "GLYPH",      // pattern library curator
        "AURORA",     // news-driven regime classifier
        "DRIFT",      // execution drift monitor
        "LATTICE",    // multi-asset portfolio lattice
        "COBALT",     // reinforcement learning trainer
        "ZEPHYR",     // sentiment velocity tracker
        "QUARK",      // microstructure analyser
        "OBSIDIAN",   // dark-pool flow inference
        "HALO",       // exogenous risk monitor (macro shocks)
        "VANTA",      // generative strategy synthesiser
        "ATOLL",      // safe-haven rotation engine
    ]
}

/// A description record that the UI uses to render agent cards and the
/// orchestrator uses to seed advanced agents on launch.
public struct AdvancedAgentDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let role: String
    public let capabilities: [String]
    public let accentColor: String
    public let confidence: Double
    public let category: AgentCategory
    public let icon: String

    public enum AgentCategory: String, Hashable, Sendable, CaseIterable {
        case market
        case risk
        case execution
        case neural
        case audio
        case infrastructure
        case research
    }

    public init(
        id: String,
        name: String,
        role: String,
        capabilities: [String],
        accentColor: String,
        confidence: Double,
        category: AgentCategory,
        icon: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.capabilities = capabilities
        self.accentColor = accentColor
        self.confidence = confidence
        self.category = category
        self.icon = icon
    }
}

/// Static catalogue of advanced agent descriptors.
public enum AdvancedAgentLibrary {
    public static let all: [AdvancedAgentDescriptor] = [
        AdvancedAgentDescriptor(
            id: "echo", name: "ECHO",
            role: "Backtest replay and walk-forward verification",
            capabilities: ["backtest.replay", "walkforward.run", "metrics.compute", "regime.fold"],
            accentColor: "#22D3EE", confidence: 0.93, category: .research, icon: "arrow.uturn.forward.circle"
        ),
        AdvancedAgentDescriptor(
            id: "prism", name: "PRISM",
            role: "Multi-timeframe confluence engine",
            capabilities: ["tf.fuse", "confluence.score", "divergence.flag", "tf.bias"],
            accentColor: "#A78BFA", confidence: 0.91, category: .market, icon: "scope"
        ),
        AdvancedAgentDescriptor(
            id: "nexus", name: "NEXUS",
            role: "Cross-venue order book fusion",
            capabilities: ["book.fuse", "venue.aggregate", "imbalance.detect", "liquidity.map"],
            accentColor: "#60A5FA", confidence: 0.89, category: .execution, icon: "rectangle.split.3x1.fill"
        ),
        AdvancedAgentDescriptor(
            id: "titan", name: "TITAN",
            role: "Deep-learning volatility forecaster",
            capabilities: ["vol.forecast", "garch.fit", "egarch.fit", "smile.surface"],
            accentColor: "#F59E0B", confidence: 0.86, category: .neural, icon: "brain.head.profile"
        ),
        AdvancedAgentDescriptor(
            id: "glyph", name: "GLYPH",
            role: "Pattern library curator",
            capabilities: ["pattern.curate", "similarity.cluster", "library.update", "annotation.label"],
            accentColor: "#F472B6", confidence: 0.88, category: .research, icon: "book.fill"
        ),
        AdvancedAgentDescriptor(
            id: "aurora", name: "AURORA",
            role: "News-driven regime classifier",
            capabilities: ["news.regime", "narrative.classify", "impact.score", "topic.cluster"],
            accentColor: "#34D399", confidence: 0.85, category: .market, icon: "newspaper.fill"
        ),
        AdvancedAgentDescriptor(
            id: "drift", name: "DRIFT",
            role: "Execution drift monitor",
            capabilities: ["drift.track", "slippage.attribute", "fill.monitor", "benchmark.compare"],
            accentColor: "#F97316", confidence: 0.92, category: .execution, icon: "waveform.path.ecg"
        ),
        AdvancedAgentDescriptor(
            id: "lattice", name: "LATTICE",
            role: "Multi-asset portfolio lattice",
            capabilities: ["lattice.build", "exposure.map", "factor.allocate", "risk.parity"],
            accentColor: "#8B5CF6", confidence: 0.90, category: .risk, icon: "square.grid.3x3.fill"
        ),
        AdvancedAgentDescriptor(
            id: "cobalt", name: "COBALT",
            role: "Reinforcement learning trainer",
            capabilities: ["rl.train", "policy.update", "reward.shape", "epsilon.decay"],
            accentColor: "#06B6D4", confidence: 0.82, category: .neural, icon: "atom"
        ),
        AdvancedAgentDescriptor(
            id: "zephyr", name: "ZEPHYR",
            role: "Sentiment velocity tracker",
            capabilities: ["sentiment.velocity", "narrative.trend", "burst.detect", "tone.diff"],
            accentColor: "#0EA5E9", confidence: 0.87, category: .market, icon: "wind"
        ),
        AdvancedAgentDescriptor(
            id: "quark", name: "QUARK",
            role: "Microstructure analyser",
            capabilities: ["microstructure.analyse", "spread.model", "toxicity.flow", "kyle.lambda"],
            accentColor: "#EF4444", confidence: 0.84, category: .market, icon: "circle.hexagongrid.fill"
        ),
        AdvancedAgentDescriptor(
            id: "obsidian", name: "OBSIDIAN",
            role: "Dark-pool flow inference",
            capabilities: ["darkpool.infer", "block.detect", "smoke.signal", "venue.route"],
            accentColor: "#1F2937", confidence: 0.81, category: .execution, icon: "moon.fill"
        ),
        AdvancedAgentDescriptor(
            id: "halo", name: "HALO",
            role: "Exogenous risk monitor (macro shocks)",
            capabilities: ["macro.shock", "geopolitical.scan", "tail.event", "contagion.map"],
            accentColor: "#F43F5E", confidence: 0.88, category: .risk, icon: "exclamationmark.shield.fill"
        ),
        AdvancedAgentDescriptor(
            id: "vanta", name: "VANTA",
            role: "Generative strategy synthesiser",
            capabilities: ["strategy.generate", "grammar.synthesise", "constraint.satisfy", "pareto.search"],
            accentColor: "#10B981", confidence: 0.83, category: .research, icon: "wand.and.stars"
        ),
        AdvancedAgentDescriptor(
            id: "atoll", name: "ATOLL",
            role: "Safe-haven rotation engine",
            capabilities: ["safe.haven.rotate", "gold.gold/bond.route", "flight.quality", "yield.curve"],
            accentColor: "#EAB308", confidence: 0.89, category: .risk, icon: "shield.checkered"
        ),
    ]

    public static func descriptors(for category: AdvancedAgentDescriptor.AgentCategory) -> [AdvancedAgentDescriptor] {
        all.filter { $0.category == category }
    }
}

/// Observable registry that exposes the advanced agent library to SwiftUI
/// views and lets the operator enable/disable individual agents or all of
/// them via `seedIntoOrchestrator()`.
@MainActor
public final class AdvancedAgentsRegistry: ObservableObject {
    public static let shared = AdvancedAgentsRegistry()

    @Published public private(set) var registered: [AdvancedAgentDescriptor] = []
    @Published public var enabledAgentIDs: Set<String> = []
    @Published public private(set) var lastSeededAt: Date?

    public init() {
        registered = AdvancedAgentLibrary.all
        enabledAgentIDs = Set(registered.map(\.id))
    }

    /// Register every enabled advanced agent into the global orchestrator
    /// so its dispatcher can route tasks to them.
    public func seedIntoOrchestrator() {
        for descriptor in registered where enabledAgentIDs.contains(descriptor.id) {
            let agent = AgentDefinition(
                name: descriptor.name,
                role: descriptor.role,
                capabilities: descriptor.capabilities,
                status: .ready,
                load: 0,
                successRate: descriptor.confidence,
                averageLatency: Double.random(in: 0.2...0.9),
                maxConcurrency: 6,
                accentColor: descriptor.accentColor
            )
            AgentOrchestrator.shared.registerAgent(agent)
        }
        lastSeededAt = Date()
    }

    public func toggle(_ id: String) {
        if enabledAgentIDs.contains(id) {
            enabledAgentIDs.remove(id)
        } else {
            enabledAgentIDs.insert(id)
        }
    }

    public func enableAll() {
        enabledAgentIDs = Set(registered.map(\.id))
    }

    public func disableAll() {
        enabledAgentIDs.removeAll()
    }

    public func agents(in category: AdvancedAgentDescriptor.AgentCategory) -> [AdvancedAgentDescriptor] {
        registered.filter { $0.category == category }
    }
}

// MARK: - Agent Skill Matrix
// Each advanced agent declares a set of capabilities; the SkillMatrix maps
// these capabilities onto the FLYE skill registry so the orchestrator can
// route tasks by capability rather than by agent name.

public enum AgentSkillMatrix {
    /// Map an advanced agent id to its primary skill (used for routing).
    public static func primarySkill(for id: String) -> String? {
        guard let descriptor = AdvancedAgentLibrary.all.first(where: { $0.id == id }) else { return nil }
        return descriptor.capabilities.first
    }

    /// Return all agent ids that declare a given capability.
    public static func agentsWith(capability: String) -> [String] {
        AdvancedAgentLibrary.all
            .filter { $0.capabilities.contains(capability) }
            .map(\.name)
    }

    /// Build a capability -> [agentName] lookup table.
    public static var capabilityIndex: [String: [String]] {
        var index: [String: [String]] = [:]
        for descriptor in AdvancedAgentLibrary.all {
            for cap in descriptor.capabilities {
                index[cap, default: []].append(descriptor.name)
            }
        }
        return index
    }
}
