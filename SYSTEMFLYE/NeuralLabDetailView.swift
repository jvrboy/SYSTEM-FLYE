import SwiftUI

struct NeuralLabDetailView: View {
    @EnvironmentObject private var store: AdvancedStore
    @State private var selectedLayer: LayerInfo?
    @State private var isTraining = false
    @State private var epochProgress: Double = 0
    @State private var currentEpoch: Int = 0
    @State private var totalEpochs: Int = 50
    @State private var showArchitecture = true
    @State private var showActivations = true
    @State private var showWeights = true
    @State private var activationMode: ActivationMode = .heatmap
    @State private var selectedFeature: String = "Momentum"
    @State private var trainingLog: [TrainingLogEntry] = []
    @State private var lossHistory: [Double] = []
    @State private var accuracyHistory: [Double] = []
    @State private var weightDistribution: [Double] = []
    @State private var gradientNorm: Double = 0.0
    @State private var learningRate: Double = 0.001
    @State private var batchSize: Int = 32
    @State private var optimizer: OptimizerType = .adam
    @State private var lossFunction: LossFunction = .crossEntropy

    enum ActivationMode: String, CaseIterable { case heatmap = "Heatmap"; case scatter = "Scatter"; case histogram = "Histogram"; case line = "Line" }
    enum OptimizerType: String, CaseIterable { case sgd = "SGD"; case adam = "Adam"; case rmsprop = "RMSprop"; case adagrad = "Adagrad" }
    enum LossFunction: String, CaseIterable { case crossEntropy = "Cross Entropy"; case mse = "MSE"; case mae = "MAE"; case huber = "Huber" }

    struct LayerInfo: Identifiable {
        let id = UUID()
        let name: String
        let type: LayerType
        let neurons: Int
        let activation: String
        let parameters: Int
        let outputShape: String
        var weightCount: Int { parameters }
    }

    enum LayerType: String { case input = "Input"; case dense = "Dense"; case lstm = "LSTM"; case dropout = "Dropout"; case output = "Output"; case convolution = "Conv2D"; case batchNorm = "BatchNorm"; case attention = "Attention" }

    struct TrainingLogEntry: Identifiable {
        let id = UUID()
        let epoch: Int
        let loss: Double
        let accuracy: Double
        let learningRate: Double
        let timestamp: Date
    }

    var layers: [LayerInfo] {
        [
            LayerInfo(name: "Input", type: .input, neurons: 128, activation: "Linear", parameters: 0, outputShape: "128"),
            LayerInfo(name: "Embedding", type: .dense, neurons: 256, activation: "ReLU", parameters: 33024, outputShape: "256"),
            LayerInfo(name: "LSTM-1", type: .lstm, neurons: 192, activation: "Tanh", parameters: 296448, outputShape: "192"),
            LayerInfo(name: "Dropout-1", type: .dropout, neurons: 192, activation: "Sigmoid", parameters: 0, outputShape: "192"),
            LayerInfo(name: "Attention", type: .attention, neurons: 192, activation: "Softmax", parameters: 73856, outputShape: "192"),
            LayerInfo(name: "Dense-1", type: .dense, neurons: 128, activation: "ReLU", parameters: 24704, outputShape: "128"),
            LayerInfo(name: "BatchNorm", type: .batchNorm, neurons: 128, activation: "Linear", parameters: 512, outputShape: "128"),
            LayerInfo(name: "Output", type: .output, neurons: 64, activation: "Softmax", parameters: 8256, outputShape: "64")
        ]
    }

