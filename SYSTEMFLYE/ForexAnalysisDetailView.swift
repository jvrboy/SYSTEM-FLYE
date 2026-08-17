import SwiftUI

struct ForexAnalysisDetailView: View {
    @EnvironmentObject private var marketDataManager: MarketDataManager
    @State private var selectedPair: String = "EURUSD"
    @State private var selectedTimeframe: Timeframe = .oneDay
    @State private var selectedIndicator: IndicatorType = .rsi
    @State private var showingMultiChart = false
    @State private var overlayType: OverlayType = .movingAverages
    @State private var priceChartData: [Double] = []
    @State private var volumeData: [Double] = []
    @State private var indicatorData: [Double] = []
    @State private var supportLevels: [Double] = []
    @State private var resistanceLevels: [Double] = []
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var showAnnotations = true
    @State private var annotations: [ChartAnnotation] = []

    enum Timeframe: String, CaseIterable {
        case oneMin = "1m"
        case fiveMin = "5m"
        case fifteenMin = "15m"
        case oneHour = "1H"
        case fourHour = "4H"
        case oneDay = "1D"
        case oneWeek = "1W"

        var id: String { rawValue }
    }

    enum IndicatorType: String, CaseIterable {
        case rsi = "RSI"
        case macd = "MACD"
        case bollinger = "Bollinger"
        case atr = "ATR"
        case stochastic = "Stoch"
        case adx = "ADX"
    }

    enum OverlayType: String, CaseIterable {
        case movingAverages = "MA"
        case bollingerBands = "BB"
        case fibonacci = "Fib"
        case supportResistance = "S/R"
    }

    struct ChartAnnotation: Identifiable {
        let id = UUID()
        let text: String
        let price: Double
        let color: Color
        let type: AnnotationType

        enum AnnotationType {
            case support, resistance, signal, event
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  F O R E X", title: "Analysis Detail")
                        Spacer()
                        Label("MARKET OPEN", systemImage: "circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Price", value: currentPriceString, detail: "live mid-price", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Change", value: priceChangeString, detail: "session", tint: priceChange >= 0 ? .green : .orange)
                        MetricTile(label: "High", value: String(format: "%.5f", highPrice), detail: "24h", tint: .green)
                        MetricTile(label: "Low", value: String(format: "%.5f", lowPrice), detail: "24h", tint: .red)
                    }

