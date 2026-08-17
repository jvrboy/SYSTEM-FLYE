import AVFoundation
import Accelerate

class GranularSynthesizer: NSObject, AVAudioPlayerDelegate {
    static let shared = GranularSynthesizer()
    
    private let audioEngine = AVAudioEngine()
    private var outputMixer: AVAudioMixerNode?
    private var granularProcessor: GranularProcessor?
    private var isRunning = false
    
    // MARK: - Granular Parameters
    struct GranularParameters {
        var grainSize: Float = 100 // ms
        var density: Float = 10 // grains per second
        var pitchShift: Float = 0 // semitones
        var timeStretch: Float = 1.0 // speed multiplier
        var overlap: Float = 0.5 // grain overlap
        var windowType: WindowType = .hann
        var spreadWidth: Float = 0 // stereo spread
        var modulation: ModulationSettings = ModulationSettings()
    }
    
    enum WindowType {
        case hann, hamming, blackman, triangle
    }
    
    struct ModulationSettings {
        var lfoRate: Float = 5 // Hz
        var lfoDepth: Float = 0
        var lfoType: LFOType = .sine
        var envAttack: Float = 10 // ms
        var envRelease: Float = 100 // ms
    }
    
    enum LFOType {
        case sine, triangle, saw, square
    }
    
    var granularParams = GranularParameters()
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        do {
            outputMixer = audioEngine.mainMixerNode
            granularProcessor = GranularProcessor(sampleRate: Float(audioEngine.outputNode.outputFormat(forBus: 0).sampleRate))
            
            try audioEngine.start()
            isRunning = true
        } catch {
            print("Audio engine setup error: \(error)")
        }
    }
    
    // MARK: - Granular Synthesis
    func processAudioWithGranularSynthesis(
        audioBuffer: AVAudioPCMBuffer,
        parameters: GranularParameters
    ) -> AVAudioPCMBuffer? {
        guard let granularProcessor = granularProcessor else { return nil }
        
        return granularProcessor.processGranular(
            buffer: audioBuffer,
            grainSize: parameters.grainSize,
            density: parameters.density,
            pitchShift: parameters.pitchShift,
            timeStretch: parameters.timeStretch,
            overlap: parameters.overlap,
            windowType: parameters.windowType,
            modulation: parameters.modulation
        )
    }
    
    // MARK: - Advanced Effects
    func applyFrequencyShift(buffer: AVAudioPCMBuffer, shiftHz: Float) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        var phase: Float = 0
        let phaseIncrement = 2 * .pi * shiftHz / sampleRate
        
        for channelIndex in 0..<Int(buffer.format.channelCount) {
            let channel = floatChannelData[channelIndex]
            
            for i in 0..<frameLength {
                let cosVal = cos(phase)
                let sinVal = sin(phase)
                channel[i] = channel[i] * cosVal
                phase += phaseIncrement
            }
        }
        
        return buffer
    }
    
    func applyFormantCorrection(buffer: AVAudioPCMBuffer, formantShift: Float) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        
        // Apply bandpass filters around formant frequencies
        let formantFrequencies: [Float] = [700, 1220, 2600] // F1, F2, F3
        
        for channelIndex in 0..<channels {
            let channel = floatChannelData[channelIndex]
            
            for freq in formantFrequencies {
                let shiftedFreq = freq * formantShift
                // Simple 2nd-order filter implementation
                applyBiquadFilter(
                    channel: channel,
                    frameLength: frameLength,
                    frequency: shiftedFreq,
                    Q: 1.0,
                    sampleRate: Float(buffer.format.sampleRate)
                )
            }
        }
        
        return buffer
    }
    
    func applySpectralCompression(buffer: AVAudioPCMBuffer, threshold: Float = 0.7) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        
        for channelIndex in 0..<Int(buffer.format.channelCount) {
            let channel = floatChannelData[channelIndex]
            
            // Simple RMS-based compression
            var sumSquares: Float = 0
            for i in 0..<frameLength {
                sumSquares += channel[i] * channel[i]
            }
            
            let rms = sqrt(sumSquares / Float(frameLength))
            if rms > threshold {
                let scale = threshold / max(rms, 0.001)
                vDSP_vsmul(channel, 1, [scale], channel, 1, vDSP_Length(frameLength))
            }
        }
        
        return buffer
    }
    
    // MARK: - Helper Methods
    private func applyBiquadFilter(
        channel: UnsafeMutablePointer<Float>,
        frameLength: Int,
        frequency: Float,
        Q: Float,
        sampleRate: Float
    ) {
        let omega = 2 * Float.pi * frequency / sampleRate
        let alpha = sin(omega) / (2 * Q)
        
        let b0: Float = 1
        let b1: Float = -2 * cos(omega)
        let b2: Float = 1
        let a0: Float = 1 + alpha
        let a1: Float = -2 * cos(omega)
        let a2: Float = 1 - alpha
        
        var y1: Float = 0, y2: Float = 0
        var x1: Float = 0, x2: Float = 0
        
        for i in 0..<frameLength {
            let x0 = channel[i]
            let y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            
            channel[i] = y0
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }
    }
}

