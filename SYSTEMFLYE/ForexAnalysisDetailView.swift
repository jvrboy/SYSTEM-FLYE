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