                    HStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(marketDataManager.popularPairs, id: \.symbol) { pair in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedPair = pair.symbol
                                            generateChartData()
                                        }
                                    } label: {
                                        Text(pair.symbol)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedPair == pair.symbol ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule())
                                            .foregroundStyle(selectedPair == pair.symbol ? .black : .white.opacity(0.7))
                                    }
                                }
                            }
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingMultiChart.toggle()
                            }
                        } label: {
                            Label(showingMultiChart ? "Single" : "Multi", systemImage: "square.grid.2x2")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(showingMultiChart ? SystemFlyeTheme.cyan : .secondary)
                    }

                    if showingMultiChart {
                        multiChartView
                    } else {
                        singleChartView
                    }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Forex Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateChartData()
            }
        }
    }

    private var currentPrice: Double {
        let prices = ["EURUSD": 1.0850, "GBPUSD": 1.2650, "USDJPY": 154.50, "AUDUSD": 0.6520, "USDCHF": 0.8820]
        return prices[selectedPair] ?? 1.0850
    }

    private var priceChange: Double {
        currentPrice + Double.random(in: -0.005...0.005)
    }

    private var currentPriceString: String {
        String(format: "%.5f", currentPrice)
    }

    private var priceChangeString: String {
        let change = priceChange - currentPrice
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.5f", change))"
    }

    private var highPrice: Double {
        currentPrice + Double.random(in: 0.001...0.01)
    }

    private var lowPrice: Double {
        currentPrice - Double.random(in: 0.001...0.01)
    }

    private func generateChartData() {
        priceChartData = (0..<48).map { _ in
            currentPrice + Double.random(in: -0.01...0.01)
        }
        volumeData = (0..<48).map { _ in Double.random(in: 100...1000) }

        switch selectedIndicator {
        case .rsi:
            indicatorData = (0..<48).map { _ in Double.random(in: 20...80) }
        case .macd:
            indicatorData = (0..<48).map { _ in Double.random(in: -0.001...0.001) }
        case .bollinger:
            indicatorData = (0..<48).map { _ in currentPrice + Double.random(in: -0.02...0.02) }
        case .atr:
            indicatorData = (0..<48).map { _ in Double.random(in: 0.001...0.01) }
        case .stochastic:
            indicatorData = (0..<48).map { _ in Double.random(in: 20...80) }
        case .adx:
            indicatorData = (0..<48).map { _ in Double.random(in: 15...50) }
        }

        supportLevels = [
            currentPrice - 0.015,
            currentPrice - 0.03,
            currentPrice - 0.05
        ]

        resistanceLevels = [
            currentPrice + 0.015,
            currentPrice + 0.03,
            currentPrice + 0.05
        ]

        annotations = [
            ChartAnnotation(text: "Entry", price: currentPrice, color: .green, type: .signal),
            ChartAnnotation(text: "Support", price: supportLevels[0], color: .blue, type: .support),
            ChartAnnotation(text: "Resistance", price: resistanceLevels[0], color: .red, type: .resistance)
        ]
    }

    private var singleChartView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PRICE CHART — \(selectedPair)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.5f", currentPrice))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(SystemFlyeTheme.cyan)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.02))

                mainChartView
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                if showAnnotations {
                    annotationOverlay
                }
            }
            .frame(height: 280)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))

            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        zoomLevel = max(0.5, zoomLevel - 0.25)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Text("Zoom: \(Int(zoomLevel * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        zoomLevel = min(3.0, zoomLevel + 0.25)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showAnnotations.toggle()
                    }
                } label: {
                    Image(systemName: showAnnotations ? "text.bubble" : "text.bubble.slash")
                        .font(.caption)
                        .foregroundStyle(showAnnotations ? SystemFlyeTheme.cyan : .secondary)
                }
                .buttonStyle(.bordered)
                .tint(showAnnotations ? SystemFlyeTheme.cyan : .secondary)
            }

            indicatorSection
        }
    }

    private var mainChartView: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * zoomLevel
            let data = priceChartData
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 0.0001)

            ZStack(alignment: .topLeading) {
                ForEach(supportLevels, id: \.self) { level in
                    let y = proxy.size.height - ((level - minVal) / range) * proxy.size.height
                    Path { p in
                        p.move(to: CGPoint(x: -10, y: y))
                        p.addLine(to: CGPoint(x: proxy.size.width + 10, y: y))
                    }
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                ForEach(resistanceLevels, id: \.self) { level in
                    let y = proxy.size.height - ((level - minVal) / range) * proxy.size.height
                    Path { p in
                        p.move(to: CGPoint(x: -10, y: y))
                        p.addLine(to: CGPoint(x: proxy.size.width + 10, y: y))
                    }
                    .stroke(Color.red.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                Path { p in
                    for (i, val) in data.enumerated() {
                        let x = CGFloat(i) / CGFloat(max(data.count - 1, 1)) * width + panOffset
                        let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .trim(from: 0, to: 1)
                .stroke(SystemFlyeTheme.cyan, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(Array(data.enumerated()), id: \.offset) { i, val in
                    let x = CGFloat(i) / CGFloat(max(data.count - 1, 1)) * width + panOffset
                    let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                    Circle()
                        .fill(SystemFlyeTheme.cyan)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                        .opacity(zoomLevel > 1.2 ? 1 : 0)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [SystemFlyeTheme.cyan.opacity(0.08), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.15)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, SystemFlyeTheme.cyan.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 120)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.7)
            }
            .clipped()
        }
        .frame(height: 280)
    }

    private var annotationOverlay: some View {
        GeometryReader { proxy in
            let data = priceChartData
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 0.0001)

            ForEach(annotations) { annotation in
                let y = proxy.size.height - ((annotation.price - minVal) / range) * proxy.size.height
                VStack(spacing: 2) {
                    Image(systemName: annotation.type == .signal ? "arrow.up.right" : annotation.type == .support ? "arrow.down" : "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(annotation.color)
                    Text(annotation.text)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(annotation.color)
                }
                .position(x: proxy.size.width * 0.7, y: y - 20)
                .opacity(showAnnotations ? 1 : 0)
                .animation(.easeInOut, value: showAnnotations)
            }
        }
    }

    private var indicatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INDICATORS")
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IndicatorType.allCases) { indicator in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedIndicator = indicator
                                generateChartData()
                            }
                        } label: {
                            Text(indicator.rawValue)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedIndicator == indicator ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule())
                                .foregroundStyle(selectedIndicator == indicator ? .black : .white.opacity(0.7))
                        }
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.02))

                GeometryReader { proxy in
                    let data = indicatorData
                    guard let minVal = data.min(), let maxVal = data.max() else { return AnyView(Text("")) }
                    let range = max(maxVal - minVal, 0.0001)

                    Path { p in
                        for (i, val) in data.enumerated() {
                            let x = proxy.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                            let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(SystemFlyeTheme.violet, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
            .frame(height: 140)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var multiChartView: some View {
        VStack(spacing: 12) {
            ForEach(marketDataManager.popularPairs.prefix(3), id: \.symbol) { pair in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(pair.condition.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 80, alignment: .leading)

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.02))

                        Sparkline(values: (0..<20).map { _ in CGFloat.random(in: 0.1...1.0) })
                            .stroke(pair.condition == .bullish ? .green : pair.condition == .bearish ? .red : SystemFlyeTheme.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    .frame(width: 200, height: 50)
                }
                .padding(12)
                .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SystemFlyeTheme.line))
            }
        }
    }
}

struct ForexAnalysisDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ForexAnalysisDetailView()
            .environmentObject(MarketDataManager())
            .preferredColorScheme(.dark)
    }
}

