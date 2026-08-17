# SYSTEM FLYE

A production-grade SwiftUI iOS application combining **forex market intelligence**, **neural forecasting**, **multi-agent orchestration**, and **granular sound design** in a single dark-themed workspace.

## Build & Run

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation.

```bash
# Install XcodeGen (one time)
brew install xcodegen

# Generate the .xcodeproj
cd SYSTEM-FLYE
xcodegen generate

# Open in Xcode
open SYSTEMFLYE.xcodeproj
```

The project targets **iOS 17.0**, Swift 5.9, device family `1,2` (iPhone + iPad), and is unsigned (`CODE_SIGNING_ALLOWED: NO`) so it can be built via GitHub Actions / sideloaded.

## Architecture

The app has two top-level workspaces, switched via a segmented control in the header:

1. **Market Intelligence** — 8-tab workspace: Command Center · Agents · Pipelines · Forex · Neural · Tools · Expansion · Backend
2. **Sound Lab** — Synthesizer · Image-to-Audio · Export · Files

## Agents (30 total)

The orchestrator seeds **15 default agents** on launch and the advanced registry adds **15 more** extension agents:

| Default | Role |
|---|---|
| ORBIT | Market reconnaissance and regime mapping |
| MIXER | Generative sound design and scene building |
| SENTINEL | Portfolio risk and operational safety |
| CONDUCTOR | Pipeline orchestration and quality gates |
| CARTOGRAPHER | Macro context and session intelligence |
| ORACLE | News sentiment fusion and narrative radar |
| ATLAS | Cross-pair correlation and macro structure |
| NOVA | Neural training and model serving |
| HARBOR | Execution planning and slippage control |
| ZENITH | Portfolio optimisation and rebalancing |
| PULSE | Volatility surface and regime pulse |
| VECTOR | Latent embedding and similarity search |
| MIRAGE | Counterfactual scenario generator |
| SAGE | Expert rule system and policy advisor |
| BEACON | Anomaly radar and alert routing |

| Advanced Extension | Role |
|---|---|
| ECHO | Backtest replay and walk-forward verification |
| PRISM | Multi-timeframe confluence engine |
| NEXUS | Cross-venue order book fusion |
| TITAN | Deep-learning volatility forecaster |
| GLYPH | Pattern library curator |
| AURORA | News-driven regime classifier |
| DRIFT | Execution drift monitor |
| LATTICE | Multi-asset portfolio lattice |
| COBALT | Reinforcement learning trainer |
| ZEPHYR | Sentiment velocity tracker |
| QUARK | Microstructure analyser |
| OBSIDIAN | Dark-pool flow inference |
| HALO | Exogenous risk monitor (macro shocks) |
| VANTA | Generative strategy synthesiser |
| ATOLL | Safe-haven rotation engine |

Agents are dispatched via 6 load-balancing strategies: `roundRobin`, `leastLoaded`, `fastestResponse`, `capabilityMatch`, `weighted`, `predictive`. The orchestrator includes circuit breakers, failover policies, heartbeat monitors, and a metrics buffer.

## Indicators (50+)

In addition to the 30 basic + advanced indicators in `TechnicalAnalysisExpansion.swift`, the `AdvancedIndicatorsExtension.swift` module adds 23 more:

- **Volatility**: Choppiness Index, Historical Volatility, Parkinson, Garman-Klass
- **Momentum**: Know Sure Thing, Pretty Good Oscillator, True Strength Index, Ultimate Oscillator
- **Volume**: Volume Oscillator, Negative Volume Index, Positive Volume Index, Chaikin Money Flow
- **Trend**: Linear Regression Slope, Trend Correlation, Hilbert Trend Mode, Vortex
- **Composite**: Awesome Oscillator, Acceleration/Deceleration, Squeeze Momentum, Chande Kroll Stop
- **Statistical**: Z-Score, Skewness, Kurtosis, Hurst Exponent

## Advanced Tools (15)

`AdvancedToolsExtension.swift` adds 15 compute engines:

- ML Predictor (gradient-boosted trees)
- Sentiment Heatmap
- Volatility Surface (sticky-delta smile)
- Smart Execution Planner (TWAP/VWAP/POV)
- Regime Classifier (HMM-style)
- Anomaly Radar
- Reinforcement Trainer (Q-learning)
- Bayesian Direction Network
- Monte Carlo Path Generator
- Walk-Forward Optimiser
- Correlation Clusterer
- Stress Scenario Lab (2008 GFC, 2020 COVID, Dot-com 1994, Asia 1997, Rate Shock 1994)
- Latent Embedder (Johnson-Lindenstrauss random projection)
- Counterfactual Simulator
- News Narrative Summariser