    var totalParameters: Int { layers.reduce(0) { $0 + $1.parameters } }
    var totalWeights: Int { layers.reduce(0) { $0 + $1.weightCount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  N E U R A L  L A B", title: "Architecture Inspector")
                        Spacer()
                        Label("ADAPTIVE", systemImage: "brain")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SystemFlyeTheme.violet)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(SystemFlyeTheme.violet.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Layers", value: "\(layers.count)", detail: "network depth", tint: .purple)
                        MetricTile(label: "Parameters", value: formatNumber(totalParameters), detail: "trainable weights", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Epoch", value: "\(currentEpoch)/\(totalEpochs)", detail: "adaptive trainer", tint: .orange)
                        MetricTile(label: "Accuracy", value: "\(Int(store.signalBias * 100))%", detail: "validation set", tint: .green)
                    }

                    HStack(spacing: 12) {
                        Button { startTraining() }
                            label: { Label(isTraining ? "Training…" : "Train Model", systemImage: isTraining ? "arrow.triangle.2.circlepath" : "play.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.violet).disabled(isTraining)
                        if isTraining {
                            ProgressView(value: epochProgress).tint(SystemFlyeTheme.violet).frame(width: 140)
                        }
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showArchitecture.toggle() } }
                            label: { Label(showArchitecture ? "Hide Architecture" : "Show Architecture", systemImage: "square.grid.3x3").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(showArchitecture ? SystemFlyeTheme.violet : .secondary)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showActivations.toggle() } }
                            label: { Label(showActivations ? "Hide Activations" : "Show Activations", systemImage: "waveform.path").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(showActivations ? SystemFlyeTheme.cyan : .secondary)
                    }

                    if showArchitecture {
                        architectureView.padding(.top, 4)
                    }
                    if showActivations {
                        activationsView.padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("TRAINING CONFIGURATION").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Optimizer").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $optimizer) { ForEach(OptimizerType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                .pickerStyle(.menu).tint(SystemFlyeTheme.violet)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Loss Function").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $lossFunction) { ForEach(LossFunction.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                .pickerStyle(.menu).tint(SystemFlyeTheme.violet)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Learning Rate").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $learningRate, in: 0.0001...0.1, step: 0.0001).tint(SystemFlyeTheme.violet)
                                Text("\(String(format: "%.4f", learningRate))").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Batch Size").font(.caption).foregroundStyle(.secondary)
                                Slider(value: .constant(Double(batchSize)), in: 8...256, step: 8).tint(SystemFlyeTheme.cyan)
                                Text("\(batchSize)").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                            }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))

