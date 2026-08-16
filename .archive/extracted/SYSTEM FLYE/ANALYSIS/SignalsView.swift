import SwiftUI

struct SignalsView: View {
    @EnvironmentObject var signalGenerator: SignalGenerator
    @EnvironmentObject var marketDataManager: MarketDataManager
    @State private var selectedFilter: SignalFilter = .active
    
    enum SignalFilter {
        case active
        case buy
        case sell
        case history
    }
    
    var filteredSignals: [TradingSignal] {
        switch selectedFilter {
        case .active:
            return signalGenerator.activeSignals
        case .buy:
            return signalGenerator.activeSignals.filter { $0.signalType == .buy }
        case .sell:
            return signalGenerator.activeSignals.filter { $0.signalType == .sell }
        case .history:
            return signalGenerator.signalHistory.suffix(20).reversed()
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trading Signals")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    
                    Text("Real-time trading signals based on technical analysis")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                
                Divider()
                    .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                
                // Filter Tabs
                HStack(spacing: 8) {
                    FilterTab(title: "Active", isSelected: selectedFilter == .active) {
                        selectedFilter = .active
                    }
                    
                    FilterTab(title: "Buy", isSelected: selectedFilter == .buy) {
                        selectedFilter = .buy
                    }
                    
                    FilterTab(title: "Sell", isSelected: selectedFilter == .sell) {
                        selectedFilter = .sell
                    }
                    
                    FilterTab(title: "History", isSelected: selectedFilter == .history) {
                        selectedFilter = .history
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                
                // Signals List
                if filteredSignals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.slash.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.gray)
                        
                        Text("No signals")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("No \(selectedFilter == .history ? "historical" : "active") signals at the moment")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(40)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredSignals) { signal in
                                SignalDetailCard(signal: signal)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color(UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 0.3)) : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color(UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 0.6)) : Color.clear, lineWidth: 1)
                )
        }
    }
}

struct SignalDetailCard: View {
    let signal: TradingSignal
    @State private var isExpanded = false
    
    var signalColor: Color {
        signal.signalType == .buy ? Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)) : Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
    }
    
    var strengthColor: Color {
        switch signal.strength {
        case .strong:
            return signalColor
        case .moderate:
            return Color(UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1))
        case .weak:
            return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 0) {
                    Image(systemName: signal.signalType == .buy ? "arrow.up" : "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .background(signalColor)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(signal.pairSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(signal.signalType.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(signalColor)
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 8) {
                        Text(signal.strength.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(strengthColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
                            .cornerRadius(4)
                        
                        Text(formatTime(signal.timestamp))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", signal.confidence))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(signalColor)
                    
                    Text("Confidence")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                Divider()
                    .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                
                VStack(alignment: .leading, spacing: 16) {
                    // Price Levels
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price Levels")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        PriceLevelRow(label: "Entry", price: signal.entryPrice, color: .blue)
                        PriceLevelRow(label: "Take Profit", price: signal.takeProfit, color: .green)
                        PriceLevelRow(label: "Stop Loss", price: signal.stopLoss, color: .red)
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Risk Metrics
                    HStack(spacing: 16) {
                        MetricBox(
                            label: "Risk:Reward",
                            value: String(format: "1:%.2f", signal.riskRewardRatio),
                            icon: "scalemass"
                        )
                        
                        MetricBox(
                            label: "Distance",
                            value: String(format: "%.2f TP / %.2f SL", 
                                signal.takeProfit - signal.entryPrice,
                                signal.entryPrice - signal.stopLoss),
                            icon: "ruler"
                        )
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Indicators
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Triggered By")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(signal.indicators, id: \.self) { indicator in
                                Text(indicator)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(signalColor.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(signal.reason)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                Text("Execute")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(signalColor)
                            .cornerRadius(6)
                        }
                        
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle")
                                Text("Dismiss")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct PriceLevelRow: View {
    let label: String
    let price: Double
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6)
                
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "%.5f", price))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

struct MetricBox: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
        .cornerRadius(6)
    }
}

struct FlowLayout: View {
    let spacing: CGFloat
    let content: [String]
    
    init(spacing: CGFloat = 8, @ViewBuilder _ content: () -> some View) {
        self.spacing = spacing
        self.content = []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // Placeholder
            EmptyView()
        }
    }
}

extension FlowLayout {
    init(spacing: CGFloat, @ArrayBuilder _ content: @escaping () -> [String]) {
        self.spacing = spacing
        self.content = content()
    }
}

@resultBuilder
struct ArrayBuilder {
    static func buildBlock(_ components: String...) -> [String] {
        components
    }
}

#Preview {
    SignalsView()
        .environmentObject(SignalGenerator())
        .environmentObject(MarketDataManager())
}
