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


struct TechnicalIndicatorDetailView_Previews: PreviewProvider {
    static var previews: some View { TechnicalIndicatorDetailView().environmentObject(MarketDataManager()).preferredColorScheme(.dark) }
}

