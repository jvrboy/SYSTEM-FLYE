import SwiftUI

// MARK: - Advanced Tools View
struct AdvancedToolsView: View {
    @EnvironmentObject private var store: AdvancedStore
    @EnvironmentObject private var analytics: AnalyticsEngine
    @EnvironmentObject private var backend: BackendServiceManager
    @State private var selectedTool: ToolCategory = .analytics
    @State private var selectedPairsForComparison: Set<String> = ["EURUSD", "GBPUSD", "USDJPY"]
    @State private var showMonteCarlo = false
    @State private var showStressTest = false
    @State private var isRunningAnalysis = false
    @State private var selectedTimeframe: AdvancedToolsView.AnalyticsTimeframe = .oneWeek
    
    enum ToolCategory: String, CaseIterable, Identifiable {
        case analytics = "Analytics"
        case comparison = "Compare"
        case heatmap = "Heatmap"
        case backend = "Backend"
        
        var id: String { rawValue }
    }
    
    enum AnalyticsTimeframe: String, CaseIterable, Identifiable {
        case oneDay = "1D"
        case oneWeek = "1W"
        case oneMonth = "1M"
        case threeMonths = "3M"
        case oneYear = "1Y"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overviewHeader
                tabBar
                
                if selectedTool == .analytics {
                    AnalyticsPanel()
                } else if selectedTool == .comparison {
                    ComparisonMatrix(selectedPairsForComparison: $selectedPairsForComparison)
                } else if selectedTool == .heatmap {
                    SignalHeatmap()
                } else {
                    BackendToolsPanel()
                }
            }
            .padding(18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }
    
    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  A D V A N C E D", title: toolTitle)
                Spacer()
                Label("ADVANCED", systemImage: "cpu").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.violet).padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.violet.opacity(0.12), in: Capsule())
            }
            
            HStack(spacing: 12) {
                MetricTile(label: "API latency", value: String(format: "%.0fms", backend.services.map { $0.latency * 1000 }.reduce(0, +) / Double(max(backend.services.count, 1))), detail: "average across services", tint: SystemFlyeTheme.cyan)
                MetricTile(label: "Service health", value: backend.overallHealth.rawValue, detail: "\(backend.services.count) endpoints", tint: backend.overallHealth == .healthy ? .green : .orange)
                MetricTile(label: "Data transfer", value: backend.formattedDataTransferred(), detail: "session total", tint: .purple)
            }
        }
    }
    
    private var toolTitle: String {
        switch selectedTool {
        case .analytics: return "Advanced Analytics"
        case .comparison: return "Pair Comparison"
        case .heatmap: return "Signal Heatmap"
        case .backend: return "Backend Tools"
        }
    }
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ToolCategory.allCases) { category in
                    Button(category.rawValue) { selectedTool = category }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedTool == category ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(selectedTool == category ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule())
                }
            }
        }
    }
}

