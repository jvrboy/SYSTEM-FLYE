import Foundation
import Accelerate
import AVFoundation

// MARK: - Audio Models
struct AudioFeatures: Codable, Identifiable {
    let id = UUID()
    var spectralCentroid: Double
    var spectralFlatness: Double
    var spectralRolloff: Double
    var spectralFlux: Double
    var zeroCrossingRate: Double
    var rmsEnergy: Double
    var loudness: Double
    var pitch: Double
    var harmonicity: Double
    var chromaFeatures: [Double]
    var mfcc: [Double]
    var melBands: [Double]
    var spectralContrast: [Double]
    var tonnetz: [Double]
    var tempo: Double
    var beatPositions: [Double]
    var onsetStrength: Double
    var spectralComplexity: Double
    var duration: Double
    var sampleRate: Double
    var timestamp: Date

    init(spectralCentroid: Double = 0, spectralFlatness: Double = 0, spectralRolloff: Double = 0, spectralFlux: Double = 0, zeroCrossingRate: Double = 0, rmsEnergy: Double = 0, loudness: Double = 0, pitch: Double = 0, harmonicity: Double = 0, chromaFeatures: [Double] = Array(repeating: 0, count: 12), mfcc: [Double] = Array(repeating: 0, count: 13), melBands: [Double] = Array(repeating: 0, count: 40), spectralContrast: [Double] = Array(repeating: 0, count: 6), tonnetz: [Double] = Array(repeating: 0, count: 6), tempo: Double = 0, beatPositions: [Double] = [], onsetStrength: Double = 0, spectralComplexity: Double = 0, duration: Double = 0, sampleRate: Double = 44100, timestamp: Date = Date()) {
        self.id = UUID()
        self.spectralCentroid = spectralCentroid
        self.spectralFlatness = spectralFlatness
        self.spectralRolloff = spectralRolloff
        self.spectralFlux = spectralFlux
        self.zeroCrossingRate = zeroCrossingRate
        self.rmsEnergy = rmsEnergy
        self.loudness = loudness
        self.pitch = pitch
        self.harmonicity = harmonicity
        self.chromaFeatures = chromaFeatures
        self.mfcc = mfcc
        self.melBands = melBands
        self.spectralContrast = spectralContrast
        self.tonnetz = tonnetz
        self.tempo = tempo
        self.beatPositions = beatPositions
        self.onsetStrength = onsetStrength
        self.spectralComplexity = spectralComplexity
        self.duration = duration
        self.sampleRate = sampleRate
        self.timestamp = timestamp
    }
}

struct RhythmAnalysis: Codable, Identifiable {
    let id = UUID()
    var tempo: Double
    var beatStrength: Double
    var swingRatio: Double
    var grooveConsistency: Double
    var timeSignature: TimeSignature
    var onsetTimes: [Double]
    var interOnsetIntervals: [Double]
    var rhythmComplexity: Double
    var syncopationIndex: Double
    var microtiming: [Double]
    var tempoStability: Double
    var timestamp: Date

    struct TimeSignature: Codable { let beatsPerBar: Int; let beatUnit: Int }

    init(tempo: Double = 0, beatStrength: Double = 0, swingRatio: Double = 0, grooveConsistency: Double = 0, timeSignature: TimeSignature = TimeSignature(beatsPerBar: 4, beatUnit: 4), onsetTimes: [Double] = [], interOnsetIntervals: [Double] = [], rhythmComplexity: Double = 0, syncopationIndex: Double = 0, microtiming: [Double] = [], tempoStability: Double = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.tempo = tempo
        self.beatStrength = beatStrength
        self.swingRatio = swingRatio
        self.grooveConsistency = grooveConsistency
        self.timeSignature = timeSignature
        self.onsetTimes = onsetTimes
        self.interOnsetIntervals = interOnsetIntervals
        self.rhythmComplexity = rhythmComplexity
        self.syncopationIndex = syncopationIndex
        self.microtiming = microtiming
        self.tempoStability = tempoStability
        self.timestamp = timestamp
    }
}

