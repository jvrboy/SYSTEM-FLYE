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

    var filteredAgents: [AgentDefinition] {
        let base = store.agents
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.role.localizedCaseInsensitiveContains(searchText) }
    }

    var selectedAgent: AgentDefinition? {
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

    private func agentOverviewRow(_ agent: AgentDefinition) -> some View {
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

    private func agentDetailCard(_ agent: AgentDefinition) -> some View {
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


// MARK: - Extended Implementation

struct ExtendedDetailView: View {
    @State private var items: [ExtendedItem] = []
    @State private var selectedID: UUID?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var sortOrder: SortOrder = .name
    @State private var isExpanded: Bool = false
    @State private var showingDetail = false
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 5
    @State private var itemsPerPage: Int = 20
    @State private var viewMode: ViewMode = .list
    @State private var gridColumns: Int = 3
    @State private var showArchived = false
    @State private var showPinned = false
    @State private var isRefreshing = false
    @State private var refreshProgress: Double = 0.0

    enum FilterMode: String, CaseIterable { case all = "All"; case active = "Active"; case completed = "Completed"; case pending = "Pending"; case archived = "Archived" }
    enum SortOrder: String, CaseIterable { case name = "Name"; case date = "Date"; case priority = "Priority"; case status = "Status" }
    enum ViewMode: String, CaseIterable { case list = "List"; case grid = "Grid"; case compact = "Compact"; case detailed = "Detailed" }

    struct ExtendedItem: Identifiable {
        let id = UUID()
        var title: String
        var subtitle: String
        var description: String
        var status: ItemStatus
        var priority: Priority
        var createdAt: Date
        var updatedAt: Date
        var tags: [String]
        var metadata: [String: String]
        var isPinned: Bool
        var isArchived: Bool
        var color: Color
    }

    enum ItemStatus: String { case pending = "Pending"; case active = "Active"; case completed = "Completed"; case failed = "Failed"; case cancelled = "Cancelled" }
    enum Priority: String, CaseIterable { case low = "Low"; case medium = "Medium"; case high = "High"; case urgent = "Urgent" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    controlsView
                    contentView
                    footerView
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Extended Detail")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { generateItems() }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  E X T E N D E D", title: "Detail View")
                Spacer()
                Label("EXTENDED", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(SystemFlyeTheme.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SystemFlyeTheme.violet.opacity(0.12), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(metricTiles) { tile in
                    MetricTile(label: tile.label, value: tile.value, detail: tile.detail, tint: tile.tint)
                }
            }
        }
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search items...", text: $searchText).textFieldStyle(.plain).foregroundStyle(.white)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterMode.allCases) { mode in
                        Button { filterMode = mode }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(filterMode == mode ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(filterMode == mode ? .black : .white.opacity(0.7)) }
                    }
                    ForEach(ViewMode.allCases) { mode in
                        Button { viewMode = mode }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(viewMode == mode ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(viewMode == mode ? .black : .white.opacity(0.7)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button { generateItems() }
                    label: { Label("Refresh", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { isExpanded.toggle() }
                    label: { Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.right.and.arrow.down.left").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.green)
                Button { showingDetail = true }
                    label: { Label("Detail", systemImage: "info.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .list: listContentView
        case .grid: gridContentView
        case .compact: compactContentView
        case .detailed: detailedContentView
        }
    }

    private var listContentView: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredItems) { item in
                HStack(spacing: 14) {
                    Circle().fill(item.color).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor(item.status))
                        Text(item.priority.rawValue).font(.caption2).foregroundStyle(priorityColor(item.priority))
                    }
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var gridContentView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumns)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Circle().fill(item.color).frame(width: 8, height: 8)
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(item.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor(item.status))
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var compactContentView: some View {
        LazyVStack(spacing: 6) {
            ForEach(filteredItems) { item in
                HStack(spacing: 10) {
                    Circle().fill(item.color).frame(width: 6, height: 6)
                    Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(item.status.rawValue).font(.caption2).foregroundStyle(statusColor(item.status))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var detailedContentView: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredItems) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.title).font(.headline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(item.priority.rawValue).font(.caption.weight(.bold)).foregroundStyle(priorityColor(item.priority))
                            .padding(.horizontal, 10).padding(.vertical, 5).background(priorityColor(item.priority).opacity(0.15), in: Capsule())
                    }
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    HStack(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.06), in: Capsule()).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    HStack(spacing: 12) {
                        Text("Created: \(item.createdAt, style: .date)").font(.caption2).foregroundStyle(.secondary)
                        Text("Updated: \(item.updatedAt, style: .relative)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var footerView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Showing \(filteredItems.count) of \(items.count) items").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Page \(currentPage + 1) of \(totalPages)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button { currentPage = max(0, currentPage - 1) }
                    label: { Image(systemName: "chevron.left").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary).disabled(currentPage == 0)
                ForEach(0..<totalPages, id: \.self) { page in
                    Button { currentPage = page }
                        label: { Text("\(page + 1)").font(.caption2.weight(.semibold)).frame(width: 28, height: 28).background(currentPage == page ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(currentPage == page ? .black : .white.opacity(0.7)) }
                }
                Button { currentPage = min(totalPages - 1, currentPage + 1) }
                    label: { Image(systemName: "chevron.right").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary).disabled(currentPage == totalPages - 1)
            }
        }
    }

    private var filteredItems: [ExtendedItem] {
        var base = items
        if !searchText.isEmpty { base = base.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.subtitle.localizedCaseInsensitiveContains(searchText) } }
        if filterMode != .all {
            switch filterMode {
            case .active: base = base.filter { $0.status == .active }
            case .completed: base = base.filter { $0.status == .completed }
            case .pending: base = base.filter { $0.status == .pending }
            case .archived: base = base.filter { $0.isArchived }
            default: break
            }
        }
        if showArchived { base = base.filter { $0.isArchived } }
        if showPinned { base = base.filter { $0.isPinned } }
        switch sortOrder {
        case .name: base.sort { $0.title < $1.title }
        case .date: base.sort { $0.updatedAt > $1.updatedAt }
        case .priority: base.sort { priorityRank($0.priority) > priorityRank($1.priority) }
        case .status: base.sort { $0.status.rawValue < $1.status.rawValue }
        }
        return base
    }

    private var metricTiles: [MetricTileData] {
        [
            MetricTileData(label: "Total", value: "\(items.count)", detail: "all items", tint: SystemFlyeTheme.cyan),
            MetricTileData(label: "Active", value: "\(items.filter { $0.status == .active }.count)", detail: "in progress", tint: .green),
            MetricTileData(label: "Pinned", value: "\(items.filter { $0.isPinned }.count)", detail: "starred", tint: .orange),
            MetricTileData(label: "Archived", value: "\(items.filter { $0.isArchived }.count)", detail: "hidden", tint: .secondary)
        ]
    }

    struct MetricTileData { let label: String; let value: String; let detail: String; let tint: Color }

    private func statusColor(_ status: ItemStatus) -> Color {
        switch status { case .pending: return .orange; case .active: return SystemFlyeTheme.cyan; case .completed: return .green; case .failed: return .red; case .cancelled: return .secondary }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority { case .low: return .secondary; case .medium: return .blue; case .high: return .orange; case .urgent: return .red }
    }

    private func priorityRank(_ priority: Priority) -> Int {
        switch priority { case .low: return 1; case .medium: return 2; case .high: return 3; case .urgent: return 4 }
    }

    private func generateItems() {
        isRefreshing = true
        let statuses: [ItemStatus] = [.pending, .active, .completed, .failed, .cancelled]
        let priorities: [Priority] = [.low, .medium, .high, .urgent]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        let titles = ["Project Alpha", "Task Beta", "Feature Gamma", "Bug Delta", "Epic Epsilon", "Story Zeta", "Ticket Eta", "Issue Theta"]
        let subtitles = ["In progress", "Under review", "Blocked", "Ready for testing", "Draft", "Approved", "Pending", "Shipped"]
        items = (0..<50).map { _ in
            ExtendedItem(title: titles.randomElement()!, subtitle: subtitles.randomElement()!, description: "This is a detailed description for the item providing comprehensive context and background information.", status: statuses.randomElement()!, priority: priorities.randomElement()!, createdAt: Date().addingTimeInterval(-Double.random(in: 0...86400 * 30)), updatedAt: Date().addingTimeInterval(-Double.random(in: 0...86400)), tags: ["tag1", "tag2", "tag3"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }, metadata: ["key1": "value1", "key2": "value2"], isPinned: Bool.random(), isArchived: Bool.random(), color: colors.randomElement()!)
        }
        isRefreshing = false
    }
}

struct ExtendedDetailView_Previews: PreviewProvider {
    static var previews: some View { ExtendedDetailView().preferredColorScheme(.dark) }
}


// MARK: - Additional Comprehensive Implementation

struct AdditionalDetailView: View {
    @State private var dataItems: [DataItem] = []
    @State private var selectedIndex: Int? = nil
    @State private var isActive: Bool = true
    @State private var progress: Double = 0.5
    @State private var counter: Int = 0
    @State private var items: [ListItem] = []
    @State private var sections: [SectionItem] = []
    @State private var selectedSection: SectionItem?
    @State private var searchQuery: String = ""
    @State private var filterEnabled: Bool = true
    @State private var sortAscending: Bool = true
    @State private var currentPage: Int = 1
    @State private var totalItems: Int = 0
    @State private var showAdvanced: Bool = false
    @State private var showSettings: Bool = false
    @State private var showHelp: Bool = false
    @State private var isDarkMode: Bool = true
    @State private var accentTint: Color = SystemFlyeTheme.cyan
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 1.4
    @State private var cornerRadius: CGFloat = 12
    @State private var shadowRadius: CGFloat = 8
    @State private var animationDuration: Double = 0.3
    @State private var transitionStyle: TransitionStyle = .spring
    @State private var layoutDirection: LayoutDirection = .vertical
    @State private var spacing: CGFloat = 12
    @State private var padding: CGFloat = 18
    @State private var backgroundOpacity: Double = 0.02
    @State private var overlayOpacity: Double = 0.1
    @State private var borderWidth: CGFloat = 1.0
    @State private var borderColor: Color = SystemFlyeTheme.line
    @State private var shadowColor: Color = .black
    @State private var shadowOffset: CGSize = CGSize(width: 0, height: 4)
    @State private var contentMode: ContentMode = .fit
    @State private var alignment: Alignment = .leading
    @State private var distribution: Distribution = .equalSpacing
    @State private var priority: Priority = .normal

    enum TransitionStyle: String, CaseIterable { case spring = "Spring"; case easeIn = "Ease In"; case easeOut = "Ease Out"; case linear = "Linear"; case none = "None" }
    enum LayoutDirection: String, CaseIterable { case vertical = "Vertical"; case horizontal = "Horizontal" }
    enum ContentMode: String, CaseIterable { case fit = "Fit"; case fill = "Fill"; case scaleToFit = "Scale" }
    enum Distribution: String, CaseIterable { case equalSpacing = "Equal"; case equalCentering = "Centered"; case leading = "Leading"; case trailing = "Trailing" }
    enum Priority: String, CaseIterable { case low = "Low"; case normal = "Normal"; case high = "High" }

    struct DataItem: Identifiable {
        let id = UUID()
        var title: String
        var value: Double
        var unit: String
        var trend: TrendDirection
        var metadata: [String: String]
        enum TrendDirection { case up, down, neutral, volatile }
    }

    struct ListItem: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var timestamp: Date
        var isSelected: Bool
        var tags: [String]
        var color: Color
    }

    struct SectionItem: Identifiable {
        let id = UUID()
        var title: String
        var items: [ListItem]
        var isExpanded: Bool
        var color: Color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    controlPanel
                    contentSection
                    statisticsSection
                    actionButtons
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Additional Detail")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadData() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  A D D I T I O N A L", title: "Detail View")
                Spacer()
                Label("ACTIVE", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isActive ? .green : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background((isActive ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(overviewTiles) { tile in
                    MetricTile(label: tile.label, value: tile.value, detail: tile.detail, tint: tile.tint)
                }
            }
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search...", text: $searchQuery).textFieldStyle(.plain).foregroundStyle(.white)
                Toggle("", isOn: $filterEnabled).labelsHidden().tint(SystemFlyeTheme.cyan)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sections.indices, id: \.self) { index in
                        Button { selectedSection = sections[index] }
                            label: { Text(sections[index].title).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedSection?.id == sections[index].id ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedSection?.id == sections[index].id ? .black : .white.opacity(0.7)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button { loadData() }
                    label: { Label("Refresh", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { showAdvanced.toggle() }
                    label: { Label(showAdvanced ? "Hide" : "Advanced", systemImage: "gearshape.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(showAdvanced ? SystemFlyeTheme.violet : .secondary)
                Button { showHelp.toggle() }
                    label: { Label("Help", systemImage: "questionmark.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let section = selectedSection {
            sectionDetailView(section)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Circle().fill(item.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(item.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(SystemFlyeTheme.line))
                }
            }
        }
    }

    private func sectionDetailView(_ section: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
            LazyVStack(spacing: 8) {
                ForEach(section.items) { item in
                    HStack(spacing: 12) {
                        Circle().fill(item.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(item.description).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text(tag).font(.caption2).padding(.horizontal, 6).padding(.vertical, 3).background(Color.white.opacity(0.06), in: Capsule()).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATISTICS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Items", value: "\(items.count)")
                StatCard(label: "Sections", value: "\(sections.count)")
                StatCard(label: "Selected", value: selectedIndex != nil ? "1" : "0")
                StatCard(label: "Progress", value: "\(Int(progress * 100))%")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { counter += 1 }
                label: { Label("Increment", systemImage: "plus").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
            Button { counter = max(0, counter - 1) }
                label: { Label("Decrement", systemImage: "minus").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.bordered).tint(.orange)
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { progress = Double.random(in: 0...1) } }
                label: { Label("Random", systemImage: "dice.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.bordered).tint(.green)
            Spacer()
            Text("Count: \(counter)").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
        }
    }

    private var overviewTiles: [OverviewTile] {
        [
            OverviewTile(label: "Total", value: "\(items.count)", detail: "items loaded", tint: SystemFlyeTheme.cyan),
            OverviewTile(label: "Sections", value: "\(sections.count)", detail: "categories", tint: SystemFlyeTheme.violet),
            OverviewTile(label: "Selected", value: selectedIndex != nil ? "1" : "0", detail: "active", tint: .green),
            OverviewTile(label: "Counter", value: "\(counter)", detail: "increments", tint: .orange)
        ]
    }

    struct OverviewTile { let label: String; let value: String; let detail: String; let tint: Color }

    private func loadData() {
        let statuses: [ListItem.ItemStatus] = [.pending, .active, .completed, .failed, .cancelled]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        let titles = ["Project Alpha", "Task Beta", "Feature Gamma", "Bug Delta", "Epic Epsilon", "Story Zeta", "Ticket Eta", "Issue Theta"]
        let descriptions = ["In progress", "Under review", "Blocked", "Ready for testing", "Draft", "Approved", "Pending", "Shipped"]
        items = (0..<30).map { _ in
            ListItem(title: titles.randomElement()!, description: descriptions.randomElement()!, timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)), isSelected: Bool.random(), tags: ["tag1", "tag2", "tag3"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }, color: colors.randomElement()!)
        }
        sections = [
            SectionItem(title: "Overview", items: Array(items.prefix(10)), isExpanded: true, color: SystemFlyeTheme.cyan),
            SectionItem(title: "Details", items: Array(items.suffix(10)), isExpanded: false, color: SystemFlyeTheme.violet),
            SectionItem(title: "History", items: Array(items.shuffled().prefix(10)), isExpanded: false, color: .green)
        ]
        totalItems = items.count
    }
}

struct ListItem: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var timestamp: Date
    var isSelected: Bool
    var tags: [String]
    var color: Color
    enum ItemStatus: String { case pending = "Pending"; case active = "Active"; case completed = "Completed"; case failed = "Failed"; case cancelled = "Cancelled" }
}

struct SectionItem: Identifiable {
    let id = UUID()
    var title: String
    var items: [ListItem]
    var isExpanded: Bool
    var color: Color
}

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ExtendedDetailView_Previews: PreviewProvider {
    static var previews: some View { ExtendedDetailView().preferredColorScheme(.dark) }
}
