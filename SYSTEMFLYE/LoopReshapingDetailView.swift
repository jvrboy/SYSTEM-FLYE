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


// MARK: - Extended Implementation

struct ExtendedDetailView: View {
    @State private var items: [ExtendedItem] = []
    @State private var selectedID: UUID?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var sortOrder: SortOrder = .name
    @State private var isExpanded: Bool = false
    @State private var showingDetail = false
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 5
    @State private var itemsPerPage: Int = 20
    @State private var viewMode: ViewMode = .list
    @State private var gridColumns: Int = 3
    @State private var showArchived = false
    @State private var showPinned = false
    @State private var isRefreshing = false
    @State private var refreshProgress: Double = 0.0

    enum FilterMode: String, CaseIterable { case all = "All"; case active = "Active"; case completed = "Completed"; case pending = "Pending"; case archived = "Archived" }
    enum SortOrder: String, CaseIterable { case name = "Name"; case date = "Date"; case priority = "Priority"; case status = "Status" }
    enum ViewMode: String, CaseIterable { case list = "List"; case grid = "Grid"; case compact = "Compact"; case detailed = "Detailed" }

    struct ExtendedItem: Identifiable {
        let id = UUID()
        var title: String
        var subtitle: String
        var description: String
        var status: ItemStatus
        var priority: Priority
        var createdAt: Date
        var updatedAt: Date
        var tags: [String]
        var metadata: [String: String]
        var isPinned: Bool
        var isArchived: Bool
        var color: Color
    }

