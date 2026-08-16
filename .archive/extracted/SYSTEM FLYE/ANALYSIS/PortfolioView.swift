import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @EnvironmentObject var marketDataManager: MarketDataManager
    @State private var selectedTab: PortfolioTab = .overview
    
    enum PortfolioTab {
        case overview
        case openTrades
        case closedTrades
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portfolio")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text("Trading performance and positions")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Tabs
                    HStack(spacing: 8) {
                        TabButton(
                            title: "Overview",
                            isSelected: selectedTab == .overview,
                            action: { selectedTab = .overview }
                        )
                        
                        TabButton(
                            title: "Open Trades",
                            isSelected: selectedTab == .openTrades,
                            action: { selectedTab = .openTrades }
                        )
                        
                        TabButton(
                            title: "Closed Trades",
                            isSelected: selectedTab == .closedTrades,
                            action: { selectedTab = .closedTrades }
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Content
                    switch selectedTab {
                    case .overview:
                        OverviewTab()
                            .environmentObject(portfolioManager)
                    case .openTrades:
                        OpenTradesTab()
                            .environmentObject(portfolioManager)
                            .environmentObject(marketDataManager)
                    case .closedTrades:
                        ClosedTradesTab()
                            .environmentObject(portfolioManager)
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 14)
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

// MARK: - Overview Tab
struct OverviewTab: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Stats
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Total Balance",
                        value: String(format: "$%.2f", portfolioManager.portfolio.totalBalance),
                        icon: "wallet.pass.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Profit/Loss",
                        value: String(format: "$%.2f", portfolioManager.portfolio.totalProfit - portfolioManager.portfolio.totalLoss),
                        icon: "chart.line.uptrend.xyaxis",
                        color: (portfolioManager.portfolio.totalProfit - portfolioManager.portfolio.totalLoss) > 0 ? .green : .red
                    )
                }
                
                HStack(spacing: 12) {
                    StatCard(
                        title: "Total Profit",
                        value: String(format: "$%.2f", portfolioManager.portfolio.totalProfit),
                        icon: "plus.circle.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Total Loss",
                        value: String(format: "$%.2f", portfolioManager.portfolio.totalLoss),
                        icon: "minus.circle.fill",
                        color: .red
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
            
            // Margin Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Margin Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    MarginRow(
                        label: "Total Balance",
                        value: String(format: "$%.2f", portfolioManager.portfolio.totalBalance)
                    )
                    
                    MarginRow(
                        label: "Used Margin",
                        value: String(format: "$%.2f", portfolioManager.portfolio.usedMargin)
                    )
                    
                    MarginRow(
                        label: "Available Margin",
                        value: String(format: "$%.2f", portfolioManager.portfolio.availableMargin)
                    )
                    
                    MarginRow(
                        label: "Margin Usage",
                        value: String(format: "%.1f%%", portfolioManager.portfolio.marginUsagePercentage)
                    )
                }
                .padding(16)
                .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
            
            Divider()
                .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
            
            // Performance Metrics
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance Metrics")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 12) {
                    PerformanceCard(
                        title: "Win Rate",
                        value: String(format: "%.1f%%", portfolioManager.portfolio.winRate)
                    )
                    
                    PerformanceCard(
                        title: "Winning Trades",
                        value: "\(portfolioManager.winCount)"
                    )
                    
                    PerformanceCard(
                        title: "Losing Trades",
                        value: "\(portfolioManager.lossCount)"
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
            
            Divider()
                .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
            
            // Advanced Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("Advanced Statistics")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    MetricRowAdvanced(
                        label: "Average Win",
                        value: String(format: "$%.2f", portfolioManager.averageWinningTrade)
                    )
                    
                    MetricRowAdvanced(
                        label: "Average Loss",
                        value: String(format: "$%.2f", portfolioManager.averageLosingTrade)
                    )
                    
                    MetricRowAdvanced(
                        label: "Profit Factor",
                        value: String(format: "%.2f", portfolioManager.profitFactor)
                    )
                    
                    MetricRowAdvanced(
                        label: "Expected Value",
                        value: String(format: "$%.2f", portfolioManager.expectedValue)
                    )
                    
                    MetricRowAdvanced(
                        label: "Max Drawdown",
                        value: String(format: "%.2f%%", portfolioManager.maxDrawdown)
                    )
                }
                .padding(16)
                .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Open Trades Tab
struct OpenTradesTab: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @EnvironmentObject var marketDataManager: MarketDataManager
    
    var body: some View {
        VStack(spacing: 16) {
            if portfolioManager.openTrades.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.gray)
                    
                    Text("No Open Trades")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Your open positions will appear here")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 12) {
                    ForEach(portfolioManager.openTrades) { trade in
                        OpenTradeCard(trade: trade)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

struct OpenTradeCard: View {
    let trade: Trade
    
    var tradeColor: Color {
        trade.type == .buy ? Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)) : Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(trade.pairSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(trade.type.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tradeColor)
                            .cornerRadius(4)
                    }
                    
                    Text("Entry: \(formatDate(trade.entryDate))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.2f Lots", trade.quantity))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(String(format: "Entry: %.5f", trade.entryPrice))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Close Trade")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(tradeColor.opacity(0.3))
                        .cornerRadius(6)
                }
                
                Button(action: {}) {
                    Text("Edit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
                        .cornerRadius(6)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Closed Trades Tab
struct ClosedTradesTab: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    
    var body: some View {
        VStack(spacing: 16) {
            if portfolioManager.closedTrades.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.gray)
                    
                    Text("No Closed Trades")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Your trading history will appear here")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                .frame(maxHeight: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 12) {
                    ForEach(portfolioManager.closedTrades.reversed()) { trade in
                        ClosedTradeCard(trade: trade)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
}

struct ClosedTradeCard: View {
    let trade: Trade
    
    var tradeColor: Color {
        (trade.profitLoss ?? 0) > 0 ? Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)) : Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(trade.pairSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(trade.type.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tradeColor)
                            .cornerRadius(4)
                    }
                    
                    Text("Closed: \(formatDate(trade.exitDate ?? Date()))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let pnl = trade.profitLoss {
                        Text(String(format: "%+.2f", pnl))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(pnl > 0 ? .green : .red)
                    }
                    
                    if let pnlPercent = trade.pnlPercentage {
                        Text(String(format: "%+.2f%%", pnlPercent))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(pnlPercent > 0 ? .green : .red)
                    }
                }
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Entry:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    Text(String(format: "%.5f", trade.entryPrice))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Divider()
                
                HStack(spacing: 4) {
                    Text("Exit:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    Text(String(format: "%.5f", trade.exitPrice ?? 0))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(8)
    }
}

struct MarginRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

struct PerformanceCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(8)
    }
}

struct MetricRowAdvanced: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    PortfolioView()
        .environmentObject(PortfolioManager())
        .environmentObject(MarketDataManager())
}
