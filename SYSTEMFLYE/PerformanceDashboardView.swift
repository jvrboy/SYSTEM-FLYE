import SwiftUI

struct PerformanceDashboardView: View {
    @State private var fpsHistory: [Double] = []
    @State private var memoryHistory: [Double] = []
    @State private var networkHistory: [Double] = []
    @State private var batteryHistory: [Double] = []
    @State private var cpuHistory: [Double] = []
    @State private var gpuHistory: [Double] = []
    @State private var diskHistory: [Double] = []
    @State private var thermalHistory: [Double] = []
    @State private var currentFPS: Double = 60
    @State private var currentMemory: Double = 120
    @State private var currentNetwork: Double = 2.4
    @State private var currentBattery: Double = 85
    @State private var currentCPU: Double = 15
    @State private var currentGPU: Double = 20
    @State private var currentDisk: Double = 45
    @State private var currentThermal: Double = 38
    @State private var isRecording = false
    @State private var selectedTimeRange: TimeRange = .oneMinute
    @State private var showDetailedMetrics = false
    @State private var alertThresholdFPS: Double = 30
    @State private var alertThresholdMemory: Double = 500
    @State private var alertThresholdCPU: Double = 80
    @State private var alerts: [PerformanceAlert] = []
    @State private var updateTimer: Timer?
    @State private var selectedMetric: MetricType = .fps
    @State private var comparisonMode = false
    @State private var previousMetrics: [Double] = []
    @State private var performanceScore: Double = 85
    @State private var benchmarkResults: [BenchmarkResult] = []

    enum TimeRange: String, CaseIterable { case tenSeconds = "10s"; case oneMinute = "1m"; case fiveMinutes = "5m"; case fifteenMinutes = "15m"; case oneHour = "1h"; var id: String { rawValue } }
    enum MetricType: String, CaseIterable { case fps = "FPS"; case memory = "Memory"; case cpu = "CPU"; case network = "Network"; case battery = "Battery"; case gpu = "GPU"; case disk = "Disk"; case thermal = "Thermal" }
    enum BenchmarkType: String, CaseIterable { case startup = "Startup"; case scrolling = "Scrolling"; case launch = "Launch"; case memory = "Memory" }

    struct PerformanceAlert: Identifiable {
        let id = UUID()
        let metric: String
        let message: String
        let severity: AlertSeverity
        let timestamp: Date
        enum AlertSeverity { case info, warning, critical }
    }

