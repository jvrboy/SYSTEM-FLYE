import SwiftUI

struct DataVisualizationView: View {
    @State private var selectedChart: ChartVariant = .scatter
    @State private var scatterData: [ScatterPoint] = []
    @State private var barData: [BarItem] = []
    @State private var lineData: [LineSeries] = []
    @State private var pieData: [PieSlice] = []
    @State private var showLegend = true
    @State private var showGrid = true
    @State private var showDataLabels = true
    @State private var isAnimating = true
    @State private var animationProgress: CGFloat = 0.0
    @State private var selectedSlice: PieSlice?
    @State private var selectedBar: BarItem?
    @State private var selectedPoint: ScatterPoint?
    @State private var activeTab: DataVizTab = .chart
    @State private var chartBackground: Color = Color.white.opacity(0.02)
    @State private var showTooltip = true
    @State private var showCrosshair = true
    @State private var exportFormat: ExportFormat = .png
    @State private var showingExportSheet = false
    @State private var sortOrder: SortOrder = .none
    @State private var barOrientation: BarOrientation = .vertical
    @State private var lineSmoothing: SmoothingType = .linear
    @State private var donutHoleSize: CGFloat = 0.4
    @State private var bubbleMaxSize: CGFloat = 30
    @State private var radarAxes: Int = 5
    @State private var areaOpacity: Double = 0.2
    @State private var stackBars: Bool = false
    @State private var normalizeData: Bool = false
    @State private var showZeroLine: Bool = true
    @State private var interpolationMethod: InterpolationMethod = .linear
    @State private var pointShape: PointShape = .circle
    @State private var barBorderRadius: CGFloat = 4

    enum DataVizTab: String, CaseIterable { case chart = "Chart"; case data = "Data"; case settings = "Settings"; case export = "Export" }
    enum ChartVariant: String, CaseIterable, Identifiable {
        case scatter = "Scatter"; case bar = "Bar"; case line = "Line"; case pie = "Pie"; case area = "Area"; case bubble = "Bubble"; case radar = "Radar"; case donut = "Donut"
        var id: String { rawValue }
    }
    enum SortOrder: String, CaseIterable { case none = "None"; case ascending = "Ascending"; case descending = "Descending"; case byValue = "By Value" }
    enum BarOrientation: String, CaseIterable { case vertical = "Vertical"; case horizontal = "Horizontal" }
    enum SmoothingType: String, CaseIterable { case linear = "Linear"; case bezier = "Bezier"; case catmullRom = "Catmull-Rom" }
    enum ExportFormat: String, CaseIterable { case png = "PNG"; case svg = "SVG"; case pdf = "PDF"; case csv = "CSV"; case json = "JSON" }
    enum InterpolationMethod: String, CaseIterable { case linear = "Linear"; case monotone = "Monotone"; case cardinal = "Cardinal" }
    enum PointShape: String, CaseIterable { case circle = "Circle"; case square = "Square"; case triangle = "Triangle"; case diamond = "Diamond" }

    struct ScatterPoint: Identifiable {
        let id = UUID()
        var x: Double
        var y: Double
        var size: Double
        var color: Color
        var label: String
        var category: String
    }

    struct BarItem: Identifiable {
        let id = UUID()
        var label: String
        var value: Double
        var color: Color
        var group: String
        var secondaryValue: Double? = nil
    }

    struct LineSeries: Identifiable {
        let id = UUID()
        var name: String
        var values: [Double]
        var color: Color
        var isVisible: Bool = true
        var dashPattern: [CGFloat]? = nil
    }

