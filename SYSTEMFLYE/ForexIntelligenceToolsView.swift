import SwiftUI

struct ForexIntelligenceToolsView: View {
    @EnvironmentObject private var marketData: MarketDataManager
    @EnvironmentObject private var backend: ForexTradingBackend
    @EnvironmentObject private var news: NewsSentimentService
    @State private var status = "Intelligence pipeline ready"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("INTELLIGENCE PIPELINE").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.secondary); Spacer(); Text(status).font(.caption2).foregroundStyle(.cyan) }
            HStack(spacing: 8) {
                Button("Optimize strategy") {
                    guard let history = marketData.priceHistory["EURUSD"] else { status = "Need EUR/USD history"; return }
                    if let result = backend.optimizeStrategy(pair: "EURUSD", history: history) { status = "Best fitness \(String(format: "%.3f", result.best.fitness))" } else { status = "Need at least 100 candles" }
                }.buttonStyle(.borderedProminent).tint(.purple)
                Button("Fetch news tone") {
                    Task { if let snapshot = await news.fetch(pair: "EURUSD") { backend.lastNewsSentiment = snapshot; status = "Tone \(String(format: "%.2f", snapshot.score)) · \(snapshot.articleCount) articles" } }
                }.buttonStyle(.bordered).tint(.cyan)
                Button("Analyze hedges") {
                    let report = backend.calculateHedging(plans: backend.plans, pairDefinitions: marketData.popularPairs)
                    status = "Residual risk \(Int(report.residualRiskPercent))%"
                }.buttonStyle(.bordered).tint(.green)
            }
            if let optimization = backend.lastOptimization {
                infoRow(title: "Genetic optimizer", value: "\(optimization.generations) generations", detail: "Fast/slow \(optimization.best.genome.fastPeriod)/\(optimization.best.genome.slowPeriod) · fitness \(String(format: "%.3f", optimization.best.fitness))", tint: .purple)
            }
            if let metrics = backend.lastRiskMetrics {
                infoRow(title: "Risk-adjusted metrics", value: "Sortino \(String(format: "%.2f", metrics.sortino))", detail: "Calmar \(String(format: "%.2f", metrics.calmar)) · Sharpe \(String(format: "%.2f", metrics.sharpe)) · DD \(String(format: "%.2f%%", metrics.maxDrawdown * 100))", tint: .orange)
            }
            if let snapshot = news.snapshots["EURUSD"] {
                infoRow(title: "Live news sentiment", value: String(format: "%+.2f", snapshot.score), detail: "Bullish \(snapshot.bullishCount) · Bearish \(snapshot.bearishCount) · Neutral \(snapshot.neutralCount)", tint: snapshot.score >= 0 ? .green : .red)
            }
            if let hedge = backend.lastHedgingReport {
                infoRow(title: "Currency hedging", value: "\(hedge.recommendations.count) recommendations", detail: "Gross \(String(format: "%.0f", hedge.grossNotional)) · residual risk \(String(format: "%.1f%%", hedge.residualRiskPercent))", tint: .green)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func infoRow(title: String, value: String, detail: String, tint: Color) -> some View {
        HStack { VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption.weight(.semibold)); Text(detail).font(.caption2).foregroundStyle(.secondary) }; Spacer(); Text(value).font(.caption.monospacedDigit().weight(.bold)).foregroundStyle(tint) }
    }
}
