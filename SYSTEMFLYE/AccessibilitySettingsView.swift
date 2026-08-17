import SwiftUI

struct AccessibilitySettingsView: View {
    @State private var voiceOverEnabled = false
    @State private var zoomEnabled = true
    @State private var zoomLevel: Double = 2.0
    @State private var reduceMotion = false
    @State private var reduceTransparency = false
    @State private var invertColors = false
    @State private var colorFilters = false
    @State private var boldText = false
    @State private var buttonShapes = true
    @State private var onOffLabels = true
    @State private var grayscale: Double = 0.0
    @State private var redGreenFilter = false
    @State private var greenRedFilter = false
    @State private var blueYellowFilter = false
    @State private var increaseContrast = false
    @State private var reduceWhitePoint = false
    @State private var switchControlEnabled = false
    @State private var assistiveTouchEnabled = false
    @State private var liveCaptionsEnabled = false
    @State private var soundRecognitionEnabled = false
    @State private var textSize: DynamicTypeSize = .large
    @State private var boldTextSize: Bool = false
    @State private var showingAccessibilityShortcut = false
    @State private var activeTab: AccessibilityTab = .vision
    @State private var hapticFeedbackEnabled = true
    @State private var audioDescriptionsEnabled = true
    @State private var monoAudioEnabled = false
    @State private var balanceLeftRight: Double = 0.0
    @State private var showClosedCaptions = true
    @State private var captionStyle: CaptionStyle = .default
    @State private var hearingDeviceCompatibility = false
    @State private var customVibrationEnabled = false
    @State private var shakeToUndo = true
    @State private var shakeToRedo = false

