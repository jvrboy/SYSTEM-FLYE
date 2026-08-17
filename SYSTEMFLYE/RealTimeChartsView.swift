import SwiftUI

struct RealTimeChartsView: View {
    @State private var series: [DataSeries] = []
    @State private var selectedSeries: DataSeries?
    @State private var chartType: ChartType = .line
    @State private var isLive: Bool = true
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var showAnnotations = true
    @State private var showLegend = true
    @State private var showGrid = true
    @State private var smoothing: Double = 0.3
    @State private var dataPoints: Int = 60
    @State private var refreshInterval: Double = 1.0
    @State private var annotations: [ChartAnnotation] = []
    @State private var timer: Timer?
    @State private var selectedTab: RealTimeTab = .chart
    @State private var showCrosshair = true
    @State private var showDataLabels = true
    @State private var animationEnabled = true
    @State private var lineWidth: CGFloat = 2.5
    @State private var pointSize: CGFloat = 4.0
    @State private var fillOpacity: Double = 0.1
    @State private var yAxisMin: Double? = nil
    @State private var yAxisMax: Double? = nil
    @State private var showYAxisLabels = true
    @State private var showXAxisLabels = true
    @State private var showTooltip = true
    @State private var selectedPointIndex: Int? = nil
    @State private var comparisonMode = false
    @State private var exportFormat: ExportFormat = .png
    @State private var showingExportSheet = false
    @State private var chartBackground: Color = Color.white.opacity(0.02)

    enum RealTimeTab: String, CaseIterable { case chart = "Chart"; case series = "Series"; case annotations = "Annotations"; case export = "Export" }
    enum ChartType: String, CaseIterable { case line = "Line"; case area = "Area"; case bar = "Bar"; case scatter = "Scatter"; case stepped = "Stepped"; case smooth = "Smooth" }
    enum ExportFormat: String, CaseIterable { case png = "PNG"; case svg = "SVG"; case pdf = "PDF"; case csv = "CSV" }

    struct DataSeries: Identifiable {
        let id = UUID()
        var name: String
        var color: Color
        var values: [Double]
        var isVisible: Bool = true
        var lineWidth: CGFloat = 2.5
        var showPoints: Bool = true
        var fill: Bool = false
        var dashPattern: [CGFloat]? = nil
    }

    struct ChartAnnotation: Identifiable {
        let id = UUID()
        let text: String
        let value: Double
        let xIndex: Int
        let color: Color
        let style: AnnotationStyle
        enum AnnotationStyle { case verticalLine, horizontalLine, label, arrow }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  C H A R T S", title: "Real-Time")
                        Spacer()
                        Label(isLive ? "LIVE" : "PAUSED", systemImage: isLive ? "circle.fill" : "pause.circle.fill")
                            .font(.caption2.weight(.bold)).foregroundStyle(isLive ? .green : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 7).background((isLive ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Series", value: "\(series.count)", detail: "data streams", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Points", value: "\(dataPoints)", detail: "visible", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "Refresh", value: "\(String(format: "%.1f", refreshInterval))s", detail: "interval", tint: .green)
                        MetricTile(label: "Zoom", value: "\(Int(zoomLevel * 100))%", detail: "current", tint: .orange)
                    }