// MARK: - Analytics Panel
struct AnalyticsPanel: View {
    @EnvironmentObject private var analytics: AnalyticsEngine
    @EnvironmentObject private var store: AdvancedStore
    @EnvironmentObject private var marketDataManager: MarketDataManager
    @State private var isRunning = false
    @State private var selectedTimeframe: AdvancedToolsView.AnalyticsTimeframe = .oneWeek
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Portfolio Analytics Engine").font(.headline.weight(.bold))
                Spacer()
                Button(isRunning ? "Running…" : "Run Analysis") {
                    Task { await runAnalysis() }
                }
                .buttonStyle(.borderedProminent)
                .tint(SystemFlyeTheme.violet)
                .disabled(isRunning)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(label: "Sharpe Ratio", value: String(format: "%.2f", analytics.sharpeRatio), detail: "risk-adjusted return", tint: .green)
                MetricTile(label: "Sortino Ratio", value: String(format: "%.2f", analytics.sortinoRatio), detail: "downside risk", tint: SystemFlyeTheme.cyan)
                MetricTile(label: "Value at Risk", value: String(format: "%.1f%%", analytics.valueAtRisk * 100), detail: "95% confidence", tint: .orange)
                MetricTile(label: "Anomalies", value: "\(analytics.anomalies.count)", detail: "price outliers detected", tint: analytics.anomalies.count > 0 ? .red : .green)
                MetricTile(label: "Monte Carlo", value: analytics.monteCarloResults.isEmpty ? "—" : "\(analytics.monteCarloResults.count) sims", detail: "stochastic paths", tint: .purple)
                MetricTile(label: "Max Drawdown", value: String(format: "%.2f%%", analytics.calculateMaxDrawdown(prices: selectedPrices)), detail: "worst case", tint: .orange)
            }
            
            if let stress = analytics.stressTestResults {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stress Test Results").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    ForEach(stress.scenarios) { result in
                        HStack {
                            Circle().fill(result.scenario.color).frame(width: 8, height: 8)
                            Text(result.scenario.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(Int((1 - result.scenario.expectedLoss) * 100))% survive").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text("-$\(String(format: "%.0f", result.loss))").font(.caption.monospacedDigit()).foregroundStyle(.red)
                        }
                        .padding(12).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            if !analytics.correlationMatrix.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Correlation Matrix").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(analytics.correlationMatrix.enumerated()), id: \.offset) { row in
                                VStack(spacing: 4) {
                                    ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(correlationColor(for: cell.element))
                                            .frame(width: 40, height: 40)
                                            .overlay(Text(String(format: "%.2f", cell.element)).font(.caption2.monospacedDigit()).foregroundStyle(.white))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("Run Monte Carlo") { Task { await runMonteCarlo() } }
                    .buttonStyle(.bordered).tint(.purple)
                Button("Run Stress Test") { Task { await runStressTest() } }
                    .buttonStyle(.bordered).tint(.orange)
                Button("Detect Anomalies") { Task { await detectAnomalies() } }
                    .buttonStyle(.bordered).tint(.red)
            }
        }
    }
    
    private func runAnalysis() async {
        isRunning = true
        await runMonteCarlo()
        await runStressTest()
        await detectAnomalies()
        isRunning = false
    }
    
    private func runMonteCarlo() async {
        let prices = selectedPrices
        let basePrice = prices.last ?? (store.selectedPair == "EUR/USD" ? 1.08 : 1.26)
        let returns = zip(prices.dropFirst(), prices).map { ($0 - $1) / max($1, 0.00001) }
        let volatility = max(MathUtilities.standardDeviation(returns), 0.05)
        await analytics.runMonteCarloSimulation(basePrice: basePrice, volatility: volatility, days: 30, simulations: 500)
    }
    
    private func runStressTest() async {
        let scenarios: [StressScenario] = [
            StressScenario(name: "Flash Crash", description: "10% drop in 1 hour", expectedLoss: 0.10, color: .stressRed),
            StressScenario(name: "Volatility Spike", description: "3x normal volatility", expectedLoss: 0.05, color: .stressOrange),
            StressScenario(name: "Liquidity Crisis", description: "Margin call cascade", expectedLoss: 0.15, color: .stressRed),
            StressScenario(name: "Rate Shock", description: "Unexpected rate decision", expectedLoss: 0.03, color: .stressOrange)
        ]
        _ = analytics.runStressTest(portfolio: Portfolio(totalBalance: 10000, usedMargin: 2000, availableMargin: 8000, totalProfit: 1500, totalLoss: 300, winRate: 65), scenarios: scenarios)
    }
    
    private func detectAnomalies() async {
        _ = analytics.detectAnomalies(prices: selectedPrices)
    }

    private var selectedPrices: [Double] {
        let symbol = store.selectedPair.replacingOccurrences(of: "/", with: "")
        return (marketDataManager.priceHistory[symbol] ?? marketDataManager.priceHistory[store.selectedPair] ?? []).map(\.close)
    }
    
    private func correlationColor(for value: Double) -> Color {
        let intensity = abs(value)
        if value > 0 { return Color.green.opacity(intensity) }
        return Color.red.opacity(intensity)
    }
}

