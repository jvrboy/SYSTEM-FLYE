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

