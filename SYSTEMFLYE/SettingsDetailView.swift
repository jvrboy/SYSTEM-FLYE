import SwiftUI

struct SettingsDetailView: View {
    @State private var searchText = ""
    @State private var notificationsEnabled = true
    @State private var hapticsEnabled = true
    @State private var soundEnabled = true
    @State private var selectedTheme = "Dark"
    @State private var riskLevel: Double = 3.0
    @State private var updateInterval: Double = 2.0
    @State private var selectedLanguage = "English"
    @State private var selectedRegion = "US"
    @State private var accessibilityZoom: Double = 1.0
    @State private var reduceMotion = false
    @State private var reduceTransparency = false
    @State private var voiceOverEnabled = false
    @State private var dynamicTypeSize: DynamicTypeSize = .large
    @State private var showingResetAlert = false
    @State private var showingExportAlert = false
    @State private var activeSection: SettingsSectionType = .general
    @State private var expandedSections: Set<String> = ["general", "notifications", "accessibility", "trading"]
    @State private var cacheSize: String = "128 MB"
    @State private var lastSyncDate: Date = Date()
    @State private var autoSyncEnabled = true
    @State private var darkModeEnabled = true
    @State private var accentColor: Color = SystemFlyeTheme.cyan
    @State private var fontSize: Double = 16.0
    @State private var lineSpacing: Double = 1.5
    @State private var paragraphSpacing: Double = 0.0
    @State private var boldTextEnabled = false
    @State private var highContrastEnabled = false
    @State private var screenTimeEnabled = false
    @State private var screenTimeLimit: Double = 120.0
    @State private var parentalControlsEnabled = false
    @State private var analyticsEnabled = true
    @State private var crashReportingEnabled = true
    @State private var personalizedAdsEnabled = false
    @State private var dataSharingEnabled = true
    @State private var biometricEnabled = true
    @State private var pinEnabled = false
    @State private var autoLockEnabled = true
    @State private var autoLockTimeout: Double = 300.0
    @State private var backgroundAppRefresh = true
    @State private var lowPowerModeEnabled = false
    @State private var dataUsageWarningEnabled = true
    @State private var dataUsageLimit: Double = 500.0
    @State private var syncWiFiOnly = true
    @State private var syncFrequency: Double = 4.0

    enum SettingsSectionType: String, CaseIterable, Identifiable {
        case general = "General"
        case notifications = "Notifications"
        case accessibility = "Accessibility"
        case trading = "Trading"
        case privacy = "Privacy"
        case data = "Data"
        case security = "Security"
        case about = "About"
        var id: String { rawValue }
    }

