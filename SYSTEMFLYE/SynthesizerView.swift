import SwiftUI
import AVFoundation

struct SynthesizerView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var synthesizer = SynthesizerViewModel()
    @State private var showWaveformPicker = false
    
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
                            .foreground(.white)
                        
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
                            .foreground(.white)
                        
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
                                        .foreground(
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
                    
                    // Playback Controls
                    HStack(spacing: 12) {
                        Button(action: { synthesizer.loadAudioFile() }) {
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
                    .foreground(.white)
                
                Spacer()
                
                Text(String(format: "%.1f", value) + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.system(size: 13, weight: .semibold))
                    .foreground(Color(red: 0.4, green: 0.8, blue: 1.0))
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
    @Published var lfoRate: Float = 5
    @Published var lfoDepth: Float = 0
    @Published var lfoType: String = "sine"
    @Published var windowType: String = "hann"
    
    private var currentAudioBuffer: AVAudioPCMBuffer?
    
    func loadAudioFile() {
        // File picker implementation
    }
    
    func playProcessed() {
        // Process and play audio
    }
}

#Preview {
    SynthesizerView()
}
