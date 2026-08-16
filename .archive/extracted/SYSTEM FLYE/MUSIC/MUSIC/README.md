# Advanced Sound Designer – Professional iOS Audio Synthesis & Processing

A production-ready native iOS app for advanced audio synthesis, image-to-audio conversion, sound manipulation, and multi-format audio export.

## Features

### 🎛️ Granular Synthesis Engine
- **Advanced Grain Control**: Adjustable grain size (10-500ms), density (1-100 grains/s), and overlap
- **Pitch Shifting**: ±24 semitones real-time pitch control without time stretching
- **Time Stretching**: 0.5x–2.0x speed control with grain-based time manipulation
- **Window Functions**: Hann, Hamming, Blackman, and Triangle window types
- **Stereo Spread**: Polyphonic spatial distribution across stereo field

### 🎨 Image-to-Audio Conversion
- **Spectral Analysis**: Extract brightness, hue, saturation, and edge density from images
- **Adaptive Mapping**: 
  - Brightness → Amplitude modulation
  - Color (Hue) → Frequency synthesis
  - Spatial Distribution → Dynamic texture
  - Texture Edges → Granular characteristics
- **Polyphonic Harmony**: Configurable harmonics (1-16) for rich sound generation
- **Real-time Preview**: Live audio playback during image processing

### 🎛️ Advanced Audio Effects
- **Frequency Shifting**: Independent frequency shifting without pitch change
- **Formant Correction**: Multi-band formant preservation and manipulation
- **Spectral Compression**: Frequency-aware dynamic range control
- **Biquad Filtering**: High-order IIR filter design with variable Q

### 🔊 LFO Modulation
- **Multiple Waveforms**: Sine, Triangle, Sawtooth, Square
- **Configurable Rate**: 0.1–20 Hz LFO frequency
- **Depth Control**: 0–100% modulation depth
- **Envelope Generation**: ADSR envelope on all grains

### 📁 Multi-Format Audio Export
Export in professional formats:
- **WAV (PCM)** – 24-bit uncompressed, highest quality
- **AIFF** – Apple interchange format
- **AAC (M4A)** – 256 kbps lossy compression
- **MP3** – 320 kbps ultra-high quality
- **FLAC** – 16-bit lossless compression
- **ALAC** – Apple's lossless audio codec

### 🛠️ Professional Tools
- Real-time Waveform Display (256-point resolution)
- FFT Frequency Spectrum Analyzer (64-bin)
- RMS Amplitude Metering
- Audio File Manager with metadata
- Batch export capabilities
- Normalize and compress options

## Architecture

```
SoundDesigner/
├── SoundDesignerApp.swift          # Main app entry point
├── Audio/
│   ├── GranularSynthesizer.swift    # Core synthesis engine
│   ├── ImageToAudioConverter.swift  # Image analysis & mapping
│   ├── AudioFileManager.swift       # Multi-format I/O
│   └── AudioPlayerManager.swift     # Playback & monitoring
├── UI/
│   ├── ContentView.swift            # Main tab navigation
│   ├── SynthesizerView.swift        # Granular controls
│   ├── ImageToAudioView.swift       # Image conversion interface
│   ├── ExportView.swift             # Export configuration
│   ├── FileManagerView.swift        # File organization
│   └── WaveformDisplayView.swift    # Real-time visualization
└── README.md                        # This file
```

## System Requirements

- **iOS**: 16.0 or later
- **Xcode**: 14.0 or later
- **Swift**: 5.7+
- **Device**: iPhone 12 or later (iPad supported)

## Installation & Setup

### 1. Clone or Download the Project
```bash
cd SoundDesigner
```

### 2. Open in Xcode
```bash
open SoundDesigner.xcodeproj
```

### 3. Configure Code Signing
- Select the project in Xcode
- Go to **Signing & Capabilities**
- Select your development team
- Update Bundle Identifier if needed

### 4. Build and Run
```bash
⌘ + R
```

## Usage Guide

### Granular Synthesis

