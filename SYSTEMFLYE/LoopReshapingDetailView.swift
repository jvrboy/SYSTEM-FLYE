import SwiftUI

struct LoopReshapingDetailView: View {
    @State private var waveformPoints: [CGPoint] = []
    @State private var sliceMarkers: [SliceMarker] = []
    @State private var selectedMarker: UUID?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var loopDuration: Double = 2.4
    @State private var stretchMode: StretchMode = .time
    @State private var warpMode: WarpMode = .beat
    @State private var zoomLevel: CGFloat = 1.0
    @State private var selectedRegion: Region?
    @State private var showGrid = true
    @State private var isRecording = false
    @State private var sampleRate: Double = 44100
    @State private var bitDepth: Int = 16
    @State private var channelMode: ChannelMode = .stereo
    @State private var activeTab: LoopTab = .waveform
    @State private var showMarkers = true
    @State private var showSlices = true
    @State private var showRegions = true
    @State private var playbackHeadVisible = true
    @State private var waveformColor: Color = SystemFlyeTheme.cyan
    @State private var markerColor: Color = .orange
    @State private var regionColor: Color = SystemFlyeTheme.violet
    @State private var selectedSliceIndex: Int? = nil
    @State private var stretchAmount: Double = 1.0
    @State private var warpAmount: Double = 0.5
    @State private var grainSize: Double = 0.1
    @State private var grainDensity: Double = 0.8
    @State private var fadeInDuration: Double = 0.05
    @State private var fadeOutDuration: Double = 0.05
    @State private var normalizeEnabled = true
    @State private var reverseEnabled = false
    @State private var showingExportSheet = false
    @State private var exportFormat: ExportFormat = .wav
    @State private var loopName: String = "Untitled Loop"
    @State private var loopTags: [String] = []
    @State private var isLoopFavorite = false
    @State private var loopBPM: Double = 120.0
    @State private var loopKey: String = "Am"
    @State private var loopGenre: String = "Electronic"
    @State private var loopMood: String = "Energetic"
    @State private var audioFileURL: URL?
    @State private var fileSize: String = "2.4 MB"
    @State private var bitRate: String = "320 kbps"

    enum LoopTab: String, CaseIterable { case waveform = "Waveform"; case slices = "Slices"; case regions = "Regions"; case export = "Export" }
    enum StretchMode: String, CaseIterable { case time = "Time"; case pitch = "Pitch"; case transient = "Transient"; case harmonic = "Harmonic"; case formant = "Formant" }
    enum WarpMode: String, CaseIterable { case beat = "Beat"; case time = "Time"; case complex = "Complex"; case texture = "Texture"; case repitch = "Repitch" }
    enum ChannelMode: String, CaseIterable { case mono = "Mono"; case stereo = "Stereo"; case multichannel = "Multichannel" }
    enum ExportFormat: String, CaseIterable { case wav = "WAV"; case aiff = "AIFF"; case mp3 = "MP3"; case flac = "FLAC"; case ogg = "OGG" }

    struct SliceMarker: Identifiable {
        let id = UUID()
        var position: Double
        var label: String
        var color: Color
        var isLocked: Bool = false
        var fadeIn: Double = 0.0
        var fadeOut: Double = 0.0
    }

    struct Region: Identifiable {
        let id = UUID()
        var start: Double
        var end: Double
        var color: Color
        var label: String
        var isLoop: Bool = true
        var isMuted: Bool = false
        var gain: Double = 1.0
        var pan: Double = 0.0
    }

    var regions: [Region] {
        [
            Region(start: 0.0, end: 0.4, color: SystemFlyeTheme.cyan, label: "Intro", isLoop: false, isMuted: false, gain: 0.8, pan: 0.0),
            Region(start: 0.4, end: 1.6, color: SystemFlyeTheme.violet, label: "Main", isLoop: true, isMuted: false, gain: 1.0, pan: 0.0),
            Region(start: 1.6, end: 2.0, color: .green, label: "Outro", isLoop: false, isMuted: false, gain: 0.9, pan: -0.2),
            Region(start: 0.8, end: 1.2, color: .orange, label: "Fill", isLoop: false, isMuted: true, gain: 0.7, pan: 0.3)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  L O O P  L A B", title: "Loop Detail")
                        Spacer()
                        Label("ON DEVICE", systemImage: "cpu").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Duration", value: String(format: "%.2fs", loopDuration), detail: "loop length", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Slices", value: "\(sliceMarkers.count)", detail: "markers set", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "BPM", value: "\(Int(loopBPM))", detail: "tempo", tint: .green)
                        MetricTile(label: "Key", value: loopKey, detail: "musical key", tint: .orange)
                    }