struct TimbreClassification: Codable, Identifiable {
    let id = UUID()
    var instrument: InstrumentType
    var confidence: Double
    var spectralShape: SpectralShape
    var envelope: EnvelopeShape
    var brightness: Double
    var warmth: Double
    var roughness: Double
    var boominess: Double
    var depth: Double
    var sharpness: Double
    var texture: Double
    var descriptors: [String]
    var timestamp: Date

    enum InstrumentType: String, Codable, CaseIterable {
        case piano, guitar, drums, bass, strings, brass, woodwinds, synth, vocal, percussion, unknown
    }

    struct SpectralShape: Codable { let slope: Double; let curvature: Double; let peakFrequency: Double; let spectralBalance: [Double] }
    struct EnvelopeShape: Codable { let attack: Double; let decay: Double; let sustain: Double; let release: Double; let shape: String }

    init(instrument: InstrumentType = .unknown, confidence: Double = 0, spectralShape: SpectralShape = SpectralShape(slope: 0, curvature: 0, peakFrequency: 0, spectralBalance: []), envelope: EnvelopeShape = EnvelopeShape(attack: 0, decay: 0, sustain: 0, release: 0, shape: "unknown"), brightness: Double = 0, warmth: Double = 0, roughness: Double = 0, boominess: Double = 0, depth: Double = 0, sharpness: Double = 0, texture: Double = 0, descriptors: [String] = [], timestamp: Date = Date()) {
        self.id = UUID()
        self.instrument = instrument
        self.confidence = confidence
        self.spectralShape = spectralShape
        self.envelope = envelope
        self.brightness = brightness
        self.warmth = warmth
        self.roughness = roughness
        self.boominess = boominess
        self.depth = depth
        self.sharpness = sharpness
        self.texture = texture
        self.descriptors = descriptors
        self.timestamp = timestamp
    }
}

// MARK: - Audio Analysis Engine
@MainActor
final class AudioAnalysisEngine: ObservableObject {
    static let shared = AudioAnalysisEngine()
    @Published private(set) var features: AudioFeatures?
    @Published private(set) var rhythmAnalysis: RhythmAnalysis?
    @Published private(set) var timbreClassification: TimbreClassification?
    @Published private(set) var isAnalyzing = false
    private var cancellationToken: Task<Void, Never>?

