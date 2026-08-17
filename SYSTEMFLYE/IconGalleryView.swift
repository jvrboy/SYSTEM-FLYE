import SwiftUI

struct IconGalleryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: IconCategory = .all
    @State private var selectedIcon: String?
    @State private var selectedSize: IconSize = .medium
    @State private var showExportSheet = false
    @State private var scale: CGFloat = 1.0
    @State private var favorites: Set<String> = []
    @State private var showFavorites = false
    @State private var backgroundColor: Color = .clear
    @State private var iconTint: Color = .white
    @State private var showIconDetails = false
    @State private var selectedTab: IconTab = .gallery
    @State private var recentIcons: [String] = []
    @State private var iconCollections: [IconCollection] = []
    @State private var downloadCounts: [String: Int] = [:]
    @State private var customCollections: [String: [String]] = [:]
    @State private var showCollections = false

    enum IconCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case communication = "Communication"
        case media = "Media"
        case maps = "Maps"
        case weather = "Weather"
        case objects = "Objects"
        case symbols = "Symbols"
        case glyphs = "Glyphs"
        var id: String { rawValue }
    }

    enum IconSize: String, CaseIterable {
        case small = "16x16"; case medium = "24x24"; case large = "32x32"; case xlarge = "64x64"
        var value: CGFloat { switch self { case .small: return 16; case .medium: return 24; case .large: return 32; case .xlarge: return 64 } }
    }

    enum IconTab: String, CaseIterable { case gallery = "Gallery"; case collections = "Collections"; case recent = "Recent"; case favorites = "Favorites" }

    struct IconCollection: Identifiable {
        let id = UUID()
        let name: String
        let icons: [String]
        let color: Color
    }

    var iconNames: [String] {
        let allIcons = [
            "airplane", "alarm", "alt", "ant", "antenna.rays", "app", "app.badge",
            "archivebox", "arkit", "atom", "battery.100", "bell", "bicycle", "binoculars",
            "bolt.fill", "book.fill", "brain.head.profile", "bubble.left.fill", "calendar",
            "camera.fill", "car.fill", "cart.fill", "checkmark.seal.fill", "circle.fill",
            "cloud.fill", "cpu", "crown.fill", "cube.fill", "deskclock.fill", "diamond.fill",
            "display", "drop.fill", "ear.fill", "ellipsis.bubble", "externaldrive.fill",
            "eye.fill", "flame.fill", "floppy-disk.fill", "gamecontroller.fill",
            "gear.circle.fill", "gift.fill", "globe", "graduationcap.fill", "heart.fill",
            "helm", "house.fill", "icloud.fill", "info.circle.fill", "key.fill",
            "leaf.fill", "lightbulb.fill", "link", "location.fill", "lock.fill",
            "mappin.circle.fill", "megaphone.fill", "mic.fill", "moon.fill", "music.note",
            "network", "nosign", "paintbrush.fill", "paperclip", "pencil.circle.fill",
            "phone.fill", "photo.fill", "pin.fill", "play.circle.fill", "plus.circle.fill",
            "power", "printer.fill", "questionmark.circle.fill", "quote.bubble",
            "recordingtape", "rosette", "safari.fill", "scissors", "scribble",
            "server.rack", "shield.fill", "shuffle", "sidebar.left", "signpost.right.fill",
            "slider.horizontal.3", "smoke.fill", "sparkles", "speaker.fill", "star.fill",
            "staroflife.fill", "sun.max.fill", "t.bubble.fill", "tag.fill", "target",
            "terminal.fill", "text.book.closed.fill", "textformat", "ticket.fill",
            "timer", "tornado", "tram.fill", "tray.fill", "tree", "umbrella.fill",
            "video.fill", "waveform.path", "wifi", "wrench.fill", "xmark.circle.fill"
        ]
        if searchText.isEmpty { return allIcons }
        return allIcons.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IconTab.allCases) { tab in
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab } }
                                label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.7)) }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
                HStack(spacing: 10) {
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showFavorites.toggle() } }
                        label: { Label(showFavorites ? "All Icons" : "Favorites", systemImage: showFavorites ? "list.bullet" : "star.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(showFavorites ? SystemFlyeTheme.cyan.opacity(0.15) : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(showFavorites ? SystemFlyeTheme.cyan : .white.opacity(0.7)) }
                    Spacer()
                    Picker("Size", selection: $selectedSize) { ForEach(IconSize.allCases) { size in Text(size.rawValue).tag(size) } }
                    .pickerStyle(.segmented).frame(width: 200)
                    Button { showExportSheet = true }
                        label: { Image(systemName: "square.and.arrow.up").font(.caption).foregroundStyle(SystemFlyeTheme.cyan) }
                        .buttonStyle(.bordered).tint(SystemFlyeTheme.cyan).sheet(isPresented: $showExportSheet) { exportView }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                tabContent
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Icon Gallery").navigationBarTitleDisplayMode(.inline)
            .onAppear { generateCollections(); generateRecentIcons() }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        VStack(spacing: 16) {
            switch selectedTab {
            case .gallery: iconGrid
            case .collections: collectionsView
            case .recent: recentView
            case .favorites: favoritesView
            }
            brandMarksSection
        }
    }

    private var brandMarksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FLYE BRAND ASSETS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    brandCard("BrandMark", named: "BrandMark")
                    brandCard("Burst",   named: "FlyeBurst")
                    brandCard("Prism",   named: "FlyePrism")
                    brandCard("Lattice", named: "FlyeLattice")
                    brandCard("Aurora",  named: "FlyeAurora")
                }
                .padding(.horizontal, 18).padding(.vertical, 8)
            }
        }
    }

    private func brandCard(_ label: String, named: String) -> some View {
        VStack(spacing: 6) {
            Image(named)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Text(label).font(.caption2.monospaced()).foregroundStyle(.secondary)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  I C O N S", title: "Gallery")
                Spacer()
                Label("\(iconNames.count)", systemImage: "square.grid.2x2").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                    .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search icons...", text: $searchText).textFieldStyle(.plain).foregroundStyle(.white)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
    }

    private var iconGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(iconNames, id: \.self) { icon in
                iconCell(icon).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedIcon = icon; showIconDetails = true } }
            }
        }
        .padding(.horizontal, 18)
    }

    private var collectionsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(iconCollections) { collection in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(collection.name).font(.headline.weight(.semibold)).foregroundStyle(.white)
                        Spacer()
                        Text("\(collection.icons.count) icons").font(.caption).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(collection.icons.prefix(10), id: \.self) { icon in
                                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(collection.color)
                                    .frame(width: 40, height: 40)
                                    .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
        .padding(.horizontal, 18)
    }

    private var recentView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if recentIcons.isEmpty {
                ContentUnavailableView("No Recent Icons", systemImage: "clock.fill") { Text("Icons you view will appear here.").font(.caption).foregroundStyle(.secondary) }.frame(height: 200)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(recentIcons, id: \.self) { icon in
                        iconCell(icon).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedIcon = icon } }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private var favoritesView: some View {
        let favs = iconNames.filter { favorites.contains($0) }
        return VStack(alignment: .leading, spacing: 14) {
            if favs.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star") { Text("Tap the star on any icon to add it here.").font(.caption).foregroundStyle(.secondary) }.frame(height: 200)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(favs, id: \.self) { icon in
                        iconCell(icon).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedIcon = icon } }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private func iconCell(_ icon: String) -> some View {
        let isFavorite = favorites.contains(icon)
        let isSelected = selectedIcon == icon
        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(isSelected ? SystemFlyeTheme.cyan.opacity(0.1) : SystemFlyeTheme.panel)
                RoundedRectangle(cornerRadius: 10).stroke(isSelected ? SystemFlyeTheme.cyan.opacity(0.4) : SystemFlyeTheme.line, lineWidth: isSelected ? 1.5 : 1)
                Image(systemName: icon).font(.system(size: selectedSize.value * scale)).foregroundStyle(iconTint)
                    .frame(width: selectedSize.value * 1.5, height: selectedSize.value * 1.5)
            }
            .frame(width: selectedSize.value * 2.5, height: selectedSize.value * 2.5)
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { if isFavorite { favorites.remove(icon) } else { favorites.insert(icon) } } }
                label: { Image(systemName: isFavorite ? "star.fill" : "star").font(.caption2).foregroundStyle(isFavorite ? .yellow : .secondary.opacity(0.4)) }
                .buttonStyle(.plain)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private func generateCollections() {
        iconCollections = [
            IconCollection(name: "Communication", icons: ["phone.fill", "message.fill", "envelope.fill", "bubble.left.fill", "video.fill", "mic.fill"], color: SystemFlyeTheme.cyan),
            IconCollection(name: "Media", icons: ["play.fill", "pause.fill", "stop.fill", "forward.fill", "backward.fill", "speaker.fill"], color: SystemFlyeTheme.violet),
            IconCollection(name: "Navigation", icons: ["location.fill", "mappin.circle.fill", "arrow.up.right", "arrow.down.right", "globe", "compass"], color: .green),
            IconCollection(name: "Weather", icons: ["sun.max.fill", "cloud.fill", "cloud.rain.fill", "snow", "tornado", "drop.fill"], color: .orange),
            IconCollection(name: "Objects", icons: ["key.fill", "lock.fill", "bell.fill", "house.fill", "cart.fill", "gift.fill"], color: .pink)
        ]
    }

    private func generateRecentIcons() {
        recentIcons = Array(iconNames.shuffled().prefix(20))
    }

    private var exportView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Icons").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Background").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach([Color.clear, .black, .white, SystemFlyeTheme.panel, SystemFlyeTheme.ink, SystemFlyeTheme.cyan], id: \.self) { color in
                            Circle().fill(color).frame(width: 32, height: 32).overlay(Circle().stroke(backgroundColor == color ? SystemFlyeTheme.cyan : Color.clear, lineWidth: 2))
                                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { backgroundColor = color } }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Icon Tint").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach([Color.white, .black, SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .red], id: \.self) { color in
                            Circle().fill(color).frame(width: 32, height: 32).overlay(Circle().stroke(iconTint == color ? SystemFlyeTheme.cyan : Color.clear, lineWidth: 2))
                                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { iconTint = color } }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scale").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Slider(value: $scale, in: 0.5...3.0, step: 0.1).tint(SystemFlyeTheme.cyan)
                    Text("\(Int(scale * 100))%").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Cancel") { showExportSheet = false }.buttonStyle(.bordered()).tint(.secondary)
                    Button("Export") { exportIcons(); showExportSheet = false }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                }
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }

    private func exportIcons() { print("Exporting \(iconNames.count) icons...") }
}

struct IconGalleryView_Previews: PreviewProvider {
    static var previews: some View { IconGalleryView().preferredColorScheme(.dark) }
}