// MARK: - Comparison Matrix
struct ComparisonMatrix: View {
    @Binding var selectedPairsForComparison: Set<String>
    @EnvironmentObject private var marketDataManager: MarketDataManager
    @State private var metric: ComparisonMetric = .price
    @State private var timeRange: ComparisonTimeRange = .day
    
    enum ComparisonMetric: String, CaseIterable, Identifiable {
        case price = "Price"
        case volatility = "Volatility"
        case rsi = "RSI"
        case volume = "Volume"
        
        var id: String { rawValue }
    }
    
    enum ComparisonTimeRange: String, CaseIterable, Identifiable {
        case day = "1D"
        case week = "1W"
        case month = "1M"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Multi-Pair Comparison").font(.headline.weight(.bold))
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(ComparisonMetric.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                Picker("Range", selection: $timeRange) {
                    ForEach(ComparisonTimeRange.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            
            let pairs = Array(selectedPairsForComparison)
            if pairs.isEmpty {
                Text("Select pairs to compare from the heatmap or settings.").font(.subheadline).foregroundStyle(.secondary).padding()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: max(pairs.count, 1)), spacing: 12) {
                    ForEach(pairs, id: \.self) { pair in
                        ComparisonCard(pair: pair, metric: metric, timeRange: timeRange)
                    }
                }
            }
        }
    }
}

struct ComparisonCard: View {
    let pair: String
    let metric: ComparisonMatrix.ComparisonMetric
    let timeRange: ComparisonMatrix.ComparisonTimeRange
    
    @EnvironmentObject private var marketDataManager: MarketDataManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pair).font(.headline.weight(.bold)).foregroundStyle(.white)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.rawValue).font(.caption).foregroundStyle(.secondary)
                    Text(metricValue).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(valueColor)
                }
                Spacer()
                Image(systemName: trendIcon).font(.title2).foregroundStyle(trendColor)
            }
            .padding(12).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SystemFlyeTheme.line))
        }
    }
    
    private var metricValue: String {
        switch metric {
        case .price: return String(format: "%.5f", marketDataManager.currentPrices[pair] ?? 0)
        case .volatility:
            let history = marketDataManager.priceHistory[pair] ?? []
            let closes = history.map(\.close)
            guard closes.count > 1 else { return "—" }
            let returns = zip(closes.dropFirst(), closes).map { ($0 - $1) / max($1, 0.00001) }
            let mean = returns.reduce(0, +) / Double(returns.count)
            let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(returns.count - 1, 1))
            return String(format: "%.2f%%", sqrt(variance) * 100)
        case .rsi:
            let indicators = marketDataManager.technicalIndicators[pair]
            return indicators.map { String(format: "%.1f", $0.rsi) } ?? "—"
        case .volume:
            let volume = marketDataManager.priceHistory[pair]?.last?.volume ?? 0
            return volume > 0 ? String(format: "%.0fK", Double(volume) / 1_000) : "—"
        }
    }
    
    private var valueColor: Color {
        guard metric == .rsi,
              let rsi = marketDataManager.technicalIndicators[pair]?.rsi else { return .white }
        return rsi < 30 ? .green : rsi > 70 ? .red : .white
    }

    private var trendIsPositive: Bool {
        let history = marketDataManager.priceHistory[pair] ?? []
        guard let first = history.first?.close, let last = history.last?.close else { return true }
        return last >= first
    }

    private var trendIcon: String { trendIsPositive ? "arrow.up.right" : "arrow.down.right" }
    private var trendColor: Color { trendIsPositive ? .green : .red }
}

// MARK: - Signal Heatmap
struct SignalHeatmap: View {
    @EnvironmentObject private var signalGenerator: SignalGenerator
    @EnvironmentObject private var store: AdvancedStore
    @State private var hoveredPair: String?
    