    enum ItemStatus: String { case pending = "Pending"; case active = "Active"; case completed = "Completed"; case failed = "Failed"; case cancelled = "Cancelled" }
    enum Priority: String, CaseIterable { case low = "Low"; case medium = "Medium"; case high = "High"; case urgent = "Urgent" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    controlsView
                    contentView
                    footerView
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Extended Detail")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { generateItems() }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  E X T E N D E D", title: "Detail View")
                Spacer()
                Label("EXTENDED", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(SystemFlyeTheme.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SystemFlyeTheme.violet.opacity(0.12), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(metricTiles) { tile in
                    MetricTile(label: tile.label, value: tile.value, detail: tile.detail, tint: tile.tint)
                }
            }
        }
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search items...", text: $searchText).textFieldStyle(.plain).foregroundStyle(.white)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterMode.allCases) { mode in
                        Button { filterMode = mode }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(filterMode == mode ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(filterMode == mode ? .black : .white.opacity(0.7)) }
                    }
                    ForEach(ViewMode.allCases) { mode in
                        Button { viewMode = mode }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(viewMode == mode ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(viewMode == mode ? .black : .white.opacity(0.7)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button { generateItems() }
                    label: { Label("Refresh", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { isExpanded.toggle() }
                    label: { Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.right.and.arrow.down.left").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.green)
                Button { showingDetail = true }
                    label: { Label("Detail", systemImage: "info.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .list: listContentView
        case .grid: gridContentView
        case .compact: compactContentView
        case .detailed: detailedContentView
        }
    }

    private var listContentView: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredItems) { item in
                HStack(spacing: 14) {
                    Circle().fill(item.color).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor(item.status))
                        Text(item.priority.rawValue).font(.caption2).foregroundStyle(priorityColor(item.priority))
                    }
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var gridContentView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumns)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Circle().fill(item.color).frame(width: 8, height: 8)
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(item.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor(item.status))
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var compactContentView: some View {
        LazyVStack(spacing: 6) {
            ForEach(filteredItems) { item in
                HStack(spacing: 10) {
                    Circle().fill(item.color).frame(width: 6, height: 6)
                    Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(item.status.rawValue).font(.caption2).foregroundStyle(statusColor(item.status))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var detailedContentView: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredItems) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.title).font(.headline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(item.priority.rawValue).font(.caption.weight(.bold)).foregroundStyle(priorityColor(item.priority))
                            .padding(.horizontal, 10).padding(.vertical, 5).background(priorityColor(item.priority).opacity(0.15), in: Capsule())
                    }
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    HStack(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.06), in: Capsule()).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    HStack(spacing: 12) {
                        Text("Created: \(item.createdAt, style: .date)").font(.caption2).foregroundStyle(.secondary)
                        Text("Updated: \(item.updatedAt, style: .relative)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var footerView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Showing \(filteredItems.count) of \(items.count) items").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Page \(currentPage + 1) of \(totalPages)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button { currentPage = max(0, currentPage - 1) }
                    label: { Image(systemName: "chevron.left").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary).disabled(currentPage == 0)
                ForEach(0..<totalPages, id: \.self) { page in
                    Button { currentPage = page }
                        label: { Text("\(page + 1)").font(.caption2.weight(.semibold)).frame(width: 28, height: 28).background(currentPage == page ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(currentPage == page ? .black : .white.opacity(0.7)) }
                }
                Button { currentPage = min(totalPages - 1, currentPage + 1) }
                    label: { Image(systemName: "chevron.right").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary).disabled(currentPage == totalPages - 1)
            }
        }
    }

    private var filteredItems: [ExtendedItem] {
        var base = items
        if !searchText.isEmpty { base = base.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.subtitle.localizedCaseInsensitiveContains(searchText) } }
        if filterMode != .all {
            switch filterMode {
            case .active: base = base.filter { $0.status == .active }
            case .completed: base = base.filter { $0.status == .completed }
            case .pending: base = base.filter { $0.status == .pending }
            case .archived: base = base.filter { $0.isArchived }
            default: break
            }
        }
        if showArchived { base = base.filter { $0.isArchived } }
        if showPinned { base = base.filter { $0.isPinned } }
        switch sortOrder {
        case .name: base.sort { $0.title < $1.title }
        case .date: base.sort { $0.updatedAt > $1.updatedAt }
        case .priority: base.sort { priorityRank($0.priority) > priorityRank($1.priority) }
        case .status: base.sort { $0.status.rawValue < $1.status.rawValue }
        }
        return base
    }

    private var metricTiles: [MetricTileData] {
        [
            MetricTileData(label: "Total", value: "\(items.count)", detail: "all items", tint: SystemFlyeTheme.cyan),
            MetricTileData(label: "Active", value: "\(items.filter { $0.status == .active }.count)", detail: "in progress", tint: .green),
            MetricTileData(label: "Pinned", value: "\(items.filter { $0.isPinned }.count)", detail: "starred", tint: .orange),
            MetricTileData(label: "Archived", value: "\(items.filter { $0.isArchived }.count)", detail: "hidden", tint: .secondary)
        ]
    }

    struct MetricTileData { let label: String; let value: String; let detail: String; let tint: Color }

    private func statusColor(_ status: ItemStatus) -> Color {
        switch status { case .pending: return .orange; case .active: return SystemFlyeTheme.cyan; case .completed: return .green; case .failed: return .red; case .cancelled: return .secondary }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority { case .low: return .secondary; case .medium: return .blue; case .high: return .orange; case .urgent: return .red }
    }

    private func priorityRank(_ priority: Priority) -> Int {
        switch priority { case .low: return 1; case .medium: return 2; case .high: return 3; case .urgent: return 4 }
    }

    private func generateItems() {
        isRefreshing = true
        let statuses: [ItemStatus] = [.pending, .active, .completed, .failed, .cancelled]
        let priorities: [Priority] = [.low, .medium, .high, .urgent]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        let titles = ["Project Alpha", "Task Beta", "Feature Gamma", "Bug Delta", "Epic Epsilon", "Story Zeta", "Ticket Eta", "Issue Theta"]
        let subtitles = ["In progress", "Under review", "Blocked", "Ready for testing", "Draft", "Approved", "Pending", "Shipped"]
        items = (0..<50).map { _ in
            ExtendedItem(title: titles.randomElement()!, subtitle: subtitles.randomElement()!, description: "This is a detailed description for the item providing comprehensive context and background information.", status: statuses.randomElement()!, priority: priorities.randomElement()!, createdAt: Date().addingTimeInterval(-Double.random(in: 0...86400 * 30)), updatedAt: Date().addingTimeInterval(-Double.random(in: 0...86400)), tags: ["tag1", "tag2", "tag3"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }, metadata: ["key1": "value1", "key2": "value2"], isPinned: Bool.random(), isArchived: Bool.random(), color: colors.randomElement()!)
        }
        isRefreshing = false
    }
}

struct ExtendedDetailView_Previews: PreviewProvider {
    static var previews: some View { ExtendedDetailView().preferredColorScheme(.dark) }
}


// MARK: - Additional Comprehensive Implementation

struct AdditionalDetailView: View {
    @State private var dataItems: [DataItem] = []
    @State private var selectedIndex: Int? = nil
    @State private var isActive: Bool = true
    @State private var progress: Double = 0.5
    @State private var counter: Int = 0
    @State private var items: [ListItem] = []
    @State private var sections: [SectionItem] = []
    @State private var selectedSection: SectionItem?
    @State private var searchQuery: String = ""
    @State private var filterEnabled: Bool = true
    @State private var sortAscending: Bool = true
    @State private var currentPage: Int = 1
    @State private var totalItems: Int = 0
    @State private var showAdvanced: Bool = false
    @State private var showSettings: Bool = false
    @State private var showHelp: Bool = false
    @State private var isDarkMode: Bool = true
    @State private var accentTint: Color = SystemFlyeTheme.cyan
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 1.4
    @State private var cornerRadius: CGFloat = 12
    @State private var shadowRadius: CGFloat = 8
    @State private var animationDuration: Double = 0.3
    @State private var transitionStyle: TransitionStyle = .spring
    @State private var layoutDirection: LayoutDirection = .vertical
    @State private var spacing: CGFloat = 12
    @State private var padding: CGFloat = 18
    @State private var backgroundOpacity: Double = 0.02
    @State private var overlayOpacity: Double = 0.1
    @State private var borderWidth: CGFloat = 1.0
    @State private var borderColor: Color = SystemFlyeTheme.line
    @State private var shadowColor: Color = .black
    @State private var shadowOffset: CGSize = CGSize(width: 0, height: 4)
    @State private var contentMode: ContentMode = .fit
    @State private var alignment: Alignment = .leading
    @State private var distribution: Distribution = .equalSpacing
    @State private var priority: Priority = .normal

    enum TransitionStyle: String, CaseIterable { case spring = "Spring"; case easeIn = "Ease In"; case easeOut = "Ease Out"; case linear = "Linear"; case none = "None" }
    enum LayoutDirection: String, CaseIterable { case vertical = "Vertical"; case horizontal = "Horizontal" }
    enum ContentMode: String, CaseIterable { case fit = "Fit"; case fill = "Fill"; case scaleToFit = "Scale" }
    enum Distribution: String, CaseIterable { case equalSpacing = "Equal"; case equalCentering = "Centered"; case leading = "Leading"; case trailing = "Trailing" }
    enum Priority: String, CaseIterable { case low = "Low"; case normal = "Normal"; case high = "High" }

    struct DataItem: Identifiable {
        let id = UUID()
        var title: String
        var value: Double
        var unit: String
        var trend: TrendDirection
        var metadata: [String: String]
        enum TrendDirection { case up, down, neutral, volatile }
    }

    struct ListItem: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var timestamp: Date
        var isSelected: Bool
        var tags: [String]
        var color: Color
    }

    struct SectionItem: Identifiable {
        let id = UUID()
        var title: String
        var items: [ListItem]
        var isExpanded: Bool
        var color: Color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    controlPanel
                    contentSection
                    statisticsSection
                    actionButtons
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Additional Detail")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadData() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  A D D I T I O N A L", title: "Detail View")
                Spacer()
                Label("ACTIVE", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isActive ? .green : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background((isActive ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(overviewTiles) { tile in
                    MetricTile(label: tile.label, value: tile.value, detail: tile.detail, tint: tile.tint)
                }
            }
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search...", text: $searchQuery).textFieldStyle(.plain).foregroundStyle(.white)
                Toggle("", isOn: $filterEnabled).labelsHidden().tint(SystemFlyeTheme.cyan)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sections.indices, id: \.self) { index in
                        Button { selectedSection = sections[index] }
                            label: { Text(sections[index].title).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedSection?.id == sections[index].id ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedSection?.id == sections[index].id ? .black : .white.opacity(0.7)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button { loadData() }
                    label: { Label("Refresh", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { showAdvanced.toggle() }
                    label: { Label(showAdvanced ? "Hide" : "Advanced", systemImage: "gearshape.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(showAdvanced ? SystemFlyeTheme.violet : .secondary)
                Button { showHelp.toggle() }
                    label: { Label("Help", systemImage: "questionmark.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let section = selectedSection {
            sectionDetailView(section)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Circle().fill(item.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(item.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(SystemFlyeTheme.line))
                }
            }
        }
    }

    private func sectionDetailView(_ section: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
            LazyVStack(spacing: 8) {
                ForEach(section.items) { item in
                    HStack(spacing: 12) {
                        Circle().fill(item.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(item.description).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text(tag).font(.caption2).padding(.horizontal, 6).padding(.vertical, 3).background(Color.white.opacity(0.06), in: Capsule()).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATISTICS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Items", value: "\(items.count)")
                StatCard(label: "Sections", value: "\(sections.count)")
                StatCard(label: "Selected", value: selectedIndex != nil ? "1" : "0")
                StatCard(label: "Progress", value: "\(Int(progress * 100))%")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { counter += 1 }
                label: { Label("Increment", systemImage: "plus").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
            Button { counter = max(0, counter - 1) }
                label: { Label("Decrement", systemImage: "minus").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.bordered).tint(.orange)
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { progress = Double.random(in: 0...1) } }
                label: { Label("Random", systemImage: "dice.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.bordered).tint(.green)
            Spacer()
            Text("Count: \(counter)").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
        }
    }

    private var overviewTiles: [OverviewTile] {
        [
            OverviewTile(label: "Total", value: "\(items.count)", detail: "items loaded", tint: SystemFlyeTheme.cyan),
            OverviewTile(label: "Sections", value: "\(sections.count)", detail: "categories", tint: SystemFlyeTheme.violet),
            OverviewTile(label: "Selected", value: selectedIndex != nil ? "1" : "0", detail: "active", tint: .green),
            OverviewTile(label: "Counter", value: "\(counter)", detail: "increments", tint: .orange)
        ]
    }

    struct OverviewTile { let label: String; let value: String; let detail: String; let tint: Color }

    private func loadData() {
        let statuses: [ListItem.ItemStatus] = [.pending, .active, .completed, .failed, .cancelled]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        let titles = ["Project Alpha", "Task Beta", "Feature Gamma", "Bug Delta", "Epic Epsilon", "Story Zeta", "Ticket Eta", "Issue Theta"]
        let descriptions = ["In progress", "Under review", "Blocked", "Ready for testing", "Draft", "Approved", "Pending", "Shipped"]
        items = (0..<30).map { _ in
            ListItem(title: titles.randomElement()!, description: descriptions.randomElement()!, timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)), isSelected: Bool.random(), tags: ["tag1", "tag2", "tag3"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }, color: colors.randomElement()!)
        }
        sections = [
            SectionItem(title: "Overview", items: Array(items.prefix(10)), isExpanded: true, color: SystemFlyeTheme.cyan),
            SectionItem(title: "Details", items: Array(items.suffix(10)), isExpanded: false, color: SystemFlyeTheme.violet),
            SectionItem(title: "History", items: Array(items.shuffled().prefix(10)), isExpanded: false, color: .green)
        ]
        totalItems = items.count
    }
}

struct ListItem: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var timestamp: Date
    var isSelected: Bool
    var tags: [String]
    var color: Color
    enum ItemStatus: String { case pending = "Pending"; case active = "Active"; case completed = "Completed"; case failed = "Failed"; case cancelled = "Cancelled" }
}

struct SectionItem: Identifiable {
    let id = UUID()
    var title: String
    var items: [ListItem]
    var isExpanded: Bool
    var color: Color
}

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ExtendedDetailView_Previews: PreviewProvider {
    static var previews: some View { ExtendedDetailView().preferredColorScheme(.dark) }
}
