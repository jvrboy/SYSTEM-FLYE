import SwiftUI

// MARK: - Agent Console Detail View
struct AgentConsoleDetailView: View {
    @EnvironmentObject private var store: AdvancedStore
    @State private var selectedAgentID: UUID?
    @State private var logFilter: LogFilter = .all
    @State private var searchText = ""
    @State private var showingControlPanel = false
    @State private var controlAction: ControlAction = .run
    @State private var isRunningBatch = false
    @State private var activeTab: ConsoleTab = .overview
    @State private var eventLog: [AgentEvent] = []
    @State private var isRecording = false
    @State private var expandedSections: Set<String> = ["metrics", "logs", "controls"]

    enum LogFilter: String, CaseIterable { case all = "All"; case info = "Info"; case warnings = "Warnings"; case errors = "Errors" }
    enum ControlAction: String, CaseIterable { case run = "Run Now"; case pause = "Pause"; case restart = "Restart"; case terminate = "Terminate" }
    enum ConsoleTab: String, CaseIterable { case overview = "Overview"; case logs = "Logs"; case metrics = "Metrics"; case controls = "Controls" }

    struct AgentEvent: Identifiable {
        let id = UUID()
        let agentName: String
        let type: EventType
        let message: String
        let timestamp: Date
        let severity: EventSeverity

        enum EventType { case heartbeat, execution, error, policy, system }
        enum EventSeverity { case info, warning, error, critical }
    }

