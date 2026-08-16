import SwiftUI

@main
struct ForexAnalyzerApp: App {
    @StateObject private var marketDataManager = MarketDataManager()
    @StateObject private var portfolioManager = PortfolioManager()
    @StateObject private var signalGenerator = SignalGenerator()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // Dashboard
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .environmentObject(marketDataManager)
                    .environmentObject(signalGenerator)
                
                // Signals
                SignalsView()
                    .tabItem {
                        Label("Signals", systemImage: "bolt.fill")
                    }
                    .environmentObject(signalGenerator)
                    .environmentObject(marketDataManager)
                
                // Analysis
                AnalysisView()
                    .tabItem {
                        Label("Analysis", systemImage: "chart.bar.fill")
                    }
                    .environmentObject(marketDataManager)
                
                // Portfolio
                PortfolioView()
                    .tabItem {
                        Label("Portfolio", systemImage: "briefcase.fill")
                    }
                    .environmentObject(portfolioManager)
                    .environmentObject(marketDataManager)
                
                // Settings
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}