    struct BenchmarkResult: Identifiable {
        let id = UUID()
        let type: BenchmarkType
        let score: Double
        let timestamp: Date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  P E R F O R M A N C E", title: "Dashboard")
                        Spacer()
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isRecording.toggle() } }
                            label: { Label(isRecording ? "Stop Recording" : "Record", systemImage: isRecording ? "stop.fill" : "record.circle").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.borderedProminent).tint(isRecording ? .red : SystemFlyeTheme.cyan)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "FPS", value: String(format: "%.0f", currentFPS), detail: "frames per second", tint: currentFPS >= 55 ? .green : currentFPS >= 30 ? .orange : .red)
                        MetricTile(label: "Memory", value: String(format: "%.0f MB", currentMemory), detail: "heap usage", tint: currentMemory < 300 ? .green : currentMemory < 500 ? .orange : .red)
                        MetricTile(label: "CPU", value: String(format: "%.0f%%", currentCPU), detail: "processor load", tint: currentCPU < 50 ? .green : currentCPU < 80 ? .orange : .red)
                        MetricTile(label: "GPU", value: String(format: "%.0f%%", currentGPU), detail: "graphics load", tint: currentGPU < 60 ? .green : currentGPU < 80 ? .orange : .red)
                        MetricTile(label: "Network", value: String(format: "%.1f MB/s", currentNetwork), detail: "throughput", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Battery", value: "\(Int(currentBattery))%", detail: "charge level", tint: currentBattery > 20 ? .green : .red)
                        MetricTile(label: "Disk", value: String(format: "%.0f%%", currentDisk), detail: "storage usage", tint: currentDisk < 70 ? .green : currentDisk < 90 ? .orange : .red)
                        MetricTile(label: "Thermal", value: "\(Int(currentThermal))°C", detail: "device temp", tint: currentThermal < 40 ? .green : currentThermal < 60 ? .orange : .red)
                        MetricTile(label: "Alerts", value: "\(alerts.count)", detail: "threshold events", tint: alerts.isEmpty ? .green : .orange)
                        MetricTile(label: "Score", value: "\(Int(performanceScore))", detail: "overall rating", tint: performanceScore >= 90 ? .green : performanceScore >= 70 ? SystemFlyeTheme.cyan : .orange)
                    }

                    HStack(spacing: 8) {
                        ForEach(TimeRange.allCases) { range in
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTimeRange = range } }
                                label: { Text(range.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 6).background(selectedTimeRange == range ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedTimeRange == range ? .black : .white.opacity(0.7)) }
                        }
                        Spacer()
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { comparisonMode.toggle() } }
                            label: { Label(comparisonMode ? "Hide Comparison" : "Compare", systemImage: "chart.bar.doc.horizontal").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(comparisonMode ? SystemFlyeTheme.cyan : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("REAL-TIME METRICS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        VStack(spacing: 12) {
                            ForEach(metricCharts) { chart in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(chart.title).font(.caption.weight(.semibold)).foregroundStyle(.white)
                                        Spacer()
                                        Text("\(String(format: "%.1f", chart.data.last ?? 0)) \(chart.unit)").font(.caption.monospacedDigit()).foregroundStyle(chart.color)
                                    }
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.02))
                                        GeometryReader { proxy in
                                            let data = chart.data
                                            guard !data.isEmpty else { return AnyView(Text("")) }
                                            let minVal = data.min() ?? 0
                                            let maxVal = data.max() ?? 1
                                            let range = max(maxVal - minVal, 0.0001)
                                            Path { p in
                                                for (i, val) in data.enumerated() {
                                                    let x = proxy.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                                                    let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                                                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                                                }
                                            }
                                            .stroke(chart.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                            if let last = data.last {
                                                let x = proxy.size.width * CGFloat(data.count - 1) / CGFloat(max(data.count - 1, 1))
                                                let y = proxy.size.height - ((last - minVal) / range) * proxy.size.height
                                                Circle().fill(chart.color).frame(width: 6, height: 6).position(x: x, y: y)
                                            }
                                        }
                                    }
                                    .frame(height: 70)
                                }
                            }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))

                    if !alerts.isEmpty { alertsView.padding(.top, 4) }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("THRESHOLD SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        VStack(spacing: 12) {
                            HStack { Text("FPS Alert").font(.caption).foregroundStyle(.secondary); Spacer(); Slider(value: $alertThresholdFPS, in: 10...60).tint(.orange); Text("\(Int(alertThresholdFPS))").font(.caption.monospacedDigit()).foregroundStyle(.orange).frame(width: 30) }
                            HStack { Text("Memory Alert").font(.caption).foregroundStyle(.secondary); Spacer(); Slider(value: $alertThresholdMemory, in: 100...1000).tint(SystemFlyeTheme.cyan); Text("\(Int(alertThresholdMemory))").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 40) }
                            HStack { Text("CPU Alert").font(.caption).foregroundStyle(.secondary); Spacer(); Slider(value: $alertThresholdCPU, in: 50...100).tint(.purple); Text("\(Int(alertThresholdCPU))%").font(.caption.monospacedDigit()).foregroundStyle(.purple).frame(width: 35) }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("BENCHMARKS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        LazyVStack(spacing: 8) {
                            ForEach(benchmarkResults) { result in
                                HStack(spacing: 12) {
                                    Text(result.type.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(result.score)) pts").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                                    Text(result.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Performance").navigationBarTitleDisplayMode(.inline)
            .onAppear { startMonitoring() }
            .onDisappear { stopMonitoring() }
        }
    }

    struct MetricChart: Identifiable {
        let id = UUID()
        let title: String
        let data: [Double]
        let color: Color
        let unit: String
    }

    private var metricCharts: [MetricChart] {
        [
            MetricChart(title: "Frame Rate (FPS)", data: fpsHistory, color: .green, unit: "fps"),
            MetricChart(title: "Memory Usage (MB)", data: memoryHistory, color: SystemFlyeTheme.cyan, unit: "MB"),
            MetricChart(title: "CPU Load (%)", data: cpuHistory, color: .orange, unit: "%"),
            MetricChart(title: "GPU Usage (%)", data: gpuHistory, color: .purple, unit: "%"),
            MetricChart(title: "Network (MB/s)", data: networkHistory, color: SystemFlyeTheme.violet, unit: "MB/s"),
            MetricChart(title: "Battery (%)", data: batteryHistory, color: .green, unit: "%"),
            MetricChart(title: "Disk Usage (%)", data: diskHistory, color: .blue, unit: "%"),
            MetricChart(title: "Thermal (°C)", data: thermalHistory, color: .red, unit: "°C")
        ]
    }

    private var alertsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALERTS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(alerts.suffix(8)) { alert in
                    HStack(spacing: 10) {
                        Circle().fill(alert.severity == .critical ? .red : .orange).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(alert.message).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(alert.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary) }
                        Spacer()
                    }
                    .padding(10).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func startMonitoring() {
        generateInitialData()
        generateBenchmarks()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in updateMetrics() }
    }

    private func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func generateInitialData() {
        fpsHistory = (0..<50).map { _ in Double.random(in: 50...65) }
        memoryHistory = (0..<50).map { _ in Double.random(in: 80...200) }
        cpuHistory = (0..<50).map { _ in Double.random(in: 5...40) }
        gpuHistory = (0..<50).map { _ in Double.random(in: 10...50) }
        networkHistory = (0..<50).map { _ in Double.random(in: 0.5...5) }
        batteryHistory = (0..<50).map { _ in Double.random(in: 70...95) }
        diskHistory = (0..<50).map { _ in Double.random(in: 30...60) }
        thermalHistory = (0..<50).map { _ in Double.random(in: 30...50) }
    }

    private func generateBenchmarks() {
        benchmarkResults = [
            BenchmarkResult(type: .startup, score: Double.random(in: 80...100), timestamp: Date().addingTimeInterval(-3600)),
            BenchmarkResult(type: .scrolling, score: Double.random(in: 70...100), timestamp: Date().addingTimeInterval(-1800)),
            BenchmarkResult(type: .launch, score: Double.random(in: 60...100), timestamp: Date().addingTimeInterval(-900)),
            BenchmarkResult(type: .memory, score: Double.random(in: 75...100), timestamp: Date().addingTimeInterval(-600))
        ]
    }

    private func updateMetrics() {
        currentFPS = Double.random(in: 50...65)
        currentMemory = Double.random(in: 100...300)
        currentCPU = Double.random(in: 5...40)
        currentGPU = Double.random(in: 10...50)
        currentNetwork = Double.random(in: 0.5...5)
        currentBattery = max(0, currentBattery - 0.01)
        currentDisk = Double.random(in: 30...60)
        currentThermal = Double.random(in: 30...50)

        fpsHistory.append(currentFPS); memoryHistory.append(currentMemory); cpuHistory.append(currentCPU)
        gpuHistory.append(currentGPU); networkHistory.append(currentNetwork); batteryHistory.append(currentBattery)
        diskHistory.append(currentDisk); thermalHistory.append(currentThermal)

        if fpsHistory.count > 60 { fpsHistory.removeFirst() }
        if memoryHistory.count > 60 { memoryHistory.removeFirst() }
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
        if gpuHistory.count > 60 { gpuHistory.removeFirst() }
        if networkHistory.count > 60 { networkHistory.removeFirst() }
        if batteryHistory.count > 60 { batteryHistory.removeFirst() }
        if diskHistory.count > 60 { diskHistory.removeFirst() }
        if thermalHistory.count > 60 { thermalHistory.removeFirst() }

        if currentFPS < alertThresholdFPS { alerts.append(PerformanceAlert(metric: "FPS", message: "Frame rate dropped below \(Int(alertThresholdFPS))", severity: .warning, timestamp: Date())) }
        if currentMemory > alertThresholdMemory { alerts.append(PerformanceAlert(metric: "Memory", message: "Memory usage exceeded \(Int(alertThresholdMemory)) MB", severity: .warning, timestamp: Date())) }
        if currentCPU > alertThresholdCPU { alerts.append(PerformanceAlert(metric: "CPU", message: "CPU usage exceeded \(Int(alertThresholdCPU))%", severity: .warning, timestamp: Date())) }
        if currentBattery < 20 { alerts.append(PerformanceAlert(metric: "Battery", message: "Battery level critical", severity: .critical, timestamp: Date())) }
        if alerts.count > 20 { alerts.removeFirst(alerts.count - 20) }

        performanceScore = max(0, min(100, performanceScore + Double.random(in: -1...1)))
    }
}

struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View { PerformanceDashboardView().preferredColorScheme(.dark) }
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
