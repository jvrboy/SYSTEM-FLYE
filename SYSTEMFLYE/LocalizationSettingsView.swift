import SwiftUI

struct LocalizationSettingsView: View {
    @State private var selectedLanguage: String = "English"
    @State private var selectedRegion: String = "US"
    @State private var calendarType: CalendarType = .gregorian
    @State private var temperatureUnit: TemperatureUnit = .celsius
    @State private var distanceUnit: DistanceUnit = .kilometers
    @State private var currency: String = "USD"
    @State private var numberFormat: NumberFormat = .decimal
    @State private var dateFormat: DateFormat = .short
    @State private var timeFormat: TimeFormat = .twelveHour
    @State private var firstWeekday: Int = 2
    @State private var forceLeftToRight = false
    @State private var enableSpellCheck = true
    @State private var keyboardLanguage: String = "system"
    @State private var showingLanguagePicker = false
    @State private var showingRegionPicker = false
    @State private var installedLanguages: [LanguageInfo] = []
    @State private var activeTab: LocalizationTab = .language
    @State private var measurementSystem: MeasurementSystem = .metric
    @State private var paperSize: PaperSize = .a4
    @State private var decimalSeparator: String = "."
    @State private var thousandsSeparator: String = ","
    @State private var currencySymbolPosition: CurrencySymbolPosition = .before
    @State private var dateSeparator: String = "/"
    @State private var timeZone: String = "Local"
    @State private var automaticTimeZone = true
    @State private var twentyFourHourTime = false
    @State private var showWeekNumbers = false
    @State private var imperialSystemEnabled = false

    enum LocalizationTab: String, CaseIterable { case language = "Language"; case formats = "Formats"; case measurement = "Measurement"; case keyboard = "Keyboard" }

    enum CalendarType: String, CaseIterable, Identifiable {
        case gregorian = "Gregorian"; case buddhist = "Buddhist"; case islamic = "Islamic"; case hebrew = "Hebrew"; case japanese = "Japanese"; case republicOfChina = "Republic of China"
        var id: String { rawValue }
    }

    enum TemperatureUnit: String, CaseIterable, Identifiable {
        case celsius = "Celsius (°C)"; case fahrenheit = "Fahrenheit (°F)"; case kelvin = "Kelvin (K)"
        var id: String { rawValue }
    }

    enum DistanceUnit: String, CaseIterable, Identifiable {
        case kilometers = "Kilometers (km)"; case miles = "Miles (mi)"; case meters = "Meters (m)"
        var id: String { rawValue }
    }

    enum NumberFormat: String, CaseIterable { case decimal = "1,234.56"; case plain = "1234.56"; case grouping = "1 234,56"; case indian = "1,23,456.78" }
    enum DateFormat: String, CaseIterable { case short = "MM/DD/YYYY"; case medium = "MMM DD, YYYY"; case long = "MMMM DD, YYYY"; case iso = "YYYY-MM-DD" }
    enum TimeFormat: String, CaseIterable { case twelveHour = "12 Hour"; case twentyFourHour = "24 Hour" }
    enum MeasurementSystem: String, CaseIterable { case metric = "Metric"; case imperial = "Imperial"; case mixed = "Mixed" }
    enum PaperSize: String, CaseIterable { case a4 = "A4"; case letter = "Letter"; case legal = "Legal"; case a3 = "A3" }
    enum CurrencySymbolPosition: String, CaseIterable { case before = "Before"; case after = "After" }

