import SwiftUI

struct TechnicalIndicatorDetailView: View {
    @EnvironmentObject private var marketDataManager: MarketDataManager
    @State private var selectedPair: String = "EURUSD"
    @State private var selectedIndicator: IndicatorType = .rsi
    @State private var timeRange: TimeRange = .oneDay
    @State private var showOverlay = true
    @State private var showDivergences = true
    @State private var alertThresholds: [AlertThreshold] = []
    @State private var currentValues: [Double] = []
    @State private var divergenceSignals: [DivergenceSignal] = []
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var selectedTab: IndicatorTab = .chart
    @State private var indicatorHistory: [IndicatorHistoryEntry] = []
    @State private var correlationData: [[Double]] = []
    @State private var signalStrength: Double = 0.7
    @State private var noiseLevel: Double = 0.3
    @State private var smoothingPeriod: Int = 14
    @State private var signalPeriod: Int = 9
    @State private var thresholdUpper: Double = 70
    @State private var thresholdLower: Double = 30
    @State private var zeroLineEnabled = true
    @State private var showHistogram = true
    @State private var histogramData: [Double] = []
    @State private var selectedIndicator2: IndicatorType = .macd
    @State private var showSecondIndicator = false
    @State private var smoothingEnabled = true
    @State private var smoothingWindow: Double = 3.0
    @State private var showSignalLine = true
    @State private var showHistogramBars = true
    @State private var histogramColor: Color = SystemFlyeTheme.violet
    @State private var lineColor: Color = SystemFlyeTheme.cyan
    @State private var fillColor: Color = SystemFlyeTheme.cyan.opacity(0.1)
    @State private var showVolume = false
    @State private var volumeData: [Double] = []
    @State private var showMA = false
    @State private var maPeriod: Int = 20
    @State private var maData: [Double] = []
    @State private var showBollingerBands = false
    @State private var bollingerPeriod: Int = 20
    @State private var bollingerStdDev: Double = 2.0
    @State private var bollingerUpper: [Double] = []
    @State private var bollingerMiddle: [Double] = []
    @State private var bollingerLower: [Double] = []
    @State private var activeIndicator: ActiveIndicator = .primary
    @State private var comparisonMode = false
    @State private var showingIndicatorInfo = false

    enum TimeRange: String, CaseIterable {
        case oneDay = "1D"; case oneWeek = "1W"; case oneMonth = "1M"; case threeMonths = "3M"; case oneYear = "1Y"
    }

    enum IndicatorType: String, CaseIterable, Identifiable {
        case rsi = "RSI"; case macd = "MACD"; case bollinger = "Bollinger"; case atr = "ATR"; case stochastic = "Stoch"; case adx = "ADX"; case cci = "CCI"; case obv = "OBV"; case vwap = "VWAP"; case ichimoku = "Ichimoku"
        var id: String { rawValue }
        var description: String {
            switch self {
            case .rsi: return "Measures speed and magnitude of price changes. Values above 70 indicate overbought, below 30 oversold."
            case .macd: return "Shows relationship between two moving averages. Crossovers indicate trend changes."
            case .bollinger: return "Bands plotted at standard deviations above/below moving average. Width indicates volatility."
            case .atr: return "Average True Range measures volatility. Higher values indicate greater volatility."
            case .stochastic: return "Compares closing price to price range over time. Values above 80 overbought, below 20 oversold."
            case .adx: return "Average Directional Index measures trend strength regardless of direction. Above 25 indicates strong trend."
            case .cci: return "Commodity Channel Index measures current price level relative to average. Above +100 overbought, below -100 oversold."
            case .obv: return "On-Balance Volume adds volume on up days, subtracts on down days. Shows buying/selling pressure."
            case .vwap: return "Volume Weighted Average Price. Intraday benchmark showing fair value."
            case .ichimoku: return "Japanese charting system showing support/resistance, trend direction, and momentum."
            }
        }
    }

    enum IndicatorTab: String, CaseIterable { case chart = "Chart"; case divergence = "Divergence"; case correlation = "Correlation"; case settings = "Settings" }

    enum ActiveIndicator: String, CaseIterable { case primary = "Primary"; case secondary = "Secondary"; case both = "Both" }

    struct AlertThreshold: Identifiable {
        let id = UUID()
        let indicator: IndicatorType
        let condition: AlertCondition
        let value: Double
        let isEnabled: Bool
        enum AlertCondition { case above, below, crossesAbove, crossesBelow, equals }
    }

    struct DivergenceSignal: Identifiable {
        let id = UUID()
        let type: DivergenceType
        let pair: String
        let pricePoint: Double
        let indicatorValue: Double
        let confidence: Double
        let timestamp: Date
        enum DivergenceType { case bullish, bearish, hiddenBullish, hiddenBearish }
    }

