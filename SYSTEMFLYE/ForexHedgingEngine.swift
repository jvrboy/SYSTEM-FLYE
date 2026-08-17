import Foundation

struct CurrencyExposure: Codable, Equatable, Identifiable {
    let id: String
    let currency: String
    let notional: Double
    let normalizedExposure: Double
}

struct HedgeRecommendation: Codable, Equatable, Identifiable {
    let id: UUID
    let sourcePair: String
    let hedgePair: String
    let direction: SignalType
    let units: Double
    let currency: String
    let rationale: String
}

struct HedgingReport: Codable, Equatable {
    let exposures: [CurrencyExposure]
    let recommendations: [HedgeRecommendation]
    let grossNotional: Double
    let residualRiskPercent: Double
    let generatedAt: Date
}

enum ForexHedgingEngine {
    static func analyze(plans: [ForexTradePlan], pairDefinitions: [ForexPair], hedgeThreshold: Double = 0.15) -> HedgingReport {
        var net: [String: Double] = [:]
        var gross = 0.0
        var pairCurrencies: [String: (String, String)] = [:]
        for pair in pairDefinitions { pairCurrencies[pair.symbol] = (pair.baseCurrency, pair.quoteCurrency) }
        for plan in plans {
            guard let currencies = pairCurrencies[plan.pair] else { continue }
            let signedUnits = plan.direction == .buy ? plan.positionUnits : -plan.positionUnits
            net[currencies.0, default: 0] += signedUnits
            net[currencies.1, default: 0] -= signedUnits
            gross += abs(plan.positionUnits)
        }
        let exposures = net.keys.sorted().map { currency in CurrencyExposure(id: currency, currency: currency, notional: net[currency] ?? 0, normalizedExposure: gross > 0 ? (net[currency] ?? 0) / gross : 0) }
        let inverseMap = Dictionary(uniqueKeysWithValues: pairDefinitions.map { ("\($0.baseCurrency)\($0.quoteCurrency)", $0.symbol) })
        var recommendations: [HedgeRecommendation] = []
        for exposure in exposures where abs(exposure.normalizedExposure) >= hedgeThreshold {
            let desiredCurrency = exposure.normalizedExposure > 0 ? exposure.currency : nil
            guard let currency = desiredCurrency else { continue }
            let candidate = pairDefinitions.first { $0.quoteCurrency == currency } ?? pairDefinitions.first { $0.baseCurrency == currency }
            guard let hedge = candidate else { continue }
            let direction: SignalType = hedge.quoteCurrency == currency ? .buy : .sell
            let units = abs(exposure.notional) * 0.5
            recommendations.append(HedgeRecommendation(id: UUID(), sourcePair: "portfolio", hedgePair: hedge.symbol, direction: direction, units: units, currency: currency, rationale: "Offset \(String(format: "%.1f", abs(exposure.notional))) units of net \(currency) exposure."))
            _ = inverseMap
        }
        let residual = gross > 0 ? (exposures.map { abs($0.notional) }.max() ?? 0) / gross * 100 : 0
        return HedgingReport(exposures: exposures, recommendations: recommendations, grossNotional: gross, residualRiskPercent: residual, generatedAt: Date())
    }
}
