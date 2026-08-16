import UIKit
import AVFoundation
import Accelerate

class ImageToAudioConverter {
    static let shared = ImageToAudioConverter()
    
    struct ImageSoundMapping {
        var brightnessToAmplitude: Bool = true
        var colorToFrequency: Bool = true
        var spatialDistribution: Bool = true
        var textureGraininess: Bool = true
        var baseFrequency: Float = 440 // Hz
        var frequencyRange: Float = 2000 // Hz
        var duration: Float = 5.0 // seconds
        var harmonics: Int = 8
    }
    
    // MARK: - Main Conversion
    func convertImageToAudio(
        image: UIImage,
        mapping: ImageSoundMapping
    ) -> AVAudioPCMBuffer? {
        guard let imageData = analyzeImage(image) else { return nil }
        
        let sampleRate: Float = 48000
        let frameCount = Int(Float(sampleRate) * mapping.duration)
        
        guard let audioBuffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(sampleRate),
                channels: 2,
                interleaved: false
            )!,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else { return nil }
        
        audioBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        guard let floatChannelData = audioBuffer.floatChannelData else { return nil }
        
        let leftChannel = floatChannelData[0]
        let rightChannel = floatChannelData[1]
        
        // Generate audio from image data
        generateAudioFromImageData(
            imageData: imageData,
            leftChannel: leftChannel,
            rightChannel: rightChannel,
            frameCount: frameCount,
            mapping: mapping,
            sampleRate: sampleRate
        )
        
        return audioBuffer
    }
    
    // MARK: - Image Analysis
    private func analyzeImage(_ image: UIImage) -> ImageAnalysisData? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var brightnessSamples: [Float] = []
        var hueSamples: [Float] = []
        var saturationSamples: [Float] = []
        var edgeDensity: [Float] = []
        
        // Sample pixels
        let sampleStep = max(1, min(width, height) / 64)
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                let r = Float(pixelData[pixelIndex]) / 255.0
                let g = Float(pixelData[pixelIndex + 1]) / 255.0
                let b = Float(pixelData[pixelIndex + 2]) / 255.0
                
                let brightness = (r + g + b) / 3.0
                brightnessSamples.append(brightness)
                
                let (hue, saturation) = rgbToHueSaturation(r: r, g: g, b: b)
                hueSamples.append(hue)
                saturationSamples.append(saturation)
            }
        }
        
        // Calculate edge density using Sobel operator
        edgeDensity = calculateEdgeDensity(pixelData: pixelData, width: width, height: height)
        
        return ImageAnalysisData(
            brightness: brightnessSamples,
            hue: hueSamples,
            saturation: saturationSamples,
            edges: edgeDensity,
            width: width,
            height: height
        )
    }
    
    private func calculateEdgeDensity(pixelData: [UInt8], width: Int, height: Int) -> [Float] {
        var edges: [Float] = []
        
        let bytesPerPixel = 4
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let current = pixelData[(y * width + x) * bytesPerPixel]
                let right = pixelData[(y * width + x + 1) * bytesPerPixel]
                let bottom = pixelData[((y + 1) * width + x) * bytesPerPixel]
                
                let gx = Float(Int(right) - Int(current))
                let gy = Float(Int(bottom) - Int(current))
                let magnitude = sqrt(gx * gx + gy * gy) / 255.0
                
                edges.append(min(magnitude, 1.0))
            }
        }
        
        return edges
    }
    
    private func rgbToHueSaturation(r: Float, g: Float, b: Float) -> (hue: Float, saturation: Float) {
        let max = max(r, g, b)
        let min = min(r, g, b)
        let delta = max - min
        
        var hue: Float = 0
        if delta > 0 {
            if max == r {
                hue = fmod((g - b) / delta, 6) / 6
            } else if max == g {
                hue = ((b - r) / delta + 2) / 6
            } else {
                hue = ((r - g) / delta + 4) / 6
            }
        }
        
        let saturation = max > 0 ? delta / max : 0
        
        return (max(0, hue), saturation)
    }
    
    // MARK: - Audio Generation
    private func generateAudioFromImageData(
        imageData: ImageAnalysisData,
        leftChannel: UnsafeMutablePointer<Float>,
        rightChannel: UnsafeMutablePointer<Float>,
        frameCount: Int,
        mapping: ImageSoundMapping,
        sampleRate: Float
    ) {
        for frame in 0..<frameCount {
            let timeNormalized = Float(frame) / Float(frameCount)
            let sampleIndex = min(Int(Float(imageData.brightness.count) * timeNormalized), imageData.brightness.count - 1)
            
            var frequency: Float = mapping.baseFrequency
            var amplitude: Float = 1.0
            
            // Map color to frequency
            if mapping.colorToFrequency && sampleIndex < imageData.hue.count {
                let hue = imageData.hue[sampleIndex]
                frequency = mapping.baseFrequency + (hue * mapping.frequencyRange)
            }
            
            // Map brightness to amplitude
            if mapping.brightnessToAmplitude && sampleIndex < imageData.brightness.count {
                amplitude = imageData.brightness[sampleIndex]
            }
            
            // Apply spatial distribution from width distribution
            if mapping.spatialDistribution && sampleIndex < imageData.edges.count {
                let spatialFactor = 1.0 - (imageData.edges[sampleIndex] * 0.3)
                amplitude *= spatialFactor
            }
            
            // Generate polyphonic harmony
            var sample: Float = 0
            
            for harmonic in 1...mapping.harmonics {
                let harmonicFreq = frequency * Float(harmonic)
                let phase = 2 * .pi * harmonicFreq * (Float(frame) / sampleRate)
                let harmonicAmplitude = amplitude / Float(harmonic)
                
                sample += sin(phase) * harmonicAmplitude
            }
            
            // Apply envelope
            let envelopeAttack: Float = 0.1
            let envelopeRelease: Float = 0.2
            let envelope = applyADSREnvelope(
                time: timeNormalized,
                attack: envelopeAttack,
                sustain: 1.0 - envelopeAttack - envelopeRelease,
                release: envelopeRelease
            )
            
            sample *= envelope
            
            // Stereo spread based on saturation
            let stereoFactor = imageData.saturation[sampleIndex]
            leftChannel[frame] = sample * (1.0 - stereoFactor * 0.3)
            rightChannel[frame] = sample * (1.0 + stereoFactor * 0.3)
        }
    }
    
    private func applyADSREnvelope(time: Float, attack: Float, sustain: Float, release: Float) -> Float {
        if time < attack {
            return time / attack
        } else if time < attack + sustain {
            return 1.0
        } else {
            let releaseTime = (time - attack - sustain) / release
            return max(0, 1.0 - releaseTime)
        }
    }
}

// MARK: - Data Structures
struct ImageAnalysisData {
    let brightness: [Float]
    let hue: [Float]
    let saturation: [Float]
    let edges: [Float]
    let width: Int
    let height: Int
}
