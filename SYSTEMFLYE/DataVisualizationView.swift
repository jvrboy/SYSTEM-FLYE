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