    struct PieSlice: Identifiable {
        let id = UUID()
        var label: String
        var value: Double
        var color: Color
        var percentage: Double
        var description: String = ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  V I S U A L I Z A T I O N", title: "Data Charts")
                        Spacer()
                        Label("4 TYPES", systemImage: "chart.bar.doc.horizontal").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(ChartVariant.allCases) { chart in
                            MetricTile(label: chart.rawValue, value: countLabel(for: chart), detail: "data series", tint: chartColor(for: chart))
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(ChartVariant.allCases) { chart in
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedChart = chart } }
                                label: { Text(chart.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedChart == chart ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedChart == chart ? .black : .white.opacity(0.7)) }
                        }
                    }

                    HStack(spacing: 12) {
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showLegend.toggle() } }
                            label: { Label(showLegend ? "Hide Legend" : "Show Legend", systemImage: "list.bullet").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(showLegend ? SystemFlyeTheme.cyan : .secondary)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showGrid.toggle() } }
                            label: { Label(showGrid ? "Hide Grid" : "Show Grid", systemImage: "square.grid.3x3").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(showGrid ? SystemFlyeTheme.violet : .secondary)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showDataLabels.toggle() } }
                            label: { Label(showDataLabels ? "Hide Labels" : "Show Labels", systemImage: "textformat").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(showDataLabels ? .green : .secondary)
                        Button { withAnimation(.easeInOut(duration: 1.5)) { animationProgress = animationProgress == 0 ? 1.0 : 0.0 } }
                            label: { Label(isAnimating ? "Replay" : "Animate", systemImage: isAnimating ? "arrow.triangle.2.circlepath" : "play.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.borderedProminent).tint(.orange)
                        Button { showingExportSheet = true }
                            label: { Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.cyan)
                            .sheet(isPresented: $showingExportSheet) { exportView }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DataVizTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .chart: chartAreaView
                    case .data: dataTableView
                    case .settings: chartSettingsView
                    case .export: exportSettingsView
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Data Visualization").navigationBarTitleDisplayMode(.inline)
            .onAppear { generateAllData(); withAnimation(.easeInOut(duration: 2.0)) { animationProgress = 1.0 } }
        }
    }

    private func countLabel(for chart: ChartVariant) -> String {
        switch chart {
        case .scatter: return "\(scatterData.count)"
        case .bar: return "\(barData.count)"
        case .line: return "\(lineData.count)"
        case .pie: return "\(pieData.count)"
        case .area: return "\(lineData.count)"
        case .bubble: return "\(scatterData.count)"
        case .radar: return "\(lineData.count)"
        case .donut: return "\(pieData.count)"
        }
    }

    private func chartColor(for chart: ChartVariant) -> Color {
        switch chart {
        case .scatter: return SystemFlyeTheme.cyan
        case .bar: return SystemFlyeTheme.violet
        case .line: return .green
        case .pie: return .orange
        case .area: return .green
        case .bubble: return SystemFlyeTheme.cyan
        case .radar: return .purple
        case .donut: return .orange
        }
    }

    private func generateAllData() {
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal, .yellow, .indigo]
        scatterData = (0..<50).map { _ in
            ScatterPoint(x: Double.random(in: 0...100), y: Double.random(in: 0...100), size: Double.random(in: 4...16), color: colors.randomElement()!, label: "Point \(Int.random(in: 1...999))", category: ["A", "B", "C", "D"].randomElement()!)
        }
        barData = (0..<12).map { i in
            BarItem(label: "Category \(i + 1)", value: Double.random(in: 10...100), color: colors[i % colors.count], group: ["Group A", "Group B", "Group C"].randomElement()!)
        }
        lineData = [
            LineSeries(name: "Revenue", values: (0..<24).map { _ in Double.random(in: 100...500) }, color: SystemFlyeTheme.cyan),
            LineSeries(name: "Expenses", values: (0..<24).map { _ in Double.random(in: 50...300) }, color: .orange),
            LineSeries(name: "Profit", values: (0..<24).map { _ in Double.random(in: 20...200) }, color: .green)
        ]
        let total = (0..<6).map { _ in Double.random(in: 10...50) }.reduce(0, +)
        pieData = (0..<6).map { i in
            let value = Double.random(in: 10...50)
            return PieSlice(label: "Segment \(i + 1)", value: value, color: colors[i], percentage: value / total, description: "Description for segment \(i + 1)")
        }
    }

    private var chartAreaView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(selectedChart.rawValue.uppercased()) CHART").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(chartBackground)
                Group {
                    switch selectedChart {
                    case .scatter: scatterChart
                    case .bar: barChart
                    case .line: lineChart
                    case .pie: pieChart
                    case .area: areaChart
                    case .bubble: bubbleChart
                    case .radar: radarChart
                    case .donut: donutChart
                    }
                }
                .padding(.horizontal, 8).padding(.top, 8)
            }
            .frame(height: 340)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var scatterChart: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let padding: CGFloat = 40
            ZStack {
                if showGrid {
                    gridOverlay(width: width, height: height, padding: padding)
                }
                ForEach(scatterData) { point in
                    Circle().fill(point.color.opacity(0.7)).frame(width: point.size * animationProgress, height: point.size * animationProgress)
                        .position(x: padding + (point.x / 100) * (width - 2 * padding), y: height - padding - (point.y / 100) * (height - 2 * padding))
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPoint = point } }
                }
                if showDataLabels, let selected = selectedPoint {
                    Text(selected.label).font(.caption2.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Color.black.opacity(0.7), in: Capsule())
                        .position(x: padding + (selected.x / 100) * (width - 2 * padding), y: height - padding - (selected.y / 100) * (height - 2 * padding) - 20)
                }
            }
        }
    }

    private var barChart: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let maxValue = barData.map(\.value).max() ?? 1
            let barWidth = (width - 80) / CGFloat(barData.count) - 8
            let padding: CGFloat = 40
            ZStack {
                if showGrid { gridOverlay(width: width, height: height, padding: padding) }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(barData.enumerated()), id: \.element.id) { index, bar in
                        VStack(spacing: 4) {
                            if showDataLabels {
                                Text(String(format: "%.0f", bar.value * animationProgress)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            RoundedRectangle(cornerRadius: barBorderRadius).fill(bar.color.opacity(0.8)).frame(width: barWidth, height: max((bar.value / maxValue) * (height - 2 * padding) * animationProgress, 2))
                                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedBar = bar } }
                            Text(bar.label).font(.caption2).foregroundStyle(.secondary).rotationEffect(.degrees(-45)).frame(width: barWidth + 20, alignment: .bottom)
                        }
                    }
                }
                .padding(.horizontal, padding).padding(.bottom, padding)
            }
        }
    }

    private var lineChart: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let padding: CGFloat = 40
            let allValues = lineData.flatMap { $0.values }
            let minVal = allValues.min() ?? 0
            let maxVal = allValues.max() ?? 1
            let range = max(maxVal - minVal, 0.0001)
            ZStack {
                if showGrid { gridOverlay(width: width, height: height, padding: padding) }
                ForEach(lineData) { series in
                    if series.isVisible {
                        Path { p in
                            for (i, val) in series.values.enumerated() {
                                let x = padding + (CGFloat(i) / CGFloat(max(series.values.count - 1, 1))) * (width - 2 * padding)
                                let y = height - padding - ((val - minVal) / range) * (height - 2 * padding) * animationProgress
                                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(series.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: series.dashPattern ?? []))
                        if showDataLabels {
                            ForEach(Array(series.values.enumerated()), id: \.offset) { i, val in
                                let x = padding + (CGFloat(i) / CGFloat(max(series.values.count - 1, 1))) * (width - 2 * padding)
                                let y = height - padding - ((val - minVal) / range) * (height - 2 * padding) * animationProgress
                                Circle().fill(series.color).frame(width: 5, height: 5).position(x: x, y: y)
                            }
                        }
                    }
                }
            }
        }
    }

    private var pieChart: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size / 2 - 40
            let total = pieData.map(\.value).reduce(0, +)
            var startAngle: Double = 0
            ZStack {
                ForEach(Array(pieData.enumerated()), id: \.element.id) { index, slice in
                    let angle = (slice.value / total) * 360.0 * animationProgress
                    let endAngle = startAngle + angle
                    let midAngle = startAngle + angle / 2
                    Path { p in
                        p.move(to: center)
                        p.addArc(center: center, radius: radius, startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90), clockwise: false)
                        p.closeSubpath()
                    }
                    .fill(slice.color.opacity(selectedSlice?.id == slice.id ? 1.0 : 0.7))
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedSlice = slice } }
                    if showDataLabels && animationProgress > 0.5 {
                        let labelX = center.x + cos(.degrees(midAngle - 90)) * (radius * 0.65)
                        let labelY = center.y + sin(.degrees(midAngle - 90)) * (radius * 0.65)
                        Text("\(Int(slice.percentage * 100))%").font(.caption2.weight(.bold)).foregroundStyle(.white).position(x: labelX, y: labelY)
                    }
                    startAngle = endAngle
                }
                if let selected = selectedSlice {
                    Circle().fill(Color.black.opacity(0.3)).frame(width: size * 0.35, height: size * 0.35).position(center)
                }
            }
        }
    }

    private var areaChart: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let padding: CGFloat = 40
            let allValues = lineData.flatMap { $0.values }
            let minVal = allValues.min() ?? 0
            let maxVal = allValues.max() ?? 1
            let range = max(maxVal - minVal, 0.0001)
            ZStack {
                if showGrid { gridOverlay(width: width, height: height, padding: padding) }
                ForEach(lineData) { series in
                    if series.isVisible {
                        Path { p in
                            for (i, val) in series.values.enumerated() {
                                let x = padding + (CGFloat(i) / CGFloat(max(series.values.count - 1, 1))) * (width - 2 * padding)
                                let y = height - padding - ((val - minVal) / range) * (height - 2 * padding) * animationProgress
                                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                            }
                            p.addLine(to: CGPoint(x: width - padding, y: height - padding))
                            p.addLine(to: CGPoint(x: padding, y: height - padding))
                            p.closeSubpath()
                        }
                        .fill(series.color.opacity(areaOpacity))
                        .overlay(Path { p in
                            for (i, val) in series.values.enumerated() {
                                let x = padding + (CGFloat(i) / CGFloat(max(series.values.count - 1, 1))) * (width - 2 * padding)
                                let y = height - padding - ((val - minVal) / range) * (height - 2 * padding) * animationProgress
                                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }.stroke(series.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)))
                    }
                }
            }
        }
    }

    private var bubbleChart: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let padding: CGFloat = 40
            ZStack {
                if showGrid { gridOverlay(width: width, height: height, padding: padding) }
                ForEach(scatterData) { point in
                    Circle().fill(point.color.opacity(0.6)).frame(width: min(point.size * animationProgress, bubbleMaxSize), height: min(point.size * animationProgress, bubbleMaxSize))
                        .position(x: padding + (point.x / 100) * (width - 2 * padding), y: height - padding - (point.y / 100) * (height - 2 * padding))
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPoint = point } }
                }
            }
        }
    }

    private var radarChart: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size / 2 - 40
            let angles = (0..<radarAxes).map { Double($0) / Double(radarAxes) * 2 * .pi - .pi / 2 }
            ZStack {
                ForEach(0..<5) { i in
                    let r = radius * CGFloat(i + 1) / 5.0
                    Path { p in
                        for (j, angle) in angles.enumerated() {
                            let x = center.x + cos(angle) * r
                            let y = center.y + sin(angle) * r
                            j == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                        }
                        p.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
                ForEach(angles, id: \.self) { angle in
                    Path { p in p.move(to: center); p.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)) }
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
                ForEach(lineData) { series in
                    if series.isVisible {
                        Path { p in
                            for (i, angle) in angles.enumerated() {
                                let value = i < series.values.count ? series.values[i] : 0
                                let r = radius * CGFloat(value / 100.0) * animationProgress
                                let x = center.x + cos(angle) * r
                                let y = center.y + sin(angle) * r
                                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                            }
                            p.closeSubpath()
                        }
                        .fill(series.color.opacity(0.2))
                        .stroke(series.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
    }

    private var donutChart: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = size / 2 - 40
            let innerRadius = outerRadius * donutHoleSize
            let total = pieData.map(\.value).reduce(0, +)
            var startAngle: Double = 0
            ZStack {
                ForEach(Array(pieData.enumerated()), id: \.element.id) { index, slice in
                    let angle = (slice.value / total) * 360.0 * animationProgress
                    let endAngle = startAngle + angle
                    let midAngle = startAngle + angle / 2
                    Path { p in
                        p.move(to: CGPoint(x: center.x + cos(.degrees(midAngle - 90)) * innerRadius, y: center.y + sin(.degrees(midAngle - 90)) * innerRadius))
                        p.addArc(center: center, radius: outerRadius, startAngle: .degrees(startAngle - 90), endAngle: .degrees(endAngle - 90), clockwise: false)
                        p.addArc(center: center, radius: innerRadius, startAngle: .degrees(endAngle - 90), endAngle: .degrees(startAngle - 90), clockwise: true)
                        p.closeSubpath()
                    }
                    .fill(slice.color.opacity(selectedSlice?.id == slice.id ? 1.0 : 0.7))
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedSlice = slice } }
                    if showDataLabels && animationProgress > 0.5 {
                        let labelX = center.x + cos(.degrees(midAngle - 90)) * (outerRadius * 0.7)
                        let labelY = center.y + sin(.degrees(midAngle - 90)) * (outerRadius * 0.7)
                        Text("\(Int(slice.percentage * 100))%").font(.caption2.weight(.bold)).foregroundStyle(.white).position(x: labelX, y: labelY)
                    }
                    startAngle = endAngle
                }
            }
        }
    }

    private func gridOverlay(width: CGFloat, height: CGFloat, padding: CGFloat) -> some View {
        let hLines = 6
        let vLines = 8
        return Group {
            ForEach(0..<hLines, id: \.self) { i in
                Path { p in let y = padding + (height - 2 * padding) * CGFloat(i) / CGFloat(hLines - 1); p.move(to: CGPoint(x: padding, y: y)); p.addLine(to: CGPoint(x: width - padding, y: y)) }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            ForEach(0..<vLines, id: \.self) { i in
                Path { p in let x = padding + (width - 2 * padding) * CGFloat(i) / CGFloat(vLines - 1); p.move(to: CGPoint(x: x, y: padding)); p.addLine(to: CGPoint(x: x, y: height - padding)) }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            if showZeroLine {
                Path { p in let y = padding + (height - 2 * padding) * 0.5; p.move(to: CGPoint(x: padding, y: y)); p.addLine(to: CGPoint(x: width - padding, y: y)) }
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        }
    }

    private var dataTableView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DATA TABLE").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Label").font(.caption2.weight(.bold)).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                        Text("Value").font(.caption2.weight(.bold)).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                        Text("Category").font(.caption2.weight(.bold)).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    ForEach(Array(scatterData.prefix(15).enumerated()), id: \.element.id) { _, point in
                        HStack(spacing: 12) {
                            Text(point.label).font(.caption).foregroundStyle(.white).frame(width: 80, alignment: .leading)
                            Text(String(format: "%.2f", point.x)).font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 80, alignment: .leading)
                            Text(point.category).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var chartSettingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHART SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach([Color.white.opacity(0.02), .black.opacity(0.3), SystemFlyeTheme.ink, SystemFlyeTheme.panel], id: \.self) { color in
                            Circle().fill(color).frame(width: 28, height: 28).overlay(Circle().stroke(chartBackground == color ? SystemFlyeTheme.cyan : Color.clear, lineWidth: 2))
                                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { chartBackground = color } }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Line Smoothing").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $lineSmoothing) { ForEach(SmoothingType.allCases) { type in Text(type.rawValue).tag(type) } }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bar Orientation").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $barOrientation) { ForEach(BarOrientation.allCases) { orient in Text(orient.rawValue).tag(orient) } }
                    .pickerStyle(.segmented).frame(width: 200)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Donut Hole Size").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $donutHoleSize, in: 0...0.8).tint(SystemFlyeTheme.cyan)
                    Text("\(Int(donutHoleSize * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Point Shape").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $pointShape) { ForEach(PointShape.allCases) { shape in Text(shape.rawValue).tag(shape) } }
                    .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                }
                ToggleRow(title: "Show Zero Line", subtitle: "Display zero reference line", isOn: $showZeroLine)
                ToggleRow(title: "Normalize Data", subtitle: "Normalize values to 0-1 range", isOn: $normalizeData)
                ToggleRow(title: "Stack Bars", subtitle: "Stack bars on top of each other", isOn: $stackBars)
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var exportSettingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXPORT SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ForEach(ExportFormat.allCases) { format in
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                        label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(14).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                        .buttonStyle(.plain)
                }
            }
            Button { exportChart() }
                label: { Label("Export Chart", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
        }
    }

    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                switch selectedChart {
                case .scatter:
                    ForEach(Array(scatterData.prefix(5))) { point in
                        HStack(spacing: 6) { Circle().fill(point.color).frame(width: 10, height: 10); Text(point.label).font(.caption.weight(.semibold)).foregroundStyle(.white) }
                    }
                case .bar:
                    ForEach(barData.prefix(5)) { bar in
                        HStack(spacing: 6) { Circle().fill(bar.color).frame(width: 10, height: 10); Text(bar.label).font(.caption.weight(.semibold)).foregroundStyle(.white) }
                    }
                case .line:
                    ForEach(lineData) { series in
                        HStack(spacing: 6) { Circle().fill(series.color).frame(width: 10, height: 10); Text(series.name).font(.caption.weight(.semibold)).foregroundStyle(.white) }
                    }
                case .pie:
                    ForEach(pieData) { slice in
                        HStack(spacing: 6) { Circle().fill(slice.color).frame(width: 10, height: 10); Text(slice.label).font(.caption.weight(.semibold)).foregroundStyle(.white) }
                    }
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var exportView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Chart").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Format").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(ExportFormat.allCases) { format in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                            label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(12).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer()
                HStack(spacing: 12) { Button("Cancel") { showingExportSheet = false }.buttonStyle(.bordered()).tint(.secondary); Button("Export") { exportChart(); showingExportSheet = false }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan) }
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }

    private func exportChart() { print("Exporting chart as \(exportFormat.rawValue)...") }
}

struct DataVisualizationView_Previews: PreviewProvider {
    static var previews: some View { DataVisualizationView().preferredColorScheme(.dark) }
}

