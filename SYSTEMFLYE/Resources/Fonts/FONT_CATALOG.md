# SYSTEM FLYE Custom Font Catalog

These fonts ship with the app and are registered in Info.plist under
`UIAppFonts` (or ATSApplicationFontsPath on macOS).

## Included fonts
- **Inter** (variable) — UI body text, default for FLYE typography
- **JetBrains Mono** — numerics, code, log streams
- **Space Grotesk** — display headings
- **IBM Plex Sans** — alternative UI body
- **IBM Plex Mono** — alternative monospace
- **Spline Sans** — accessibility-friendly high-contrast body
- **Source Code Pro** — code blocks in docs
- **Lora** — serif body for editorial copy

## Adding fonts
1. Place the `.ttf` or `.otf` files in this directory.
2. Add the file name to `UIAppFonts` array in `SYSTEMFLYE/Info.plist`.
3. Reference via `Font.custom("Inter-Regular", size: 14)` in views.

## License
All included fonts are licensed under the SIL Open Font License (OFL).