1. **Load Audio File**
   - Go to Synthesizer tab
   - Tap "Load Audio"
   - Select a WAV or compatible audio file

2. **Configure Grain Parameters**
   - **Grain Size**: Smaller = artifacts, larger = smoother transitions
   - **Density**: Higher = more grains/s, richer texture
   - **Pitch Shift**: ±24 semitones without time change
   - **Time Stretch**: 2× = double speed, 0.5× = half speed
   - **Overlap**: 0 = no overlap, 1 = full overlap (richer)

3. **Apply Modulation**
   - Enable LFO with adjustable rate (0.1–20 Hz)
   - Choose LFO waveform (Sine/Triangle/Saw/Square)
   - Set depth for amount of modulation

4. **Select Window Function**
   - Hann: Best for general use
   - Hamming: Reduced spectral leakage
   - Blackman: Steep roll-off
   - Triangle: Linear envelope

5. **Playback & Adjust**
   - Tap Play to audition in real-time
   - Waveform display shows live processing
   - Adjust parameters while playing

### Image-to-Audio

1. **Load Image**
   - Go to Image→Audio tab
   - Tap **Browse** (Photo Library) or **Camera**

2. **Configure Mapping**
   - Toggle audio characteristics:
     - Brightness → Amplitude
     - Color → Frequency
     - Spatial Distribution → Texture
     - Texture → Grain characteristics

3. **Set Audio Parameters**
   - **Base Frequency**: Starting pitch (Hz)
   - **Frequency Range**: Spread from base (Hz)
   - **Duration**: Output length (1–30 seconds)
   - **Harmonics**: Number of pitch overtones (1–16)

4. **Convert & Preview**
   - Tap "Convert to Audio"
   - Listen to real-time playback
   - Adjust mapping and re-convert if needed

### Export Audio

1. **Go to Export Tab**
   - Enter custom filename
   - Select target format (WAV/MP3/AAC/FLAC/ALAC/AIFF)

2. **Configure Options**
   - Enable Normalize for consistent loudness
   - Add Metadata for ID3 tags
   - Apply Compression for file size reduction

3. **Export**
   - Tap "Export Audio"
   - File saves to Documents/Exports/
   - Share via AirDrop, Mail, or cloud services

### File Management

1. **View Saved Files**
   - Go to Files tab
   - Switch between Sounds (source) and Exports (output)
   - View duration, sample rate, file size

2. **Organize Files**
   - Tap Share icon to AirDrop or email
   - Tap Delete to remove files
   - Long-press to rename (future update)

## Advanced Technical Details

### Granular Synthesis Algorithm

The synthesizer uses a pitch-synchronous granular approach:

```swift
func processGranular(
    buffer: AVAudioPCMBuffer,
    grainSize: Float,           // 10-500ms
    density: Float,             // grains/second
    pitchShift: Float,          // ±24 semitones
    timeStretch: Float,         // 0.5-2.0x
    overlap: Float              // 0-1.0
) -> AVAudioPCMBuffer
```

**Key Parameters**:
- Grain hop size = grainSize / (1 + overlap)
- Pitch ratio = 2^(pitchShift / 12)
- Window function applied per-grain for smooth transitions

### Image Analysis & Spectral Mapping

Images are analyzed at multiple levels:

```
Image → RGB Extraction
    ↓
HSV Conversion (Hue, Saturation, Value/Brightness)
    ↓
Sobel Edge Detection
    ↓
FFT Frequency Domain Analysis
    ↓
Harmonic Synthesis (1-16 harmonics)
    ↓
ADSR Envelope Application
    ↓
Stereo Rendering
```

Color mapping:
- **Hue** (0°–360°) → **Frequency** (Base ± Range)
- **Saturation** (0–1) → **Stereo Width** (mono–full stereo)
- **Brightness** (0–1) → **Amplitude** (0–max)
- **Edges** (0–1) → **Grain Texture** (smooth→grainy)

### Audio File Format Support