    var filteredAgents: [AdvancedAgentDefinition] {
        let base = store.agents
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.role.localizedCaseInsensitiveContains(searchText) }
    }

    var selectedAgent: AdvancedAgentDefinition? {
        guard let id = selectedAgentID else { return store.agents.first }
        return store.agents.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  A G E N T S", title: "Console Detail")
                        Spacer()
                        Label("ON-DEVICE", systemImage: "cpu")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SystemFlyeTheme.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Active agents", value: "\(store.agents.filter { $0.status == .running }.count)", detail: "currently executing", tint: .green)
                        MetricTile(label: "Total agents", value: "\(store.agents.count)", detail: "registered", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Avg confidence", value: String(format: "%.1f%%", store.agents.map(\.confidence).reduce(0, +) / Double(max(store.agents.count, 1)) * 100), detail: "ensemble average", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "Runs this session", value: "\(store.runCount)", detail: "total invocations", tint: .orange)
                    }

                    if let agent = selectedAgent {
                        agentDetailCard(agent)
                            .padding(.top, 4)
                    }

                    tabBarView
                    tabContent
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Agent Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingControlPanel = true }
                        label: { Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan) }
                }
            }
            .confirmationDialog("Agent Control", isPresented: $showingControlPanel, titleVisibility: .visible) {
                ForEach(ControlAction.allCases) { action in
                    Button(action.rawValue) { controlAction = action; applyControlAction() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { generateEventLog() }
        }
    }

    private var tabBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ConsoleTab.allCases) { tab in
                    Button { activeTab = tab }
                        label: {
                            Text(tab.rawValue).font(.caption.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule())
                                .foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7))
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .overview: overviewTab
        case .logs: logsTab
        case .metrics: metricsTab
        case .controls: controlsTab
        }
    }

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AGENT OVERVIEW").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(store.agents) { agent in
                agentOverviewRow(agent)
            }
        }
    }

    private func agentOverviewRow(_ agent: AdvancedAgentDefinition) -> some View {
        HStack(spacing: 12) {
            Circle().fill(agent.accent).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(agent.role).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(agent.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(agent.status == .running ? .orange : agent.status == .paused ? .red : .green)
                Text("\(Int(agent.confidence * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(agent.accent)
            }
        }
        .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
    }

    private var logsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SYSTEM LOGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Picker("Log filter", selection: $logFilter) {
                    ForEach(LogFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                }.pickerStyle(.segmented).frame(width: 220)
            }
            LazyVStack(spacing: 6) {
                ForEach(filteredLogs, id: \.self) { log in
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(SystemFlyeTheme.line.opacity(0.3)))
                }
            }
        }
    }

    private var metricsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PERFORMANCE METRICS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(performanceMetrics) { metric in
                    HStack(spacing: 8) {
                        Text(metric.label).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(metric.value).font(.caption.weight(.semibold)).foregroundStyle(.white).monospacedDigit()
                        Image(systemName: metric.trendIcon).font(.caption2).foregroundStyle(metric.trendColor)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var controlsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QUICK CONTROLS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button { store.runCount += 1 } label: { Label("Force Run", systemImage: "bolt.fill").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { withAnimation { isRunningBatch.toggle() } } label: { Label(isRunningBatch ? "Stop Batch" : "Batch Run", systemImage: isRunningBatch ? "stop.fill" : "list.bullet").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
                Button { generateEventLog() } label: { Label("Refresh Logs", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.green)
            }
            eventLogView
        }
    }

    private func agentDetailCard(_ agent: AdvancedAgentDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Circle().fill(agent.accent).frame(width: 12, height: 12)
                        Text(agent.name).font(.title3.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(agent.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(agent.status == .running ? .orange : agent.status == .paused ? .red : .green)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background((agent.status == .running ? Color.orange : agent.status == .paused ? Color.red : Color.green).opacity(0.15), in: Capsule())
                    }
                    Text(agent.role).font(.subheadline).foregroundStyle(.secondary)
                    Text("Last run: \(agent.lastRun)").font(.caption).foregroundStyle(.tertiary)
                }
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Confidence").font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                    Text("\(Int(agent.confidence * 100))%").font(.title.weight(.bold)).foregroundStyle(agent.accent).monospacedDigit()
                }
            }
            Divider().background(SystemFlyeTheme.line)
            VStack(alignment: .leading, spacing: 12) {
                Text("ASSIGNED TOOLS").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(agent.tools, id: \.self) { tool in
                            Text(tool).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 12).padding(.vertical, 7).background(Color.white.opacity(0.06), in: Capsule())
                                .overlay(Capsule().stroke(SystemFlyeTheme.line))
                        }
                    }
                }
            }
            Divider().background(SystemFlyeTheme.line)
            VStack(alignment: .leading, spacing: 10) {
                Text("PERFORMANCE METRICS").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(performanceMetrics) { metric in
                        HStack(spacing: 8) {
                            Text(metric.label).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(metric.value).font(.caption.weight(.semibold)).foregroundStyle(.white).monospacedDigit()
                            Image(systemName: metric.trendIcon).font(.caption2).foregroundStyle(metric.trendColor)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            HStack(spacing: 10) {
                Button { store.runAgent(agent.id) } label: { Label(agent.status == .paused ? "Resume" : "Run now", systemImage: agent.status == .paused ? "play.fill" : "bolt.fill").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(agent.accent).disabled(agent.status == .running)
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.agents.first(where: { $0.id == agent.id })?.status = agent.status == .paused ? .ready : .paused } }
                    label: { Label(agent.status == .paused ? "Resume" : "Pause", systemImage: agent.status == .paused ? "play.fill" : "pause.fill").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(agent.status == .paused ? .green : .orange)
                Button { withAnimation(.easeInOut) { if let idx = store.agents.firstIndex(where: { $0.id == agent.id }) { store.agents[idx].status = .ready } } }
                    label: { Label("Reset", systemImage: "arrow.counterclockwise").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.blue)
            }
        }
        .padding(20)
        .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private var eventLogView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EVENT STREAM").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(eventLog.prefix(15)) { event in
                    HStack(spacing: 10) {
                        Image(systemName: eventSeverityIcon(event.severity)).foregroundStyle(eventSeverityColor(event.severity))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.agentName): \(event.message)").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("\(event.timestamp, style: .time) · \(event.type.rawValue.capitalized)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(11).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func eventSeverityIcon(_ severity: AgentEvent.EventSeverity) -> String {
        switch severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private func eventSeverityColor(_ severity: AgentEvent.EventSeverity) -> Color {
        switch severity {
        case .info: return SystemFlyeTheme.cyan
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }

    private var performanceMetrics: [PerformanceMetric] {
        [
            PerformanceMetric(label: "Memory usage", value: "\(Int.random(in: 40...120)) MB", trend: .stable),
            PerformanceMetric(label: "CPU load", value: "\(Int.random(in: 5...45))%", trend: .down),
            PerformanceMetric(label: "Executions", value: "\(store.runCount)", trend: .up),
            PerformanceMetric(label: "Avg latency", value: "\(String(format: "%.2f", Double.random(in: 0.1...0.9)))s", trend: .stable),
            PerformanceMetric(label: "Error rate", value: "\(String(format: "%.2f", Double.random(in: 0...0.05)))%", trend: .up),
            PerformanceMetric(label: "Queue depth", value: "\(Int.random(in: 0...12))", trend: .stable)
        ]
    }

    struct PerformanceMetric: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let trend: TrendDirection

        enum TrendDirection { case up, down, stable }
        var trendIcon: String {
            switch trend {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "minus"
            }
        }
        var trendColor: Color {
            switch trend {
            case .up: return .green
            case .down: return .red
            case .stable: return .secondary
            }
        }
    }

    private var filteredLogs: [String] {
        let logs = generateLogs()
        switch logFilter {
        case .all: return logs
        case .info: return logs.filter { $0.contains("INFO") }
        case .warnings: return logs.filter { $0.contains("WARN") }
        case .errors: return logs.filter { $0.contains("ERROR") }
        }
    }

    private func generateLogs() -> [String] {
        var logs: [String] = []
        let agents = store.agents.map(\.name)
        for i in 0..<24 {
            let agent = agents.randomElement() ?? "SYSTEM"
            let types = ["INFO", "WARN", "ERROR", "DEBUG"]
            let type = types.randomElement()!
            let messages = [
                "\(agent) heartbeat acknowledged",
                "\(agent) processing batch #\(Int.random(in: 100...999))",
                "\(agent) confidence recalibrated to \(Int.random(in: 60...99))%",
                "Memory pressure normal for \(agent)",
                "\(agent) awaiting next execution window",
                "Telemetry event recorded for \(agent)",
                "\(agent) policy gate passed",
                "\(agent) network latency within bounds"
            ]
            let msg = messages.randomElement()!
            let timestamp = String(format: "%02d:%02d:%02d", 14 + i / 60, i % 60, Int.random(in: 0...59))
            logs.append("[\(timestamp)] [\(type)] \(msg)")
        }
        return logs.sorted()
    }

    private func generateEventLog() {
        let agents = store.agents.map(\.name)
        let types: [AgentEvent.EventType] = [.heartbeat, .execution, .error, .policy, .system]
        let severities: [AgentEvent.EventSeverity] = [.info, .info, .info, .warning, .error]
        eventLog = (0..<20).map { _ in
            AgentEvent(
                agentName: agents.randomElement()!,
                type: types.randomElement()!,
                message: ["Heartbeat OK", "Processing complete", "Policy check passed", "Latency spike detected", "Memory warning"][Int.random(in: 0..<5)],
                timestamp: Date().addingTimeInterval(-Double.random(in: 0...3600)),
                severity: severities.randomElement()!
            )
        }.sorted { $0.timestamp > $1.timestamp }
    }

    private func applyControlAction() {
        guard let agent = selectedAgent else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            switch controlAction {
            case .run: store.runAgent(agent.id)
            case .pause: if let idx = store.agents.firstIndex(where: { $0.id == agent.id }) { store.agents[idx].status = .paused }
            case .restart: if let idx = store.agents.firstIndex(where: { $0.id == agent.id }) { store.agents[idx].status = .ready; store.runAgent(agent.id) }
            case .terminate: if let idx = store.agents.firstIndex(where: { $0.id == agent.id }) { store.agents[idx].status = .paused }
            }
        }
    }
}

struct LogRow: View {
    let log: String
    var body: some View {
        Text(log)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(SystemFlyeTheme.line.opacity(0.3)))
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let trend: AgentConsoleDetailView.PerformanceMetric.TrendDirection
    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(.white).monospacedDigit()
            Image(systemName: trendIcon).font(.caption2).foregroundStyle(trendColor)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
    private var trendIcon: String { switch trend { case .up: return "arrow.up.right"; case .down: return "arrow.down.right"; case .stable: return "minus" } }
    private var trendColor: Color { switch trend { case .up: return .green; case .down: return .red; case .stable: return .secondary } }
}

struct AgentConsoleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AgentConsoleDetailView().environmentObject(AdvancedStore()).preferredColorScheme(.dark)
    }
}

