import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SynthesizerView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var synthesizer = SynthesizerViewModel()
    @State private var showWaveformPicker = false
    @State private var showFileImporter = false
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Waveform Display
                    WaveformDisplayView(waveformData: playerManager.waveformData)
                        .frame(height: 180)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.3, green: 0.5, blue: 0.8),
                                                    Color(red: 0.2, green: 0.4, blue: 0.6)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                    
                    HStack(spacing: 8) {
                        Image(systemName: synthesizer.status.contains("failed") ? "xmark.octagon.fill" : "checkmark.circle.fill")
                            .foregroundStyle(synthesizer.status.contains("failed") ? .red : .green)
                        Text(synthesizer.status).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    // Granular Parameters
                    VStack(spacing: 16) {
                        ParameterSlider(
                            label: "Grain Size",
                            value: $synthesizer.grainSize,
                            range: 10...500,
                            unit: "ms"
                        )
                        
                        ParameterSlider(
                            label: "Grain Density",
                            value: $synthesizer.density,
                            range: 1...100,
                            unit: "grains/s"
                        )
                        
                        ParameterSlider(
                            label: "Pitch Shift",
                            value: $synthesizer.pitchShift,
                            range: -24...24,
                            unit: "semitones"
                        )
                        
                        ParameterSlider(
                            label: "Time Stretch",
                            value: $synthesizer.timeStretch,
                            range: 0.5...2.0,
                            unit: "×"
                        )
                        
                        ParameterSlider(
                            label: "Grain Overlap",
                            value: $synthesizer.overlap,
                            range: 0...1.0,
                            unit: ""
                        )
                        
                        ParameterSlider(
                            label: "Stereo Spread",
                            value: $synthesizer.spreadWidth,
                            range: 0...1.0,
                            unit: ""
                        )

                        ParameterSlider(label: "Position Jitter", value: $synthesizer.positionJitter, range: 0...1, unit: "")
                        ParameterSlider(label: "Grain Size Jitter", value: $synthesizer.grainSizeJitter, range: 0...1, unit: "")
                        ParameterSlider(label: "Reverse Probability", value: $synthesizer.reverseProbability, range: 0...1, unit: "")
                        ParameterSlider(label: "Output Gain", value: $synthesizer.gain, range: 0...1.5, unit: "×")
                        ParameterSlider(label: "Filter Cutoff", value: $synthesizer.filterCutoff, range: 100...20000, unit: "Hz")
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Modulation Section
                    VStack(spacing: 12) {
                        Text("LFO Modulation")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white)
                        
                        ParameterSlider(
                            label: "LFO Rate",
                            value: $synthesizer.lfoRate,
                            range: 0.1...20.0,
                            unit: "Hz"
                        )
                        
                        ParameterSlider(
                            label: "LFO Depth",
                            value: $synthesizer.lfoDepth,
                            range: 0...1.0,
                            unit: ""
                        )
                        
                        Picker("LFO Type", selection: $synthesizer.lfoType) {
                            Text("Sine").tag("sine")
                            Text("Triangle").tag("triangle")
                            Text("Sawtooth").tag("saw")
                            Text("Square").tag("square")
                        }
                        .pickerStyle(.segmented)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    // Window Function Selection
                    VStack(spacing: 12) {
                        Text("Window Function")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 8) {
                            ForEach(["Hann", "Hamming", "Blackman", "Triangle"], id: \.self) { window in
                                Button(action: { synthesizer.windowType = window.lowercased() }) {
                                    Text(window)
                                        .font(.system(size: 12, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    synthesizer.windowType == window.lowercased() ?
                                                    Color(red: 0.4, green: 0.8, blue: 1.0) :
                                                    Color(red: 0.15, green: 0.15, blue: 0.2)
                                                )
                                        )
                                        .foregroundStyle(
                                            synthesizer.windowType == window.lowercased() ?
                                            Color.black : Color.white
                                        )
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                    )
                    
                    EnvelopeEditorView(points: $synthesizer.envelopePoints)

                    // Playback Controls
                    HStack(spacing: 12) {
                        Button(action: { showFileImporter = true }) {
                            Label("Load Audio", systemImage: "arrow.down.doc")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.2, green: 0.4, blue: 0.6))
                                )
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            if playerManager.isPlaying {
                                playerManager.pause()
                            } else {
                                synthesizer.playProcessed()
                            }
                        }) {
                            Label(playerManager.isPlaying ? "Pause" : "Play", systemImage: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.4, green: 0.8, blue: 1.0))
                                )
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(16)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first { synthesizer.loadAudioFile(from: url) }
            }
        }
    }
}

struct ParameterSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(String(format: "%.1f", value) + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
            }
            
            Slider(value: $value, in: range)
                .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
        }
    }
}

class SynthesizerViewModel: ObservableObject {
    @Published var grainSize: Float = 100
    @Published var density: Float = 10
    @Published var pitchShift: Float = 0
    @Published var timeStretch: Float = 1.0
    @Published var overlap: Float = 0.5
    @Published var spreadWidth: Float = 0
    @Published var positionJitter: Float = 0
    @Published var grainSizeJitter: Float = 0
    @Published var reverseProbability: Float = 0
    @Published var gain: Float = 0.85
    @Published var filterCutoff: Float = 18000
    @Published var envelopePoints: [EnvelopePoint] = CustomEnvelope.neutral.points
    @Published var lfoRate: Float = 5
    @Published var lfoDepth: Float = 0
    @Published var lfoType: String = "sine"
    @Published var windowType: String = "hann"
    
    private var currentAudioBuffer: AVAudioPCMBuffer?
    
    func loadAudioFile(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return }
            try file.read(into: buffer)
            currentAudioBuffer = buffer
            status = "Loaded \(url.lastPathComponent)"
        } catch {
            status = "Load failed: \(error.localizedDescription)"
        }
    }

    func playProcessed() {
        guard let currentAudioBuffer else { status = "Load an audio file first"; return }
        let parameters = GranularSynthesizer.GranularParameters(grainSize: grainSize, density: density, pitchShift: pitchShift, timeStretch: timeStretch, overlap: overlap, positionJitter: positionJitter, grainSizeJitter: grainSizeJitter, reverseProbability: reverseProbability, panSpread: spreadWidth, gain: gain, filterCutoff: filterCutoff, filterResonance: 0.1, windowType: windowTypeValue, envelope: CustomEnvelope(name: "Custom", points: envelopePoints), modulation: GranularSynthesizer.ModulationSettings(lfoRate: lfoRate, lfoDepth: lfoDepth, lfoType: lfoTypeValue, envAttack: 10, envRelease: 100))
        guard let processed = GranularSynthesizer.shared.processAudioWithGranularSynthesis(audioBuffer: currentAudioBuffer, parameters: parameters) else { status = "Processing failed"; return }
        AudioPlayerManager.shared.play(audioBuffer: processed)
        status = "Processed and playing"
    }

    @Published var status = "Load an audio file to begin"

    private var windowTypeValue: GranularSynthesizer.WindowType {
        switch windowType { case "hamming": return .hamming; case "blackman": return .blackman; case "triangle": return .triangle; default: return .hann }
    }

    private var lfoTypeValue: GranularSynthesizer.LFOType {
        switch lfoType { case "triangle": return .triangle; case "saw": return .saw; case "square": return .square; default: return .sine }
    }
}

#Preview {
    SynthesizerView()
}
