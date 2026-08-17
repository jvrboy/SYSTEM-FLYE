import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var marketDataManager: MarketDataManager
    @EnvironmentObject var signalGenerator: SignalGenerator
    
    var body: some View {
        AnyView(NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Market Analysis")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(signalGenerator.totalSignals) Active Signals")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.green)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Real-time")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                        .cornerRadius(8)
                    }
                    .padding(20)
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Forex Pairs
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Major Pairs")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        VStack(spacing: 0) {
                            ForEach(marketDataManager.selectedPairs, id: \.self) { pair in
                                PairRowView(pair: pair)
                                    .environmentObject(marketDataManager)
                                    .environmentObject(signalGenerator)
                                
                                if pair != marketDataManager.selectedPairs.last {
                                    Divider()
                                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                                }
                            }
                        }
                        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                        .padding(.vertical, 20)
                    
                    // Top Signals
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Strong Signals")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(signalGenerator.strongSignals.count)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                        
                        if signalGenerator.strongSignals.isEmpty {
                            Text("No strong signals at the moment")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(signalGenerator.strongSignals.prefix(3)) { signal in
                                    SignalCompactView(signal: signal)
                                    
                                    if signal != signalGenerator.strongSignals.prefix(3).last {
                                        Divider()
                                            .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                                    }
                                }
                            }
                            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                        .padding(.vertical, 20)
                    
                    // Market Statistics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 12) {
                            StatBox(
                                title: "Win Rate",
                                value: String(format: "%.1f%%", signalGenerator.winRate),
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            StatBox(
                                title: "Total Signals",
                                value: "\(signalGenerator.signalHistory.count)",
                                icon: "bolt.fill",
                                color: .blue
                            )
                            
                            StatBox(
                                title: "Market Pairs",
                                value: "\(marketDataManager.selectedPairs.count)",
                                icon: "globe",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
            .navigationTitle("Forex Analyzer")
        })
    }
}

struct PairRowView: View {
    let pair: String
    @EnvironmentObject var marketDataManager: MarketDataManager
    @EnvironmentObject var signalGenerator: SignalGenerator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pair)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let analysis = marketDataManager.marketAnalysis[pair] {
                        Text(analysis.condition.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let price = marketDataManager.currentPrices[pair] {
                        Text(String(format: "%.5f", price))
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    if let indicators = marketDataManager.technicalIndicators[pair] {
                        HStack(spacing: 8) {
                            RSIBadge(rsi: indicators.rsi)
                            MACDBadge(macd: indicators.macd)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct RSIBadge: View {
    let rsi: Double
    
    var rsiColor: Color {
        if rsi > 70 {
            return Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
        } else if rsi < 30 {
            return Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1))
        } else {
            return .gray
        }
    }
    
    var body: some View {
        Text(String(format: "RSI %.0f", rsi))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(rsiColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
            .cornerRadius(4)
    }
}

struct MACDBadge: View {
    let macd: TechnicalIndicators.MACDValue
    
    var macdColor: Color {
        return macd.histogram > 0 ? Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)) : Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
    }
    
    var body: some View {
        Text(macd.histogram > 0 ? "▲" : "▼")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(macdColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
            .cornerRadius(4)
    }
}

struct SignalCompactView: View {
    let signal: TradingSignal
    
    var signalColor: Color {
        signal.signalType == .buy ? Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)) : Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 0) {
                Image(systemName: signal.signalType == .buy ? "arrow.up" : "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)
            .background(signalColor)
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(signal.pairSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(signal.signalType.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signalColor)
                        .cornerRadius(3)
                }
                
                Text(String(format: "Entry: %.5f | R:R: %.2f", signal.entryPrice, signal.riskRewardRatio))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", signal.confidence))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(signalColor)
                
                Text(signal.strength.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
        .environmentObject(MarketDataManager())
        .environmentObject(SignalGenerator())
}