## Backend

Three distinct backend layers:

- **`BackendServiceManager`** — 5 service registry (Market Data, Historical, Auth, Signal Engine, Offline Queue), 15-second health checks, cache manager with TTL.
- **`OperationalBackendStore`** — Wraps `BackendServiceManager` with `INITIALIZING / READY / DEGRADED / OFFLINE` state machine and audit event stream.
- **`ProductionStore`** — Atomic JSON persistence (`Application Support/SYSTEMFLYE/workspace.json`) with versioned `FlyeEnvelope<T>` Codable wrapper, schema migration, audit log (300-entry cap), diagnostics export.

## Fonts

11 custom open-source fonts ship in `Resources/Fonts/` and are registered in `Info.plist`:

Inter · JetBrains Mono · Space Grotesk · IBM Plex Sans · IBM Plex Mono · Spline Sans · Source Code Pro · Lora · Sora · Space Mono · Fira Code

The Font Catalog view (Expansion → Fonts) lists bundled fonts first, then all system fonts.

## App Icons

The asset catalog ships:
- 13 iPhone/iPad icon sizes (20×20 through 1024×1024)
- `AccentColor` colorset (cyan: `#33D3EE`)
- `BrandMark` imageset (used in Settings and share sheets)
- 4 decorative imagesets: `FlyeBurst`, `FlyePrism`, `FlyeLattice`, `FlyeAurora` (viewable in Expansion → Icons)

## Tests

Tests live under `SYSTEMFLYETests/`:
- `SYSTEMFLYETests.swift` — Technical indicator tests
- `AdvancedCoreTests.swift` — Core module tests
- `AdvancedAnalyticsTests.swift` — Analytics tests
- `BackendToolsTests.swift` — Backend tools tests
- `ProductionCoreTests.swift` — Persistence tests
- `AdvancedExtensionsTests.swift` — New advanced agents / indicators / tools tests

## File Layout

```
SYSTEM-FLYE/
├── project.yml                     # XcodeGen spec
├── SYSTEMFLYE/
│   ├── SYSTEMFLYEApp.swift          # @main entry point
│   ├── Models.swift                 # Core domain models
│   ├── AgentOrchestrator.swift      # Agent registry + dispatcher
│   ├── AdvancedAgentsRegistry.swift  # 15 new advanced agents  (new)
│   ├── AdvancedIndicatorsExtension.swift  # 23 new indicators  (new)
│   ├── AdvancedToolsExtension.swift       # 15 new tools  (new)
│   ├── AdvancedExtensionsView.swift       # UI for all new extensions  (new)
│   ├── FlyeCustomFonts.swift              # Custom font catalog  (new)
│   ├── SharedDetailComponents.swift       # Shared StatCard/ToggleRow  (new)
│   ├── BackendServiceManager.swift
│   ├── BackendOperationalCore.swift
│   ├── ProductionCore.swift
│   ├── FeaturePlatformCore.swift
│   ├── FeaturePlatformViews.swift    # Wires AdvancedExtensionsView into Expansion tab
│   ├── FontCatalogView.swift         # Lists bundled custom fonts first
│   ├── IconGalleryView.swift         # Shows FLYE brand assets section
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   ├── AppIcon.appiconset/   # 13 icon sizes (iPhone+iPad+marketing)
│   │   │   ├── AccentColor.colorset/ # Cyan accent
│   │   │   ├── BrandMark.imageset/   # Logo
│   │   │   ├── FlyeBurst.imageset/   # Decorative
│   │   │   ├── FlyePrism.imageset/   # Decorative
│   │   │   ├── FlyeLattice.imageset/ # Decorative
│   │   │   └── FlyeAurora.imageset/  # Decorative
│   │   ├── Fonts/                    # 11 .ttf custom fonts
│   │   └── *.wav                     # 11 audio UI sounds
│   └── *.swift                       # ~130 additional Swift modules
└── SYSTEMFLYETests/
    └── AdvancedExtensionsTests.swift # Tests for new advanced extensions  (new)
```

## License

Code: MIT.
Fonts: SIL Open Font License (OFL).
