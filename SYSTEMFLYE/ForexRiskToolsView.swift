import SwiftUI

struct ForexRiskToolsView: View {
    @EnvironmentObject private var marketData: MarketDataManager
    @EnvironmentObject private var backend: ForexTradingBackend
    @State private var correlationLimit = 0.75
    @State private var accountBalance = 10_000.0
    @State private var status = "Risk analytics ready"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RISK & VALIDATION LAB").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                Text(status).font(.caption2).foregroundStyle(.cyan)
            }
            HStack(spacing: 10) {
                Button("Walk-forward EUR/USD") {
                    guard let history = marketData.priceHistory["EURUSD"] else { status = "Need EUR/USD history"; return }
                    if let result = backend.walkForward(pair: "EURUSD", history: history) { status = "OOS \(Int(result.winRate * 100))% · stability \(Int(result.stabilityScore * 100))%" } else { status = "Need more history" }
                }
                .buttonStyle(.borderedProminent).tint(.purple)
                Button("Scan correlations") {
                    let histories = marketData.priceHistory.filter { marketData.selectedPairs.contains($0.key) }
                    let report = backend.correlationReport(histories: histories, limit: correlationLimit)
                    status = report.isWithinLimit ? "Correlation limits passed" : "High correlation: \(report.highestPair ?? "pair")"
                }
                .buttonStyle(.bordered).tint(.cyan)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Max pair correlation"); Spacer(); Text("\(Int(correlationLimit * 100))%").foregroundStyle(.cyan) }
                Slider(value: $correlationLimit, in: 0.4...0.95, step: 0.05).tint(.cyan)
                HStack { Text("Account balance"); Spacer(); Text(String(format: "$%.0f", accountBalance)).foregroundStyle(.cyan) }
                Slider(value: $accountBalance, in: 1000...1_000_000, step: 1000).tint(.green)
            }
            if let result = backend.lastWalkForward {
                riskRow(title: "Walk-forward", value: "\(result.totalTrades) trades · \(Int(result.winRate * 100))% win", detail: "OOS return \(String(format: "%.5f", result.outOfSampleReturn)) · DD \(String(format: "%.5f", result.maxDrawdown))", tint: .purple)
            }
            if let report = backend.lastCorrelationReport {
                riskRow(title: "Correlation matrix", value: report.isWithinLimit ? "PASS" : "BLOCK", detail: "Highest \(report.highestPair ?? "none") · \(Int(report.highestCorrelation * 100))%", tint: report.isWithinLimit ? .green : .red)
            }
            if let gate = backend.lastPortfolioRiskGate {
                riskRow(title: "Portfolio risk gate", value: gate.approved ? "APPROVED" : "BLOCKED", detail: gate.messages.first ?? "", tint: gate.approved ? .green : .red)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func riskRow(title: String, value: String, detail: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption.weight(.semibold)); Text(detail).font(.caption2).foregroundStyle(.secondary) }
            Spacer()
            Text(value).font(.caption.monospacedDigit().weight(.bold)).foregroundStyle(tint)
        }
    }
}
