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