    enum AccessibilityTab: String, CaseIterable { case vision = "Vision"; case hearing = "Hearing"; case motor = "Motor"; case general = "General" }
    enum CaptionStyle: String, CaseIterable { case `default` = "Default"; case largeText = "Large Text"; case highContrast = "High Contrast"; case monochrome = "Monochrome" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        Text("Customize accessibility features").font(.system(size: 14, weight: .regular)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                    Divider().background(SystemFlyeTheme.line)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AccessibilityTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .vision: visionSettings
                    case .hearing: hearingSettings
                    case .motor: motorSettings
                    case .general: generalSettings
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Accessibility").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAccessibilityShortcut) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Accessibility Shortcut").font(.title.weight(.bold)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Triple-click the side button to quickly access accessibility features.").font(.subheadline).foregroundStyle(.secondary)
                            VStack(spacing: 12) {
                                AccessibilityShortcutOption(title: "VoiceOver", icon: "eye.fill", isSelected: voiceOverEnabled)
                                AccessibilityShortcutOption(title: "Zoom", icon: "magnifyingglass", isSelected: zoomEnabled)
                                AccessibilityShortcutOption(title: "AssistiveTouch", icon: "hand.tap.fill", isSelected: assistiveTouchEnabled)
                                AccessibilityShortcutOption(title: "Switch Control", icon: "switch.2", isSelected: switchControlEnabled)
                                AccessibilityShortcutOption(title: "Guided Access", icon: "lock.fill", isSelected: false)
                            }
                        }
                        Spacer()
                    }
                    .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
                    .navigationTitle("Shortcut").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingAccessibilityShortcut = false } } }
                }
            }
        }
    }

    private var visionSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "eye.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("VISION").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "VoiceOver", subtitle: "Screen reader for visually impaired users", isOn: $voiceOverEnabled)
                    ToggleRow(title: "Zoom", subtitle: "Magnify content up to 15x", isOn: $zoomEnabled)
                    HStack { Text("Zoom Level").font(.caption).foregroundColor(.secondary); Spacer(); Slider(value: $zoomLevel, in: 1.0...15.0, step: 0.5).tint(SystemFlyeTheme.cyan); Text("\(Int(zoomLevel))x").font(.caption.monospacedDigit()).foregroundColor(SystemFlyeTheme.cyan).frame(width: 35) }
                    ToggleRow(title: "Reduce Motion", subtitle: "Minimize animations and parallax", isOn: $reduceMotion)
                    ToggleRow(title: "Reduce Transparency", subtitle: "Increase contrast by reducing blur", isOn: $reduceTransparency)
                    ToggleRow(title: "Increase Contrast", subtitle: "Make text and content more distinct", isOn: $increaseContrast)
                    ToggleRow(title: "Bold Text", subtitle: "Increase font weight", isOn: $boldText)
                    ToggleRow(title: "Button Shapes", subtitle: "Add shapes to buttons", isOn: $buttonShapes)
                    ToggleRow(title: "On/Off Labels", subtitle: "Show labels for on/off switches", isOn: $onOffLabels)
                    ToggleRow(title: "Reduce White Point", subtitle: "Dim white colors", isOn: $reduceWhitePoint)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "textformat").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("DISPLAY & TEXT").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text Size").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Picker("", selection: $textSize) { ForEach(DynamicTypeSize.allCases, id: \.self) { size in Text(sizeLabel(for: size)).tag(size) } }
                        .pickerStyle(.segmented)
                    }
                    ToggleRow(title: "Bold Text", subtitle: "Increase text weight globally", isOn: $boldTextSize)
                    HStack { Text("Grayscale").font(.caption).foregroundColor(.secondary); Spacer(); Slider(value: $grayscale, in: 0...1).tint(.gray); Text("\(Int(grayscale * 100))%").font(.caption.monospacedDigit()).foregroundColor(.gray).frame(width: 35) }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "eye.trianglebadge.exclamationmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("COLOR FILTERS").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Color Filters", subtitle: "Apply filters for color blindness", isOn: $colorFilters)
                    if colorFilters {
                        VStack(spacing: 12) {
                            FilterToggleRow(title: "Red/Green", color: .red, isOn: $redGreenFilter)
                            FilterToggleRow(title: "Green/Red", color: .green, isOn: $greenRedFilter)
                            FilterToggleRow(title: "Blue/Yellow", color: .blue, isOn: $blueYellowFilter)
                        }
                        .padding(.top, 8)
                    }
                    ToggleRow(title: "Invert Colors", subtitle: "Invert display colors", isOn: $invertColors)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            Button { showingAccessibilityShortcut = true }
                label: {
                    HStack { Text("Accessibility Shortcut").font(.subheadline.weight(.semibold)).foregroundColor(.blue); Spacer(); Text("Triple-click side button").font(.subheadline).foregroundColor(.gray); Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray) }
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
        }
    }

    private var hearingSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "ear.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("HEARING").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Live Captions", subtitle: "Transcribe audio in real time", isOn: $liveCaptionsEnabled)
                    ToggleRow(title: "Sound Recognition", subtitle: "Identify surrounding sounds", isOn: $soundRecognitionEnabled)
                    ToggleRow(title: "Audio Descriptions", subtitle: "Narrate video content", isOn: $audioDescriptionsEnabled)
                    ToggleRow(title: "Mono Audio", subtitle: "Combine stereo channels", isOn: $monoAudioEnabled)
                    if monoAudioEnabled {
                        HStack { Text("Left/Right Balance").font(.caption).foregroundColor(.secondary); Spacer(); Slider(value: $balanceLeftRight, in: -1...1).tint(SystemFlyeTheme.cyan); Text(String(format: "%.0f", balanceLeftRight * 100)).font(.caption.monospacedDigit()).foregroundColor(SystemFlyeTheme.cyan).frame(width: 30) }.padding(.horizontal, 4)
                    }
                    ToggleRow(title: "Hearing Device Compatibility", subtitle: "Enable Bluetooth hearing aids", isOn: $hearingDeviceCompatibility)
                    ToggleRow(title: "Closed Captions + SDH", subtitle: "Show captions and subtitles", isOn: $showClosedCaptions)
                    if showClosedCaptions {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Caption Style").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Picker("", selection: $captionStyle) { ForEach(CaptionStyle.allCases) { style in Text(style.rawValue).tag(style) } }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var motorSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "hand.tap.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("PHYSICAL & MOTOR").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Switch Control", subtitle: "Navigate with adaptive switches", isOn: $switchControlEnabled)
                    ToggleRow(title: "AssistiveTouch", subtitle: "Customizable touch gestures", isOn: $assistiveTouchEnabled)
                    ToggleRow(title: "Haptic Feedback", subtitle: "Vibrate on interactions", isOn: $hapticFeedbackEnabled)
                    ToggleRow(title: "Custom Vibration", subtitle: "Create custom vibration patterns", isOn: $customVibrationEnabled)
                    ToggleRow(title: "Shake to Undo", subtitle: "Shake device to undo", isOn: $shakeToUndo)
                    ToggleRow(title: "Shake to Redo", subtitle: "Shake device to redo", isOn: $shakeToRedo)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "gearshape.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("GENERAL").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Prefer Accessibility", subtitle: "Prioritize accessibility features", isOn: .constant(true))
                    ToggleRow(title: "Auto-Enable Features", subtitle: "Automatically enable recommended settings", isOn: .constant(false))
                    ToggleRow(title: "Accessibility Shortcut", subtitle: "Triple-click side button", isOn: .constant(true))
                    ToggleRow(title: "Accessibility Inspector", subtitle: "Enable developer inspector", isOn: .constant(false))
                    ToggleRow(title: "AssistiveTouch Waiting", subtitle: "Show menu when idle", isOn: .constant(false))
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private func sizeLabel(for size: DynamicTypeSize) -> String {
        switch size { case .xSmall: return "XS"; case .small: return "S"; case .medium: return "M"; case .large: return "L"; case .xLarge: return "XL"; case .xxLarge: return "XXL"; case .xxxLarge: return "XXXL"; case .accessibility1: return "A1"; case .accessibility2: return "A2"; case .accessibility3: return "A3"; case .accessibility4: return "A4"; case .accessibility5: return "A5"; default: return "L" }
    }
}

struct FilterToggleRow: View {
    let title: String
    let color: Color
    @Binding var isOn: Bool
    var body: some View {
        Toggle { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white) } onToggled: { }
            toggleStyle: .checkbox
            .tint(color)
            .padding(.horizontal, 4)
    }
}

struct AccessibilityShortcutOption: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(isSelected ? SystemFlyeTheme.cyan : .secondary).frame(width: 24)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) }
        }
        .padding(14)
        .background(isSelected ? SystemFlyeTheme.cyan.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? SystemFlyeTheme.cyan.opacity(0.3) : SystemFlyeTheme.line))
    }
}

struct AccessibilitySettingsView_Previews: PreviewProvider {
    static var previews: some View { AccessibilitySettingsView().preferredColorScheme(.dark) }
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
