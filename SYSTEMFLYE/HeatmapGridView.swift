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

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct HeatmapGridView_Previews: PreviewProvider {
    static var previews: some View { HeatmapGridView().preferredColorScheme(.dark) }
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
