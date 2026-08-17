import SwiftUI
import Charts

// MARK: - Advanced Extensions View
// Single SwiftUI tab exposing all new advanced agents, indicators, and tools
// registered by AdvancedAgentsRegistry, AdvancedIndicatorCatalog, and
// AdvancedToolsRegistry. Wired into PlatformExpansionView as a new "Advanced"
// section so the live UI surfaces the extensions.

@MainActor
public struct AdvancedExtensionsView: View {
    @StateObject private var agentsRegistry = AdvancedAgentsRegistry.shared
    @StateObject private var toolsRegistry = AdvancedToolsRegistry.shared
    @State private var selectedTab: AdvancedTab = .agents

    enum AdvancedTab: String, CaseIterable, Identifiable {
        case agents = "Agents"
        case indicators = "Indicators"
        case tools = "Tools"
        case mlLab = "ML Lab"
        case execution = "Execution"
        case risk = "Risk"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .agents: return "cpu"
            case .indicators: return "chart.xyaxis.line"
            case .tools: return "wrench.and.screwdriver.fill"
            case .mlLab: return "brain.head.profile"
            case .execution: return "target"
            case .risk: return "shield.lefthalf.filled"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            ScrollView {
                Group {
                    switch selectedTab {
                    case .agents:
                        agentsSection
                    case .indicators:
                        indicatorsSection
                    case .tools:
                        toolsSection
                    case .mlLab:
                        mlLabSection
                    case .execution:
                        executionSection
                    case .risk:
                        riskSection
                    }
                }
                .padding(16)
            }
            .background(FlyeTheme.canvas)
        }
        .background(FlyeTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            agentsRegistry.seedIntoOrchestrator()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "atom")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FlyeTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("ADVANCED EXTENSIONS").font(.system(size: 16, weight: .black, design: .rounded))
                Text("30 AGENTS · 23 INDICATORS · 15 TOOLS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FlyeTheme.muted)
            }
            Spacer()
            Button {
                agentsRegistry.seedIntoOrchestrator()
            } label: {
                Label("Seed", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(FlyeTheme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(FlyeTheme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(FlyeTheme.panel)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AdvancedTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selectedTab == tab ? FlyeTheme.accent.opacity(0.2) : Color.white.opacity(0.04), in: Capsule())
                            .foregroundStyle(selectedTab == tab ? FlyeTheme.accent : FlyeTheme.muted)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(FlyeTheme.panel)
    }

    // MARK: Agents
    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADVANCED AGENTS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(AdvancedAgentDescriptor.AgentCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: categoryIcon(category))
                            .foregroundStyle(FlyeTheme.accent)
                        Text(category.rawValue.uppercased()).font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(agentsRegistry.agents(in: category).count)")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    ForEach(agentsRegistry.agents(in: category)) { agent in
                        advancedAgentRow(agent)
                    }
                }
            }
        }
    }

    private func advancedAgentRow(_ agent: AdvancedAgentDescriptor) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color(hex: agent.accentColor) ?? .cyan)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: agent.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(agent.role).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack {
                    ForEach(agent.capabilities.prefix(3), id: \.self) { cap in
                        Text(cap)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.white.opacity(0.05), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f%%", agent.confidence * 100))
                    .font(.caption.monospaced()).foregroundStyle(FlyeTheme.positive)
                Toggle("", isOn: Binding(
                    get: { agentsRegistry.enabledAgentIDs.contains(agent.id) },
                    set: { _ in agentsRegistry.toggle(agent.id) }
                ))
                .labelsHidden().tint(FlyeTheme.accent)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private func categoryIcon(_ c: AdvancedAgentDescriptor.AgentCategory) -> String {
        switch c {
        case .market: return "chart.xyaxis.line"
        case .risk: return "shield.lefthalf.filled"
        case .execution: return "target"
        case .neural: return "brain.head.profile"
        case .audio: return "waveform"
        case .infrastructure: return "server.rack"
        case .research: return "book.fill"
        }
    }

    // MARK: Indicators
    private var indicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADVANCED INDICATORS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(AdvancedIndicatorCatalog.entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(entry.category)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(FlyeTheme.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(FlyeTheme.accent)
                    }
                    Text(entry.description).font(.caption).foregroundStyle(.secondary)
                    Text("→ \(entry.interpretation)").font(.caption2.monospaced()).foregroundStyle(FlyeTheme.positive)
                }
                .padding(10)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Tools
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADVANCED TOOLS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(toolsRegistry.descriptors) { tool in
                Button {
                    toolsRegistry.invoke(tool.id)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(FlyeTheme.accent.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: tool.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(FlyeTheme.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                            Text(tool.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Text(tool.category)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.white.opacity(0.05), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(toolsRegistry.lastToolInvoked == tool.id ? FlyeTheme.accent.opacity(0.1) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: ML Lab
    private var mlLabSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ML PREDICTOR").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            let sample = MLPredictor.Feature(rsi: 58, macd: 0.0008, atr: 0.0035, ema20: 1.085, ema50: 1.082, adx: 22, sentiment: 0.3, volumeZ: 1.2)
            let prediction = toolsRegistry.mlPredictor.predict(sample)
            VStack(alignment: .leading, spacing: 6) {
                Text("Sample Feature").font(.caption.weight(.semibold)).foregroundStyle(.white)
                Text(String(format: "RSI=%.0f · ADX=%.0f · Sentiment=%.2f · VolZ=%.2f", sample.rsi, sample.adx, sample.sentiment, sample.volumeZ))
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                Divider()
                Text(String(format: "Bullish probability: %.1f%%", prediction * 100))
                    .font(.title2.monospaced()).foregroundStyle(prediction > 0.5 ? FlyeTheme.positive : FlyeTheme.muted)
            }
            .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))

            Text("VOLATILITY SURFACE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Applying sticky-delta smile (atmVol=0.12, skew=-0.04, kurt=0.02)")
                    .font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<toolsRegistry.volatilitySurface.maturities.count, id: \.self) { i in
                    HStack {
                        Text(String(format: "T=%.2f", toolsRegistry.volatilitySurface.maturities[i]))
                            .font(.caption2.monospaced()).foregroundStyle(.secondary)
                        ForEach(0..<toolsRegistry.volatilitySurface.strikes.count, id: \.self) { j in
                            Text(String(format: "%.3f", toolsRegistry.volatilitySurface.grid[i][j]))
                                .font(.caption2.monospaced()).foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Execution
    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXECUTION PLANNER").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            let slices = toolsRegistry.executionPlanner.plan(orderQty: 1_000_000, durationMinutes: 60, vwapProfile: [0.05, 0.08, 0.12, 0.15, 0.18, 0.17, 0.12, 0.08, 0.05], strategy: "vwap")
            VStack(alignment: .leading, spacing: 6) {
                Text("VWAP slicing of $1M over 60 minutes")
                    .font(.caption2).foregroundStyle(.secondary)
                ForEach(slices.prefix(5)) { slice in
                    HStack {
                        Text(slice.id.uuidString.prefix(8))
                            .font(.caption2.monospaced()).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "$%.0f", slice.quantity))
                            .font(.caption2.monospaced()).foregroundStyle(.white)
                        Text(slice.venue)
                            .font(.caption2.monospaced()).foregroundStyle(FlyeTheme.accent)
                    }
                }
                let slip = toolsRegistry.executionPlanner.estimatedSlippage(slices: slices, avgSpread: 0.0002)
                Text(String(format: "Estimated slippage: %.5f", slip))
                    .font(.caption2.monospaced()).foregroundStyle(FlyeTheme.positive)
            }
            .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Risk
    private var riskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STRESS SCENARIOS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(toolsRegistry.stressLab.scenarios) { scenario in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(scenario.name).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "Equity %.0f%%", scenario.equityShock * 100))
                            .font(.caption2.monospaced())
                            .foregroundStyle(scenario.equityShock < 0 ? Color.red : Color.green)
                    }
                    Text(scenario.description).font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Text(String(format: "Rates %+dbps", scenario.ratesShock)).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        Text(String(format: "Credit %+dbps", scenario.creditShock)).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        Text(String(format: "FX %+.2f%%", scenario.fxShock * 100)).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
            }

            Text("ANOMALY RADAR").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            let features: [String: Double] = ["rsi": 78, "zscore": 2.9, "volz": 3.4, "sentiment": 0.85]
            let baselines: [String: (mean: Double, std: Double)] = [
                "rsi": (55, 8), "zscore": (0, 1), "volz": (0, 1), "sentiment": (0, 0.3)
            ]
            let anomalies = toolsRegistry.anomalyRadar.scan(features: features, baselines: baselines)
            VStack(alignment: .leading, spacing: 4) {
                if anomalies.isEmpty {
                    Text("No anomalies detected in current snapshot.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(anomalies) { anomaly in
                        HStack {
                            Circle().fill(anomaly.zScore > 0 ? Color.red : Color.orange).frame(width: 8, height: 8)
                            Text(anomaly.indicator).font(.caption.weight(.bold)).foregroundStyle(.white)
                            Text(String(format: "z=%.2f", anomaly.zScore)).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            Spacer()
                            Text(anomaly.direction).font(.caption2.monospaced()).foregroundStyle(FlyeTheme.accent)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Color hex helper (mini; FLYE has its own in Utilities.swift but this
// makes AdvancedExtensionsView self-contained).
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

#if DEBUG
#Preview("Advanced Extensions") {
    AdvancedExtensionsView()
        .environmentObject(BackendServiceManager.shared)
}
#endif