// MARK: - Granular Processor
class GranularProcessor {
    let sampleRate: Float
    private var grainBuffer: [Float] = []
    private var grainPositions: [Float] = []
    
    init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }
    
    func processGranular(
        buffer: AVAudioPCMBuffer,
        grainSize: Float,
        density: Float,
        pitchShift: Float,
        timeStretch: Float,
        overlap: Float,
        windowType: GranularSynthesizer.WindowType,
        modulation: GranularSynthesizer.ModulationSettings
    ) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let grainLengthSamples = Int((grainSize / 1000.0) * sampleRate)
        let grainHopSize = Int(Float(grainLengthSamples) / (1.0 + overlap))
        
        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: AVAudioFrameCount(frameLength)
        ) else { return nil }
        
        let outputData = outputBuffer.floatChannelData
        outputBuffer.frameLength = buffer.frameLength
        
        // Generate window function
        let window = generateWindow(size: grainLengthSamples, type: windowType)
        
        // Process grains
        var grainPosition: Int = 0
        var outputPosition: Int = 0
        var lfoPhase: Float = 0
        let lfoIncrement = 2 * Float.pi * modulation.lfoRate / sampleRate
        
        while grainPosition < frameLength - grainLengthSamples {
            for channelIndex in 0..<Int(buffer.format.channelCount) {
                let inputChannel = floatChannelData[channelIndex]
                let outputChannel = outputData![channelIndex]
                
                // Calculate pitch-shifted grain
                let pitchRatio = exp2(pitchShift / 12.0)
                
                for grainSample in 0..<grainLengthSamples {
                    let inputIndex = Int(Float(grainSample) * pitchRatio)
                    if inputIndex < frameLength && outputPosition < frameLength {
                        let lfoValue = sin(lfoPhase) * modulation.lfoDepth
                        let modifiedSample = inputChannel[grainPosition + inputIndex]
                        let windowedSample = modifiedSample * window[grainSample]
                        let modulated = windowedSample * (1.0 + lfoValue)
                        
                        outputChannel[outputPosition] += modulated
                    }
                }
                
                lfoPhase += lfoIncrement
            }
            
            grainPosition += grainHopSize
            outputPosition += grainHopSize
        }
        
        return outputBuffer
    }
    
    private func generateWindow(size: Int, type: GranularSynthesizer.WindowType) -> [Float] {
        var window = Array(repeating: Float(0), count: size)
        
        for i in 0..<size {
            let normalized = Float(i) / Float(size - 1)
            
            switch type {
            case .hann:
                window[i] = 0.5 * (1 - cos(2 * .pi * normalized))
            case .hamming:
                window[i] = 0.54 - 0.46 * cos(2 * .pi * normalized)
            case .blackman:
                window[i] = 0.42 - 0.5 * cos(2 * .pi * normalized) + 0.08 * cos(4 * .pi * normalized)
            case .triangle:
                window[i] = 1 - abs(2 * (normalized - 0.5))
            }
        }
        
        return window
    }
}