                    if !trainingLog.isEmpty {
                        trainingLogView.padding(.top, 4)
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Neural Lab").navigationBarTitleDisplayMode(.inline)
        }
    }

    private var architectureView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("NETWORK ARCHITECTURE").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Text("\(formatNumber(totalParameters)) parameters").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(layers) { layer in
                        LayerCard(layer: layer, isSelected: selectedLayer?.id == layer.id)
                            .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedLayer = layer } }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            if let layer = selectedLayer {
                layerInspectionCard(layer).padding(.top, 8)
            }
        }
        .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private func layerInspectionCard(_ layer: LayerInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(layer.name.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(layer.type.rawValue).font(.caption.weight(.semibold)).foregroundStyle(SystemFlyeTheme.violet)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(SystemFlyeTheme.violet.opacity(0.1), in: Capsule())
            }
            Divider().background(SystemFlyeTheme.line)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Neurons", value: "\(layer.neurons)")
                StatCard(label: "Params", value: formatNumber(layer.parameters))
                StatCard(label: "Output", value: layer.outputShape)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Activation Function").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                Text(layer.activation).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            if showWeights {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WEIGHT DISTRIBUTION").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                    GeometryReader { proxy in
                        let values = weightDistribution
                        guard !values.isEmpty else { return AnyView(Text("")) }
                        let minVal = values.min() ?? 0
                        let maxVal = values.max() ?? 1
                        let range = max(maxVal - minVal, 0.0001)
                        Path { p in
                            for (i, val) in values.enumerated() {
                                let x = proxy.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                                let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                                i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(SystemFlyeTheme.violet, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: 100)
                }
            }
        }
        .padding(16).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
    }

    private var activationsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("FEATURE ACTIVATIONS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Picker("Mode", selection: $activationMode) {
                    ForEach(ActivationMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }.pickerStyle(.segmented).frame(width: 220)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Momentum", "Volatility", "Liquidity", "Sentiment", "Momentum-2", "Volatility-2", "Liquidity-2", "Sentiment-2"], id: \.self) { feature in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedFeature = feature } }
                            label: { Text(feature).font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(selectedFeature == feature ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedFeature == feature ? .black : .white.opacity(0.7)) }
                    }
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                activationContent.padding(16)
            }
            .frame(height: 220)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    @ViewBuilder
    private var activationContent: some View {
        switch activationMode {
        case .heatmap:
            VStack(spacing: 4) {
                ForEach(0..<8) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<12) { col in
                            let value = Double.random(in: 0.1...1.0)
                            RoundedRectangle(cornerRadius: 4).fill(SystemFlyeTheme.violet.opacity(value * 0.8)).frame(width: 28, height: 16)
                        }
                    }
                }
            }
        case .scatter:
            Canvas { context, size in
                let points: [(x: CGFloat, y: CGFloat)] = (0..<40).map { _ in (x: CGFloat.random(in: 20...(size.width - 20)), y: CGFloat.random(in: 20...(size.height - 20))) }
                for point in points {
                    let rect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                    context.fill(Circle().path(in: rect), with: .color(SystemFlyeTheme.violet.opacity(0.6)))
                }
                let path = Path { p in p.addEllipse(in: CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.6)) }
                context.stroke(path, with: .color(SystemFlyeTheme.line), lineWidth: 1)
            }
            .frame(height: 180)
        case .histogram:
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<12) { i in
                    let value = Double.random(in: 0.1...1.0)
                    HStack(spacing: 8) {
                        Text("\(i * 10)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                        RoundedRectangle(cornerRadius: 3).fill(SystemFlyeTheme.violet.opacity(0.3 + value * 0.5)).frame(width: 200 * CGFloat(value), height: 10)
                        Text("\(Int(value * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        case .line:
            GeometryReader { proxy in
                let values = (0..<24).map { _ in CGFloat.random(in: 0.1...1.0) }
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 1
                let range = max(maxVal - minVal, 0.01)
                ZStack {
                    Path { p in
                        for (i, val) in values.enumerated() {
                            let x = proxy.size.width * CGFloat(i) / CGFloat(values.count - 1)
                            let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(SystemFlyeTheme.violet, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                        let x = proxy.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                        Circle().fill(SystemFlyeTheme.violet).frame(width: 5, height: 5).position(x: x, y: y)
                    }
                }
            }
            .frame(height: 180)
        }
    }

    private var trainingLogView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRAINING LOG").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 6) {
                ForEach(trainingLog) { entry in
                    HStack(spacing: 10) {
                        Text("E\(entry.epoch)").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.violet).frame(width: 40, alignment: .leading)
                        Text(String(format: "%.4f", entry.loss)).font(.caption.monospacedDigit()).foregroundStyle(.red).frame(width: 70, alignment: .leading)
                        Text("\(Int(entry.accuracy * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.green).frame(width: 50, alignment: .leading)
                        Text(String(format: "%.4f", entry.learningRate)).font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 70, alignment: .leading)
                        Text(entry.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func startTraining() {
        isTraining = true
        epochProgress = 0
        currentEpoch = 0
        trainingLog.removeAll()
        lossHistory.removeAll()
        accuracyHistory.removeAll()
        weightDistribution.removeAll()
        Task { @MainActor in
            for epoch in 1...totalEpochs {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { break }
                currentEpoch = epoch
                epochProgress = Double(epoch) / Double(totalEpochs)
                store.neuralEpoch = epoch
                store.signalBias = min(0.97, 0.67 + Double(epoch) * 0.006)
                let loss = max(0.01, 1.0 - Double(epoch) * 0.02 + Double.random(in: -0.02...0.02))
                let accuracy = min(0.99, 0.5 + Double(epoch) * 0.01 + Double.random(in: -0.01...0.01))
                lossHistory.append(loss)
                accuracyHistory.append(accuracy)
                weightDistribution = (0..<20).map { _ in Double.random(in: -1...1) }
                trainingLog.append(TrainingLogEntry(epoch: epoch, loss: loss, accuracy: accuracy, learningRate: learningRate * pow(0.95, Double(epoch)), timestamp: Date()))
            }
            isTraining = false
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 { return String(format: "%.1fM", Double(num) / 1_000_000) }
        else if num >= 1_000 { return String(format: "%.1fK", Double(num) / 1_000) }
        return "\(num)"
    }
}

struct LayerCard: View {
    let layer: NeuralLabDetailView.LayerInfo
    let isSelected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(layer.name).font(.caption.weight(.semibold)).foregroundStyle(.white)
            Text(layer.type.rawValue).font(.caption2).foregroundStyle(.secondary)
            Text("\(layer.neurons) neurons").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet)
            Text(layer.activation).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 120).padding(14).background(isSelected ? SystemFlyeTheme.violet.opacity(0.1) : SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? SystemFlyeTheme.violet.opacity(0.5) : SystemFlyeTheme.line))
    }
}

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct NeuralLabDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NeuralLabDetailView().environmentObject(AdvancedStore()).preferredColorScheme(.dark)
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
