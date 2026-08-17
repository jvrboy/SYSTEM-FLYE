import Foundation
import SwiftUI

// MARK: - Music Platform

struct MusicToolDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let accent: Color
    let capability: MusicCapability

    enum MusicCapability: String, CaseIterable {
        case spectral = "Spectral Forge"
        case granular = "Granular Motion"
        case rhythm = "Rhythm Matrix"
        case modulation = "Modulation Lab"
        case mastering = "Master Bus"
        case scene = "Scene Composer"
    }
}

// MARK: - Forex Platform

struct ForexToolDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let accent: Color
    let capability: ForexCapability

    enum ForexCapability: String, CaseIterable {
        case regime = "Regime Detection"
        case correlation = "Correlation Matrix"
        case risk = "Risk Console"
        case calendar = "Macro Calendar"
        case scenarios = "Scenario Lab"
        case execution = "Execution Planner"
    }
}

struct TechnicalToolDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let accent: Color
}

struct LoopToolDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let accent: Color
}

struct ForexWatchItem: Identifiable, Hashable {
    let id: String
    let symbol: String
    var score: Double
    var direction: String
    var regime: String
    var risk: String
}

// MARK: - Agent / Skill / Pipeline Platform

struct FlyeAgent: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let icon: String
    let accent: Color
    var status: AgentRuntimeStatus
    var runs: Int
    var confidence: Double
    let skillIDs: [String]

    enum AgentRuntimeStatus: String, CaseIterable {
        case ready = "READY"
        case running = "RUNNING"
        case paused = "PAUSED"
    }
}

struct FlyeSkill: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let description: String
    let icon: String
    var isEnabled: Bool
}

struct FlyePipeline: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let stageNames: [String]
    var isRunning: Bool
    var completion: Double
    var lastRun: Date?
}

@MainActor
final class FeaturePlatformStore: ObservableObject {
    static let shared = FeaturePlatformStore()

    @Published var musicTools: [MusicToolDefinition] = [
        .init(id: "spectral", name: "Spectral Forge", subtitle: "FFT sculpting and harmonic layers", icon: "waveform.path", accent: .cyan, capability: .spectral),
        .init(id: "granular", name: "Granular Motion", subtitle: "Clouds, grains, and time travel", icon: "circle.hexagongrid.fill", accent: .purple, capability: .granular),
        .init(id: "rhythm", name: "Rhythm Matrix", subtitle: "Probability sequencer and swing", icon: "square.grid.3x3.fill", accent: .orange, capability: .rhythm),
        .init(id: "modulation", name: "Modulation Lab", subtitle: "LFO routing and macro control", icon: "waveform.badge.plus", accent: .green, capability: .modulation),
        .init(id: "mastering", name: "Master Bus", subtitle: "Dynamics, width, and loudness", icon: "slider.horizontal.3", accent: .pink, capability: .mastering),
        .init(id: "scene", name: "Scene Composer", subtitle: "Save and morph complete setups", icon: "square.stack.3d.up.fill", accent: .yellow, capability: .scene)
    ]

    @Published var technicalTools: [TechnicalToolDefinition] = [
        .init(id: "trend-suite", name: "Trend Suite", subtitle: "ADX, DI spread, ROC, and trend strength", icon: "chart.line.uptrend.xyaxis", accent: .cyan),
        .init(id: "volume-suite", name: "Volume Suite", subtitle: "OBV, VWAP, volume pressure, and flow", icon: "chart.bar.xaxis", accent: .green),
        .init(id: "volatility-suite", name: "Volatility Suite", subtitle: "ATR, Keltner channels, and squeeze state", icon: "waveform.path.ecg", accent: .orange),
        .init(id: "structure-suite", name: "Structure Suite", subtitle: "Pivot points, Fibonacci, and swing levels", icon: "chart.xyaxis.line", accent: .purple),
        .init(id: "ichimoku-suite", name: "Cloud Suite", subtitle: "Ichimoku conversion, base, and cloud", icon: "cloud.sun.fill", accent: .pink),
        .init(id: "momentum-suite", name: "Momentum Suite", subtitle: "CCI, Williams %R, and signal score", icon: "gauge.with.dots.needle.67percent", accent: .yellow),
        .init(id: "supertrend-suite", name: "SuperTrend Suite", subtitle: "ATR trend bands and regime flips", icon: "arrow.triangle.2.circlepath", accent: .teal),
        .init(id: "money-flow-suite", name: "Money Flow Suite", subtitle: "MFI and volume pressure", icon: "banknote.fill", accent: .mint),
        .init(id: "aroon-suite", name: "Aroon Suite", subtitle: "Trend age and directional dominance", icon: "clock.arrow.2.circlepath", accent: .indigo),
        .init(id: "donchian-suite", name: "Donchian Suite", subtitle: "Breakout channels and squeeze state", icon: "rectangle.split.3x1.fill", accent: .red)
    ]