    struct SettingsItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let type: SettingsItemType
        var value: String = ""
        var isOn: Bool = false
    }

    enum SettingsItemType {
        case toggle, slider, picker, info, action, navigation
    }

    let themes = ["Dark", "Light", "Auto", "OLED Black"]
    let languages = ["English", "Spanish", "French", "German", "Japanese", "Chinese", "Korean", "Portuguese"]
    let regions = ["US", "UK", "EU", "APAC", "LATAM"]

    var sections: [SettingsSection] {
        let allSections: [SettingsSection] = [
            SettingsSection(title: "General", icon: "gearshape", items: [
                SettingsItem(title: "Theme", subtitle: "Choose your preferred color theme", type: .picker, value: selectedTheme),
                SettingsItem(title: "Language", subtitle: "Select display language", type: .picker, value: selectedLanguage),
                SettingsItem(title: "Region", subtitle: "Format for dates and numbers", type: .picker, value: selectedRegion),
                SettingsItem(title: "Font Size", subtitle: "Adjust text size", type: .slider, value: "\(Int(fontSize))pt"),
                SettingsItem(title: "Line Spacing", subtitle: "Adjust line spacing", type: .slider, value: "\(String(format: "%.1f", lineSpacing))"),
                SettingsItem(title: "Dark Mode", subtitle: "Enable dark appearance", type: .toggle, isOn: darkModeEnabled),
                SettingsItem(title: "Bold Text", subtitle: "Increase font weight", type: .toggle, isOn: boldTextEnabled),
                SettingsItem(title: "High Contrast", subtitle: "Increase contrast", type: .toggle, isOn: highContrastEnabled),
                SettingsItem(title: "Accent Color", subtitle: "Choose accent color", type: .navigation),
                SettingsItem(title: "Appearance", subtitle: "Customize app appearance", type: .navigation)
            ]),
            SettingsSection(title: "Notifications", icon: "bell", items: [
                SettingsItem(title: "Enable Notifications", subtitle: "Receive alerts for signals", type: .toggle, isOn: notificationsEnabled),
                SettingsItem(title: "Sound Alerts", subtitle: "Play sound for alerts", type: .toggle, isOn: soundEnabled),
                SettingsItem(title: "Haptic Feedback", subtitle: "Vibrate on notifications", type: .toggle, isOn: hapticsEnabled),
                SettingsItem(title: "Badge Count", subtitle: "Show badge on app icon", type: .toggle, isOn: true),
                SettingsItem(title: "Notification Style", subtitle: "Banners or Alerts", type: .navigation),
                SettingsItem(title: "Scheduled Summary", subtitle: "Daily digest of notifications", type: .toggle, isOn: false)
            ]),
            SettingsSection(title: "Accessibility", icon: "figure.stand", items: [
                SettingsItem(title: "Reduce Motion", subtitle: "Minimize animations", type: .toggle, isOn: reduceMotion),
                SettingsItem(title: "Reduce Transparency", subtitle: "Increase contrast", type: .toggle, isOn: reduceTransparency),
                SettingsItem(title: "VoiceOver", subtitle: "Screen reader support", type: .toggle, isOn: voiceOverEnabled),
                SettingsItem(title: "Dynamic Type", subtitle: "Adjust text size", type: .slider, value: "\(dynamicTypeSize)"),
                SettingsItem(title: "Zoom", subtitle: "Magnify content", type: .slider, value: "\(Int(accessibilityZoom * 100))%"),
                SettingsItem(title: "AssistiveTouch", subtitle: "Customizable gestures", type: .toggle, isOn: false),
                SettingsItem(title: "Switch Control", subtitle: "Navigate with switches", type: .toggle, isOn: false),
                SettingsItem(title: "Live Captions", subtitle: "Transcribe audio", type: .toggle, isOn: false),
                SettingsItem(title: "Sound Recognition", subtitle: "Identify sounds", type: .toggle, isOn: false)
            ]),
            SettingsSection(title: "Trading", icon: "chart.line.uptrend.xyaxis", items: [
                SettingsItem(title: "Risk Level", subtitle: "Adjust risk tolerance", type: .slider, value: "Level \(Int(riskLevel))"),
                SettingsItem(title: "Data Update Interval", subtitle: "Refresh frequency", type: .slider, value: "\(Int(updateInterval))s"),
                SettingsItem(title: "Auto-Trade", subtitle: "Enable automatic trading", type: .toggle, isOn: false),
                SettingsItem(title: "Paper Trading", subtitle: "Practice with simulated money", type: .toggle, isOn: true),
                SettingsItem(title: "Default Pair", subtitle: "EURUSD", type: .navigation),
                SettingsItem(title: "Default Timeframe", subtitle: "1 Hour", type: .navigation),
                SettingsItem(title: "Stop Loss", subtitle: "Auto-set stop loss", type: .toggle, isOn: true),
                SettingsItem(title: "Take Profit", subtitle: "Auto-set take profit", type: .toggle, isOn: true),
                SettingsItem(title: "Trailing Stop", subtitle: "Enable trailing stops", type: .toggle, isOn: false),
                SettingsItem(title: "Max Positions", subtitle: "Limit open positions", type: .slider, value: "5")
            ]),
            SettingsSection(title: "Privacy", icon: "lock.shield", items: [
                SettingsItem(title: "Screen Time", subtitle: "Monitor app usage", type: .toggle, isOn: screenTimeEnabled),
                SettingsItem(title: "Screen Time Limit", subtitle: "\(Int(screenTimeLimit / 60)) minutes", type: .slider),
                SettingsItem(title: "Parental Controls", subtitle: "Restrict content", type: .toggle, isOn: parentalControlsEnabled),
                SettingsItem(title: "Analytics", subtitle: "Share usage data", type: .toggle, isOn: analyticsEnabled),
                SettingsItem(title: "Crash Reports", subtitle: "Send crash data", type: .toggle, isOn: crashReportingEnabled),
                SettingsItem(title: "Personalized Ads", subtitle: "Ad personalization", type: .toggle, isOn: personalizedAdsEnabled),
                SettingsItem(title: "Data Sharing", subtitle: "Share with partners", type: .toggle, isOn: dataSharingEnabled)
            ]),
            SettingsSection(title: "Data", icon: "externaldrive.fill", items: [
                SettingsItem(title: "Auto Sync", subtitle: "Sync automatically", type: .toggle, isOn: autoSyncEnabled),
                SettingsItem(title: "Sync WiFi Only", subtitle: "Sync on WiFi only", type: .toggle, isOn: syncWiFiOnly),
                SettingsItem(title: "Sync Frequency", subtitle: "Every \(Int(syncFrequency)) hours", type: .slider),
                SettingsItem(title: "Background Refresh", subtitle: "Update in background", type: .toggle, isOn: backgroundAppRefresh),
                SettingsItem(title: "Low Power Mode", subtitle: "Reduce power usage", type: .toggle, isOn: lowPowerModeEnabled),
                SettingsItem(title: "Data Usage Warning", subtitle: "Warn at limit", type: .toggle, isOn: dataUsageWarningEnabled),
                SettingsItem(title: "Data Limit", subtitle: "\(Int(dataUsageLimit)) MB", type: .slider),
                SettingsItem(title: "Cache Size", subtitle: cacheSize, type: .info),
                SettingsItem(title: "Last Sync", subtitle: lastSyncDate, style: .date, type: .info),
                SettingsItem(title: "Clear Cache", subtitle: "Free up space", type: .action),
                SettingsItem(title: "Export Data", subtitle: "Download your data", type: .action)
            ]),
            SettingsSection(title: "Security", icon: "faceid", items: [
                SettingsItem(title: "Biometric Login", subtitle: "Use Face ID / Touch ID", type: .toggle, isOn: biometricEnabled),
                SettingsItem(title: "PIN Code", subtitle: "Require PIN on launch", type: .toggle, isOn: pinEnabled),
                SettingsItem(title: "Auto-Lock", subtitle: "Lock after inactivity", type: .toggle, isOn: autoLockEnabled),
                SettingsItem(title: "Auto-Lock Timeout", subtitle: "\(Int(autoLockTimeout / 60)) minutes", type: .slider),
                SettingsItem(title: "Two-Factor Auth", subtitle: "Extra security layer", type: .toggle, isOn: true),
                SettingsItem(title: "Login History", subtitle: "View recent logins", type: .navigation),
                SettingsItem(title: "Trusted Devices", subtitle: "Manage devices", type: .navigation)
            ]),
            SettingsSection(title: "About", icon: "info.circle", items: [
                SettingsItem(title: "Version", subtitle: "1.0.0", type: .info),
                SettingsItem(title: "Build", subtitle: "2026.08.17", type: .info),
                SettingsItem(title: "Framework", subtitle: "SwiftUI 5.9", type: .info),
                SettingsItem(title: "License", subtitle: "Proprietary", type: .navigation),
                SettingsItem(title: "Acknowledgments", subtitle: "Third-party libraries", type: .navigation),
                SettingsItem(title: "Check for Updates", subtitle: "Look for new versions", type: .action),
                SettingsItem(title: "Rate App", subtitle: "Leave a review", type: .action),
                SettingsItem(title: "Share App", subtitle: "Share with friends", type: .action)
            ]),
            SettingsSection(title: "Danger Zone", icon: "exclamationmark.triangle.fill", items: [
                SettingsItem(title: "Reset All Settings", subtitle: "Restore defaults", type: .action),
                SettingsItem(title: "Clear All Data", subtitle: "Delete everything", type: .action),
                SettingsItem(title: "Factory Reset", subtitle: "Erase all content", type: .action)
            ])
        ]

        if searchText.isEmpty {
            return allSections
        } else {
            return allSections.map { section in
                let filteredItems = section.items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                if filteredItems.isEmpty { return nil }
                return SettingsSection(title: section.title, icon: section.icon, items: filteredItems)
            }.compactMap { $0 }
        }
    }

    struct SettingsSection: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let items: [SettingsItem]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Customize your experience")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                    Divider().background(SystemFlyeTheme.line)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                        TextField("Search settings", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    LazyVStack(spacing: 0) {
                        ForEach(sections) { section in
                            settingsSectionView(section)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Settings Detail")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetAllSettings() }
            } message: { Text("This will reset all settings to their default values. This action cannot be undone.") }
            .alert("Export Data", isPresented: $showingExportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Export") { exportData() }
            } message: { Text("Export your data as a JSON file. This may take a moment.") }
        }
    }

    private func settingsSectionView(_ section: SettingsSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: section.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24)
                Text(section.title.uppercased()).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ForEach(section.items) { item in
                settingsItemView(item)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }

            Divider().background(SystemFlyeTheme.line)
        }
    }

    @ViewBuilder
    private func settingsItemView(_ item: SettingsItem) -> some View {
        Group {
            switch item.type {
            case .toggle:
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("", isOn: $item.isOn).labelsHidden().tint(SystemFlyeTheme.cyan)
            case .slider:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                        Text(item.value).font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                    }
                    Slider(value: .constant(0.5), in: 0...1).tint(SystemFlyeTheme.cyan)
                }
            case .picker:
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: .constant(item.value)) {
                        ForEach(themes, id: \.self) { option in Text(option).tag(option) }
                    }
                    .pickerStyle(.menu)
                    .tint(SystemFlyeTheme.cyan)
                }
            case .info:
                HStack {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(item.value).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
            case .action:
                Button {
                    if item.title.contains("Reset") { showingResetAlert = true }
                    else if item.title.contains("Export") { showingExportAlert = true }
                    else { print("Action: \(item.title)") }
                } label: {
                    HStack {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(item.title.contains("Clear") || item.title.contains("Reset") ? .red : SystemFlyeTheme.cyan)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            case .navigation:
                Button {
                    print("Navigate to \(item.title)")
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sizeLabel(for size: DynamicTypeSize) -> String {
        switch size {
        case .xSmall: return "XS"; case .small: return "S"; case .medium: return "M"; case .large: return "L"
        case .xLarge: return "XL"; case .xxLarge: return "XXL"; case .xxxLarge: return "XXXL"
        case .accessibility1: return "A1"; case .accessibility2: return "A2"; case .accessibility3: return "A3"
        case .accessibility4: return "A4"; case .accessibility5: return "A5"; default: return "L"
        }
    }

    private func resetAllSettings() {
        notificationsEnabled = true; hapticsEnabled = true; soundEnabled = true; selectedTheme = "Dark"
        riskLevel = 3.0; updateInterval = 2.0; reduceMotion = false; reduceTransparency = false
        voiceOverEnabled = false; accessibilityZoom = 1.0; boldTextEnabled = false; highContrastEnabled = false
        autoSyncEnabled = true; syncWiFiOnly = true; syncFrequency = 4.0; backgroundAppRefresh = true
        lowPowerModeEnabled = false; dataUsageWarningEnabled = true; dataUsageLimit = 500.0
        biometricEnabled = true; pinEnabled = false; autoLockEnabled = true; autoLockTimeout = 300.0
        analyticsEnabled = true; crashReportingEnabled = true; personalizedAdsEnabled = false; dataSharingEnabled = true
    }

    private func exportData() {
        print("Exporting data...")
    }
}

struct SettingsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDetailView().preferredColorScheme(.dark)
    }
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
