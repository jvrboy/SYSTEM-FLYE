import SwiftUI

struct BackendOperationsView: View {
    @EnvironmentObject private var backend: OperationalBackendStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(eyebrow: "F L Y E  /  B A C K E N D", title: "Operations")
                Spacer()
                Label(backend.runtimeState.rawValue, systemImage: "circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stateColor)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(label: "Runtime", value: backend.runtimeState.rawValue, detail: "operational state", tint: stateColor)
                MetricTile(label: "Queue", value: "\(backend.queueCount)", detail: "offline operations", tint: .orange)
                MetricTile(label: "Requests", value: "\(backend.requestCount)", detail: "session total", tint: SystemFlyeTheme.cyan)
                MetricTile(label: "Failures", value: "\(backend.failedRequestCount)", detail: "session total", tint: backend.failedRequestCount == 0 ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("RUNTIME CONTROLS").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                Toggle("Offline-first mode", isOn: $backend.configuration.offlineMode)
                Toggle("Telemetry events", isOn: $backend.configuration.telemetryEnabled)
                HStack {
                    Button(backend.isRefreshing ? "Refreshing…" : "Refresh health") {
                        Task { await backend.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SystemFlyeTheme.cyan)
                    .disabled(backend.isRefreshing)
                    Button("Clear events") { backend.clearEvents() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 16))

            HStack {
                Text("EVENT STREAM").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                if let date = backend.lastRefresh { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) }
            }
            ForEach(backend.events.prefix(8)) { event in
                HStack(spacing: 10) {
                    Image(systemName: event.severity == .error ? "xmark.octagon.fill" : event.severity == .warning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(event.severity == .error ? .red : event.severity == .warning ? .orange : .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.message).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("\(event.category.uppercased())  ·  \(event.timestamp, style: .time)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(11)
                .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task { backend.start() }
    }

    private var stateColor: Color {
        switch backend.runtimeState {
        case .initializing: return .orange
        case .ready: return .green
        case .degraded: return .yellow
        case .offline: return .gray
        }
    }
}

struct PlatformExpansionView: View {
    @EnvironmentObject private var platform: FeaturePlatformStore
    @EnvironmentObject private var marketDataManager: MarketDataManager
    @State private var section = 0
    private let sections = ["Music", "Forex", "Technical", "Loop Lab", "Agents", "Skills", "Pipelines", "Fonts"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  E X P A N S I O N", title: sections[section])
                Spacer()
                Text(platform.lastAction).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sections.indices, id: \.self) { index in
                        Button(sections[index]) { section = index }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(section == index ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(section == index ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule())
                    }
                }
            }
            ScrollView {
                switch section {
                case 0: musicTools
                case 1: forexTools
                case 2: technicalTools
                case 3: loopTools
                case 4: agents
                case 5: skills
                case 6: pipelines
                default: fonts
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var musicTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADVANCED MUSIC TOOLS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(platform.musicTools) { tool in
                toolRow(icon: tool.icon, title: tool.name, subtitle: tool.subtitle, accent: tool.accent, selected: platform.selectedMusicToolID == tool.id) {
                    platform.executeMusicTool(tool.id)
                }
            }
            musicConsole
        }
    }

    private var musicConsole: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("LIVE TOOL CONSOLE").font(.caption2.weight(.bold)).tracking(1.4); Spacer(); Label("ON DEVICE", systemImage: "cpu").font(.caption2).foregroundStyle(SystemFlyeTheme.cyan) }
            HStack(spacing: 8) {
                ForEach([0.28, 0.62, 0.44, 0.82, 0.56, 0.74, 0.38, 0.9, 0.48, 0.66], id: \.self) { value in
                    Capsule().fill(SystemFlyeTheme.cyan.opacity(0.35 + value * 0.5)).frame(maxWidth: .infinity).frame(height: CGFloat(18 + value * 70))
                }
            }
            HStack {
                Text("Texture density")
                Spacer()
                Text("72%").monospacedDigit().foregroundStyle(SystemFlyeTheme.cyan)
            }.font(.caption)
            ProgressView(value: platform.musicRenderProgress == 0 ? 0.72 : platform.musicRenderProgress).tint(SystemFlyeTheme.cyan)
            HStack {
                Text(platform.isRenderingMusic ? "Rendering scene…" : "Ready for export").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(platform.isRenderingMusic ? "Rendering…" : "Render scene") { platform.renderSelectedMusicTool() }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan).disabled(platform.isRenderingMusic)
            }
        }
        .padding(16)
        .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
    }

