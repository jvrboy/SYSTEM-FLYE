import SwiftUI

struct MusicToolDetailView: View {
    @EnvironmentObject private var platform: FeaturePlatformStore
    @State private var selectedEffect: MusicEffect?
    @State private var isRoutingMatrixVisible = false
    @State private var effectChain: [MusicEffect]
    @State private var masterVolume: Double = 0.8
    @State private var selectedSlot: Int?
    @State private var isRecording = false
    @State private var showPresets = false
    @State private var currentPreset: String = "Default"
    @State private var reverbAmount: Double = 0.3
    @State private var delayTime: Double = 0.35
    @State private var delayFeedback: Double = 0.4
    @State private var filterCutoff: Double = 0.7
    @State private var filterResonance: Double = 0.2
    @State private var distortionDrive: Double = 0.5
    @State private var modulationRate: Double = 0.6
    @State private var modulationDepth: Double = 0.4
    @State private var showAnalyzer = true
    @State private var selectedAnalyzerMode: AnalyzerMode = .spectrum
    @State private var routingConnections: [UUID: Set<UUID>] = [:]
    @State private var midiChannel: Int = 0
    @State private var tempo: Double = 120.0
    @State private var timeSignature: (numerator: Int, denominator: Int) = (4, 4)
    @State private var isMetronomeOn = false
    @State private var masterPan: Double = 0.0
    @State private var compressorThreshold: Double = 0.7
    @State private var compressorRatio: Double = 4.0
    @State private var limiterThreshold: Double = 0.9
    @State private var reverbDecay: Double = 2.5
    @State private var reverbPreDelay: Double = 0.02
    @State private var delayWet: Double = 0.3
    @State private var delayDry: Double = 0.7
    @State private var chorusRate: Double = 0.5
    @State private var chorusDepth: Double = 0.4
    @State private var phaserRate: Double = 0.3
    @State private var phaserDepth: Double = 0.6
    @State private var flangerRate: Double = 0.2
    @State private var flangerDepth: Double = 0.5
    @State private var eqLowGain: Double = 0.6
    @State private var eqMidGain: Double = 0.5
    @State private var eqHighGain: Double = 0.4
    @State private var eqLowFreq: Double = 200.0
    @State private var eqMidFreq: Double = 1000.0
    @State private var eqHighFreq: Double = 5000.0

    enum AnalyzerMode: String, CaseIterable { case spectrum = "Spectrum"; case waveform = "Waveform"; case levels = "Levels" }

    struct MusicEffect: Identifiable {
        let id = UUID()
        var name: String
        var type: EffectType
        var isActive: Bool
        var bypassed: Bool
        var color: Color
        var parameters: [String: Double]
    }

    enum EffectType: String, CaseIterable {
        case reverb = "Reverb"; case delay = "Delay"; case filter = "Filter"; case distortion = "Distortion"; case modulation = "Modulation"
        case compressor = "Compressor"; case equalizer = "EQ"; case chorus = "Chorus"; case phaser = "Phaser"; case flanger = "Flanger"
        case limiter = "Limiter"; case gate = "Gate"; case pitchShift = "Pitch"; case chorusStereo = "Stereo Chorus"
    }