    let pairs: [String] = ["EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD", "EURGBP", "EURJPY", "GBPJPY"]
    let signals: [QuantSignal] = [
        QuantSignal(pair: "EUR/USD", direction: "LONG", score: 0.82, regime: "Trend", risk: "0.8R"),
        QuantSignal(pair: "GBP/JPY", direction: "SHORT", score: 0.74, regime: "Volatile", risk: "1.2R"),
        QuantSignal(pair: "AUD/USD", direction: "WATCH", score: 0.51, regime: "Range", risk: "0.4R")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Signal Strength Heatmap").font(.headline.weight(.bold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(pairs, id: \.self) { pair in
                    let signal = signals.first { $0.pair.replacingOccurrences(of: "/", with: "") == pair }
                    HeatmapCell(pair: pair, signal: signal, isHovered: hoveredPair == pair)
                        .onHover { hovering in
                            hoveredPair = hovering ? pair : nil
                        }
                }
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 16))
            
            HStack(spacing: 24) {
                HStack(spacing: 6) { Rectangle().fill(Color.green.opacity(0.3)).frame(width: 16, height: 16); Text("Strong Buy").font(.caption) }
                HStack(spacing: 6) { Rectangle().fill(Color.orange.opacity(0.3)).frame(width: 16, height: 16); Text("Moderate").font(.caption) }
                HStack(spacing: 6) { Rectangle().fill(Color.red.opacity(0.3)).frame(width: 16, height: 16); Text("Sell").font(.caption) }
                HStack(spacing: 6) { Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 16, height: 16); Text("Neutral").font(.caption) }
            }
            .padding(.horizontal, 8)
        }
    }
}

struct HeatmapCell: View {
    let pair: String
    let signal: QuantSignal?
    let isHovered: Bool
    
    var cellColor: Color {
        guard let signal = signal else { return Color.gray.opacity(0.2) }
        switch signal.direction {
        case "LONG": return Color.green.opacity(0.3 + Double(signal.score) * 0.5)
        case "SHORT": return Color.red.opacity(0.3 + Double(signal.score) * 0.5)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(pair.replacingOccurrences(of: "/", with: "/\n")).font(.caption2.weight(.bold)).multilineTextAlignment(.center).foregroundStyle(.white)
            if let signal = signal {
                Text("\(Int(signal.score * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(cellColor)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isHovered ? Color.white : Color.clear, lineWidth: isHovered ? 2 : 0))
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Backend Tools Panel
struct BackendToolsPanel: View {
    @EnvironmentObject private var backend: BackendServiceManager
    @State private var cacheSize: Int = 0
    @State private var circuitState = "CLOSED"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Backend Service Manager").font(.headline.weight(.bold))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(label: "Active connections", value: "\(backend.activeConnections)", detail: "concurrent requests", tint: SystemFlyeTheme.cyan)
                MetricTile(label: "Data transferred", value: backend.formattedDataTransferred(), detail: "session total", tint: .purple)
                MetricTile(label: "Circuit state", value: circuitState, detail: "backend resilience", tint: .green)
                MetricTile(label: "Cache entries", value: "\(cacheSize)", detail: "in-memory cache", tint: .orange)
            }
            
            HStack(spacing: 12) {
                Button("Refresh Services") { Task { await backend.performHealthChecks() } }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button("Clear Cache") {
                    CacheManager.shared.clear()
                    cacheSize = 0
                }
                .buttonStyle(.bordered).tint(.orange)
                Button("Run Diagnostics") {
                    Task { await BackgroundSyncScheduler.shared.runAll() }
                }
                .buttonStyle(.bordered).tint(.purple)
            }
            
            Text("Service Health").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(backend.services) { service in
                ServiceHealthRow(service: service)
            }
        }
        .task { circuitState = String(describing: await CircuitBreaker.shared.currentState()).uppercased() }
    }
}

struct ServiceHealthRow: View {
    let service: ServiceDescriptor
    
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("\(service.endpoint)  ·  \(String(format: "%.0fms", service.latency * 1000))  ·  \(String(format: "%.1f%%", service.uptime)) uptime").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(service.health.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor)
        }
        .padding(12).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        switch service.health {
        case .healthy: return .green
        case .degraded: return .orange
        case .down: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview
#Preview {
    AdvancedToolsView()
        .environmentObject(AdvancedStore())
        .environmentObject(AnalyticsEngine())
        .environmentObject(BackendServiceManager.shared)
        .environmentObject(MarketDataManager())
}