    struct IndicatorHistoryEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let value: Double
        let signal: SignalType
        enum SignalType { case buy, sell, neutral, overbought, oversold }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  T E C H N I C A L", title: "Indicator Detail")
                        Spacer()
                        Label("REAL-TIME", systemImage: "waveform.path").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Pair", value: selectedPair, detail: "analyzed", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Indicator", value: selectedIndicator.rawValue, detail: selectedIndicator.description.prefix(30) + "...", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "Current", value: currentValueString, detail: "latest reading", tint: currentValueColor)
                        MetricTile(label: "Divergences", value: "\(divergenceSignals.count)", detail: "detected", tint: divergenceSignals.count > 0 ? .orange : .green)
                    }

                    HStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(IndicatorType.allCases) { indicator in
                                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedIndicator = indicator; generateData() } }
                                        label: { Text(indicator.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(selectedIndicator == indicator ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedIndicator == indicator ? .black : .white.opacity(0.7)) }
                                }
                            }
                        }
                        Spacer()
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showOverlay.toggle() } }
                            label: { Image(systemName: showOverlay ? "chart.xyaxis.line" : "chart.xyaxis.line.slash").font(.caption).foregroundStyle(showOverlay ? SystemFlyeTheme.cyan : .secondary) }
                            .buttonStyle(.bordered).tint(showOverlay ? SystemFlyeTheme.cyan : .secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(IndicatorTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch selectedTab {
                    case .chart: chartTab
                    case .divergence: divergenceTab
                    case .correlation: correlationTab
                    case .settings: settingsTab
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Technical Indicator").navigationBarTitleDisplayMode(.inline)
            .onAppear { generateData(); generateHistory(); setupAlertThresholds(); generateCorrelation(); generateHistogram() }
        }
    }

    @State private var activeTab: IndicatorTab = .chart

    private var currentValue: Double { currentValues.last ?? 50.0 }
    private var currentValueString: String { String(format: "%.2f", currentValue) }
    private var currentValueColor: Color {
        switch selectedIndicator {
        case .rsi, .stochastic: if currentValue > 70 { return .red }; if currentValue < 30 { return .green }; return SystemFlyeTheme.cyan
        case .macd: return currentValue > 0 ? .green : .red
        default: return SystemFlyeTheme.cyan
        }
    }

    private var chartTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(selectedIndicator.rawValue) — \(selectedPair)").font(.headline.weight(.semibold)).foregroundStyle(.white)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                GeometryReader { proxy in
                    let data = currentValues
                    guard !data.isEmpty else { return AnyView(Text("")) }
                    let minVal = data.min() ?? 0
                    let maxVal = data.max() ?? 1
                    let range = max(maxVal - minVal, 0.0001)
                    ZStack {
                        Path { p in
                            for (i, val) in data.enumerated() {
                                let x = proxy.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                                let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        if showHistogramBars {
                            ForEach(Array(data.enumerated()), id: \.offset) { i, val in
                                let x = proxy.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                                let height = abs(val) / range * proxy.size.height * 0.3
                                RoundedRectangle(cornerRadius: 2).fill(histogramColor.opacity(0.6)).frame(width: 4, height: max(height, 2)).position(x: x, y: proxy.size.height - height / 2)
                            }
                        }
                        if showSignalLine {
                            Path { p in
                                for (i, val) in data.enumerated() {
                                    let x = proxy.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                                    let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(lineColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 4]))
                        }
                        if zeroLineEnabled {
                            Path { p in let y = proxy.size.height - ((0 - minVal) / range) * proxy.size.height; p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: proxy.size.width, y: y)) }
                            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        ForEach(Array(data.enumerated()), id: \.offset) { i, val in
                            let x = proxy.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                            let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                            Circle().fill(lineColor).frame(width: 4, height: 4).position(x: x, y: y)
                        }
                        if showOverlay {
                            Path { p in
                                let upperY = proxy.size.height - ((maxVal - minVal) * 0.8 + minVal - minVal) / range * proxy.size.height
                                p.move(to: CGPoint(x: 0, y: upperY)); p.addLine(to: CGPoint(x: proxy.size.width, y: upperY))
                            }
                            .stroke(SystemFlyeTheme.violet.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            Path { p in
                                let lowerY = proxy.size.height - ((maxVal - minVal) * 0.2 + minVal - minVal) / range * proxy.size.height
                                p.move(to: CGPoint(x: 0, y: lowerY)); p.addLine(to: CGPoint(x: proxy.size.width, y: lowerY))
                            }
                            .stroke(SystemFlyeTheme.violet.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.top, 8)
            }
            .frame(height: 260)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))

            HStack(spacing: 12) {
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showDivergences.toggle() } }
                    label: { Label(showDivergences ? "Hide Divergences" : "Show Divergences", systemImage: "triangle.two").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8) }
                    .buttonStyle(.bordered).tint(showDivergences ? SystemFlyeTheme.violet : .secondary)
                Button { scanForDivergences() }
                    label: { Label(isScanning ? "Scanning…" : "Scan Divergences", systemImage: "magnifyingglass").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.violet).disabled(isScanning)
                if isScanning { ProgressView(value: scanProgress).tint(SystemFlyeTheme.violet).frame(width: 100) }
                Button { showingIndicatorInfo = true }
                    label: { Label("Info", systemImage: "info.circle").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8) }
                    .buttonStyle(.bordered).tint(.green).sheet(isPresented: $showingIndicatorInfo) { indicatorInfoView }
            }
        }
    }

    private var lineColor: Color {
        switch selectedIndicator {
        case .rsi, .stochastic: return SystemFlyeTheme.cyan
        case .macd: return SystemFlyeTheme.violet
        case .bollinger: return .green
        case .atr: return .orange
        case .adx: return .purple
        case .cci: return .pink
        case .obv: return .blue
        case .vwap: return .teal
        case .ichimoku: return .indigo
        }
    }

    private var histogramColor: Color {
        switch selectedIndicator {
        case .macd: return currentValue >= 0 ? .green : .red
        default: return SystemFlyeTheme.violet
        }
    }

    private var divergenceTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DIVERGENCE SIGNALS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            if divergenceSignals.isEmpty {
                ContentUnavailableView("No Divergences Detected", systemImage: "triangle.two") { Text("Run a divergence scan to detect patterns.").font(.caption).foregroundStyle(.secondary) }.frame(height: 150)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(divergenceSignals) { signal in
                        HStack(spacing: 12) {
                            Image(systemName: signal.type == .bullish || signal.type == .hiddenBullish ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(signal.type == .bullish || signal.type == .hiddenBullish ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(signal.type.rawValue.capitalized).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text("Confidence: \(Int(signal.confidence * 100))%").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(signal.indicatorValue))").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                        }
                        .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var correlationTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CORRELATION MATRIX").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(correlationData.enumerated()), id: \.offset) { row in
                        VStack(spacing: 4) {
                            ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
                                RoundedRectangle(cornerRadius: 4).fill(correlationColor(for: cell.element)).frame(width: 40, height: 40)
                                    .overlay(Text(String(format: "%.2f", cell.element)).font(.caption2.monospacedDigit()).foregroundStyle(.white))
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("INDICATOR SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smoothing Period").font(.caption).foregroundStyle(.secondary)
                    Slider(value: .constant(Double(smoothingPeriod)), in: 1...50, step: 1).tint(SystemFlyeTheme.cyan)
                    Text("\(smoothingPeriod)").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signal Period").font(.caption).foregroundStyle(.secondary)
                    Slider(value: .constant(Double(signalPeriod)), in: 1...50, step: 1).tint(SystemFlyeTheme.violet)
                    Text("\(signalPeriod)").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet)
                }
                HStack {
                    Text("Upper Threshold").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Slider(value: $thresholdUpper, in: 50...90).tint(.red)
                    Text("\(Int(thresholdUpper))").font(.caption.monospacedDigit()).foregroundStyle(.red).frame(width: 25)
                }
                HStack {
                    Text("Lower Threshold").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Slider(value: $thresholdLower, in: 10...50).tint(.green)
                    Text("\(Int(thresholdLower))").font(.caption.monospacedDigit()).foregroundStyle(.green).frame(width: 25)
                }
                ToggleRow(title: "Zero Line", subtitle: "Show zero reference line", isOn: $zeroLineEnabled)
                ToggleRow(title: "Histogram", subtitle: "Show histogram bars", isOn: $showHistogram)
                ToggleRow(title: "Signal Line", subtitle: "Show signal line overlay", isOn: $showSignalLine)
                ToggleRow(title: "Volume", subtitle: "Show volume bars", isOn: $showVolume)
                ToggleRow(title: "Moving Average", subtitle: "Show MA overlay", isOn: $showMA)
                ToggleRow(title: "Bollinger Bands", subtitle: "Show Bollinger Bands", isOn: $showBollingerBands)
                ToggleRow(title: "Comparison Mode", subtitle: "Compare two indicators", isOn: $comparisonMode)
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var indicatorInfoView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Indicator Information").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Name").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(selectedIndicator.rawValue).font(.title3.weight(.bold)).foregroundStyle(.white)
                    Text("Description").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(selectedIndicator.description).font(.subheadline).foregroundStyle(.white)
                    Text("Current Value").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(currentValueString).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(currentValueColor)
                    Text("Signal Strength").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(Int(signalStrength * 100))%").font(.title3.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan).monospacedDigit()
                    Text("Noise Level").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(Int(noiseLevel * 100))%").font(.title3.weight(.bold)).foregroundStyle(.orange).monospacedDigit()
                }
                Spacer()
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }

    private func correlationColor(for value: Double) -> Color {
        let t = max(0, min(1, (value + 1) / 2))
        if value > 0.5 { return Color.red.opacity(0.3 + t * 0.5) }
        if value < -0.5 { return Color.blue.opacity(0.3 + (1 - t) * 0.5) }
        return Color.gray.opacity(0.3)
    }

    private func generateData() {
        switch selectedIndicator {
        case .rsi, .stochastic: currentValues = (0..<48).map { _ in Double.random(in: 20...80) }
        case .macd: currentValues = (0..<48).map { _ in Double.random(in: -0.001...0.001) }
        case .bollinger: currentValues = (0..<48).map { _ in currentPrice + Double.random(in: -0.02...0.02) }
        case .atr: currentValues = (0..<48).map { _ in Double.random(in: 0.001...0.01) }
        case .adx: currentValues = (0..<48).map { _ in Double.random(in: 15...50) }
        case .cci: currentValues = (0..<48).map { _ in Double.random(in: -100...100) }
        case .obv: currentValues = (0..<48).map { _ in Double.random(in: -1000000...1000000) }
        case .vwap: currentValues = (0..<48).map { _ in Double.random(in: -0.01...0.01) }
        case .ichimoku: currentValues = (0..<48).map { _ in Double.random(in: -0.02...0.02) }
        }
        signalStrength = Double.random(in: 0.5...0.95)
        noiseLevel = Double.random(in: 0.05...0.3)
    }

    private var currentPrice: Double {
        let prices = ["EURUSD": 1.0850, "GBPUSD": 1.2650, "USDJPY": 154.50, "AUDUSD": 0.6520, "USDCHF": 0.8820]
        return prices[selectedPair] ?? 1.0850
    }

    private func generateHistory() {
        let types: [IndicatorHistoryEntry.SignalType] = [.buy, .sell, .neutral, .overbought, .oversold]
        indicatorHistory = (0..<30).map { i in
            IndicatorHistoryEntry(timestamp: Date().addingTimeInterval(-Double(i) * 1800), value: Double.random(in: 0...100), signal: types.randomElement()!)
        }
    }

    private func setupAlertThresholds() {
        alertThresholds = [
            AlertThreshold(indicator: .rsi, condition: .above, value: 70, isEnabled: true),
            AlertThreshold(indicator: .rsi, condition: .below, value: 30, isEnabled: true),
            AlertThreshold(indicator: .macd, condition: .crossesAbove, value: 0, isEnabled: true),
            AlertThreshold(indicator: .adx, condition: .above, value: 25, isEnabled: false)
        ]
    }

    private func generateCorrelation() {
        correlationMatrix = (0..<5).map { _ in (0..<5).map { _ in Double.random(in: -1...1) } }
    }

    private func generateHistogram() {
        histogramData = (0..<20).map { _ in Double.random(in: 0.1...1.0) }
    }

    private func scanForDivergences() {
        isScanning = true; scanProgress = 0; divergenceSignals.removeAll()
        Task { @MainActor in
            for i in 0..<20 { try? await Task.sleep(for: .milliseconds(50)); scanProgress = Double(i) / 20.0 }
            let types: [DivergenceSignal.DivergenceType] = [.bullish, .bearish, .hiddenBullish, .hiddenBearish]
            divergenceSignals = (0..<Int.random(in: 3...8)).map { _ in
                DivergenceSignal(type: types.randomElement()!, pair: selectedPair, pricePoint: Double.random(in: 1.0...2.0), indicatorValue: Double.random(in: 20...80), confidence: Double.random(in: 0.6...0.95), timestamp: Date())
            }
            isScanning = false; scanProgress = 1.0
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity, alignment: .leading)
        Toggle("", isOn: $isOn).labelsHidden().tint(SystemFlyeTheme.cyan)
    }
}

struct TechnicalIndicatorDetailView_Previews: PreviewProvider {
    static var previews: some View { TechnicalIndicatorDetailView().environmentObject(MarketDataManager()).preferredColorScheme(.dark) }
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
