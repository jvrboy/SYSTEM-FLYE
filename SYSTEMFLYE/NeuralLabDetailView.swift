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


struct NeuralLabDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NeuralLabDetailView().environmentObject(AdvancedStore()).preferredColorScheme(.dark)
    }
}