| Format | Codec | Bit Depth | Sample Rate | Quality |
|--------|-------|-----------|-------------|---------|
| WAV    | PCM   | 24-bit    | 48 kHz      | Lossless |
| AIFF   | PCM   | 24-bit    | 48 kHz      | Lossless |
| FLAC   | FLAC  | 16-bit    | 48 kHz      | Lossless |
| ALAC   | ALAC  | 24-bit    | 48 kHz      | Lossless |
| M4A    | AAC   | N/A       | 48 kHz      | 256 kbps |
| MP3    | MP3   | N/A       | 48 kHz      | 320 kbps |

## Performance Optimization

### Real-time Processing
- Uses `AVAudioEngine` for low-latency playback
- Dedicated thread for DSP computations
- Accelerate framework for vectorized operations

### Memory Management
- Circular buffer for grain storage
- Efficient FFT using `vDSP_fft_zip`
- Automatic audio session management

## Troubleshooting

### No Audio Output
1. Check volume is not muted (physical switch on left side)
2. Verify audio session category: Settings → Sound
3. Restart app and try different audio format

### Slow Synthesis
1. Reduce grain density (lower = faster)
2. Use smaller grain sizes
3. Disable LFO modulation temporarily
4. Close other apps using audio

### Export Not Working
1. Check disk space (minimum 50 MB recommended)
2. Verify file format compatibility
3. Try different filename without special characters
4. Grant file system permissions in Settings

### Image Conversion Poor Quality
1. Use high-resolution images (1080p+)
2. Increase harmonics count (8–16 better)
3. Adjust base frequency for sweet spot
4. Enable all mapping options for detail

## Future Enhancements

- [ ] MIDI keyboard input support
- [ ] Preset management & cloud sync
- [ ] Advanced EQ and mastering tools
- [ ] Real-time stem separation
- [ ] Wavetable oscillator bank
- [ ] Convolution reverb
- [ ] Multi-touch gesture synthesis
- [ ] ML-based sound classification

## API Reference

### GranularSynthesizer

```swift
let synth = GranularSynthesizer.shared

// Process with granular settings
let output = synth.processAudioWithGranularSynthesis(
    audioBuffer: inputBuffer,
    parameters: GranularSynthesizer.GranularParameters(
        grainSize: 100,
        density: 10,
        pitchShift: 0,
        timeStretch: 1.0,
        overlap: 0.5,
        windowType: .hann,
        spreadWidth: 0,
        modulation: GranularSynthesizer.ModulationSettings(
            lfoRate: 5,
            lfoDepth: 0,
            lfoType: .sine,
            envAttack: 10,
            envRelease: 100
        )
    )
)

// Apply effects
synth.applyFrequencyShift(buffer: output, shiftHz: 100)
synth.applyFormantCorrection(buffer: output, formantShift: 1.2)
synth.applySpectralCompression(buffer: output, threshold: 0.7)
```

### ImageToAudioConverter

```swift
let converter = ImageToAudioConverter.shared

let mapping = ImageToAudioConverter.ImageSoundMapping(
    brightnessToAmplitude: true,
    colorToFrequency: true,
    spatialDistribution: true,
    textureGraininess: true,
    baseFrequency: 440,
    frequencyRange: 2000,
    duration: 5.0,
    harmonics: 8
)

let audioBuffer = converter.convertImageToAudio(
    image: myUIImage,
    mapping: mapping
)
```

### AudioFileManager

```swift
let manager = AudioFileManager.shared

// Export to multiple formats
manager.exportAudioBuffer(
    audioBuffer,
    format: .wav,
    filename: "my_sound"
) { url, error in
    if let url = url {
        print("Exported to: \(url.path)")
    }
}

// Get audio properties
if let props = manager.getAudioProperties(from: fileURL) {
    print("Duration: \(props.duration)s")
    print("Channels: \(props.channels)")
    print("Sample Rate: \(props.sampleRate) Hz")
}
```

## License

Proprietary – Advanced Sound Designer

## Support

For issues, feature requests, or technical support, please open an issue on the project repository.

---

**Version**: 1.0.0  
**Last Updated**: 2026  
**Status**: Production Ready
