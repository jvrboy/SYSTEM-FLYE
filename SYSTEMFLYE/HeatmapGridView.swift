import SwiftUI

struct HeatmapGridView: View {
    @State private var gridData: [[HeatmapCell]] = []
    @State private var selectedCell: HeatmapCell?
    @State private var colorScale: ColorScale = .viridis
    @State private var showTooltips = true
    @State private var showColorLegend = true
    @State private var clusteringEnabled = true
    @State private var drillDownLevel: Int = 0
    @State private var zoomLevel: CGFloat = 1.0
    @State private var isRefreshing = false
    @State private var drillDownPath: [String] = []
    @State private var selectedTab: HeatmapTab = .grid
    @State private var sortOrder: SortOrder = .none
    @State private var filterValue: Double = 0.0
    @State private var showHistogram = false
    @State private var showStatistics = true
    @State private var rowLabels: [String] = []
    @State private var columnLabels: [String] = []
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 1
    @State private var averageValue: Double = 0
    @State private var standardDeviation: Double = 0
    @State private var clusterCount: Int = 0
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .csv

    enum HeatmapTab: String, CaseIterable { case grid = "Grid"; case clusters = "Clusters"; case statistics = "Statistics"; case export = "Export" }
    enum SortOrder: String, CaseIterable { case none = "None"; case ascending = "Ascending"; case descending = "Descending"; case byRow = "By Row"; case byColumn = "By Column" }
    enum ExportFormat: String, CaseIterable { case csv = "CSV"; case json = "JSON"; case png = "PNG"; case svg = "SVG" }

    struct HeatmapCell: Identifiable {
        let id = UUID()
        let row: String
        let column: String
        let value: Double
        let category: String
        let trend: TrendDirection
        let details: [String: String]
        enum TrendDirection { case up, down, neutral }
    }