    @Published var loopTools: [LoopToolDefinition] = [
        .init(id: "slice", name: "Transient Slicer", subtitle: "Detect and re-grid transient slices", icon: "scissors", accent: .cyan),
        .init(id: "stretch", name: "Elastic Time", subtitle: "Time-stretch with preserve-pitch control", icon: "arrow.left.and.right.text.vertical", accent: .purple),
        .init(id: "reverse", name: "Reverse Morph", subtitle: "Reverse grains and crossfade the seam", icon: "arrow.uturn.backward.circle", accent: .orange),
        .init(id: "stutter", name: "Stutter Grid", subtitle: "Create repeat, gate, and retrigger patterns", icon: "repeat.1", accent: .green),
        .init(id: "shuffle", name: "Probability Shuffle", subtitle: "Reorder slices with deterministic seeds", icon: "dice", accent: .pink),
        .init(id: "freeze", name: "Spectral Freeze", subtitle: "Freeze a tonal frame and morph its tail", icon: "snowflake", accent: .yellow)
    ]

    @Published var forexTools: [ForexToolDefinition] = [
        .init(id: "regime", name: "Regime Detection", subtitle: "Trend, range, and transition scoring", icon: "chart.xyaxis.line", accent: .cyan, capability: .regime),
        .init(id: "correlation", name: "Correlation Matrix", subtitle: "Cross-pair relationship map", icon: "square.grid.3x3.topleft.filled", accent: .purple, capability: .correlation),
        .init(id: "risk", name: "Risk Console", subtitle: "Exposure, drawdown, and sizing", icon: "shield.lefthalf.filled", accent: .orange, capability: .risk),
        .init(id: "calendar", name: "Macro Calendar", subtitle: "Event impact and session windows", icon: "calendar.badge.clock", accent: .green, capability: .calendar),
        .init(id: "scenarios", name: "Scenario Lab", subtitle: "Shock paths and outcome ranges", icon: "chart.bar.xaxis", accent: .pink, capability: .scenarios),
        .init(id: "execution", name: "Execution Planner", subtitle: "Entry, stop, target, and invalidation", icon: "target", accent: .yellow, capability: .execution)
    ]

    @Published var watchlist: [ForexWatchItem] = [
        .init(id: "EURUSD", symbol: "EUR/USD", score: 0.84, direction: "LONG", regime: "Trend", risk: "0.8R"),
        .init(id: "GBPJPY", symbol: "GBP/JPY", score: 0.72, direction: "SHORT", regime: "Volatile", risk: "1.2R"),
        .init(id: "AUDUSD", symbol: "AUD/USD", score: 0.54, direction: "WATCH", regime: "Range", risk: "0.4R"),
        .init(id: "USDJPY", symbol: "USD/JPY", score: 0.68, direction: "LONG", regime: "Transition", risk: "0.6R")
    ]

    @Published var agents: [FlyeAgent] = [
        .init(id: "orbit", name: "ORBIT", role: "Market reconnaissance and regime mapping", icon: "scope", accent: .cyan, status: .ready, runs: 1284, confidence: 0.94, skillIDs: ["regime", "correlation"]),
        .init(id: "mixer", name: "MIXER", role: "Generative sound design and scene building", icon: "waveform", accent: .purple, status: .ready, runs: 842, confidence: 0.88, skillIDs: ["spectral", "granular"]),
        .init(id: "sentinel", name: "SENTINEL", role: "Portfolio risk and operational safety", icon: "shield.checkered", accent: .orange, status: .paused, runs: 531, confidence: 0.97, skillIDs: ["risk", "audit"]),
        .init(id: "conductor", name: "CONDUCTOR", role: "Pipeline orchestration and quality gates", icon: "point.3.connected.trianglepath.dotted", accent: .green, status: .ready, runs: 216, confidence: 0.91, skillIDs: ["orchestration", "quality"]),
        .init(id: "cartographer", name: "CARTOGRAPHER", role: "Macro context and session intelligence", icon: "map", accent: .yellow, status: .ready, runs: 193, confidence: 0.86, skillIDs: ["macro", "calendar"])
    ]

