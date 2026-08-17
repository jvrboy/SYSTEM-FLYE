import SwiftUI

// MARK: - FLYE Custom Fonts Catalog
// Registry of the 11 open-source fonts shipped with the app under
// Resources/Fonts/*.ttf (registered in Info.plist under UIAppFonts).
// The FontCatalogView lists these first so designers can find the
// bundled faces without scanning the full UIFont.familyNames dump.

public enum FlyeCustomFonts {
    /// (PostScript family name, friendly display name, file name, category)
    public static let bundled: [(postScript: String, display: String, file: String, category: String)] = [
        ("Inter",            "Inter",            "Inter.ttf",            "Sans Serif"),
        ("JetBrainsMono",    "JetBrains Mono",    "JetBrainsMono.ttf",    "Monospaced"),
        ("SpaceGrotesk",     "Space Grotesk",     "SpaceGrotesk.ttf",     "Display"),
        ("IBMPlexSans",      "IBM Plex Sans",     "IBMPlexSans.ttf",      "Sans Serif"),
        ("IBMPlexMono",      "IBM Plex Mono",     "IBMPlexMono.ttf",      "Monospaced"),
        ("SplineSans",       "Spline Sans",       "SplineSans.ttf",       "Sans Serif"),
        ("SourceCodePro",    "Source Code Pro",   "SourceCodePro.ttf",    "Monospaced"),
        ("Lora",             "Lora",              "Lora.ttf",             "Serif"),
        ("Sora",             "Sora",              "Sora.ttf",             "Display"),
        ("SpaceMono",        "Space Mono",        "SpaceMono.ttf",        "Monospaced"),
        ("FiraCode",         "Fira Code",         "FiraCode.ttf",         "Monospaced"),
    ]

    /// Family names — what FontCatalogView's picker uses.
    public static var bundledFamilies: [String] {
        bundled.map(\.display)
    }

    /// Resolve a friendly display name to the actual Font.custom name.
    public static func fontName(for display: String) -> String {
        bundled.first { $0.display == display }?.postScript ?? display
    }

    /// Build a SwiftUI Font for the given display name + size + weight.
    /// Falls back to the system font if the family is unknown.
    public static func font(display: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let postScript = fontName(for: display)
        if postScript == display {
            return .system(size: size, weight: weight)
        }
        return .custom(postScript, size: size).weight(weight)
    }

    /// Sample preview text per category so the gallery has interesting demo copy.
    public static func sampleText(for category: String) -> String {
        switch category {
        case "Sans Serif":   return "Flye market intelligence · neutral UI body"
        case "Serif":         return "Editorial long-read typography · narrative copy"
        case "Monospaced":   return "RSI 62.4 · MACD +0.0008 · ATR 0.0035"
        case "Display":      return "SYSTEM FLYE"
        case "Handwriting":  return "Quick annotations · personal sketch"
        case "Rounded":       return "Friendly callouts"
        default:             return "The quick brown fox jumps over the lazy dog"
        }
    }
}

// MARK: - Typography Presets
// Pre-baked type scale used by the dashboard's hero stat blocks. These
// provide consistent vertical rhythm without each call site having to
// compute its own font metrics.

public enum FlyeTypography {
    public static let hero    = Font.custom("SpaceGrotesk", size: 34).weight(.black)
    public static let title   = Font.custom("SpaceGrotesk", size: 22).weight(.bold)
    public static let body    = Font.custom("Inter", size: 14).weight(.regular)
    public static let caption = Font.custom("Inter", size: 11).weight(.medium)
    public static let mono    = Font.custom("JetBrainsMono", size: 12).weight(.regular)
    public static let metric  = Font.custom("JetBrainsMono", size: 18).weight(.semibold)
    public static let label   = Font.custom("Inter", size: 10).weight(.bold)
}