    private var forexTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FOREX ANALYSIS TOOLS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Button(platform.isScanningForex ? "Scanning…" : "Run scan") { platform.runForexScan() }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan).disabled(platform.isScanningForex)
            }
            if platform.isScanningForex { ProgressView(value: platform.forexScanProgress).tint(SystemFlyeTheme.cyan) }
            ForEach(platform.forexTools) { tool in
                toolRow(icon: tool.icon, title: tool.name, subtitle: tool.subtitle, accent: tool.accent, selected: platform.selectedForexToolID == tool.id) {
                    platform.executeForexTool(tool.id)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("WATCHLIST SCORING").font(.caption2.weight(.bold)).tracking(1.3)
                ForEach(platform.watchlist) { item in
                    HStack {
                        Text(item.symbol).font(.subheadline.weight(.bold)).frame(width: 72, alignment: .leading)
                        Text(item.regime).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(item.direction).font(.caption.weight(.bold)).foregroundStyle(item.direction == "LONG" ? .green : item.direction == "SHORT" ? .orange : .secondary)
                        Text("\(Int(item.score * 100))").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                    }
                    ProgressView(value: item.score).tint(item.direction == "SHORT" ? .orange : SystemFlyeTheme.cyan)
                }
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var technicalTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADVANCED TECHNICAL ANALYSIS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(platform.technicalTools) { tool in
                toolRow(icon: tool.icon, title: tool.name, subtitle: tool.subtitle, accent: tool.accent, selected: platform.selectedTechnicalToolID == tool.id) {
                    platform.executeTechnicalTool(tool.id)
                }
            }
            if let values = marketDataManager.advancedTechnicalIndicators["EURUSD"] {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(label: "ADX", value: String(format: "%.1f", values.adx), detail: "trend strength", tint: .cyan)
                    MetricTile(label: "CCI", value: String(format: "%.1f", values.cci), detail: "cycle momentum", tint: .purple)
                    MetricTile(label: "VWAP", value: String(format: "%.5f", values.vwap), detail: "volume weighted", tint: .green)
                    MetricTile(label: "ROC", value: String(format: "%.2f%%", values.roc), detail: "rate of change", tint: .orange)
                    MetricTile(label: "Signal", value: "\(Int(values.signalScore * 100))", detail: "composite score", tint: .yellow)
                    MetricTile(label: "Trend", value: String(format: "%.2f", values.trendStrength), detail: "directional bias", tint: .pink)
                }
            }
        }
    }

    private var loopTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOOP RESHAPING LAB").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(platform.loopTools) { tool in
                toolRow(icon: tool.icon, title: tool.name, subtitle: tool.subtitle, accent: tool.accent, selected: platform.selectedLoopToolID == tool.id) {
                    platform.executeLoopTool(tool.id)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("RESHAPE PREVIEW").font(.caption2.weight(.bold)).tracking(1.3); Spacer(); Label("NON-DESTRUCTIVE", systemImage: "lock.fill").font(.caption2).foregroundStyle(.green) }
                HStack(alignment: .center, spacing: 3) {
                    ForEach(Array(stride(from: 0, to: platform.loopPreview.count, by: max(1, platform.loopPreview.count / 32))), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2).fill(index % 5 == 0 ? SystemFlyeTheme.cyan : SystemFlyeTheme.violet.opacity(0.55)).frame(maxWidth: .infinity).frame(height: CGFloat(12 + abs(platform.loopPreview[index]) * 34))
                    }
                }
                HStack {
                    Text("\(platform.loopPreview.count) samples  ·  \(platform.loopTransientCount) transients").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Process loop") { platform.processLoopTool() }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                }
                Text("Slice, stretch, reverse, stutter, shuffle, and freeze operations are staged for export-safe loop editing.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var agents: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEW AGENTS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(platform.agents) { agent in
                HStack(spacing: 12) {
                    Image(systemName: agent.icon).font(.title3).foregroundStyle(agent.accent).frame(width: 34, height: 34).background(agent.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) { Text(agent.name).font(.subheadline.weight(.bold)); Text(agent.role).font(.caption).foregroundStyle(.secondary); Text("\(agent.runs) runs  ·  \(Int(agent.confidence * 100))% confidence").font(.caption2).foregroundStyle(agent.accent) }
                    Spacer()
                    Button(agent.status == .paused ? "Paused" : agent.status == .running ? "Running…" : "Run") { platform.runAgent(agent.id) }.buttonStyle(.borderedProminent).tint(agent.accent).disabled(agent.status == .running || agent.status == .paused)
                }
                .padding(13).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var skills: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEW SKILLS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(platform.skills) { skill in
                Button { platform.toggleSkill(skill.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: skill.icon).foregroundStyle(skill.isEnabled ? SystemFlyeTheme.cyan : .secondary).frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) { Text(skill.name).font(.subheadline.weight(.bold)); Text("\(skill.category)  ·  \(skill.description)").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                        Spacer(); Image(systemName: skill.isEnabled ? "checkmark.circle.fill" : "circle").foregroundStyle(skill.isEnabled ? .green : .secondary)
                    }
                    .padding(13).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var pipelines: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEW PIPELINES").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(platform.pipelines) { pipeline in
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Image(systemName: pipeline.icon).foregroundStyle(SystemFlyeTheme.cyan); VStack(alignment: .leading, spacing: 3) { Text(pipeline.name).font(.subheadline.weight(.bold)); Text(pipeline.description).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(pipeline.isRunning ? "Running…" : "Run") { platform.runPipeline(pipeline.id) }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan).disabled(pipeline.isRunning) }
                    ProgressView(value: pipeline.completion).tint(SystemFlyeTheme.cyan)
                    HStack { ForEach(Array(pipeline.stageNames.enumerated()), id: \.offset) { index, stage in Text("\(index + 1)  \(stage)").font(.caption2).foregroundStyle(index < Int(pipeline.completion * Double(pipeline.stageNames.count)) ? .green : .secondary) }; Spacer() }
                }
                .padding(15).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 15))
            }
        }
    }

    private var fonts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("ADVANCED TYPOGRAPHY LAB").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary); Spacer(); Text("\(FlyeFontCatalog.presets.count) presets").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
            Text("A 420-preset typography system built from system-safe rounded, serif, monospaced, and default families with nine weights and multiple scales.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(FlyeFontCatalog.presets.prefix(30)) { preset in
                HStack { Text(preset.name).font(preset.font); Spacer(); Text(preset.isMonospaced ? "MONO" : "UI").font(.caption2.monospaced()).foregroundStyle(.secondary) }.padding(10).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func toolRow(icon: String, title: String, subtitle: String, accent: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(accent).frame(width: 34, height: 34).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.weight(.bold)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                Spacer(); Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right").foregroundStyle(selected ? .green : .secondary)
            }
            .padding(13).background(selected ? accent.opacity(0.12) : SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? accent.opacity(0.45) : .clear))
        }
        .buttonStyle(.plain)
    }
}
