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
                    MusicParameterSlider(label: "Amount", value: $reverbAmount, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["amount"] = val } })
                    MusicParameterSlider(label: "Decay", value: $reverbDecay, binding: { _ in })
                    MusicParameterSlider(label: "Pre-delay", value: $reverbPreDelay, binding: { _ in })
                }
            case .delay:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Time", value: $delayTime, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["time"] = val } })
                    MusicParameterSlider(label: "Feedback", value: $delayFeedback, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["fb"] = val } })
                    MusicParameterSlider(label: "Wet", value: $delayWet, binding: { _ in })
                    MusicParameterSlider(label: "Dry", value: $delayDry, binding: { _ in })
                }
            case .filter:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Cutoff", value: $filterCutoff, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["cutoff"] = val } })
                    MusicParameterSlider(label: "Resonance", value: $filterResonance, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["res"] = val } })
                    MusicParameterSlider(label: "Drive", value: $distortionDrive, binding: { _ in })
                }
            case .distortion:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Drive", value: $distortionDrive, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["drive"] = val } })
                    MusicParameterSlider(label: "Tone", value: .constant(0.5), binding: { _ in })
                    MusicParameterSlider(label: "Mix", value: .constant(0.7), binding: { _ in })
                }
            case .modulation, .chorus:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Rate", value: $modulationRate, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["rate"] = val } })
                    MusicParameterSlider(label: "Depth", value: $modulationDepth, binding: { val in if let idx = effectChain.firstIndex(where: { $0.id == effect.id }) { effectChain[idx].parameters["depth"] = val } })
                    MusicParameterSlider(label: "Feedback", value: .constant(0.3), binding: { _ in })
                    MusicParameterSlider(label: "Mix", value: .constant(0.5), binding: { _ in })
                }
            case .phaser:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Rate", value: $phaserRate, binding: { _ in })
                    MusicParameterSlider(label: "Depth", value: $phaserDepth, binding: { _ in })
                    MusicParameterSlider(label: "Feedback", value: .constant(0.4), binding: { _ in })
                    MusicParameterSlider(label: "Stages", value: .constant(0.8), binding: { _ in })
                }
            case .flanger:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Rate", value: $flangerRate, binding: { _ in })
                    MusicParameterSlider(label: "Depth", value: $flangerDepth, binding: { _ in })
                    MusicParameterSlider(label: "Feedback", value: .constant(0.5), binding: { _ in })
                    MusicParameterSlider(label: "Mix", value: .constant(0.5), binding: { _ in })
                }
            case .compressor:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Threshold", value: $compressorThreshold, binding: { _ in })
                    MusicParameterSlider(label: "Ratio", value: $compressorRatio, binding: { _ in })
                    MusicParameterSlider(label: "Attack", value: .constant(0.01), binding: { _ in })
                    MusicParameterSlider(label: "Release", value: .constant(0.1), binding: { _ in })
                }
            case .equalizer:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Low Gain", value: $eqLowGain, binding: { _ in })
                    MusicParameterSlider(label: "Mid Gain", value: $eqMidGain, binding: { _ in })
                    MusicParameterSlider(label: "High Gain", value: $eqHighGain, binding: { _ in })
                    MusicParameterSlider(label: "Low Freq", value: $eqLowFreq, binding: { _ in })
                    MusicParameterSlider(label: "Mid Freq", value: $eqMidFreq, binding: { _ in })
                    MusicParameterSlider(label: "High Freq", value: $eqHighFreq, binding: { _ in })
                }
            case .limiter:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Threshold", value: $limiterThreshold, binding: { _ in })
                    MusicParameterSlider(label: "Release", value: .constant(0.05), binding: { _ in })
                }
            case .gate:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Threshold", value: .constant(0.3), binding: { _ in })
                    MusicParameterSlider(label: "Attack", value: .constant(0.01), binding: { _ in })
                    MusicParameterSlider(label: "Release", value: .constant(0.1), binding: { _ in })
                }
            case .pitchShift:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Semitones", value: .constant(0.0), binding: { _ in })
                    MusicParameterSlider(label: "Formant", value: .constant(0.5), binding: { _ in })
                }
            case .chorusStereo:
                VStack(spacing: 12) {
                    MusicParameterSlider(label: "Rate", value: $chorusRate, binding: { _ in })
                    MusicParameterSlider(label: "Depth", value: $chorusDepth, binding: { _ in })
                    MusicParameterSlider(label: "Width", value: .constant(0.8), binding: { _ in })
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

struct MusicParameterSlider: View {
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