    enum ColorScale: String, CaseIterable, Identifiable {
        case viridis = "Viridis"; case plasma = "Plasma"; case inferno = "Inferno"; case magma = "Magma"; case coolWarm = "Cool-Warm"; case blues = "Blues"; case greens = "Greens"; case reds = "Reds"
        var id: String { rawValue }
        func color(for value: Double) -> Color {
            let t = max(0, min(1, value))
            switch self {
            case .viridis: return Color(red: 0.267 + t * (0.993 - 0.267), green: 0.005 + t * (0.906 - 0.005), blue: 0.329 + t * (0.144 - 0.329))
            case .plasma: return Color(red: 0.050 + t * (0.940 - 0.050), green: 0.030 + t * (0.975 - 0.030), blue: 0.527 + t * (0.131 - 0.527))
            case .inferno: return Color(red: 0.001 + t * (0.988 - 0.001), green: 0.001 + t * (0.998 - 0.001), blue: 0.014 + t * (0.645 - 0.014))
            case .magma: return Color(red: 0.001 + t * (0.817 - 0.001), green: 0.001 + t * (0.114 - 0.001), blue: 0.136 + t * (0.937 - 0.136))
            case .coolWarm: return t < 0.5 ? Color(red: 0.231 + (0.5 - t) * 2 * (0.000 - 0.231), green: 0.321 + (0.5 - t) * 2 * (0.565 - 0.321), blue: 0.792 + (0.5 - t) * 2 * (0.851 - 0.792)) : Color(red: 0.000 + (t - 0.5) * 2 * (0.851 - 0.000), green: 0.565 + (t - 0.5) * 2 * (0.192 - 0.565), blue: 0.851 + (t - 0.5) * 2 * (0.098 - 0.851))
            case .blues: return Color(red: 0.968 - t * 0.4, green: 0.985 - t * 0.3, blue: 1.000 - t * 0.1)
            case .greens: return Color(red: 0.900 - t * 0.6, green: 0.980 - t * 0.2, blue: 0.850 - t * 0.5)
            case .reds: return Color(red: 1.000 - t * 0.1, green: 0.900 - t * 0.5, blue: 0.850 - t * 0.5)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  H E A T M A P", title: "Grid View")
                        Spacer()
                        Label("\(gridData.count) x \(gridData.first?.count ?? 0)", systemImage: "square.grid.2x2").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Cells", value: "\(gridData.count * (gridData.first?.count ?? 0))", detail: "total data points", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Selected", value: selectedCell != nil ? "1" : "0", detail: "active cell", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "Clusters", value: "\(clusterCount)", detail: "detected groups", tint: .green)
                        MetricTile(label: "Avg Value", value: String(format: "%.2f", averageValue), detail: "grid average", tint: .orange)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isRefreshing = true; generateGridData(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { isRefreshing = false } } }
                                label: { Label(isRefreshing ? "Refreshing…" : "Refresh", systemImage: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan).disabled(isRefreshing)
                            ForEach(ColorScale.allCases) { scale in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { colorScale = scale } }
                                    label: { Text(scale.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(colorScale == scale ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(colorScale == scale ? .black : .white.opacity(0.7)) }
                            }
                            Spacer()
                            Button { showingExportSheet = true }
                                label: { Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
                                .buttonStyle(.bordered).tint(SystemFlyeTheme.cyan).sheet(isPresented: $showingExportSheet) { exportOptionsView }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(HeatmapTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch selectedTab {
                    case .grid: gridTab
                    case .clusters: clustersTab
                    case .statistics: statisticsTab
                    case .export: exportTab
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Heatmap Grid").navigationBarTitleDisplayMode(.inline)
            .onAppear { generateGridData() }
        }
    }

    private var gridTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HEATMAP GRID").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            if !drillDownPath.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(drillDownPath.enumerated()), id: \.offset) { index, path in
                        Text(path).font(.caption2.weight(.semibold)).foregroundStyle(SystemFlyeTheme.cyan)
                    }
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drillDownPath.removeLast(); drillDownLevel = max(0, drillDownLevel - 1); generateGridData() } }
                        label: { Image(systemName: "arrow.left").font(.caption2).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, 4).padding(.vertical, 4)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    heatmapCanvas.scaleEffect(zoomLevel)
                }
                .scrollIndicators(.hidden)
            }
            .frame(height: 320)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            if showColorLegend { colorLegendView.padding(.top, 4) }
            if let selected = selectedCell, drillDownLevel == 0 { cellDetailView(selected).padding(.top, 4) }
        }
    }

    private var clustersTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CLUSTER ANALYSIS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(0..<clusterCount) { i in
                    HStack(spacing: 12) {
                        Circle().fill(colorScale.color(for: Double(i) / Double(max(clusterCount, 1)))).frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) { Text("Cluster \(i + 1)").font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text("\(Int.random(in: 5...50)) cells").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text("\(Int.random(in: 60...95))%").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var statisticsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATISTICS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Min", value: String(format: "%.4f", minValue))
                StatCard(label: "Max", value: String(format: "%.4f", maxValue))
                StatCard(label: "Average", value: String(format: "%.4f", averageValue))
                StatCard(label: "Std Dev", value: String(format: "%.4f", standardDeviation))
                StatCard(label: "Count", value: "\(gridData.count * (gridData.first?.count ?? 0))")
                StatCard(label: "Non-zero", value: "\(gridData.flatMap { $0 }.filter { $0.value > 0 }.count)")
            }
            if showHistogram {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HISTOGRAM").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                    ForEach(0..<10) { i in
                        let value = Double.random(in: 0.1...1.0)
                        HStack(spacing: 8) {
                            Text("\(i * 10)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                            RoundedRectangle(cornerRadius: 3).fill(SystemFlyeTheme.violet.opacity(0.3 + value * 0.5)).frame(width: 200 * CGFloat(value), height: 10)
                            Text("\(Int(value * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var exportTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXPORT DATA").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ForEach(ExportFormat.allCases) { format in
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                        label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(14).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                        .buttonStyle(.plain)
                }
            }
            Button { exportHeatmapData() }
                label: { Label("Export", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
        }
    }

    private var heatmapCanvas: some View {
        VStack(spacing: 2) {
            ForEach(Array(gridData.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 2) {
                    Text(rowLabels.indices.contains(rowIndex) ? rowLabels[rowIndex] : "Row \(rowIndex + 1)")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.white).frame(width: 60, alignment: .trailing)
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScale.color(for: cell.value))
                            .frame(width: 48, height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(selectedCell?.id == cell.id ? Color.white : Color.clear, lineWidth: selectedCell?.id == cell.id ? 2 : 0))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if drillDownLevel < 2 && Bool.random() { drillDownPath.append(cell.row); drillDownLevel += 1; generateGridData() }
                                    selectedCell = cell
                                }
                            }
                            .popover(isPresented: .constant(showTooltips && selectedCell?.id == cell.id), arrowEdge: .top) {
                                tooltipView(for: cell).frame(width: 180)
                            }
                    }
                }
            }
            HStack(spacing: 2) {
                Color.clear.frame(width: 60)
                ForEach(Array(gridData.first ?? []).indices, id: \.self) { colIndex in
                    let col = columnLabels.indices.contains(colIndex) ? columnLabels[colIndex] : "T\(colIndex + 1)"
                    Text(col).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 48)
                }
            }
        }
        .padding(8)
    }

    private func tooltipView(for cell: HeatmapCell) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(cell.row) / \(cell.column)").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.2f", cell.value)).font(.caption.monospacedDigit()).foregroundStyle(colorScale.color(for: cell.value))
            }
            Divider().background(SystemFlyeTheme.line)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(cell.details.enumerated()), id: \.offset) { _, (key, value) in
                    HStack { Text(key).font(.caption).foregroundStyle(.secondary); Spacer(); Text(value).font(.caption.monospacedDigit()).foregroundStyle(.white) }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: trendIcon(cell.trend)).font(.caption2).foregroundStyle(trendColor(cell.trend))
                Text(cell.trend == .up ? "Trending Up" : cell.trend == .down ? "Trending Down" : "Neutral").font(.caption2).foregroundStyle(trendColor(cell.trend))
            }
        }
        .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SystemFlyeTheme.line))
    }

    private func trendIcon(_ trend: HeatmapCell.TrendDirection) -> String {
        switch trend { case .up: return "arrow.up.right"; case .down: return "arrow.down.right"; case .neutral: return "minus" }
    }

    private func trendColor(_ trend: HeatmapCell.TrendDirection) -> Color {
        switch trend { case .up: return .green; case .down: return .red; case .neutral: return .secondary }
    }

    private func cellDetailView(_ cell: HeatmapCell) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(cell.row) / \(cell.column)".uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(cell.category).font(.caption.weight(.semibold)).foregroundStyle(SystemFlyeTheme.cyan).padding(.horizontal, 10).padding(.vertical, 5).background(SystemFlyeTheme.cyan.opacity(0.1), in: Capsule())
            }
            Divider().background(SystemFlyeTheme.line)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) { Text("Value").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(String(format: "%.4f", cell.value)).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(colorScale.color(for: cell.value)) }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text("Trend").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(cell.trend == .up ? "Up" : cell.trend == .down ? "Down" : "Flat").font(.title3.weight(.bold)).foregroundStyle(trendColor(cell.trend)) }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("METRICS").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(cell.details.enumerated()), id: \.offset) { _, (key, value) in
                        VStack(alignment: .leading, spacing: 2) { Text(key).font(.caption2).foregroundStyle(.secondary); Text(value).font(.caption.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private var colorLegendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VALUE SCALE").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                Text("0.00 → 1.00").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let value = Double(i) / 19.0
                    RoundedRectangle(cornerRadius: 3).fill(colorScale.color(for: value)).frame(width: 18, height: 14)
                }
            }
        }
        .padding(12).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private var exportOptionsView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Heatmap").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Format").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(ExportFormat.allCases) { format in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                            label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(12).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer()
                HStack(spacing: 12) { Button("Cancel") { showingExportSheet = false }.buttonStyle(.bordered()).tint(.secondary); Button("Export") { exportHeatmapData(); showingExportSheet = false }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan) }
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }

    private func generateGridData() {
        let rows = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "NZDUSD", "USDCAD", "USDCHF", "EURGBP", "EURJPY", "GBPJPY", "AUDCAD", "AUDNZD"]
        let columns = ["1m", "5m", "15m", "1H", "4H", "1D", "1W", "1M", "3M", "6M", "1Y", "2Y"]
        let categories = ["Major", "Minor", "Exotic", "Commodity", "Index"]
        let trends: [HeatmapCell.TrendDirection] = [.up, .down, .neutral]
        rowLabels = rows
        columnLabels = columns
        gridData = rows.map { row in
            columns.map { col in
                HeatmapCell(row: row, column: col, value: Double.random(in: 0...1), category: categories.randomElement()!, trend: trends.randomElement()!, details: [
                    "Open": String(format: "%.5f", Double.random(in: 1.0...2.0)),
                    "High": String(format: "%.5f", Double.random(in: 1.0...2.0)),
                    "Low": String(format: "%.5f", Double.random(in: 1.0...2.0)),
                    "Close": String(format: "%.5f", Double.random(in: 1.0...2.0)),
                    "Volume": "\(Int.random(in: 1000...100000))",
                    "Change": String(format: "%.2f%%", Double.random(in: -2...2))
                ])
            }
        }
        let allValues = gridData.flatMap { $0.map(\.value) }
        minValue = allValues.min() ?? 0
        maxValue = allValues.max() ?? 1
        averageValue = allValues.reduce(0, +) / Double(max(allValues.count, 1))
        let variance = allValues.reduce(0) { $0 + pow($1 - averageValue, 2) } / Double(max(allValues.count, 1))
        standardDeviation = sqrt(variance)
        clusterCount = Int.random(in: 3...8)
    }

    private func exportHeatmapData() { print("Exporting heatmap data as \(exportFormat.rawValue)...") }
}


struct HeatmapGridView_Previews: PreviewProvider {
    static var previews: some View { HeatmapGridView().preferredColorScheme(.dark) }
}

