# SYSTEM FLYE

SYSTEM FLYE is a consolidated native SwiftUI iOS workspace combining market intelligence with a professional sound lab. The app uses a single `SYSTEMFLYEApp` entry point and switches between intelligence and sonic workspaces without duplicating app lifecycles.

## Open in Xcode

Create a new iOS App project named `SYSTEMFLYE` in Xcode, then add every Swift file in this directory and the `Resources` folder to the app target. Use iOS 17 or newer, set the bundle identifier to `com.systemflye.app`, and use `Info.plist` for microphone/audio permissions. The code intentionally keeps the existing API client injectable and falls back to deterministic demo data for previews and offline development.

## Included workspaces

- Market Intelligence: dashboard, analysis, signals, portfolio, and settings.
- Sound Lab: granular synthesizer, image-to-audio conversion, export, and local file management.
- Bundled WAV assets in `Resources/` for interface and synthesis workflows.