    func analyzeAudioSamples(samples: [Float], sampleRate: Double = 44100) async -> AudioFeatures {
        isAnalyzing = true
        defer { isAnalyzing = false }
        let fftSize = 2048
        let hopSize = 512
        let frames = (samples.count - fftSize) / hopSize
        var spectralCentroids: [Double] = []
        var spectralFlats: [Double] = []
        var spectralRolloffs: [Double] = []
        var spectralFluxes: [Double] = []
        var rmsValues: [Double] = []
        var zcrs: [Double] = []
        var mfccFrames: [[Double]] = []
        var chromaFrames: [[Double]] = []
        var melBandsFrames: [[Double]] = []
        var previousMagnitude: [Float] = Array(repeating: 0, count: fftSize / 2)
        let log2Table = (0..<1024).map { log2(max(1, Double($0))) / log2(1024.0) }
        for frameIndex in 0..<max(1, frames) {
            let start = frameIndex * hopSize
            let frame = Array(samples[start..<min(samples.count, start + fftSize)])
            let windowed = applyHannWindow(frame)
            let fftResult = performFFT(windowed, fftSize: fftSize)
            let magnitude = computeMagnitudeSpectrum(fftResult)
            let power = magnitude.map { $0 * $0 }
            let totalPower = power.reduce(0, +)
            if totalPower > 0 {
                let spectralCentroid = zip(magnitude, Array(0..<magnitude.count)).map { $0 * Double($1) }.reduce(0, +) / totalPower
                spectralCentroids.append(spectralCentroid)
                let geometricMean = exp(power.map { log(max($0, 1e-10)) }.reduce(0, +) / Double(power.count))
                let arithmeticMean = totalPower / Double(power.count)
                spectralFlats.append(geometricMean / max(arithmeticMean, 1e-10))
                let cumulativePower = power.reduce(into: [Double]()) { $0.append(($0.last ?? 0) + $1) }
                let totalCumulative = cumulativePower.last ?? 1
                let rolloffIndex = cumulativePower.firstIndex { $0 >= totalCumulative * 0.85 } ?? power.count - 1
                spectralRolloffs.append(Double(rolloffIndex) * sampleRate / Double(fftSize))
                let flux = zip(magnitude, previousMagnitude).map { max(0, $0 - Double($1)) }.reduce(0, +)
                spectralFluxes.append(flux)
                previousMagnitude = magnitude.map { Float($0) }
                let rms = sqrt(frame.map { $0 * $0 }.reduce(0, +) / Double(frame.count))
                rmsValues.append(rms)
                let zcr = zip(frame, frame.dropFirst()).filter { $0 * $1 < 0 }.count / Double(frame.count)
                zcrs.append(zcr)
            }
            let frameMfcc = computeMFCC(power: power, sampleRate: sampleRate, numCoefficients: 13)
            mfccFrames.append(frameMfcc)
            let frameChroma = computeChroma(magnitude: magnitude, sampleRate: sampleRate, fftSize: fftSize)
            chromaFrames.append(frameChroma)
            let frameMel = computeMelBands(power: power, sampleRate: sampleRate, fftSize: fftSize, numBands: 40)
            melBandsFrames.append(frameMel)
        }
        let avgSpectralCentroid = spectralCentroids.reduce(0, +) / Double(max(1, spectralCentroids.count))
        let avgSpectralFlatness = spectralFlats.reduce(0, +) / Double(max(1, spectralFlats.count))
        let avgSpectralRolloff = spectralRolloffs.reduce(0, +) / Double(max(1, spectralRolloffs.count))
        let avgSpectralFlux = spectralFluxes.reduce(0, +) / Double(max(1, spectralFluxes.count))
        let avgZCR = zcrs.reduce(0, +) / Double(max(1, zcrs.count))
        let avgRMS = rmsValues.reduce(0, +) / Double(max(1, rmsValues.count))
        let avgLoudness = 20 * log10(max(avgRMS, 1e-10))
        let avgMFCC = mfccFrames.reduce(into: Array(repeating: 0.0, count: 13)) { $0 = zip($0, $1).map { $0 + $1 } }.map { $0 / Double(max(1, mfccFrames.count)) }
        let avgChroma = chromaFrames.reduce(into: Array(repeating: 0.0, count: 12)) { $0 = zip($0, $1).map { $0 + $1 } }.map { $0 / Double(max(1, chromaFrames.count)) }
        let avgMelBands = melBandsFrames.reduce(into: Array(repeating: 0.0, count: 40)) { $0 = zip($0, $1).map { $0 + $1 } }.map { $0 / Double(max(1, melBandsFrames.count)) }
        let pitch = estimatePitch(samples: samples, sampleRate: sampleRate)
        let harmonicity = estimateHarmonicity(samples: samples, sampleRate: sampleRate)
        let tempo = estimateTempo(rmsValues: rmsValues, sampleRate: sampleRate, hopSize: hopSize)
        let features = AudioFeatures(spectralCentroid: avgSpectralCentroid, spectralFlatness: avgSpectralFlatness, spectralRolloff: avgSpectralRolloff, spectralFlux: avgSpectralFlux, zeroCrossingRate: avgZCR, rmsEnergy: avgRMS, loudness: avgLoudness, pitch: pitch, harmonicity: harmonicity, chromaFeatures: avgChroma, mfcc: avgMFCC, melBands: avgMelBands, spectralContrast: computeSpectralContrast(power: melBandsFrames.flatMap { $0 }), tonnetz: Array(repeating: 0, count: 6), tempo: tempo, onsetStrength: avgSpectralFlux, spectralComplexity: avgSpectralFlatness, duration: Double(samples.count) / sampleRate, sampleRate: sampleRate)
        self.features = features
        return features
    }

