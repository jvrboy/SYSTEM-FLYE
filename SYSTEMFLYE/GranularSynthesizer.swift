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
        var grainSize: Float = 100 // milliseconds
        var density: Float = 10 // grains per second
        var pitchShift: Float = 0 // semitones
        var timeStretch: Float = 1.0 // speed multiplier
        var overlap: Float = 0.5 // 0...1
        var positionJitter: Float = 0 // 0...1
        var grainSizeJitter: Float = 0 // 0...1
        var reverseProbability: Float = 0 // 0...1
        var panSpread: Float = 0 // 0...1
        var gain: Float = 0.85
        var filterCutoff: Float = 18000
        var filterResonance: Float = 0.1
        var windowType: WindowType = .hann
        var envelope: CustomEnvelope = .neutral
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
            positionJitter: parameters.positionJitter,
            grainSizeJitter: parameters.grainSizeJitter,
            reverseProbability: parameters.reverseProbability,
            panSpread: parameters.panSpread,
            gain: parameters.gain,
            filterCutoff: parameters.filterCutoff,
            filterResonance: parameters.filterResonance,
            windowType: parameters.windowType,
            envelope: parameters.envelope,
            modulation: parameters.modulation
        )
    }
    
    // MARK: - Advanced Effects
    func applyFrequencyShift(buffer: AVAudioPCMBuffer, shiftHz: Float) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        guard frameLength > 0, sampleRate > 0 else { return buffer }
        let safeShift = min(sampleRate * 0.49, max(-sampleRate * 0.49, shiftHz))
        let phaseIncrement = 2 * .pi * safeShift / sampleRate
        
        for channelIndex in 0..<Int(buffer.format.channelCount) {
            var phase: Float = 0
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
                let shiftedFreq = min(Float(buffer.format.sampleRate) * 0.45, max(20, freq * formantShift))
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
        guard frameLength > 0 else { return buffer }
        
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
        positionJitter: Float,
        grainSizeJitter: Float,
        reverseProbability: Float,
        panSpread: Float,
        gain: Float,
        filterCutoff: Float,
        filterResonance: Float,
        windowType: GranularSynthesizer.WindowType,
        envelope: CustomEnvelope,
        modulation: GranularSynthesizer.ModulationSettings
    ) -> AVAudioPCMBuffer? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0, channelCount > 0 else { return nil }
        let safeGrainSize = min(2000, max(5, grainSize))
        let baseGrainSamples = max(8, Int((safeGrainSize / 1000) * sampleRate))
        let safeDensity = min(200, max(0.25, density))
        let overlapFactor = min(0.95, max(0, overlap))
        let hopFromDensity = Int(sampleRate / safeDensity)
        let grainHop = max(1, min(frameLength, Int(Float(baseGrainSamples) * (1 - overlapFactor)), hopFromDensity))
        let pitchRatio = min(8, max(0.125, exp2(pitchShift / 12)))
        let stretch = min(8, max(0.125, timeStretch))

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(frameLength)), let outputData = outputBuffer.floatChannelData else { return nil }
        outputBuffer.frameLength = AVAudioFrameCount(frameLength)
        for channel in 0..<channelCount { outputData[channel].initialize(repeating: 0, count: frameLength) }

        var grainPosition = 0
        var outputPosition = 0
        var lfoPhase: Float = 0
        var rng: UInt64 = 0x9E3779B97F4A7C15
        let lfoIncrement = 2 * Float.pi * min(40, max(0, modulation.lfoRate)) / sampleRate
        let safeGain = min(2, max(0, gain))

        while grainPosition < frameLength && outputPosition < frameLength {
            rng = rng &* 2862933555777941757 &+ 3037000493
            let unit = Float(rng % 10_000) / 10_000
            let sizeJitter = 1 + (unit - 0.5) * 2 * min(0.9, max(0, grainSizeJitter))
            let grainSamples = max(8, Int(Float(baseGrainSamples) * sizeJitter))
            let window = generateWindow(size: grainSamples, type: windowType)
            let shouldReverse = Float(rng % 10_000) / 10_000 < min(1, max(0, reverseProbability))
            let positionOffset = Int((unit - 0.5) * 2 * Float(baseGrainSamples) * min(1, max(0, positionJitter)))
            let sourceStart = min(max(0, grainPosition + positionOffset), max(0, frameLength - 1))

            for sampleIndex in 0..<grainSamples {
                let normalized = Float(sampleIndex) / Float(max(1, grainSamples - 1))
                let envelopeValue = envelope.value(at: Double(normalized))
                let sourceProgress = shouldReverse ? (1 - normalized) : normalized
                let sourceIndex = sourceStart + Int(sourceProgress * Float(grainSamples) * pitchRatio * stretch)
                guard sourceIndex >= 0, sourceIndex < frameLength else { continue }
                let lfoValue = 1 + sin(lfoPhase) * min(1, max(0, modulation.lfoDepth))
                let sampleGain = window[sampleIndex] * envelopeValue * lfoValue * safeGain
                let destination = outputPosition + sampleIndex
                guard destination < frameLength else { continue }
                for channel in 0..<channelCount {
                    let pan = channelCount > 1 ? 1 + (Float(channel) / Float(channelCount - 1) - 0.5) * 2 * min(1, max(0, panSpread)) : 1
                    outputData[channel][destination] += floatChannelData[channel][sourceIndex] * sampleGain * pan
                }
                lfoPhase += lfoIncrement
            }
            grainPosition += grainHop
            outputPosition += max(1, Int(Float(grainHop) * stretch))
        }

        let cutoff = min(sampleRate * 0.49, max(20, filterCutoff))
        if cutoff < sampleRate * 0.48 {
            let alpha = exp(-2 * Float.pi * cutoff / sampleRate)
            for channel in 0..<channelCount {
                var previous: Float = 0
                for index in 0..<frameLength {
                    previous = (1 - alpha) * outputData[channel][index] + alpha * previous
                    outputData[channel][index] = previous
                }
            }
        }

        var peak: Float = 0
        for channel in 0..<channelCount { for index in 0..<frameLength { peak = max(peak, abs(outputData[channel][index])) } }
        if peak > 0.98 { let scale = 0.98 / peak; for channel in 0..<channelCount { vDSP_vsmul(outputData[channel], 1, [scale], outputData[channel], 1, vDSP_Length(frameLength)) } }
        _ = filterResonance
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
