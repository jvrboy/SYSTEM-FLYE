import AVFoundation
import Accelerate
import Combine

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var waveformData: [Float] = []
    @Published var frequencyData: [Float] = Array(repeating: 0, count: 64)
    @Published var amplitude: Float = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var currentAudioBuffer: AVAudioPCMBuffer?
    
    private let audioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var analyzerNode: AVAudioUnit?
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        do {
            playerNode = AVAudioPlayerNode()
            audioEngine.attach(playerNode!)
            audioEngine.connect(playerNode!, to: audioEngine.mainMixerNode, format: nil)
            
            try audioEngine.start()
        } catch {
            print("Audio engine setup error: \(error)")
        }
    }
    
    // MARK: - Playback Control
    func play(audioBuffer: AVAudioPCMBuffer) {
        currentAudioBuffer = audioBuffer
        duration = TimeInterval(audioBuffer.frameLength) / audioBuffer.format.sampleRate
        
        guard let playerNode = playerNode else { return }
        
        do {
            playerNode.stop()
            
            playerNode.scheduleBuffer(audioBuffer, completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            })
            
            try audioEngine.start()
            playerNode.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
            }
            
            // Start display link for real-time updates
            startDisplayLink()
            
            // Generate waveform data
            generateWaveformData(from: audioBuffer)
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    func pause() {
        playerNode?.pause()
        isPlaying = false
        stopDisplayLink()
    }
    
    func stop() {
        playerNode?.stop()
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
    }
    
    func seek(to time: TimeInterval) {
        guard let playerNode = playerNode, let buffer = currentAudioBuffer else { return }
        
        let sampleRate = buffer.format.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)
        
        playerNode.stop()
        
        if let frameCount = buffer.frameLength as AVAudioFrameCount? {
            if framePosition < frameCount {
                let remainingFrames = frameCount - AVAudioFrameCount(framePosition)
                if let playbackBuffer = AVAudioPCMBuffer(
                    pcmFormat: buffer.format,
                    frameCapacity: remainingFrames
                ) {
                    playbackBuffer.frameLength = remainingFrames
                    
                    if let floatChannelData = buffer.floatChannelData {
                        for channel in 0..<Int(buffer.format.channelCount) {
                            memcpy(
                                playbackBuffer.floatChannelData![channel],
                                floatChannelData[channel] + Int(framePosition),
                                Int(remainingFrames) * MemoryLayout<Float>.size
                            )
                        }
                    }
                    
                    playerNode.scheduleBuffer(playbackBuffer)
                    currentTime = time
                    playerNode.play()
                }
            }
        }
    }
    
    // MARK: - Waveform Generation
    private func generateWaveformData(from buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let samplesPerPoint = max(1, frameLength / 256)
        
        var waveformPoints: [Float] = []
        
        for i in stride(from: 0, to: frameLength, by: samplesPerPoint) {
            var maxAmplitude: Float = 0
            
            for sample in i..<min(i + samplesPerPoint, frameLength) {
                for channel in 0..<channelCount {
                    let amplitude = abs(floatChannelData[channel][sample])
                    maxAmplitude = max(maxAmplitude, amplitude)
                }
            }
            
            waveformPoints.append(maxAmplitude)
        }
        
        DispatchQueue.main.async {
            self.waveformData = waveformPoints
        }
    }
    
    // MARK: - Real-time Monitoring
    private func startDisplayLink() {
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateMeters)
        )
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateMeters() {
        guard playerNode != nil else { return }
        
        let mainMixer = audioEngine.mainMixerNode
        mainMixer.installTap(
            onBus: 0,
            bufferSize: 2048,
            format: mainMixer.outputFormat(forBus: 0)
        ) { [weak self] buffer, _ in
            self?.analyzeAudio(buffer: buffer)
        }
    }
    
    private func analyzeAudio(buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS amplitude
        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let sample = floatChannelData[0][i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength))
        
        DispatchQueue.main.async {
            self.amplitude = rms
        }
        
        // Perform FFT for frequency analysis
        performFFT(floatChannelData[0], frameLength: frameLength)
    }
    
    private func performFFT(_ samples: UnsafeMutablePointer<Float>, frameLength: Int) {
        var realParts = Array(UnsafeBufferPointer(start: samples, count: frameLength))
        var imaginaryParts = [Float](repeating: 0, count: frameLength)
        var log2n = 0
        var value = frameLength
        while value > 1 { value /= 2; log2n += 1 }
        guard (1 << log2n) == frameLength else { return }
        guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2)) else { return }
        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imaginaryParts.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var complexSplitData = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
        
        vDSP_fft_zip(
            fftSetup,
            &complexSplitData,
            1,
            vDSP_Length(log2n),
            FFTDirection(FFT_FORWARD)
        )
        
        var magnitudes = [Float](repeating: 0, count: frameLength / 2)
        
        for i in 0..<frameLength / 2 {
            let real = realBuffer[i]
            let imag = imaginaryBuffer[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // Downsample to 64 bins
        let binSize = max(1, frameLength / 128)
        var frequencyBins = [Float](repeating: 0, count: 64)
        
        for bin in 0..<64 {
            let startIndex = bin * binSize
            let endIndex = min((bin + 1) * binSize, magnitudes.count)
            
            if startIndex < magnitudes.count {
                let slice = magnitudes[startIndex..<endIndex]
                frequencyBins[bin] = slice.max() ?? 0
            }
        }
        
                DispatchQueue.main.async {
                    self.frequencyData = frequencyBins
                }
            }
        }
        vDSP_destroy_fftsetup(fftSetup)
    }
}