    func analyzeRhythm(samples: [Float], sampleRate: Double = 44100) async -> RhythmAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }
        let fftSize = 2048
        let hopSize = 512
        var rmsValues: [Double] = []
        for frameIndex in stride(from: 0, to: samples.count, by: hopSize) {
            let frame = Array(samples[frameIndex..<min(samples.count, frameIndex + fftSize)])
            let rms = sqrt(frame.map { $0 * $0 }.reduce(0, +) / Double(frame.count))
            rmsValues.append(rms)
        }
        let tempo = estimateTempo(rmsValues: rmsValues, sampleRate: sampleRate, hopSize: hopSize)
        let onsetTimes = detectOnsets(rmsValues: rmsValues, sampleRate: sampleRate, hopSize: hopSize)
        let iois = zip(onsetTimes, onsetTimes.dropFirst()).map { $1 - $0 }
        let avgIOI = iois.reduce(0, +) / Double(max(1, iois.count))
        let swingRatio = calculateSwingRatio(iois: iois)
        let grooveConsistency = calculateGrooveConsistency(iois: iois)
        let rhythmComplexity = calculateRhythmComplexity(iois: iois)
        let syncopationIndex = calculateSyncopation(iois: iois, rmsValues: rmsValues)
        let microtiming = calculateMicrotiming(iois: iois)
        let tempoStability = calculateTempoStability(iois: iois)
        let analysis = RhythmAnalysis(tempo: tempo, beatStrength: rmsValues.max() ?? 0, swingRatio: swingRatio, grooveConsistency: grooveConsistency, onsetTimes: onsetTimes, interOnsetIntervals: iois, rhythmComplexity: rhythmComplexity, syncopationIndex: syncopationIndex, microtiming: microtiming, tempoStability: tempoStability)
        self.rhythmAnalysis = analysis
        return analysis
    }

    func classifyTimbre(samples: [Float], sampleRate: Double = 44100) async -> TimbreClassification {
        isAnalyzing = true
        defer { isAnalyzing = false }
        let features = await analyzeAudioSamples(samples: samples, sampleRate: sampleRate)
        let spectralShape = classifySpectralShape(features: features)
        let envelope = classifyEnvelope(samples: samples, sampleRate: sampleRate)
        let brightness = classifyBrightness(features: features)
        let warmth = classifyWarmth(features: features)
        let roughness = classifyRoughness(features: features)
        let boominess = classifyBoominess(features: features)
        let instrument = classifyInstrument(features: features, envelope: envelope, spectralShape: spectralShape)
        let descriptors = generateTimbreDescriptors(features: features, spectralShape: spectralShape, envelope: envelope)
        let classification = TimbreClassification(instrument: instrument, confidence: 0.85, spectralShape: spectralShape, envelope: envelope, brightness: brightness, warmth: warmth, roughness: roughness, boominess: boominess, depth: warmth * 0.5, sharpness: brightness * 0.3, texture: roughness * 0.4, descriptors: descriptors)
        self.timbreClassification = classification
        return classification
    }

    private func applyHannWindow(_ frame: [Float]) -> [Float] {
        let n = frame.count
        return (0..<n).map { i in frame[i] * 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(n - 1))) }
    }

    private func performFFT(_ signal: [Float], fftSize: Int) -> [Float] {
        let realOut = [Float](repeating: 0, count: fftSize / 2)
        let imagOut = [Float](repeating: 0, count: fftSize / 2)
        let log2n = vDSP_Length(log2(Float(fftSize)))
        var forward = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        var complexBuffer = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: realOut), imagp: UnsafeMutablePointer(mutating: imagOut))
        vDSP_fft_zip(&forward, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
        return [Float](repeating: 0, count: fftSize / 2)
    }

    private func computeMagnitudeSpectrum(_ fftResult: [Float]) -> [Double] {
        return fftResult.map { Double($0) }
    }

    private func computeMFCC(power: [Double], sampleRate: Double, numCoefficients: Int) -> [Double] {
        let numFilters = 26
        var mfcc: [Double] = Array(repeating: 0, count: numCoefficients)
        let minFreq = 20.0
        let maxFreq = sampleRate / 2.0
        let melMin = 2595 * log10(1 + minFreq / 700)
        let melMax = 2595 * log10(1 + maxFreq / 700)
        let melPoints = (0..<numFilters + 2).map { melMin + Double($0) * (melMax - melMin) / Double(numFilters + 1) }
        let hzPoints = melPoints.map { 700 * (pow(10, $0 / 2595) - 1) }
        let binPoints = hzPoints.map { Int(floor((fftSize + 1) * $0 / sampleRate)) }
        let filterBank = (0..<numFilters).map { i in
            return (0..<power.count).map { k in
                if k < binPoints[i] { return 0.0 }
                if k >= binPoints[i] && k < binPoints[i + 1] { return Double(k - binPoints[i]) / Double(binPoints[i + 1] - binPoints[i]) }
                if k >= binPoints[i + 1] && k < binPoints[i + 2] { return Double(binPoints[i + 2] - k) / Double(binPoints[i + 2] - binPoints[i + 1]) }
                return 0.0
            }
        }
        let energies = filterBank.map { filter in zip(filter, power).map { $0 * $1 }.reduce(0, +) }
        let logEnergies = energies.map { log(max($0, 1e-10)) }
        for i in 0..<numCoefficients {
            for j in 0..<logEnergies.count {
                mfcc[i] += logEnergies[j] * cos(.pi * Double(i) * (Double(j) + 0.5) / Double(logEnergies.count))
            }
        }
        return mfcc
    }

    private func computeChroma(magnitude: [Double], sampleRate: Double, fftSize: Int) -> [Double] {
        let numChroma = 12
        var chroma = Array(repeating: 0.0, count: numChroma)
        for (index, mag) in magnitude.enumerated() {
            let freq = Double(index) * sampleRate / Double(fftSize)
            let midi = 69 + 12 * log2(max(freq, 1) / 440.0)
            let chromaIndex = Int(round(midi)) % numChroma
            chroma[chromaIndex] += mag * mag
        }
        let sum = chroma.reduce(0, +)
        return sum > 0 ? chroma.map { $0 / sum } : chroma
    }

    private func computeMelBands(power: [Double], sampleRate: Double, fftSize: Int, numBands: Int) -> [Double] {
        var bands = Array(repeating: 0.0, count: numBands)
        let minFreq = 20.0
        let maxFreq = sampleRate / 2.0
        let melMin = 2595 * log10(1 + minFreq / 700)
        let melMax = 2595 * log10(1 + maxFreq / 700)
        let melPoints = (0..<numBands + 2).map { melMin + Double($0) * (melMax - melMin) / Double(numBands + 1) }
        let hzPoints = melPoints.map { 700 * (pow(10, $0 / 2595) - 1) }
        let binPoints = hzPoints.map { Int(floor((fftSize + 1) * $0 / sampleRate)) }
        for i in 0..<numBands {
            let start = binPoints[i]
            let mid = binPoints[i + 1]
            let end = binPoints[i + 2]
            var sum = 0.0
            for j in max(0, start)..<min(power.count, mid) { sum += power[j] * Double(j - start) / Double(mid - start) }
            for j in max(0, mid)..<min(power.count, end) { sum += power[j] * Double(end - j) / Double(end - mid) }
            bands[i] = sum
        }
        return bands
    }

    private func computeSpectralContrast(power: [Double]) -> [Double] {
        let numBands = 6
        var contrast = Array(repeating: 0.0, count: numBands)
        let bandSize = power.count / numBands
        for i in 0..<numBands {
            let start = i * bandSize
            let end = min(power.count, start + bandSize)
            let bandPower = Array(power[start..<end]).sorted()
            let valley = bandPower.first ?? 0
            let peak = bandPower.last ?? 0
            contrast[i] = log10(max(peak, 1e-10) / max(valley, 1e-10))
        }
        return contrast
    }

    private func estimatePitch(samples: [Float], sampleRate: Double) -> Double {
        let minFreq = 80.0
        let maxFreq = 1000.0
        let minLag = Int(sampleRate / maxFreq)
        let maxLag = Int(sampleRate / minFreq)
        var bestLag = minLag
        var bestCorrelation = -Double.greatestFiniteMagnitude
        for lag in minLag..<maxLag {
            var correlation = 0.0
            for i in 0..<samples.count - lag {
                correlation += Double(samples[i]) * Double(samples[i + lag])
            }
            if correlation > bestCorrelation { bestCorrelation = correlation; bestLag = lag }
        }
        return sampleRate / Double(bestLag)
    }

    private func estimateHarmonicity(samples: [Float], sampleRate: Double) -> Double {
        let pitch = estimatePitch(samples: samples, sampleRate: sampleRate)
        guard pitch > 0 else { return 0 }
        let fundamentalPeriod = Int(sampleRate / pitch)
        var harmonicSum = 0.0
        var noiseSum = 0.0
        for harmonic in 1..<10 {
            let period = fundamentalPeriod * harmonic
            if period < samples.count {
                for i in 0..<samples.count - period {
                    harmonicSum += Double(samples[i]) * Double(samples[i + period])
                }
            }
        }
        for i in 0..<samples.count { noiseSum += Double(samples[i]) * Double(samples[i]) }
        return harmonicSum / max(noiseSum, 1e-10)
    }

    private func estimateTempo(rmsValues: [Double], sampleRate: Double, hopSize: Int) -> Double {
        guard rmsValues.count > 10 else { return 0 }
        let onsetEnvelope = zip(rmsValues, rmsValues.dropFirst()).map { max(0, $1 - $0) }
        let peaks = detectPeaks(onsetEnvelope, threshold: 0.3)
        let iois = zip(peaks, peaks.dropFirst()).map { $1 - $0 }
        let avgIOI = iois.reduce(0, +) / Double(max(1, iois.count))
        return avgIOI > 0 ? 60.0 / avgIOI : 120.0
    }

    private func detectOnsets(rmsValues: [Double], sampleRate: Double, hopSize: Int) -> [Double] {
        let onsetEnvelope = zip(rmsValues, rmsValues.dropFirst()).map { max(0, $1 - $0) }
        let peaks = detectPeaks(onsetEnvelope, threshold: 0.3)
        return peaks.map { Double($0) * Double(hopSize) / sampleRate }
    }

    private func detectPeaks(_ signal: [Double], threshold: Double) -> [Int] {
        var peaks: [Int] = []
        for i in 1..<signal.count - 1 {
            if signal[i] > signal[i - 1] && signal[i] > signal[i + 1] && signal[i] > threshold {
                peaks.append(i)
            }
        }
        return peaks
    }

    private func calculateSwingRatio(iois: [Double]) -> Double {
        guard iois.count >= 2 else { return 0.5 }
        let shortIOIs = iois.filter { $0 < iois.reduce(0, +) / Double(iois.count) }
        let longIOIs = iois.filter { $0 >= iois.reduce(0, +) / Double(iois.count) }
        let avgShort = shortIOIs.reduce(0, +) / Double(max(1, shortIOIs.count))
        let avgLong = longIOIs.reduce(0, +) / Double(max(1, longIOIs.count))
        return avgLong > 0 ? avgShort / avgLong : 0.5
    }

    private func calculateGrooveConsistency(iois: [Double]) -> Double {
        guard iois.count > 1 else { return 0 }
        let mean = iois.reduce(0, +) / Double(iois.count)
        let variance = iois.map { pow($0 - mean, 2) }.reduce(0, +) / Double(iois.count)
        return variance > 0 ? 1.0 / (1.0 + variance * 100) : 1.0
    }

    private func calculateRhythmComplexity(iois: [Double]) -> Double {
        guard iois.count > 2 else { return 0 }
        let uniqueIOIs = Set(iois.map { Int($0 * 1000) })
        return Double(uniqueIOIs.count) / Double(iois.count)
    }

    private func calculateSyncopation(iois: [Double], rmsValues: [Double]) -> Double {
        guard iois.count > 2 else { return 0 }
        let meanIOI = iois.reduce(0, +) / Double(iois.count)
        let unexpectedBeats = iois.filter { $0 < meanIOI * 0.5 }.count
        return Double(unexpectedBeats) / Double(max(1, iois.count))
    }

    private func calculateMicrotiming(iois: [Double]) -> [Double] {
        guard iois.count > 1 else { return [] }
        let mean = iois.reduce(0, +) / Double(iois.count)
        return iois.map { $0 - mean }
    }

    private func calculateTempoStability(iois: [Double]) -> Double {
        guard iois.count > 1 else { return 0 }
        let mean = iois.reduce(0, +) / Double(iois.count)
        let std = sqrt(iois.map { pow($0 - mean, 2) }.reduce(0, +) / Double(iois.count))
        return mean > 0 ? max(0, 1.0 - std / mean) : 0
    }

    private func classifySpectralShape(features: AudioFeatures) -> TimbreClassification.SpectralShape {
        let slope = features.spectralCentroid / max(features.sampleRate / 2, 1)
        let curvature = features.spectralFlatness
        return TimbreClassification.SpectralShape(slope: slope, curvature: curvature, peakFrequency: features.spectralRolloff, spectralBalance: features.melBands)
    }

    private func classifyEnvelope(samples: [Float], sampleRate: Double) -> TimbreClassification.EnvelopeShape {
        let rmsValues = stride(from: 0, to: samples.count, by: 512).map { start in
            let frame = Array(samples[start..<min(samples.count, start + 512)])
            return sqrt(frame.map { $0 * $0 }.reduce(0, +) / Double(frame.count))
        }
        let peakIndex = rmsValues.enumerated().max { $0.element < $1.element }?.offset ?? 0
        let attack = Double(peakIndex) * 512.0 / sampleRate
        let decay = Double(rmsValues.count - peakIndex) * 512.0 / sampleRate
        return TimbreClassification.EnvelopeShape(attack: attack, decay: decay, sustain: rmsValues.last ?? 0, release: 0, shape: "percussive")
    }

    private func classifyBrightness(features: AudioFeatures) -> Double {
        return min(1.0, features.spectralCentroid / (features.sampleRate * 0.4))
    }

    private func classifyWarmth(features: AudioFeatures) -> Double {
        return max(0, 1.0 - features.spectralCentroid / (features.sampleRate * 0.3))
    }

    private func classifyRoughness(features: AudioFeatures) -> Double {
        return features.spectralFlux * features.zeroCrossingRate * 100
    }

    private func classifyBoominess(features: AudioFeatures) -> Double {
        return features.melBands.prefix(5).reduce(0, +) / Double(max(1, features.melBands.count))
    }

    private func classifyInstrument(features: AudioFeatures, envelope: TimbreClassification.EnvelopeShape, spectralShape: TimbreClassification.SpectralShape) -> TimbreClassification.InstrumentType {
        if features.pitch > 1000 && envelope.attack < 0.05 && envelope.attack > 0.001 { return .percussion }
        if features.pitch > 80 && features.pitch < 1000 && envelope.attack > 0.01 && envelope.attack < 0.3 && spectralShape.brightness > 0.5 { return .piano }
        if features.pitch > 80 && features.pitch < 1000 && envelope.attack > 0.005 && envelope.attack < 0.1 { return .guitar }
        if features.pitch > 40 && features.pitch < 300 && features.harmonicity > 0.8 { return .bass }
        if features.pitch > 200 && features.pitch < 2000 && features.harmonicity > 0.6 && features.mfcc[1] > 0 { return .strings }
        if features.pitch > 200 && features.pitch < 2000 && features.harmonicity > 0.5 && features.mfcc[2] > 0 { return .brass }
        if features.pitch > 300 && features.pitch < 3000 && features.spectralCentroid > 2000 { return .woodwinds }
        if features.pitch > 0 && features.spectralFlatness > 0.5 { return .synth }
        if features.pitch > 80 && features.pitch < 500 && features.chromaFeatures.count > 5 { return .vocal }
        return .unknown
    }

    private func generateTimbreDescriptors(features: AudioFeatures, spectralShape: TimbreClassification.SpectralShape, envelope: TimbreClassification.EnvelopeShape) -> [String] {
        var descriptors: [String] = []
        if features.spectralCentroid > 3000 { descriptors.append("bright") } else if features.spectralCentroid < 1000 { descriptors.append("dark") } else { descriptors.append("warm") }
        if features.spectralFlatness > 0.5 { descriptors.append("noisy") } else { descriptors.append("tonal") }
        if envelope.attack < 0.01 { descriptors.append("percussive") } else if envelope.attack > 0.2 { descriptors.append("gradual") } else { descriptors.append("plucked") }
        if features.roughness > 0.5 { descriptors.append("rough") } else { descriptors.append("smooth") }
        if features.boominess > 0.5 { descriptors.append("boomy") }
        if features.tempo > 120 { descriptors.append("fast") } else if features.tempo > 80 { descriptors.append("moderate") } else { descriptors.append("slow") }
        return descriptors
    }
}