                    HStack(spacing: 12) {
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isLive.toggle() } }
                            label: { Label(isLive ? "Pause" : "Resume", systemImage: isLive ? "pause.fill" : "play.fill").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                            .buttonStyle(.borderedProminent).tint(isLive ? .orange : SystemFlyeTheme.cyan)
                        Picker("", selection: $chartType) { ForEach(ChartType.allCases, id: \.self) { type in Text(type.rawValue).tag(type) } }
                        .pickerStyle(.segmented).frame(width: 300)
                        Spacer()
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showAnnotations.toggle() } }
                            label: { Image(systemName: showAnnotations ? "text.bubble" : "text.bubble.slash").font(.caption).foregroundStyle(showAnnotations ? SystemFlyeTheme.cyan : .secondary) }
                            .buttonStyle(.bordered).tint(showAnnotations ? SystemFlyeTheme.cyan : .secondary)
                        Button { showingExportSheet = true }
                            label: { Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.cyan).sheet(isPresented: $showingExportSheet) { exportView }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RealTimeTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch selectedTab {
                    case .chart: chartAreaView
                    case .series: seriesSettingsView
                    case .annotations: annotationsSettingsView
                    case .export: exportSettingsView
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Real-Time Charts").navigationBarTitleDisplayMode(.inline)
            .onAppear { initializeSeries(); startLiveUpdates() }
            .onDisappear { stopLiveUpdates() }
        }
    }

    private func initializeSeries() {
        series = [
            DataSeries(name: "Signal A", color: SystemFlyeTheme.cyan, values: (0..<60).map { _ in Double.random(in: 20...80) }),
            DataSeries(name: "Signal B", color: SystemFlyeTheme.violet, values: (0..<60).map { _ in Double.random(in: 10...70) }),
            DataSeries(name: "Signal C", color: .green, values: (0..<60).map { _ in Double.random(in: 30...90) })
        ]
    }

    private func startLiveUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            guard isLive else { return }
            for i in series.indices {
                var newValues = series[i].values
                newValues.append(Double.random(in: 20...90))
                if newValues.count > 200 { newValues.removeFirst() }
                series[i].values = newValues
            }
        }
    }

    private func stopLiveUpdates() {
        timer?.invalidate()
        timer = nil
    }

    private var chartAreaView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHART AREA").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(chartBackground)
                GeometryReader { proxy in
                    if series.isEmpty {
                        Text("No data series available").font(.caption).foregroundStyle(.secondary)
                    } else {
                        chartContent(in: proxy)
                    }
                }
            }
            .frame(height: 340)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    @ViewBuilder
    private func chartContent(in proxy: GeometryProxy) -> some View {
        let allValues = series.compactMap { $0.values.last }
        let minVal = series.flatMap { $0.values }.min() ?? 0
        let maxVal = series.flatMap { $0.values }.max() ?? 1
        let range = max(maxVal - minVal, 0.0001)

        ZStack(alignment: .topLeading) {
            if showGrid {
                gridLines(in: proxy)
            }
            ForEach(series) { s in
                if s.isVisible {
                    seriesPath(series: s, in: proxy, minVal: minVal, range: range)
                }
            }
            if showAnnotations {
                annotationOverlay(in: proxy, minVal: minVal, range: range)
            }
            if showCrosshair, let selected = selectedSeries {
                crosshairOverlay(series: selected, in: proxy, minVal: minVal, range: range)
            }
            if showTooltip, let idx = selectedPointIndex {
                tooltipOverlay(index: idx, in: proxy, minVal: minVal, range: range)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture().onChanged { value in panOffset = value.translation.width / zoomLevel }.onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { panOffset = 0 } })
        .scaleEffect(x: zoomLevel, y: 1, anchor: .center)
        .gesture(MagnificationGesture().onChanged { value in zoomLevel = min(5.0, max(0.5, value)) })
    }

    private func gridLines(in proxy: GeometryProxy) -> some View {
        let width = proxy.size.width
        let height = proxy.size.height
        let hLines = 6
        let vLines = 8
        return Group {
            ForEach(0..<hLines, id: \.self) { i in
                Path { p in let y = height * CGFloat(i) / CGFloat(hLines - 1); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: width, y: y)) }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            ForEach(0..<vLines, id: \.self) { i in
                Path { p in let x = width * CGFloat(i) / CGFloat(vLines - 1); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: height)) }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            if showYAxisLabels {
                ForEach(0..<5, id: \.self) { i in
                    Text(String(format: "%.1f", minVal + (maxVal - minVal) * CGFloat(i) / 4.0)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).position(x: 25, y: height - CGFloat(i) * height / 4.0)
                }
            }
        }
    }

    private func seriesPath(series s: DataSeries, in proxy: GeometryProxy, minVal: Double, range: Double) -> some View {
        let values = s.values
        let width = proxy.size.width
        let height = proxy.size.height
        let step = width / CGFloat(max(values.count - 1, 1))
        return Group {
            if chartType == .line || chartType == .smooth {
                Path { p in
                    for (i, val) in values.enumerated() {
                        let x = CGFloat(i) * step + panOffset
                        let y = height - ((val - minVal) / range) * height
                        if chartType == .smooth {
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else {
                                let prevX = CGFloat(i - 1) * step + panOffset
                                let prevY = height - ((values[i - 1] - minVal) / range) * height
                                let cp1x = prevX + (x - prevX) / 2
                                let cp1y = prevY
                                let cp2x = prevX + (x - prevX) / 2
                                let cp2y = y
                                p.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: cp1x, y: cp1y), control2: CGPoint(x: cp2x, y: cp2y))
                            }
                        } else {
                            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(s.color, style: StrokeStyle(lineWidth: s.lineWidth, lineCap: .round, lineJoin: .round, dash: s.dashPattern ?? []))
                .fill(chartType == .area ? s.color.opacity(fillOpacity) : .clear)
            } else if chartType == .area {
                Path { p in
                    for (i, val) in values.enumerated() {
                        let x = CGFloat(i) * step + panOffset
                        let y = height - ((val - minVal) / range) * height
                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: width + panOffset, y: height))
                    p.addLine(to: CGPoint(x: panOffset, y: height))
                    p.closeSubpath()
                }
                .fill(s.color.opacity(fillOpacity))
                .overlay(Path { p in
                    for (i, val) in values.enumerated() {
                        let x = CGFloat(i) * step + panOffset
                        let y = height - ((val - minVal) / range) * height
                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                    }
                }.stroke(s.color, style: StrokeStyle(lineWidth: s.lineWidth, lineCap: .round, lineJoin: .round)))
            } else if chartType == .bar {
                ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                    let x = CGFloat(i) * step
                    let barWidth = max(step * 0.6, 2)
                    let y = height - ((val - minVal) / range) * height
                    RoundedRectangle(cornerRadius: 2).fill(s.color.opacity(0.7)).frame(width: barWidth, height: max(y, 2)).position(x: x + barWidth / 2, y: y)
                }
            } else if chartType == .scatter {
                ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                    let x = CGFloat(i) * step + panOffset
                    let y = height - ((val - minVal) / range) * height
                    Circle().fill(s.color).frame(width: s.showPoints ? pointSize + 3 : pointSize, height: s.showPoints ? pointSize + 3 : pointSize).position(x: x, y: y)
                }
            } else if chartType == .stepped {
                Path { p in
                    for (i, val) in values.enumerated() {
                        let x = CGFloat(i) * step + panOffset
                        let y = height - ((val - minVal) / range) * height
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else {
                            let prevX = CGFloat(i - 1) * step + panOffset
                            let prevY = height - ((values[i - 1] - minVal) / range) * height
                            p.addLine(to: CGPoint(x: prevX, y: y))
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(s.color, style: StrokeStyle(lineWidth: s.lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func annotationOverlay(in proxy: GeometryProxy, minVal: Double, range: Double) -> some View {
        Group {
            ForEach(annotations) { annotation in
                let width = proxy.size.width
                let height = proxy.size.height
                let x = width * CGFloat(annotation.xIndex) / CGFloat(max(dataPoints - 1, 1))
                switch annotation.style {
                case .verticalLine:
                    Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: height)) }
                    .stroke(annotation.color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                case .horizontalLine:
                    let y = height - ((annotation.value - minVal) / range) * height
                    Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: width, y: y)) }
                    .stroke(annotation.color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                case .label:
                    Text(annotation.text).font(.caption2.weight(.bold)).foregroundStyle(annotation.color).padding(.horizontal, 8).padding(.vertical, 4).background(Color.black.opacity(0.6), in: Capsule()).position(x: x, y: 20)
                case .arrow:
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(annotation.color).position(x: x, y: 20)
                }
            }
        }
    }

    private func crosshairOverlay(series: DataSeries, in proxy: GeometryProxy, minVal: Double, range: Double) -> some View {
        Group {
            if let last = series.values.last {
                let width = proxy.size.width
                let height = proxy.size.height
                let x = width * CGFloat(series.values.count - 1) / CGFloat(max(dataPoints - 1, 1))
                let y = height - ((last - minVal) / range) * height
                Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: height)); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: width, y: y)) }
                .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                Circle().fill(series.color).frame(width: 8, height: 8).position(x: x, y: y)
                VStack(spacing: 2) {
                    Text(String(format: "%.2f", last)).font(.caption2.monospacedDigit()).foregroundStyle(.white)
                    Text(series.name).font(.caption2).foregroundStyle(series.color)
                }
                .padding(.horizontal, 8).padding(.vertical, 4).background(Color.black.opacity(0.7), in: Capsule()).position(x: x + 50, y: y - 20)
            }
        }
    }

    private func tooltipOverlay(index: Int, in proxy: GeometryProxy, minVal: Double, range: Double) -> some View {
        Group {
            if let firstSeries = series.first, index < firstSeries.values.count {
                let width = proxy.size.width
                let height = proxy.size.height
                let x = width * CGFloat(index) / CGFloat(max(dataPoints - 1, 1))
                let y = height - ((firstSeries.values[index] - minVal) / range) * height
                VStack(spacing: 4) {
                    ForEach(series) { s in
                        if index < s.values.count {
                            HStack(spacing: 6) {
                                Circle().fill(s.color).frame(width: 6, height: 6)
                                Text(s.name).font(.caption2).foregroundStyle(.white)
                                Text(String(format: "%.2f", s.values[index])).font(.caption2.monospacedDigit()).foregroundStyle(s.color)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6).background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                .position(x: x + 80, y: y)
            }
        }
    }

    private var seriesSettingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SERIES SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ForEach(series) { s in
                HStack(spacing: 12) {
                    Circle().fill(s.color).frame(width: 10, height: 10)
                    Text(s.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: .constant(s.isVisible)).labelsHidden().tint(s.color)
                    Picker("", selection: .constant(s.lineWidth)) { Text("Thin").tag(1.5); Text("Normal").tag(2.5); Text("Thick").tag(4.0) }
                    .pickerStyle(.menu).tint(s.color)
                }
                .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var annotationsSettingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ANNOTATIONS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            if annotations.isEmpty {
                ContentUnavailableView("No Annotations", systemImage: "text.bubble") { Text("Add annotations to highlight important data points.").font(.caption).foregroundStyle(.secondary) }.frame(height: 150)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(annotations) { annotation in
                        HStack(spacing: 12) {
                            Image(systemName: annotation.style == .label ? "text.bubble" : "line.diagonal").font(.caption).foregroundStyle(annotation.color)
                            Text(annotation.text).font(.subheadline).foregroundStyle(.white)
                            Spacer()
                            Text("x: \(annotation.xIndex)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { annotations.removeAll { $0.id == annotation.id } } } label: { Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary) }
                        }
                        .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            Button { let newAnnotation = ChartAnnotation(text: "Marker \(annotations.count + 1)", value: Double.random(in: 20...80), xIndex: Int.random(in: 0..<dataPoints), color: [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange].randomElement()!, style: .label); withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { annotations.append(newAnnotation) } }
                label: { Label("Add Annotation", systemImage: "plus.circle.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
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
            HStack(spacing: 12) {
                Toggle("Include Annotations", isOn: .constant(true)).labelsHidden().tint(SystemFlyeTheme.cyan)
                Text("Annotations").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Include Legend", isOn: .constant(true)).labelsHidden().tint(SystemFlyeTheme.cyan)
                Text("Legend").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            Button { exportChart() }
                label: { Label("Export Chart", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
        }
    }

    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(series) { s in
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 10, height: 10)
                        Text(s.name).font(.caption.weight(.semibold)).foregroundStyle(.white)
                        Toggle("", isOn: .constant(s.isVisible)).labelsHidden().tint(s.color)
                            .onTapGesture { if let idx = series.firstIndex(where: { $0.id == s.id }) { series[idx].isVisible.toggle() } }
                    }
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

struct RealTimeChartsView_Previews: PreviewProvider {
    static var previews: some View { RealTimeChartsView().preferredColorScheme(.dark) }
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