    struct LanguageInfo: Identifiable {
        let id = UUID()
        let code: String
        let name: String
        let nativeName: String
        let isSystemDefault: Bool
        let isInstalled: Bool
        let icon: String
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Localization").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        Text("Language, region, and format preferences").font(.system(size: 14, weight: .regular)).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                    Divider().background(SystemFlyeTheme.line)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LocalizationTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .language: languageTab
                    case .formats: formatsTab
                    case .measurement: measurementTab
                    case .keyboard: keyboardTab
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Localization").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLanguagePicker) { languagePickerView }
            .sheet(isPresented: $showingRegionPicker) { regionPickerView }
            .onAppear { loadLanguages() }
        }
    }

    private var languageTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "globe").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("LANGUAGE & REGION").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("Language").font(.subheadline.weight(.semibold)).foregroundColor(.white); Text("Display language for the app").font(.caption).foregroundColor(.gray) }
                    Spacer()
                    Button { showingLanguagePicker = true } label: { HStack(spacing: 6) { Text(selectedLanguage).font(.subheadline.weight(.semibold)).foregroundStyle(SystemFlyeTheme.cyan); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("Region").font(.subheadline.weight(.semibold)).foregroundColor(.white); Text("Format for dates, numbers, and currency").font(.caption).foregroundColor(.gray) }
                    Spacer()
                    Button { showingRegionPicker = true } label: { HStack(spacing: 6) { Text(regionName(for: selectedRegion)).font(.subheadline.weight(.semibold)).foregroundStyle(SystemFlyeTheme.cyan); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("Keyboard Language").font(.subheadline.weight(.semibold)).foregroundColor(.white); Text("Preferred keyboard input language").font(.caption).foregroundColor(.gray) }
                    Spacer()
                    Picker("", selection: $keyboardLanguage) { Text("System Default").tag("system"); ForEach(installedLanguages, id: \.code) { Text("\($0.nativeName) (\($0.name))").tag($0.code) } }
                    .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("Force LTR").font(.subheadline.weight(.semibold)).foregroundColor(.white); Text("Force left-to-right text direction").font(.caption).foregroundColor(.gray) }
                    Spacer()
                    Toggle("", isOn: $forceLeftToRight).labelsHidden().tint(SystemFlyeTheme.cyan)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            Divider().background(SystemFlyeTheme.line)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "textformat").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("INSTALLED LANGUAGES").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                ForEach(installedLanguages) { lang in
                    HStack(spacing: 12) {
                        Text(lang.icon).font(.title2)
                        VStack(alignment: .leading, spacing: 2) { Text(lang.nativeName).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(lang.name).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        if selectedLanguage == lang.name { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 20)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedLanguage = lang.name; showingLanguagePicker = false } }
                }
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var formatsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "calendar").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("DATE & TIME").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Calendar Type").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $calendarType) { ForEach(CalendarType.allCases) { type in Text(type.rawValue).tag(type) } }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Date Format").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(DateFormat.allCases) { format in
                                Button { dateFormat = format } label: { Text(format.rawValue).font(.caption.monospacedDigit()).padding(.horizontal, 8).padding(.vertical, 4).background(dateFormat == format ? SystemFlyeTheme.cyan : Color.white.opacity(0.06), in: Capsule()).foregroundStyle(dateFormat == format ? .black : .white.opacity(0.7)) }.buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        Text("Time Format").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $timeFormat) { ForEach(TimeFormat.allCases) { format in Text(format.rawValue).tag(format) } }
                        .pickerStyle(.segmented).frame(width: 180)
                    }
                    HStack {
                        Text("First Day of Week").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $firstWeekday) { ForEach(1...7, id: \.self) { day in Text(weekdayName(day)).tag(day) } }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Show Week Numbers").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $showWeekNumbers).labelsHidden().tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Automatic Time Zone").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $automaticTimeZone).labelsHidden().tint(SystemFlyeTheme.cyan)
                    }
                    if !automaticTimeZone {
                        HStack {
                            Text("Time Zone").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $timeZone) { Text("UTC").tag("UTC"); Text("EST").tag("EST"); Text("PST").tag("PST"); Text("GMT").tag("GMT"); Text("CET").tag("CET") }
                            .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "number").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("NUMBERS").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Number Format").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $numberFormat) { ForEach(NumberFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Decimal Separator").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $decimalSeparator) { Text(".").tag("."); Text(",").tag(",") }
                        .pickerStyle(.segmented).frame(width: 80)
                    }
                    HStack {
                        Text("Thousands Separator").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $thousandsSeparator) { Text(",").tag(","); Text(" ").tag(" "); Text(".").tag(".") }
                        .pickerStyle(.segmented).frame(width: 120)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var measurementTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "ruler").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("UNITS & MEASUREMENTS").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Measurement System").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $measurementSystem) { ForEach(MeasurementSystem.allCases) { system in Text(system.rawValue).tag(system) } }
                        .pickerStyle(.segmented).frame(width: 200)
                    }
                    HStack {
                        Text("Temperature").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $temperatureUnit) { ForEach(TemperatureUnit.allCases) { unit in Text(unit.rawValue).tag(unit) } }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Distance").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $distanceUnit) { ForEach(DistanceUnit.allCases) { unit in Text(unit.rawValue).tag(unit) } }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Currency").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $currency) { Text("USD ($)").tag("USD"); Text("EUR (€)").tag("EUR"); Text("GBP (£)").tag("GBP"); Text("JPY (¥)").tag("JPY"); Text("CNY (¥)").tag("CNY") }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    HStack {
                        Text("Currency Symbol Position").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $currencySymbolPosition) { ForEach(CurrencySymbolPosition.allCases) { pos in Text(pos.rawValue).tag(pos) } }
                        .pickerStyle(.segmented).frame(width: 160)
                    }
                    HStack {
                        Text("Paper Size").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                        Spacer()
                        Picker("", selection: $paperSize) { ForEach(PaperSize.allCases) { size in Text(size.rawValue).tag(size) } }
                        .pickerStyle(.menu).tint(SystemFlyeTheme.cyan)
                    }
                    ToggleRow(title: "Imperial System", subtitle: "Enable imperial units", isOn: $imperialSystemEnabled)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private var keyboardTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) { Image(systemName: "keyboard").font(.system(size: 14, weight: .semibold)).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 24); Text("KEYBOARD & INPUT").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary) }.padding(.horizontal, 20).padding(.vertical, 12)
                VStack(spacing: 12) {
                    ToggleRow(title: "Spell Check", subtitle: "Check spelling as you type", isOn: $enableSpellCheck)
                    ToggleRow(title: "Auto-Capitalization", subtitle: "Automatically capitalize words", isOn: .constant(true))
                    ToggleRow(title: "Auto-Correction", subtitle: "Correct spelling automatically", isOn: .constant(true))
                    ToggleRow(title: "Check Spelling", subtitle: "Underline misspelled words", isOn: $enableSpellCheck)
                    ToggleRow(title: "Predictive Text", subtitle: "Show word suggestions", isOn: .constant(true))
                    ToggleRow(title: "Smart Punctuation", subtitle: "Automatically add punctuation", isOn: .constant(true))
                    ToggleRow(title: "." Shortcut", subtitle: "Double-space for period", isOn: .constant(true))
                    ToggleRow(title: "Enable Dictation", subtitle: "Voice input support", isOn: .constant(false))
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                Divider().background(SystemFlyeTheme.line)
            }
        }
    }

    private func loadLanguages() {
        installedLanguages = [
            LanguageInfo(code: "en", name: "English", nativeName: "English", isSystemDefault: true, isInstalled: true, icon: "🇺🇸"),
            LanguageInfo(code: "es", name: "Spanish", nativeName: "Español", isSystemDefault: false, isInstalled: true, icon: "🇪🇸"),
            LanguageInfo(code: "fr", name: "French", nativeName: "Français", isSystemDefault: false, isInstalled: true, icon: "🇫🇷"),
            LanguageInfo(code: "de", name: "German", nativeName: "Deutsch", isSystemDefault: false, isInstalled: true, icon: "🇩🇪"),
            LanguageInfo(code: "ja", name: "Japanese", nativeName: "日本語", isSystemDefault: false, isInstalled: true, icon: "🇯🇵"),
            LanguageInfo(code: "zh", name: "Chinese", nativeName: "中文", isSystemDefault: false, isInstalled: true, icon: "🇨🇳"),
            LanguageInfo(code: "ko", name: "Korean", nativeName: "한국어", isSystemDefault: false, isInstalled: true, icon: "🇰🇷"),
            LanguageInfo(code: "pt", name: "Portuguese", nativeName: "Português", isSystemDefault: false, isInstalled: true, icon: "🇧🇷"),
            LanguageInfo(code: "ru", name: "Russian", nativeName: "Русский", isSystemDefault: false, isInstalled: false, icon: "🇷🇺"),
            LanguageInfo(code: "ar", name: "Arabic", nativeName: "العربية", isSystemDefault: false, isInstalled: false, icon: "🇸🇦")
        ]
    }

    private func regionName(for code: String) -> String {
        switch code { case "US": return "United States"; case "UK": return "United Kingdom"; case "EU": return "Europe"; case "APAC": return "Asia Pacific"; case "LATAM": return "Latin America"; default: return code }
    }

    private func weekdayName(_ day: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[(day - 1) % 7]
    }

    private var languagePickerView: some View {
        NavigationStack {
            List(installedLanguages) { lang in
                HStack(spacing: 12) {
                    Text(lang.icon).font(.title2)
                    VStack(alignment: .leading, spacing: 2) { Text(lang.nativeName).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(lang.name).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if selectedLanguage == lang.name { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedLanguage = lang.name; showingLanguagePicker = false } }
            }
            .listStyle(.plain)
            .navigationTitle("Select Language").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingLanguagePicker = false } } }
        }
    }

    private var regionPickerView: some View {
        NavigationStack {
            List(["US", "UK", "EU", "APAC", "LATAM"], id: \.self) { region in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) { Text(regionName(for: region)).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(region).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if selectedRegion == region { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedRegion = region; showingRegionPicker = false } }
            }
            .listStyle(.plain)
            .navigationTitle("Select Region").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingRegionPicker = false } } }
        }
    }
}

struct LocalizationSettingsView_Previews: PreviewProvider {
    static var previews: some View { LocalizationSettingsView().preferredColorScheme(.dark) }
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
