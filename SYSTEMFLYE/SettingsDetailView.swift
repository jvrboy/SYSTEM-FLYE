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

