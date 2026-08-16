import Foundation
import Combine

@MainActor
class PortfolioManager: ObservableObject {
    @Published var portfolio: Portfolio = Portfolio(
        totalBalance: 10000,
        usedMargin: 2000,
        availableMargin: 8000,
        totalProfit: 1500,
        totalLoss: 300,
        winRate: 65
    )
    
    @Published var openTrades: [Trade] = []
    @Published var closedTrades: [Trade] = []
    @Published var selectedTrade: Trade?
    
    init() {
        loadMockTrades()
    }
    
    // MARK: - Trade Management
    func addTrade(pair: String, type: SignalType, entryPrice: Double, quantity: Double) {
        let trade = Trade(
            id: UUID(),
            pairSymbol: pair,
            type: type,
            entryPrice: entryPrice,
            exitPrice: nil,
            quantity: quantity,
            entryDate: Date(),
            exitDate: nil,
            profitLoss: nil,
            status: .open
        )
        
        openTrades.append(trade)
        updateMargin(quantity: quantity, price: entryPrice)
    }
    
    func closeTrade(_ trade: Trade, atPrice exitPrice: Double) {
        guard let index = openTrades.firstIndex(where: { $0.id == trade.id }) else { return }
        
        var closedTrade = trade
        closedTrade.exitPrice = exitPrice
        closedTrade.exitDate = Date()
        closedTrade.status = .closed
        
        let profitLoss = trade.type == .buy ?
            (exitPrice - trade.entryPrice) * trade.quantity :
            (trade.entryPrice - exitPrice) * trade.quantity
        
        closedTrade.profitLoss = profitLoss
        
        openTrades.remove(at: index)
        closedTrades.append(closedTrade)
        
        // Update portfolio
        if profitLoss > 0 {
            portfolio.totalProfit += profitLoss
        } else {
            portfolio.totalLoss += abs(profitLoss)
        }
        
        updateMargin(quantity: -trade.quantity, price: exitPrice)
    }
    
    func updateMargin(quantity: Double, price: Double) {
        let marginRequired = (quantity * price * 0.02) // 2% margin requirement
        portfolio.usedMargin += marginRequired
        portfolio.availableMargin = portfolio.totalBalance - portfolio.usedMargin
    }
    
    // MARK: - Statistics
    var totalOpenPL: Double {
        openTrades.reduce(0) { total, trade in
            // This would need current prices to calculate properly
            total
        }
    }
    
    var closedTradesCount: Int {
        closedTrades.count
    }
    
    var winCount: Int {
        closedTrades.filter { ($0.profitLoss ?? 0) > 0 }.count
    }
    
    var lossCount: Int {
        closedTrades.filter { ($0.profitLoss ?? 0) < 0 }.count
    }
    
    var averageWinningTrade: Double {
        let winningTrades = closedTrades.filter { ($0.profitLoss ?? 0) > 0 }
        guard !winningTrades.isEmpty else { return 0 }
        return winningTrades.map { $0.profitLoss ?? 0 }.reduce(0, +) / Double(winningTrades.count)
    }
    
    var averageLosingTrade: Double {
        let losingTrades = closedTrades.filter { ($0.profitLoss ?? 0) < 0 }
        guard !losingTrades.isEmpty else { return 0 }
        return losingTrades.map { $0.profitLoss ?? 0 }.reduce(0, +) / Double(losingTrades.count)
    }
    
    var profitFactor: Double {
        let totalWins = closedTrades.filter { ($0.profitLoss ?? 0) > 0 }.map { $0.profitLoss ?? 0 }.reduce(0, +)
        let totalLosses = abs(closedTrades.filter { ($0.profitLoss ?? 0) < 0 }.map { $0.profitLoss ?? 0 }.reduce(0, +))
        
        guard totalLosses > 0 else { return totalWins > 0 ? 10.0 : 0 }
        return totalWins / totalLosses
    }
    
    var expectedValue: Double {
        guard !closedTrades.isEmpty else { return 0 }
        let winRate = Double(winCount) / Double(closedTrades.count)
        return (winRate * averageWinningTrade) + ((1 - winRate) * averageLosingTrade)
    }
    
    var maxDrawdown: Double {
        var peak = portfolio.totalBalance
        var maxDD = 0.0
        var balance = portfolio.totalBalance
        
        for trade in closedTrades {
            if let pnl = trade.profitLoss {
                balance += pnl
                if balance > peak {
                    peak = balance
                } else {
                    let dd = (peak - balance) / peak
                    maxDD = max(maxDD, dd)
                }
            }
        }
        
        return maxDD * 100
    }
    
    // MARK: - Mock Data
    private func loadMockTrades() {
        let pairs = ["EURUSD", "GBPUSD", "USDJPY"]
        
        for i in 0..<8 {
            let pair = pairs[i % pairs.count]
            let type: SignalType = i % 2 == 0 ? .buy : .sell
            let entryPrice = Double.random(in: 0.9...2.0)
            let exitPrice = entryPrice + Double.random(in: -0.02...0.02)
            let quantity = Double.random(in: 1...5)
            
            let pnl = type == .buy ?
                (exitPrice - entryPrice) * quantity :
                (entryPrice - exitPrice) * quantity
            
            let trade = Trade(
                id: UUID(),
                pairSymbol: pair,
                type: type,
                entryPrice: entryPrice,
                exitPrice: exitPrice,
                quantity: quantity,
                entryDate: Date(timeIntervalSinceNow: TimeInterval(-i * 86400)),
                exitDate: Date(timeIntervalSinceNow: TimeInterval(-i * 86400 + 3600)),
                profitLoss: pnl,
                status: .closed
            )
            
            closedTrades.append(trade)
        }
        
        // Add some open trades
        for i in 0..<3 {
            let pair = pairs[i % pairs.count]
            let type: SignalType = i % 2 == 0 ? .buy : .sell
            let entryPrice = Double.random(in: 0.9...2.0)
            let quantity = Double.random(in: 1...3)
            
            let trade = Trade(
                id: UUID(),
                pairSymbol: pair,
                type: type,
                entryPrice: entryPrice,
                exitPrice: nil,
                quantity: quantity,
                entryDate: Date(),
                exitDate: nil,
                profitLoss: nil,
                status: .open
            )
            
            openTrades.append(trade)
        }
    }
}