                    HStack(spacing: 12) {
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPlaying.toggle() } }
                            label: { Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.borderedProminent).tint(isPlaying ? .orange : SystemFlyeTheme.cyan)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isRecording.toggle() } }
                            label: { Label(isRecording ? "Stop Recording" : "Record", systemImage: isRecording ? "stop.fill" : "record.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(isRecording ? .red : .green)
                        Button { addSliceMarker() }
                            label: { Label("Add Slice", systemImage: "scissors").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.violet)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showGrid.toggle() } }
                            label: { Image(systemName: showGrid ? "square.grid.3x3.fill" : "square.grid.3x3").font(.caption).foregroundStyle(showGrid ? SystemFlyeTheme.cyan : .secondary) }
                            .buttonStyle(.bordered).tint(showGrid ? SystemFlyeTheme.cyan : .secondary)
                        Button { showingExportSheet = true }
                            label: { Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.cyan).sheet(isPresented: $showingExportSheet) { exportView }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LoopTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .waveform: waveformTab
                    case .slices: slicesTab
                    case .regions: regionsTab
                    case .export: exportTab
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("STRETCH / WARP CONTROLS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Stretch Mode").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $stretchMode) { ForEach(StretchMode.allCases) { mode in Text(mode.rawValue).tag(mode) } }
                                .pickerStyle(.segmented)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Warp Mode").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $warpMode) { ForEach(WarpMode.allCases) { mode in Text(mode.rawValue).tag(mode) } }
                                .pickerStyle(.segmented)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Stretch Amount").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $stretchAmount, in: 0.25...4.0, step: 0.05).tint(SystemFlyeTheme.cyan)
                                Text("\(String(format: "%.2f", stretchAmount))x").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Warp Factor").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $warpAmount, in: 0...1, step: 0.01).tint(SystemFlyeTheme.violet)
                                Text("\(Int(warpAmount * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet)
                            }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("AUDIO PROPERTIES").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sample Rate").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $sampleRate) { Text("44.1 kHz").tag(44100.0); Text("48 kHz").tag(48000.0); Text("96 kHz").tag(96000.0) }
                                .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bit Depth").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $bitDepth) { ForEach([16, 24, 32], id: \.self) { Text("\($0)-bit").tag($0) } }
                                .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Channels").font(.caption).foregroundStyle(.secondary)
                                Picker("", selection: $channelMode) { ForEach(ChannelMode.allCases) { mode in Text(mode.rawValue).tag(mode) } }
                                .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Grain Size").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $grainSize, in: 0.01...0.5, step: 0.01).tint(SystemFlyeTheme.violet)
                                Text("\(String(format: "%.2f", grainSize))s").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Grain Density").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $grainDensity, in: 0...1, step: 0.05).tint(SystemFlyeTheme.cyan)
                                Text("\(Int(grainDensity * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fade In").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $fadeInDuration, in: 0...0.5, step: 0.01).tint(.green)
                                Text("\(String(format: "%.0f", fadeInDuration * 1000))ms").font(.caption2.monospacedDigit()).foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Loop Detail").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExportSheet) { exportView }
            .onAppear { generateWaveform(); addDefaultMarkers() }
        }
    }

    private var waveformTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WAVEFORM VIEW").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                if showGrid { gridOverlay }
                waveformCanvas.padding(.horizontal, 8).padding(.top, 8)
                if isPlaying { playbackIndicator }
            }
            .frame(height: 220)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var slicesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SLICE MARKERS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(sliceMarkers) { marker in
                        SliceMarkerCard(marker: marker, isSelected: selectedMarker == marker.id)
                            .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMarker = marker.id; selectedSliceIndex = sliceMarkers.firstIndex(where: { $0.id == marker.id }) } }
                    }
                }
            }
            .scrollIndicators(.hidden)
            if let selected = selectedMarker, let marker = sliceMarkers.first(where: { $0.id == selected }) {
                markerDetailCard(marker).padding(.top, 8)
            }
        }
    }

    private var regionsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REGIONS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(regions) { region in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4).fill(region.color).frame(width: 12, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(region.label).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("\(String(format: "%.2f", region.start))s - \(String(format: "%.2f", region.end))s").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(!region.isMuted)).labelsHidden().tint(region.isMuted ? .secondary : SystemFlyeTheme.cyan)
                        Text("Gain: \(Int(region.gain * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var exportTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXPORT").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ForEach(ExportFormat.allCases) { format in
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                        label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(14).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                        .buttonStyle(.plain)
                }
            }
            Button { exportLoop() }
                label: { Label("Export Loop", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
        }
    }

    private var waveformCanvas: some View {
        Canvas { context, size in
            let points = waveformPoints
            guard !points.isEmpty else { return }
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 1
            let rangeY = max(maxY - minY, 1)
            let scaleY = (size.height * 0.6) / rangeY
            let centerY = size.height * 0.5
            var path = Path()
            for (i, pt) in points.enumerated() {
                let x = (pt.x / 300.0) * size.width
                let y = centerY - ((pt.y - centerY) * scaleY)
                i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(waveformColor), lineWidth: 2)
            for pt in points where arc4random_uniform(100) < 20 {
                let x = (pt.x / 300.0) * size.width
                let y = centerY - ((pt.y - centerY) * scaleY)
                let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                context.fill(Circle().path(in: rect), with: .color(waveformColor.opacity(0.5)))
            }
        }
    }

    private var gridOverlay: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 20 * zoomLevel
            ForEach(0..<Int(proxy.size.width / spacing) + 1, id: \.self) { i in
                Path { p in p.move(to: CGPoint(x: CGFloat(i) * spacing, y: 0)); p.addLine(to: CGPoint(x: CGFloat(i) * spacing, y: proxy.size.height)) }
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
            }
            ForEach(0..<Int(proxy.size.height / spacing) + 1, id: \.self) { i in
                Path { p in p.move(to: CGPoint(x: 0, y: CGFloat(i) * spacing)); p.addLine(to: CGPoint(x: proxy.size.width, y: CGFloat(i) * spacing)) }
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
            }
        }
    }

    private var playbackIndicator: some View {
        GeometryReader { proxy in
            Path { p in
                let x = playbackProgress * proxy.size.width
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: proxy.size.height))
            }
            .stroke(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
    }

    private func generateWaveform() {
        waveformPoints = (0..<80).map { i in
            let x = CGFloat(i) / 79.0 * 300
            let y = 100 + (sin(CGFloat(i) * 0.3) * 30) + (CGFloat.random(in: -10...10))
            return CGPoint(x: x, y: y)
        }
    }

    private func addDefaultMarkers() {
        sliceMarkers = [
            SliceMarker(position: 0.0, label: "Start", color: .green, isLocked: true),
            SliceMarker(position: 0.25, label: "Slice 1", color: SystemFlyeTheme.cyan),
            SliceMarker(position: 0.5, label: "Slice 2", color: SystemFlyeTheme.violet),
            SliceMarker(position: 0.75, label: "Slice 3", color: .orange),
            SliceMarker(position: 1.0, label: "End", color: .red, isLocked: true)
        ]
    }

    private func addSliceMarker() {
        let positions = sliceMarkers.map(\.position)
        let newPos = positions.isEmpty ? 0.5 : (positions.max()! + 0.1).truncatingRemainder(dividingBy: 1.0)
        let colors: [Color] = [.cyan, .violet, .green, .orange, .pink, .purple]
        let labels = ["Slice A", "Slice B", "Slice C", "Slice D", "Slice E", "Slice F"]
        let newMarker = SliceMarker(position: newPos, label: labels.randomElement()!, color: colors.randomElement()!)
        sliceMarkers.append(newMarker)
        selectedMarker = newMarker.id
    }

    private func markerDetailCard(_ marker: SliceMarker) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(marker.label.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.1f%%", marker.position * 100)).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(marker.color)
            }
            Divider().background(SystemFlyeTheme.line)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) { Text("Position").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(String(format: "%.3fs", marker.position * loopDuration)).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text("Sample").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text("\(Int(marker.position * loopDuration * sampleRate))").font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
            }
            VStack(spacing: 10) {
                Button { if let idx = sliceMarkers.firstIndex(where: { $0.id == marker.id }) { sliceMarkers.remove(at: idx); selectedMarker = nil } }
                    label: { Label("Delete", systemImage: "trash").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered()).tint(.red)
                Button { if let idx = sliceMarkers.firstIndex(where: { $0.id == marker.id }) { sliceMarkers[idx].position = min(1.0, sliceMarkers[idx].position + 0.05) } }
                    label: { Image(systemName: "arrow.right").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary)
                Button { if let idx = sliceMarkers.firstIndex(where: { $0.id == marker.id }) { sliceMarkers[idx].position = max(0.0, sliceMarkers[idx].position - 0.05) } }
                    label: { Image(systemName: "arrow.left").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary)
            }
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private var exportView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Loop").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Format").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(ExportFormat.allCases) { format in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                            label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(12).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer()
                HStack(spacing: 12) { Button("Cancel") { showingExportSheet = false }.buttonStyle(.bordered()).tint(.secondary); Button("Export") { exportLoop(); showingExportSheet = false }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan) }
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }

    private func exportLoop() { print("Exporting loop as \(exportFormat.rawValue)...") }
}

struct SliceMarkerCard: View {
    let marker: LoopReshapingDetailView.SliceMarker
    let isSelected: Bool
    var body: some View {
        VStack(spacing: 6) {
            Circle().fill(marker.color).frame(width: 10, height: 10)
            Text(marker.label).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
            Text(String(format: "%.0f%%", marker.position * 100)).font(.caption2.monospacedDigit()).foregroundStyle(marker.color)
        }
        .frame(width: 70)
        .padding(.vertical, 10)
        .background(isSelected ? marker.color.opacity(0.15) : SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? marker.color.opacity(0.5) : SystemFlyeTheme.line, lineWidth: isSelected ? 1.5 : 1))
    }
}

struct LoopReshapingDetailView_Previews: PreviewProvider {
    static var previews: some View { LoopReshapingDetailView().preferredColorScheme(.dark) }
}

