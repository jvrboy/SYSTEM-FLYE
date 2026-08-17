import AVFoundation
import Accelerate
import AudioToolbox

class AudioFileManager {
    static let shared = AudioFileManager()
    
    enum AudioFormat: String, CaseIterable {
        case wav = "WAV (Uncompressed)"
        case aiff = "AIFF"
        case m4a = "AAC (iTunes)"
        case mp3 = "MP3"
        case flac = "FLAC"
        case alac = "ALAC (Apple)"
        
        var fileExtension: String {
            switch self {
            case .wav: return "wav"
            case .aiff: return "aiff"
            case .m4a: return "m4a"
            case .mp3: return "mp3"
            case .flac: return "flac"
            case .alac: return "m4a"
            }
        }
        
        var formatID: AudioFormatID {
            switch self {
            case .wav: return kAudioFormatLinearPCM
            case .aiff: return kAudioFormatLinearPCM
            case .m4a: return kAudioFormatMPEG4AAC
            case .mp3: return kAudioFormatMPEGLayer3
            case .flac: return kAudioFormatFLAC
            case .alac: return kAudioFormatAppleLossless
            }
        }
    }
    
    let documentDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]
    
    var soundsDirectory: URL {
        documentDirectory.appendingPathComponent("Sounds", isDirectory: true)
    }
    
    var exportsDirectory: URL {
        documentDirectory.appendingPathComponent("Exports", isDirectory: true)
    }
    
    init() {
        createDirectoriesIfNeeded()
    }
    
    // MARK: - Directory Management
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(
            at: soundsDirectory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: exportsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Reading Audio Files
    func loadAudioFile(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            ) else { return nil }
            
            try audioFile.read(into: buffer)
            return buffer
        } catch {
            #if DEBUG
            print("Error loading audio file: \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Exporting Audio Files
    func exportAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        format: AudioFormat,
        filename: String,
        completion: @escaping (URL?, Error?) -> Void
    ) {
        let outputURL = exportsDirectory.appendingPathComponent(filename).appendingPathExtension(format.fileExtension)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.writeAudioBuffer(buffer, to: outputURL, format: format)
                DispatchQueue.main.async {
                    completion(outputURL, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    private func writeAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        to url: URL,
        format: AudioFormat
    ) throws {
        let audioFile = try AVAudioFile(forWriting: url, settings: getAudioSettings(for: format, format: buffer.format))
        try audioFile.write(from: buffer)
    }
    
    // MARK: - Audio Settings
    private func getAudioSettings(for format: AudioFormat, format pcmFormat: AVAudioFormat) -> [String: Any] {
        let sampleRate = pcmFormat.sampleRate
        let channels = pcmFormat.channelCount
        
        switch format {
        case .wav, .aiff:
            return [
                AVFormatIDKey: format.formatID,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: (format == .aiff)
            ]
            
        case .m4a:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: 256000,
                AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_Constant
            ]
            
        case .mp3:
            return [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: 320000
            ]
            
        case .flac:
            return [
                AVFormatIDKey: kAudioFormatFLAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitDepthHintKey: 24
            ]
            
        case .alac:
            return [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitDepthHintKey: 24
            ]
        }
    }
    
    // MARK: - File Operations
    func getSavedSounds() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: soundsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "wav" }
        } catch {
            return []
        }
    }
    
    func getExportedSounds() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: exportsDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            return []
        }
    }
    
    func deleteFile(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func duplicateFile(_ url: URL, newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.copyItem(at: url, to: newURL)
        return newURL
    }
    
    // MARK: - Audio Analysis
    func getAudioDuration(from url: URL) -> TimeInterval? {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = audioFile.processingFormat.sampleRate
        let duration = TimeInterval(audioFile.length) / sampleRate
        return duration
    }
    
    func getAudioProperties(from url: URL) -> AudioProperties? {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return nil }
        
        let format = audioFile.processingFormat
        let duration = TimeInterval(audioFile.length) / format.sampleRate
        
        return AudioProperties(
            duration: duration,
            sampleRate: format.sampleRate,
            channels: Int(format.channelCount),
            fileSize: getFileSizeInMB(url)
        )
    }
    
    private func getFileSizeInMB(_ url: URL) -> Double {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return 0
        }
        
        guard let fileSize = attributes[.size] as? NSNumber else {
            return 0
        }
        
        return fileSize.doubleValue / (1024 * 1024)
    }
}

struct AudioProperties {
    let duration: TimeInterval
    let sampleRate: Double
    let channels: Int
    let fileSize: Double
}
