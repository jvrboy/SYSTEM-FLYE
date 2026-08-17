import SwiftUI

@main
struct SYSTEMFLYEApp: App {
    @StateObject private var marketDataManager = MarketDataManager()
    @StateObject private var signalGenerator = SignalGenerator()
    @StateObject private var advancedStore = AdvancedStore()
    @StateObject private var analyticsEngine = AnalyticsEngine()
    @StateObject private var backendServiceManager = BackendServiceManager.shared
    @StateObject private var operationalBackend = OperationalBackendStore.shared
    @StateObject private var featurePlatform = FeaturePlatformStore.shared
    @StateObject private var forexTradingBackend = ForexTradingBackend.shared
    @StateObject private var apiClientManager = APIClientManager.shared
    @StateObject private var newsSentimentService = NewsSentimentService.shared
    @StateObject private var productionStore = ProductionStore()
    @State private var mode: FlyeMode = .intelligence

    var body: some Scene {
        WindowGroup {
            FlyeRootView(mode: $mode)
                .environmentObject(marketDataManager)
                .environmentObject(signalGenerator)
                .environmentObject(advancedStore)
                .environmentObject(analyticsEngine)
                .environmentObject(backendServiceManager)
                .environmentObject(operationalBackend)
                .environmentObject(featurePlatform)
                .environmentObject(forexTradingBackend)
                .environmentObject(apiClientManager)
                .environmentObject(newsSentimentService)
                .environmentObject(productionStore)
                .task {
                    operationalBackend.start()
                    newsSentimentService.startMonitoring(pairs: ["EURUSD", "GBPUSD", "USDJPY"], interval: 300)
                    await productionStore.restore()
                }
                .preferredColorScheme(.dark)
        }
    }
}

enum FlyeMode: String, CaseIterable, Identifiable {
    case intelligence = "Intelligence"
    case soundLab = "Sound Lab"
    var id: String { rawValue }
    var icon: String { self == .intelligence ? "chart.xyaxis.line" : "waveform" }
}

struct FlyeRootView: View {
    @Binding var mode: FlyeMode
    @State private var selectedMarketTab = 0

    var body: some View {
        ZStack {
            FlyeTheme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Picker("Workspace", selection: $mode) {
                    ForEach(FlyeMode.allCases) { item in
                        Label(item.rawValue, systemImage: item.icon).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Group {
                    if mode == .intelligence {
                        AdvancedDashboardView()
                    } else {
                        SoundLabView()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles.square.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(FlyeTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("SYSTEM FLYE").font(.system(size: 18, weight: .black, design: .rounded))
                Text(mode == .intelligence ? "MARKET INTELLIGENCE" : "SONIC INSTRUMENTS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(FlyeTheme.muted)
            }
            Spacer()
            Circle().fill(FlyeTheme.positive).frame(width: 8, height: 8)
                .accessibilityLabel("System online")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var marketTabs: some View {
        HStack(spacing: 0) {
            ForEach([("Overview", "square.grid.2x2"), ("Analysis", "waveform.path.ecg"), ("Signals", "bolt.fill"), ("Portfolio", "briefcase.fill"), ("Settings", "gearshape.fill")].indices, id: \.self) { index in
                Button { selectedMarketTab = index } label: {
                    VStack(spacing: 4) {
                        Image(systemName: ["square.grid.2x2", "waveform.path.ecg", "bolt.fill", "briefcase.fill", "gearshape.fill"][index])
                        Text(["Overview", "Analysis", "Signals", "Portfolio", "Settings"][index]).font(.caption2)
                    }
                    .frame(maxWidth: .infinity).foregroundStyle(selectedMarketTab == index ? FlyeTheme.accent : FlyeTheme.muted)
                }
                .accessibilityLabel(["Overview", "Analysis", "Signals", "Portfolio", "Settings"][index])
            }
        }
        .padding(.top, 12).padding(.bottom, 8).background(FlyeTheme.panel)
    }
}

enum FlyeTheme {
    static let canvas = Color(red: 0.035, green: 0.045, blue: 0.075)
    static let panel = Color(red: 0.075, green: 0.09, blue: 0.14)
    static let accent = Color(red: 0.26, green: 0.78, blue: 0.96)
    static let positive = Color(red: 0.30, green: 0.90, blue: 0.64)
    static let muted = Color(red: 0.48, green: 0.55, blue: 0.66)
}

#Preview {
    FlyeRootView(mode: .constant(.intelligence))
        .environmentObject(MarketDataManager())
        .environmentObject(SignalGenerator())
        .environmentObject(AdvancedStore())
        .environmentObject(AnalyticsEngine())
        .environmentObject(BackendServiceManager.shared)
        .environmentObject(OperationalBackendStore.shared)
        .environmentObject(FeaturePlatformStore.shared)
        .environmentObject(ForexTradingBackend.shared)
        .environmentObject(APIClientManager.shared)
        .environmentObject(NewsSentimentService.shared)
        .environmentObject(ProductionStore())
}
