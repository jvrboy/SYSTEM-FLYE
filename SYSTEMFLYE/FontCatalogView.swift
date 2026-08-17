import SwiftUI

struct FontCatalogView: View {
    @State private var searchText = ""
    @State private var selectedCategory: FontCategory = .sansSerif
    @State private var selectedFont: String = "SF Pro"
    @State private var fontSize: Double = 16
    @State private var fontWeight: Font.Weight = .regular
    @State private var showFavorites = false
    @State private var favoriteFonts: Set<String> = ["SF Pro", "SF Mono", "SF Compact"]
    @State private var previewText: String = "The quick brown fox jumps over the lazy dog"
    @State private var isEditing = false
    @State private var showingShareSheet = false
    @State private var showFontDetails = false
    @State private var sortOrder: SortOrder = .alphabetical
    @State private var selectedFontSizePreset: FontSizePreset = .medium
    @State private var lineHeight: Double = 1.4
    @State private var letterSpacing: Double = 0.0
    @State private var textAlignment: TextAlignment = .leading
    @State private var showGlyphGrid = false
    @State private var showVariableAxes = false
    @State private var fontWeights: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]

    enum FontCategory: String, CaseIterable, Identifiable {
        case sansSerif = "Sans Serif"; case serif = "Serif"; case monospaced = "Monospaced"; case display = "Display"; case handwriting = "Handwriting"; case rounded = "Rounded"
        var id: String { rawValue }
    }

    enum SortOrder: String, CaseIterable { case alphabetical = "A-Z"; case popularity = "Popularity"; case recent = "Recent" }

    enum FontSizePreset: String, CaseIterable { case small = "Small"; case medium = "Medium"; case large = "Large"; case extraLarge = "XL" }

    var filteredFonts: [String] {
        let allFonts = fontFamilies()
        if searchText.isEmpty { return allFonts }
        return allFonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FontCategory.allCases) { category in
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory = category } }
                                label: { Text(category.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedCategory == category ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedCategory == category ? .black : .white.opacity(0.7)) }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }

                HStack(spacing: 10) {
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showFavorites.toggle() } }
                        label: { Label(showFavorites ? "All Fonts" : "Favorites", systemImage: showFavorites ? "list.bullet" : "star.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(showFavorites ? SystemFlyeTheme.cyan.opacity(0.15) : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(showFavorites ? SystemFlyeTheme.cyan : .white.opacity(0.7)) }
                    Spacer()
                    Button { showingShareSheet = true }
                        label: { Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
                        .buttonStyle(.bordered).tint(SystemFlyeTheme.cyan)
                        .sheet(isPresented: $showingShareSheet) { ShareSheet(items: ["Font: \(selectedFont)\nSize: \(Int(fontSize))\nWeight: \(fontWeight)"]) }
                    Picker("", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { order in Text(order.rawValue).tag(order) }
                    }
                    .pickerStyle(.segmented).frame(width: 160)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                if showFavorites { favoritesView } else { fontCatalogView }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Font Catalog").navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  F O N T S", title: "Catalog")
                Spacer()
                Label("\(filteredFonts.count)", systemImage: "textformat").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                    .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search fonts...", text: $searchText).textFieldStyle(.plain).foregroundStyle(.white)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 12) {
                Text("PREVIEW").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Enter preview text...", text: $previewText, axis: .vertical)
                            .font(.custom(selectedFont, size: fontSize).weight(fontWeight))
                            .foregroundStyle(.white)
                            .lineLimit(3...6)
                        HStack(spacing: 8) {
                            ForEach(fontWeights, id: \.self) { weight in
                                Button { fontWeight = weight }
                                    label: { Text(weightName(weight)).font(.caption2).padding(.horizontal, 10).padding(.vertical, 6).background(fontWeight == weight ? SystemFlyeTheme.cyan : Color.white.opacity(0.06), in: Capsule()).foregroundStyle(fontWeight == weight ? .black : .white.opacity(0.7)) }
                            }
                        }
                        Slider(value: $fontSize, in: 8...72, step: 1).tint(SystemFlyeTheme.cyan)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Line Height").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $lineHeight, in: 1.0...2.5, step: 0.1).tint(SystemFlyeTheme.violet)
                                Text("\(String(format: "%.1f", lineHeight))").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Letter Spacing").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $letterSpacing, in: -0.5...0.5, step: 0.05).tint(SystemFlyeTheme.cyan)
                                Text("\(String(format: "%.2f", letterSpacing))").font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                            }
                        }
                        HStack {
                            ForEach(TextAlignment.allCases) { alignment in
                                Button { textAlignment = alignment }
                                    label: { Image(systemName: alignmentIcon(alignment)).font(.caption).foregroundStyle(textAlignment == alignment ? SystemFlyeTheme.cyan : .secondary) }
                                    .buttonStyle(.bordered).tint(textAlignment == alignment ? SystemFlyeTheme.cyan : .secondary)
                            }
                        }
                    }
                    .padding(16)
                }
                .frame(height: 220)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
        .padding(18)
    }

    enum TextAlignment: String, CaseIterable { case leading = "leading"; case center = "center"; case trailing = "trailing" }

    private func alignmentIcon(_ alignment: TextAlignment) -> String {
        switch alignment {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }

    private var fontCatalogView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredFonts) { font in
                fontCard(font)
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedFont = font; showFontDetails = true } }
            }
        }
        .padding(.horizontal, 18)
    }

    private var favoritesView: some View {
        let favs = filteredFonts.filter { favoriteFonts.contains($0) }
        return VStack(alignment: .leading, spacing: 14) {
            if favs.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star") { Text("Tap the star icon on any font to add it here.").font(.caption).foregroundStyle(.secondary) }.frame(height: 200)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(favs) { font in
                        fontCard(font).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedFont = font } }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private func fontCard(_ font: String) -> some View {
        let isFavorite = favoriteFonts.contains(font)
        let isSelected = selectedFont == font
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(font).font(.custom(font, size: 10)).foregroundStyle(.white)
                Spacer()
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { if isFavorite { favoriteFonts.remove(font) } else { favoriteFonts.insert(font) } } }
                    label: { Image(systemName: isFavorite ? "star.fill" : "star").font(.caption2).foregroundStyle(isFavorite ? .yellow : .secondary.opacity(0.4)) }
                    .buttonStyle(.plain)
            }
            Text(previewText.isEmpty ? "The quick brown fox" : previewText).font(.custom(font, size: 14)).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
            Text("\(Int.random(in: 100...9999)) glyphs").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? SystemFlyeTheme.cyan.opacity(0.08) : SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? SystemFlyeTheme.cyan.opacity(0.4) : SystemFlyeTheme.line))
    }

    /// Returns the merged list of (a) FLYE bundled custom fonts and (b) all
    /// system-installed font families. The bundled custom fonts are listed
    /// first so they're easy to find in the UI.
    private func fontFamilies() -> [String] {
        let bundled = FlyeCustomFonts.bundledFamilies
        let system = UIFont.familyNames.filter { !bundled.contains($0) }
        return (bundled + system.sorted())
    }
    private func weightName(_ weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight: return "UL"; case .thin: return "Th"; case .light: return "Lt"; case .regular: return "Rg"
        case .medium: return "Md"; case .semibold: return "Sb"; case .bold: return "Bd"; case .heavy: return "Hv"; case .black: return "Bk"
        default: return "Rg"
        }
    }
    private func category(for font: String) -> FontCategory {
        let descriptors = UIFont.fontNames(forFamilyName: font)
        let name = descriptors.first?.lowercased() ?? ""
        if name.contains("mono") || name.contains("courier") || name.contains("menlo") { return .monospaced }
        if name.contains("serif") || name.contains("georgia") || name.contains("times") { return .serif }
        if name.contains("hand") || name.contains("script") { return .handwriting }
        if name.contains("rounded") { return .rounded }
        if name.contains("display") { return .display }
        return .sansSerif
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}

struct FontCatalogView_Previews: PreviewProvider {
    static var previews: some View { FontCatalogView().preferredColorScheme(.dark) }
}