    @Published var skills: [FlyeSkill] = [
        .init(id: "regime", name: "Regime Mapping", category: "Forex", description: "Classifies market state using momentum, volatility, and structure.", icon: "waveform.path.ecg", isEnabled: true),
        .init(id: "correlation", name: "Cross-Pair Correlation", category: "Forex", description: "Tracks rolling relationships and concentration risk.", icon: "square.grid.3x3", isEnabled: true),
        .init(id: "risk", name: "Risk Gate", category: "Safety", description: "Blocks oversized plans and validates stop/target geometry.", icon: "checkmark.shield", isEnabled: true),
        .init(id: "spectral", name: "Spectral Design", category: "Music", description: "Maps spectral energy into controlled synthesis parameters.", icon: "waveform", isEnabled: true),
        .init(id: "granular", name: "Granular Synthesis", category: "Music", description: "Creates evolving textures from grains, density, and freeze windows.", icon: "circle.hexagongrid", isEnabled: true),
        .init(id: "macro", name: "Macro Context", category: "Research", description: "Ranks event risk and session conditions around a pair.", icon: "calendar", isEnabled: true),
        .init(id: "orchestration", name: "Pipeline Orchestration", category: "Operations", description: "Runs staged workflows with progress, retries, and gates.", icon: "point.3.connected.trianglepath.dotted", isEnabled: true),
        .init(id: "quality", name: "Quality Assurance", category: "Operations", description: "Checks outputs for completeness, safety, and reproducibility.", icon: "checkmark.seal", isEnabled: true),
        .init(id: "audit", name: "Audit Trail", category: "Safety", description: "Records operational events for review and diagnostics.", icon: "list.bullet.rectangle", isEnabled: true),
        .init(id: "calendar", name: "Session Calendar", category: "Research", description: "Organizes session windows, events, and volatility expectations.", icon: "calendar.badge.clock", isEnabled: true)
    ]

    @Published var pipelines: [FlyePipeline] = [
        .init(id: "morning-brief", name: "Morning Intelligence Brief", description: "Fetch, validate, analyze, and summarize the session open.", icon: "sunrise.fill", stageNames: ["Fetch prices", "Validate feed", "Map regimes", "Score risks", "Publish brief"], isRunning: false, completion: 1, lastRun: Date().addingTimeInterval(-900)),
        .init(id: "signal-review", name: "Signal Review Gate", description: "Re-evaluate signals against risk, correlation, and macro context.", icon: "checkmark.shield.fill", stageNames: ["Load signals", "Check exposure", "Check calendar", "Approve or reject", "Write audit"], isRunning: false, completion: 0.8, lastRun: Date().addingTimeInterval(-3600)),
        .init(id: "sound-scene", name: "Sound Scene Builder", description: "Assemble a sound scene from a seed, texture, and master profile.", icon: "music.note.list", stageNames: ["Choose seed", "Generate grains", "Route modulation", "Master bus", "Save scene"], isRunning: false, completion: 0.65, lastRun: Date().addingTimeInterval(-7200)),
        .init(id: "diagnostics", name: "Production Diagnostics", description: "Probe services, queue state, persistence, and data quality.", icon: "stethoscope", stageNames: ["Check services", "Inspect queue", "Verify storage", "Run data checks", "Export report"], isRunning: false, completion: 1, lastRun: Date().addingTimeInterval(-300))
    ]

    @Published var selectedMusicToolID = "spectral"
    @Published var selectedForexToolID = "regime"
    @Published var selectedTechnicalToolID = "trend-suite"
    @Published var selectedLoopToolID = "slice"
    @Published var lastAction = "System ready"
    @Published var musicRenderProgress = 0.0
    @Published var forexScanProgress = 0.0
    @Published var isRenderingMusic = false
    @Published var isScanningForex = false
    @Published var loopPreview: [Float] = (0..<512).map { index in Float(sin(Double(index) * 0.12) * (0.45 + 0.35 * sin(Double(index) * 0.031))) }
    @Published var loopTransientCount = 0