    init() {
        _effectChain = State(initialValue: [
            MusicEffect(name: "Input Gain", type: .compressor, isActive: true, bypassed: false, color: .blue, parameters: ["gain": 0.8]),
            MusicEffect(name: "EQ Low", type: .equalizer, isActive: true, bypassed: false, color: .purple, parameters: ["gain": 0.6, "freq": 120.0]),
            MusicEffect(name: "Filter HP", type: .filter, isActive: true, bypassed: false, color: .cyan, parameters: ["cutoff": 0.7, "res": 0.2]),
            MusicEffect(name: "Distortion", type: .distortion, isActive: false, bypassed: true, color: .orange, parameters: ["drive": 0.5]),
            MusicEffect(name: "Chorus", type: .chorus, isActive: true, bypassed: false, color: .green, parameters: ["rate": 0.6, "depth": 0.4]),
            MusicEffect(name: "Delay", type: .delay, isActive: true, bypassed: false, color: .pink, parameters: ["time": 0.35, "fb": 0.4]),
            MusicEffect(name: "Reverb", type: .reverb, isActive: true, bypassed: false, color: .teal, parameters: ["amount": 0.3]),
            MusicEffect(name: "Limiter", type: .limiter, isActive: true, bypassed: false, color: .indigo, parameters: ["threshold": 0.9, "release": 0.3])
        ])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  M U S I C", title: "Tool Detail")
                        Spacer()
                        Label("ON DEVICE", systemImage: "cpu").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Effects", value: "\(effectChain.count)", detail: "in chain", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Active", value: "\(effectChain.filter { $0.isActive && !$0.bypassed }.count)", detail: "processing", tint: .green)
                        MetricTile(label: "CPU", value: "12%", detail: "audio engine", tint: .orange)
                        MetricTile(label: "Latency", value: "2.4ms", detail: "round-trip", tint: SystemFlyeTheme.violet)
                    }

                    HStack(spacing: 12) {
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isRecording.toggle() } }
                            label: { Label(isRecording ? "Stop" : "Record", systemImage: isRecording ? "stop.fill" : "record.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.borderedProminent).tint(isRecording ? .red : SystemFlyeTheme.cyan)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showPresets.toggle() } }
                            label: { Label("Presets", systemImage: "list.bullet").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(showPresets ? SystemFlyeTheme.cyan : .secondary)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isRoutingMatrixVisible.toggle() } }
                            label: { Label("Routing", systemImage: "point.3.filled.connected.trianglepath.dotted").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(isRoutingMatrixVisible ? SystemFlyeTheme.violet : .secondary)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showAnalyzer.toggle() } }
                            label: { Label("Analyzer", systemImage: "waveform.path").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(showAnalyzer ? .green : .secondary)
                    }

                    if showPresets { presetsView.padding(.top, 4) }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("EFFECT CHAIN").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(effectChain.enumerated()), id: \.element.id) { index, effect in
                                    EffectSlotView(effect: effect, index: index, isSelected: selectedSlot == index, isFirst: index == 0, isLast: index == effectChain.count - 1)
                                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedSlot = index; selectedEffect = effect } }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))

                    if let effect = selectedEffect {
                        effectControlPanel(effect).padding(.top, 4)
                    }

                    if isRoutingMatrixVisible {
                        routingMatrixView.padding(.top, 4)
                    }

                    if showAnalyzer {
                        analyzerView.padding(.top, 4)
                    }

                    HStack(spacing: 12) {
                        Text("MASTER").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                        Slider(value: $masterVolume, in: 0...1).tint(SystemFlyeTheme.cyan)
                        Text("\(Int(masterVolume * 100))%").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 40)
                        Text("PAN").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                        Slider(value: $masterPan, in: -1...1).tint(SystemFlyeTheme.violet)
                        Text("\(Int(masterPan * 100))").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet).frame(width: 30)
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("TRANSPORT").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tempo").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $tempo, in: 60.0...200.0).tint(SystemFlyeTheme.cyan)
                                Text("\(Int(tempo)) BPM").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Time Signature").font(.caption).foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Picker("", selection: $timeSignature.numerator) { ForEach(1...12, id: \.self) { Text("\($0)").tag($0) } }
                                    .pickerStyle(.wheel).frame(width: 60).tint(SystemFlyeTheme.cyan)
                                    Text("/").font(.title3.weight(.bold)).foregroundStyle(.secondary)
                                    Picker("", selection: $timeSignature.denominator) { ForEach([1, 2, 4, 8, 16], id: \.self) { Text("\($0)").tag($0) } }
                                    .pickerStyle(.wheel).frame(width: 60).tint(SystemFlyeTheme.cyan)
                                }
                            }
                            Toggle("Metronome", isOn: $isMetronomeOn).labelsHidden().tint(SystemFlyeTheme.cyan)
                            Text(isMetronomeOn ? "ON" : "OFF").font(.caption2.weight(.bold)).foregroundStyle(isMetronomeOn ? SystemFlyeTheme.cyan : .secondary)
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Music Tool Detail").navigationBarTitleDisplayMode(.inline)
        }
    }

    private var presetsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRESETS").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Default", "Vocal", "Bass", "Guitar", "Drums", "Ambient", "Cinematic", "Lo-Fi", "Electronic", "Acoustic"], id: \.self) { preset in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { currentPreset = preset; applyPreset(preset) } }
                            label: { Text(preset).font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10).background(currentPreset == preset ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(currentPreset == preset ? .black : .white.opacity(0.7)) }
                    }
                }
            }
        }
        .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
    }

    private func applyPreset(_ preset: String) {
        switch preset {
        case "Vocal":
            effectChain = [MusicEffect(name: "EQ Vocal", type: .equalizer, isActive: true, bypassed: false, color: .purple, parameters: ["gain": 0.7]),
                MusicEffect(name: "DeEsser", type: .compressor, isActive: true, bypassed: false, color: .orange, parameters: ["threshold": 0.5]),
                MusicEffect(name: "Reverb", type: .reverb, isActive: true, bypassed: false, color: .teal, parameters: ["amount": 0.25]),
                MusicEffect(name: "Delay", type: .delay, isActive: false, bypassed: true, color: .pink, parameters: ["time": 0.3, "fb": 0.3])]
        case "Bass":
            effectChain = [MusicEffect(name: "Sub Boost", type: .equalizer, isActive: true, bypassed: false, color: .blue, parameters: ["gain": 0.9, "freq": 60.0]),
                MusicEffect(name: "Distortion", type: .distortion, isActive: true, bypassed: false, color: .orange, parameters: ["drive": 0.6]),
                MusicEffect(name: "Compressor", type: .compressor, isActive: true, bypassed: false, color: .green, parameters: ["threshold": 0.7]),
                MusicEffect(name: "Limiter", type: .limiter, isActive: true, bypassed: false, color: .indigo, parameters: ["threshold": 0.9])]
        default: break
        }
    }

    private func effectControlPanel(_ effect: MusicEffect) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(effect.name.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Toggle("Bypass", isOn: Binding(get: { effect.bypassed }, set: { newValue in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].bypassed = newValue } }))
                .labelsHidden().tint(effect.bypassed ? .secondary : SystemFlyeTheme.cyan)
                Text(effect.bypassed ? "On" : "Off").font(.caption2.weight(.bold)).foregroundStyle(effect.bypassed ? .secondary : SystemFlyeTheme.cyan)
            }
            Divider().background(SystemFlyeTheme.line)
            parameterView(for: effect)
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    @ViewBuilder
    private func parameterView(for effect: MusicEffect) -> some View {
        Group {
            switch effect.type {
            case .reverb:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Amount", value: $reverbAmount, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["amount"] = val } })
                    ParameterSlider(label: "Decay", value: $reverbDecay, binding: { _ in })
                    ParameterSlider(label: "Pre-delay", value: $reverbPreDelay, binding: { _ in })
                }
            case .delay:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Time", value: $delayTime, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["time"] = val } })
                    ParameterSlider(label: "Feedback", value: $delayFeedback, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["fb"] = val } })
                    ParameterSlider(label: "Wet", value: $delayWet, binding: { _ in })
                    ParameterSlider(label: "Dry", value: $delayDry, binding: { _ in })
                }
            case .filter:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Cutoff", value: $filterCutoff, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["cutoff"] = val } })
                    ParameterSlider(label: "Resonance", value: $filterResonance, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["res"] = val } })
                    ParameterSlider(label: "Drive", value: $distortionDrive, binding: { _ in })
                }
            case .distortion:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Drive", value: $distortionDrive, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["drive"] = val } })
                    ParameterSlider(label: "Tone", value: .constant(0.5), binding: { _ in })
                    ParameterSlider(label: "Mix", value: .constant(0.7), binding: { _ in })
                }
            case .modulation, .chorus:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Rate", value: $modulationRate, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["rate"] = val } })
                    ParameterSlider(label: "Depth", value: $modulationDepth, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["depth"] = val } })
                    ParameterSlider(label: "Feedback", value: .constant(0.3), binding: { _ in })
                    ParameterSlider(label: "Mix", value: .constant(0.5), binding: { _ in })
                }
            case .phaser:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Rate", value: $phaserRate, binding: { _ in })
                    ParameterSlider(label: "Depth", value: $phaserDepth, binding: { _ in })
                    ParameterSlider(label: "Feedback", value: .constant(0.4), binding: { _ in })
                    ParameterSlider(label: "Stages", value: .constant(0.8), binding: { _ in })
                }
            case .flanger:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Rate", value: $flangerRate, binding: { _ in })
                    ParameterSlider(label: "Depth", value: $flangerDepth, binding: { _ in })
                    ParameterSlider(label: "Feedback", value: .constant(0.5), binding: { _ in })
                    ParameterSlider(label: "Mix", value: .constant(0.5), binding: { _ in })
                }
            case .compressor:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Threshold", value: $compressorThreshold, binding: { _ in })
                    ParameterSlider(label: "Ratio", value: $compressorRatio, binding: { _ in })
                    ParameterSlider(label: "Attack", value: .constant(0.01), binding: { _ in })
                    ParameterSlider(label: "Release", value: .constant(0.1), binding: { _ in })
                }
            case .equalizer:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Low Gain", value: $eqLowGain, binding: { _ in })
                    ParameterSlider(label: "Mid Gain", value: $eqMidGain, binding: { _ in })
                    ParameterSlider(label: "High Gain", value: $eqHighGain, binding: { _ in })
                    ParameterSlider(label: "Low Freq", value: $eqLowFreq, binding: { _ in })
                    ParameterSlider(label: "Mid Freq", value: $eqMidFreq, binding: { _ in })
                    ParameterSlider(label: "High Freq", value: $eqHighFreq, binding: { _ in })
                }
            case .limiter:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Threshold", value: $limiterThreshold, binding: { _ in })
                    ParameterSlider(label: "Release", value: .constant(0.05), binding: { _ in })
                }
            case .gate:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Threshold", value: .constant(0.3), binding: { _ in })
                    ParameterSlider(label: "Attack", value: .constant(0.01), binding: { _ in })
                    ParameterSlider(label: "Release", value: .constant(0.1), binding: { _ in })
                }
            case .pitchShift:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Semitones", value: .constant(0.0), binding: { _ in })
                    ParameterSlider(label: "Formant", value: .constant(0.5), binding: { _ in })
                }
            case .chorusStereo:
                VStack(spacing: 12) {
                    ParameterSlider(label: "Rate", value: $chorusRate, binding: { _ in })
                    ParameterSlider(label: "Depth", value: $chorusDepth, binding: { _ in })
                    ParameterSlider(label: "Width", value: .constant(0.8), binding: { _ in })
                }
            }
        }
    }

    private var routingMatrixView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ROUTING MATRIX").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Input").font(.caption2.weight(.bold)).frame(width: 60, alignment: .leading)
                        ForEach(effectChain, id: \.id) { effect in
                            Text(effect.name).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(width: 80)
                        }
                    }
                    ForEach(effectChain, id: \.id) { fromEffect in
                        HStack(spacing: 8) {
                            Text(fromEffect.name).font(.caption2.weight(.semibold)).foregroundStyle(.white).frame(width: 60, alignment: .leading)
                            ForEach(effectChain, id: \.id) { toEffect in
                                Button { toggleRouting(from: fromEffect.id, to: toEffect.id) }
                                    label: {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isRouted(from: fromEffect.id, to: toEffect.id) ? SystemFlyeTheme.cyan : SystemFlyeTheme.line)
                                            .frame(width: 80, height: 32)
                                            .overlay(Image(systemName: "arrow.right").font(.caption2).foregroundStyle(isRouted(from: fromEffect.id, to: toEffect.id) ? .black : .secondary))
                                    }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private var analyzerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AUDIO ANALYZER").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnalyzerMode.allCases) { mode in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedAnalyzerMode = mode } }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(selectedAnalyzerMode == mode ? .green : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedAnalyzerMode == mode ? .black : .white.opacity(0.7)) }
                    }
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                GeometryReader { proxy in
                    let values = (0..<48).map { _ in CGFloat.random(in: 0.1...1.0) }
                    let minVal = values.min() ?? 0
                    let maxVal = values.max() ?? 1
                    let range = max(maxVal - minVal, 0.01)
                    Group {
                        switch selectedAnalyzerMode {
                        case .spectrum:
                            Path { p in
                                for (i, val) in values.enumerated() {
                                    let x = proxy.size.width * CGFloat(i) / CGFloat(values.count - 1)
                                    let y = proxy.size.height - ((val - minVal) / range) * proxy.size.height
                                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        case .waveform:
                            Path { p in
                                for (i, val) in values.enumerated() {
                                    let x = proxy.size.width * CGFloat(i) / CGFloat(values.count - 1)
                                    let y = proxy.size.height / 2 + (val - 0.5) * proxy.size.height * 0.8
                                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(SystemFlyeTheme.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        case .levels:
                            VStack(spacing: 4) {
                                ForEach(0..<20) { i in
                                    let value = Double.random(in: 0.1...1.0)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(value > 0.9 ? .red : value > 0.7 ? .orange : .green)
                                        .frame(width: proxy.size.width * CGFloat(value), height: 10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.top, 8)
            }
            .frame(height: 150)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private func isRouted(from: UUID, to: UUID) -> Bool {
        routingConnections[from]?.contains(to) ?? false
    }

    private func toggleRouting(from: UUID, to: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if routingConnections[from]?.contains(to) == true {
                routingConnections[from]?.remove(to)
            } else {
                if routingConnections[from] == nil { routingConnections[from] = [] }
                routingConnections[from]?.insert(to)
            }
        }
    }
}

struct EffectSlotView: View {
    let effect: MusicToolDetailView.MusicEffect
    let index: Int
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(effect.isActive && !effect.bypassed ? effect.color.opacity(0.15) : SystemFlyeTheme.panel)
                RoundedRectangle(cornerRadius: 12).stroke(isSelected ? SystemFlyeTheme.cyan : SystemFlyeTheme.line, lineWidth: isSelected ? 2 : 1)
                VStack(spacing: 4) {
                    Image(systemName: effectIcon(for: effect.type)).font(.system(size: 18, weight: .semibold)).foregroundStyle(effect.isActive && !effect.bypassed ? effect.color : .secondary)
                    Text("\(index + 1)").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Text(effect.name).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(1).frame(width: 80)
                }
                .padding(.vertical, 10)
            }
            .frame(width: 100)
            if !isLast { Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary) }
        }
    }

    private func effectIcon(for type: MusicToolDetailView.EffectType) -> String {
        switch type {
        case .reverb: return "waveform.path"
        case .delay: return "ellipsis.rectangle"
        case .filter: return "waveform.path.badge.plus"
        case .distortion: return "bolt.fill"
        case .modulation, .chorus, .chorusStereo: return "waveform.path.ecg"
        case .compressor: return "arrow.down.to.line.compression"
        case .equalizer: return "chart.bar"
        case .phaser: return "waveform.path"
        case .flanger: return "waveform.path"
        case .limiter: return "gauge.high"
        case .gate: return "shield.fill"
        case .pitchShift: return "arrow.up.and.down"
        }
    }
}

struct ParameterSlider: View {
    let label: String
    @Binding var value: Double
    let binding: (Double) -> Void
    var range: ClosedRange<Double> = 0...1
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100)).font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
            }
            Slider(value: $value, in: range).tint(SystemFlyeTheme.cyan).onChange(of: value) { newValue in binding(newValue) }
        }
    }
}

struct MusicToolDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MusicToolDetailView().environmentObject(FeaturePlatformStore()).preferredColorScheme(.dark)
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
