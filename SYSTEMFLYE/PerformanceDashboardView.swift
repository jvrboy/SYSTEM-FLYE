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