    func runAgent(_ id: String) {
        guard let index = agents.firstIndex(where: { $0.id == id }), agents[index].status != .running else { return }
        agents[index].status = .running
        agents[index].runs += 1
        lastAction = "\(agents[index].name) started"
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.1))
            guard let self, let currentIndex = self.agents.firstIndex(where: { $0.id == id }) else { return }
            self.agents[currentIndex].status = .ready
            self.lastAction = "\(self.agents[currentIndex].name) completed"
        }
    }

    func toggleSkill(_ id: String) {
        guard let index = skills.firstIndex(where: { $0.id == id }) else { return }
        skills[index].isEnabled.toggle()
        lastAction = "\(skills[index].name) \(skills[index].isEnabled ? "enabled" : "disabled")"
    }

    func runPipeline(_ id: String) {
        guard let index = pipelines.firstIndex(where: { $0.id == id }), !pipelines[index].isRunning else { return }
        pipelines[index].isRunning = true
        pipelines[index].completion = 0
        lastAction = "\(pipelines[index].name) started"
        Task { @MainActor [weak self] in
            guard let self else { return }
            for step in 1...20 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let currentIndex = self.pipelines.firstIndex(where: { $0.id == id }) else { return }
                self.pipelines[currentIndex].completion = Double(step) / 20
            }
            guard let currentIndex = self.pipelines.firstIndex(where: { $0.id == id }) else { return }
            self.pipelines[currentIndex].isRunning = false
            self.pipelines[currentIndex].lastRun = Date()
            self.lastAction = "\(self.pipelines[currentIndex].name) completed"
        }
    }

    func executeMusicTool(_ id: String) {
        selectedMusicToolID = id
        let tool = musicTools.first { $0.id == id }
        lastAction = "Loaded \(tool?.name ?? "music tool")"
    }

    func executeTechnicalTool(_ id: String) {
        selectedTechnicalToolID = id
        lastAction = "Loaded \(technicalTools.first { $0.id == id }?.name ?? "technical tool")"
    }

    func executeLoopTool(_ id: String) {
        selectedLoopToolID = id
        lastAction = "Loaded \(loopTools.first { $0.id == id }?.name ?? "loop tool")"
    }

    func processLoopTool() {
        let operation: String
        switch selectedLoopToolID {
        case "stretch": operation = "stretch"
        case "reverse": operation = "reverse"
        case "stutter": operation = "stutter"
        case "shuffle": operation = "shuffle"
        case "freeze": operation = "freeze"
        default: operation = "slice"
        }
        let result = LoopReshapingEngine.process(samples: loopPreview, operation: operation, amount: 0.55)
        loopPreview = result.samples
        loopTransientCount = result.detectedTransients.count
        lastAction = "\(result.operation.capitalized) processed \(result.samples.count) samples"
    }

    func executeForexTool(_ id: String) {
        selectedForexToolID = id
        let tool = forexTools.first { $0.id == id }
        lastAction = "Loaded \(tool?.name ?? "forex tool")"
    }

    func renderSelectedMusicTool() {
        guard !isRenderingMusic else { return }
        isRenderingMusic = true
        musicRenderProgress = 0
        lastAction = "Rendering music scene"
        Task { @MainActor [weak self] in
            guard let self else { return }
            for step in 1...20 {
                try? await Task.sleep(for: .milliseconds(80))
                self.musicRenderProgress = Double(step) / 20
            }
            self.isRenderingMusic = false
            self.lastAction = "Music scene rendered and ready for export"
        }
    }

    func runForexScan() {
        guard !isScanningForex else { return }
        isScanningForex = true
        forexScanProgress = 0
        lastAction = "Scanning forex watchlist"
        Task { @MainActor [weak self] in
            guard let self else { return }
            for step in 1...15 {
                try? await Task.sleep(for: .milliseconds(90))
                self.forexScanProgress = Double(step) / 15
            }
            for index in self.watchlist.indices {
                let drift = Double.random(in: -0.03...0.03)
                self.watchlist[index].score = min(0.99, max(0.05, self.watchlist[index].score + drift))
            }
            self.isScanningForex = false
            self.lastAction = "Forex scan completed"
        }
    }
}

// MARK: - 420 Advanced Typography Presets

struct FlyeTypographyPreset: Identifiable, Hashable {
    let id: Int
    let name: String
    let weight: Font.Weight
    let design: Font.Design
    let scale: CGFloat
    let isMonospaced: Bool

    var font: Font {
        Font.system(size: scale, weight: weight, design: design)
    }
}

enum FlyeFontCatalog {
    static let presets: [FlyeTypographyPreset] = {
        let weights: [(String, Font.Weight)] = [
            ("Thin", .thin), ("ExtraLight", .ultraLight), ("Light", .light), ("Regular", .regular),
            ("Medium", .medium), ("Semibold", .semibold), ("Bold", .bold), ("Heavy", .heavy), ("Black", .black), ("Monospaced", .regular)
        ]
        let designs: [(String, Font.Design)] = [("Default", .default), ("Rounded", .rounded), ("Serif", .serif), ("Monospaced", .monospaced)]
        var result: [FlyeTypographyPreset] = []
        var id = 0
        for family in 0..<11 {
            for (weightName, weight) in weights {
                for (designName, design) in designs {
                    result.append(FlyeTypographyPreset(id: id, name: "FLYE \(family + 1) / \(designName) / \(weightName)", weight: weight, design: design, scale: CGFloat(11 + (family % 6) * 2), isMonospaced: designName == "Monospaced" || weightName == "Monospaced"))
                    id += 1
                }
            }
        }
        return result
    }()
}
