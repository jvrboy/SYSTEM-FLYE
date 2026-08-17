import Foundation
import Accelerate
import CoreML

// MARK: - Forecast Models
enum ForecastModelType: String, Codable, CaseIterable {
    case arima = "ARIMA"
    case sarima = "SARIMA"
    case exponentialSmoothing = "EXPONENTIAL_SMOOTHING"
    case holtWinters = "HOLT_WINTERS"
    case prophet = "PROPHET"
    case lstm = "LSTM"
    case transformer = "TRANSFORMER"
    case ensemble = "ENSEMBLE"
}

struct ForecastResult: Codable, Identifiable {
    let id = UUID()
    var modelType: ForecastModelType
    var predictions: [Double]
    var lowerBounds: [Double]
    var upperBounds: [Double]
    var timestamps: [Date]
    var confidenceLevel: Double
    var modelParameters: [String: Double]
    var accuracy: AccuracyMetrics
    var residuals: [Double]
    var featureImportance: [String: Double]
    var timestamp: Date

    struct AccuracyMetrics: Codable {
        let mae: Double
        let mse: Double
        let rmse: Double
        let mape: Double
        let smape: Double
        let rSquared: Double
        let mase: Double
        let bias: Double
        let theilsU: Double

        static let empty = AccuracyMetrics(mae: 0, mse: 0, rmse: 0, mape: 0, smape: 0, rSquared: 0, mase: 0, bias: 0, theilsU: 0)
    }

    init(modelType: ForecastModelType, predictions: [Double] = [], lowerBounds: [Double] = [], upperBounds: [Double] = [], timestamps: [Date] = [], confidenceLevel: Double = 0.95, modelParameters: [String: Double] = [:], accuracy: AccuracyMetrics = .empty, residuals: [Double] = [], featureImportance: [String: Double] = [:], timestamp: Date = Date()) {
        self.id = UUID()
        self.modelType = modelType
        self.predictions = predictions
        self.lowerBounds = lowerBounds
        self.upperBounds = upperBounds
        self.timestamps = timestamps
        self.confidenceLevel = confidenceLevel
        self.modelParameters = modelParameters
        self.accuracy = accuracy
        self.residuals = residuals
        self.featureImportance = featureImportance
        self.timestamp = timestamp
    }
}

struct EnsembleForecast: Codable, Identifiable {
    let id = UUID()
    var componentModels: [ForecastResult]
    var weights: [Double]
    var combinedPredictions: [Double]
    var combinedLowerBounds: [Double]
    var combinedUpperBounds: [Double]
    var diversityScore: Double
    var agreementScore: Double
    var timestamp: Date

    init(componentModels: [ForecastResult], weights: [Double] = [], combinedPredictions: [Double] = [], combinedLowerBounds: [Double] = [], combinedUpperBounds: [Double] = [], diversityScore: Double = 0, agreementScore: Double = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.componentModels = componentModels
        self.weights = weights
        self.combinedPredictions = combinedPredictions
        self.combinedLowerBounds = combinedLowerBounds
        self.combinedUpperBounds = combinedUpperBounds
        self.diversityScore = diversityScore
        self.agreementScore = agreementScore
        self.timestamp = timestamp
    }
}

// MARK: - Forecasting Engine
@MainActor
final class ForecastingEngine: ObservableObject {
    static let shared = ForecastingEngine()
    @Published private(set) var forecasts: [ForecastResult] = []
    @Published private(set) var ensembleForecasts: [EnsembleForecast] = []
    @Published private(set) var isForecasting = false
    private var cancellationToken: Task<Void, Never>?
    private let maxResults = 50

    func forecastARIMA(series: [Double], order: (p: Int, d: Int, q: Int), steps: Int = 30) async -> ForecastResult {
        guard !isForecasting else { return ForecastResult(modelType: .arima) }
        isForecasting = true
        defer { isForecasting = false }
        var differenced = series
        for _ in 0..<order.d { differenced = zip(differenced, differenced.dropFirst()).map { $1 - $0 } }
        let arParams = estimateAR(differenced, order: order.p)
        let maParams = estimateMA(differenced, order: order.q)
        let residuals = calculateResiduals(differenced, arParams: arParams, maParams: maParams)
        let predictions = generateARIMAPredictions(arParams: arParams, maParams: maParams, steps: steps, lastValues: Array(differenced.suffix(max(order.p, order.q))))
        let accuracy = calculateAccuracy(actuals: Array(series.suffix(steps)), predictions: Array(predictions.prefix(steps)))
        let confidenceIntervals = computeConfidenceIntervals(predictions: predictions, residuals: residuals, confidenceLevel: 0.95)
        let timestamps = (0..<steps).map { Calendar.current.date(byAdding: .day, value: $0, to: Date()) ?? Date() }
        let result = ForecastResult(modelType: .arima, predictions: predictions, lowerBounds: confidenceIntervals.lower, upperBounds: confidenceIntervals.upper, timestamps: timestamps, accuracy: accuracy, residuals: residuals, modelParameters: ["p": Double(order.p), "d": Double(order.d), "q": Double(order.q)])
        if forecasts.count >= maxResults { forecasts.removeFirst() }
        forecasts.append(result)
        return result
    }

    func forecastHoltWinters(series: [Double], seasonalPeriod: Int = 7, steps: Int = 30) async -> ForecastResult {
        guard series.count > seasonalPeriod * 2 else { return ForecastResult(modelType: .holtWinters) }
        let params = estimateHoltWintersParameters(series: series, seasonalPeriod: seasonalPeriod)
        let predictions = generateHoltWintersForecast(params: params, steps: steps, seasonalPeriod: seasonalPeriod)
        let accuracy = calculateAccuracy(actuals: Array(series.suffix(steps)), predictions: Array(predictions.prefix(steps)))
        let residuals = calculateResiduals(series, predictions: Array(predictions.prefix(series.count)))
        let confidenceIntervals = computeConfidenceIntervals(predictions: predictions, residuals: residuals, confidenceLevel: 0.95)
        let timestamps = (0..<steps).map { Calendar.current.date(byAdding: .day, value: $0, to: Date()) ?? Date() }
        return ForecastResult(modelType: .holtWinters, predictions: predictions, lowerBounds: confidenceIntervals.lower, upperBounds: confidenceIntervals.upper, timestamps: timestamps, accuracy: accuracy, residuals: residuals, modelParameters: ["alpha": params.alpha, "beta": params.beta, "gamma": params.gamma])
    }

    func forecastProphet(series: [Double], timestamps: [Date], steps: Int = 30) async -> ForecastResult {
        guard series.count > 10, series.count == timestamps.count else { return ForecastResult(modelType: .prophet) }
        let trend = estimateTrend(series: series)
        let seasonality = extractSeasonality(series: series, timestamps: timestamps)
        let holidayEffects: [Double] = []
        let predictions = generateProphetForecast(trend: trend, seasonality: seasonality, holidays: holidayEffects, steps: steps)
        let accuracy = calculateAccuracy(actuals: Array(series.suffix(steps)), predictions: Array(predictions.prefix(steps)))
        let residuals = calculateResiduals(series, predictions: Array(predictions.prefix(series.count)))
        let confidenceIntervals = computeConfidenceIntervals(predictions: predictions, residuals: residuals, confidenceLevel: 0.8)
        let futureTimestamps = (0..<steps).map { Calendar.current.date(byAdding: .day, value: $0 + 1, to: timestamps.last ?? Date()) ?? Date() }
        return ForecastResult(modelType: .prophet, predictions: predictions, lowerBounds: confidenceIntervals.lower, upperBounds: confidenceIntervals.upper, timestamps: futureTimestamps, accuracy: accuracy, residuals: residuals, modelParameters: ["trendStrength": trend.strength])
    }

    func createEnsemble(forecasts: [ForecastResult], method: EnsembleMethod = .weightedAverage) async -> EnsembleForecast {
        guard !forecasts.isEmpty else { return EnsembleForecast(componentModels: []) }
        let predictions = forecasts.map { $0.predictions }
        let maxLength = predictions.map { $0.count }.max() ?? 0
        let combined: [Double]
        let lowerBounds: [Double]
        let upperBounds: [Double]
        switch method {
        case .simpleAverage:
            combined = (0..<maxLength).map { index in predictions.map { $0.indices.contains(index) ? $0[index] : 0 }.reduce(0, +) / Double(max(1, forecasts.count)) }
        case .weightedAverage:
            let weights = calculateModelWeights(forecasts: forecasts)
            combined = (0..<maxLength).map { index in zip(predictions, weights).map { $0.indices.contains(index) ? $0[index] * $1 : 0 }.reduce(0, +) }
        case .median:
            combined = (0..<maxLength).map { index in predictions.map { $0.indices.contains(index) ? $0[index] : 0 }.sorted().mid() }
        case .trimmedMean:
            combined = (0..<maxLength).map { index in predictions.map { $0.indices.contains(index) ? $0[index] : 0 }.sorted().dropFirst(1).dropLast(1).reduce(0, +) / Double(max(1, forecasts.count - 2)) }
        }
        lowerBounds = combined.map { $0 * 0.9 }
        upperBounds = combined.map { $0 * 1.1 }
        let diversity = calculateDiversity(forecasts: forecasts)
        let agreement = calculateAgreement(forecasts: forecasts)
        let ensemble = EnsembleForecast(componentModels: forecasts, weights: Array(repeating: 1.0 / Double(forecasts.count), count: forecasts.count), combinedPredictions: combined, combinedLowerBounds: lowerBounds, combinedUpperBounds: upperBounds, diversityScore: diversity, agreementScore: agreement)
        self.ensembleForecasts.append(ensemble)
        return ensemble
    }

    private func estimateAR(_ series: [Double], order: Int) -> [Double] {
        guard order > 0, series.count > order else { return [] }
        var arParams = Array(repeating: 0.0, count: order)
        let n = series.count
        var autocov = Array(repeating: 0.0, count: order)
        for lag in 0..<order {
            for i in 0..<(n - lag) { autocov[lag] += series[i] * series[i + lag] }
            autocov[lag] /= Double(n - lag)
        }
        var r = autocov
        var a = Array(repeating: 0.0, count: order + 1)
        a[0] = 1.0
        for k in 1...order {
            var lambdaVal = r[k - 1]
            for j in 0..<(k - 1) { lambdaVal -= a[j] * r[k - 1 - j] }
            let kappa = lambdaVal / a[k - 1]
            for j in 1..<k { a[j] = a[j] - kappa * a[k - 1 - j] }
            a[k] = -kappa
        }
        arParams = Array(a[1...order])
        return arParams
    }

    private func estimateMA(_ series: [Double], order: Int) -> [Double] {
        guard order > 0, series.count > order else { return [] }
        return Array(repeating: 0.1, count: order)
    }

    private func calculateResiduals(_ series: [Double], arParams: [Double], maParams: [Double]) -> [Double] {
        guard !arParams.isEmpty else { return series }
        var residuals: [Double] = []
        for i in arParams.count..<series.count {
            var predicted = series[i - 1]
            for (lag, param) in arParams.enumerated() { predicted -= param * series[i - 1 - lag] }
            residuals.append(series[i] - predicted)
        }
        return residuals
    }

    private func generateARIMAPredictions(arParams: [Double], maParams: [Double], steps: Int, lastValues: [Double]) -> [Double] {
        var predictions: [Double] = []
        var history = lastValues
        for _ in 0..<steps {
            var prediction = history.last ?? 0
            for (lag, param) in arParams.enumerated() {
                let index = history.count - 1 - lag
                if index >= 0 { prediction -= param * history[index] }
            }
            for (lag, param) in maParams.enumerated() {
                let index = predictions.count - 1 - lag
                if index >= 0 { prediction += param * predictions[index] }
            }
            predictions.append(prediction)
            history.append(prediction)
        }
        return predictions
    }

    private func estimateHoltWintersParameters(series: [Double], seasonalPeriod: Int) -> (alpha: Double, beta: Double, gamma: Double, level: Double, trend: Double, seasonal: [Double]) {
        let alpha = 0.2
        let beta = 0.05
        let gamma = 0.3
        var level = series.prefix(seasonalPeriod).reduce(0, +) / Double(seasonalPeriod)
        var trend = (series.last! - series.first!) / Double(series.count - 1)
        var seasonal = (0..<seasonalPeriod).map { i in series[i] - level }
        return (alpha, beta, gamma, level, trend, seasonal)
    }

    private func generateHoltWintersForecast(params: (alpha: Double, beta: Double, gamma: Double, level: Double, trend: Double, seasonal: [Double]), steps: Int, seasonalPeriod: Int) -> [Double] {
        var predictions: [Double] = []
        var currentLevel = params.level
        var currentTrend = params.trend
        for step in 0..<steps {
            let seasonalIndex = step % seasonalPeriod
            let prediction = currentLevel + currentTrend + params.seasonal[seasonalIndex]
            predictions.append(prediction)
            currentLevel = params.alpha * (params.seasonal[seasonalIndex] - currentTrend) + (1 - params.alpha) * currentLevel
            currentTrend = params.beta * (currentLevel - params.level) + (1 - params.beta) * currentTrend
        }
        return predictions
    }

    private func estimateTrend(series: [Double]) -> (slope: Double, intercept: Double, strength: Double) {
        let n = Double(series.count)
        let meanX = (0..<series.count).map { Double($0) }.reduce(0, +) / n
        let meanY = series.reduce(0, +) / n
        var numerator = 0.0, denominator = 0.0
        for i in 0..<series.count {
            numerator += (Double(i) - meanX) * (series[i] - meanY)
            denominator += pow(Double(i) - meanX, 2)
        }
        let slope = denominator > 0 ? numerator / denominator : 0
        let intercept = meanY - slope * meanX
        let variance = series.map { pow($0 - meanY, 2) }.reduce(0, +) / n
        let explainedVariance = zip(series, (0..<series.count).map { slope * Double($0) + intercept }).map { pow($0 - $1, 2) }.reduce(0, +) / n
        let strength = variance > 0 ? max(0, 1 - explainedVariance / variance) : 0
        return (slope, intercept, strength)
    }

    private func extractSeasonality(series: [Double], timestamps: [Date]) -> [Double] {
        let calendar = Calendar.current
        var byDayOfWeek: [Int: [Double]] = [:]
        for (index, timestamp) in timestamps.enumerated() {
            let day = calendar.component(.weekday, from: timestamp)
            byDayOfWeek[day, default: []].append(series[index])
        }
        var seasonal: [Double] = Array(repeating: 0, count: 7)
        let overallMean = series.reduce(0, +) / Double(series.count)
        for (day, values) in byDayOfWeek {
            seasonal[day - 1] = values.reduce(0, +) / Double(values.count) - overallMean
        }
        return seasonal
    }

    private func generateProphetForecast(trend: (slope: Double, intercept: Double, strength: Double), seasonality: [Double], holidays: [Double], steps: Int) -> [Double] {
        return (0..<steps).map { step in
            let trendValue = trend.intercept + trend.slope * Double(series.count + step)
            let seasonalValue = seasonality[step % 7]
            return trendValue + seasonalValue
        }
    }

    private func calculateModelWeights(forecasts: [ForecastResult]) -> [Double] {
        let accuracies = forecasts.map { $0.accuracy.rSquared }
        let totalAccuracy = accuracies.reduce(0, +)
        return totalAccuracy > 0 ? accuracies.map { $0 / totalAccuracy } : Array(repeating: 1.0 / Double(forecasts.count), count: forecasts.count)
    }

    private func calculateDiversity(forecasts: [ForecastResult]) -> Double {
        guard forecasts.count > 1 else { return 0 }
        let predictions = forecasts.map { $0.predictions }
        let maxLength = predictions.map { $0.count }.max() ?? 0
        var totalCorrelation = 0.0
        var count = 0
        for i in 0..<forecasts.count {
            for j in i + 1..<forecasts.count {
                let p1 = Array(predictions[i].prefix(maxLength))
                let p2 = Array(predictions[j].prefix(maxLength))
                if p1.count == p2.count && p1.count > 1 {
                    totalCorrelation += pearsonCorrelation(p1, p2)
                    count += 1
                }
            }
        }
        return count > 0 ? 1.0 - abs(totalCorrelation / Double(count)) : 0
    }

    private func calculateAgreement(forecasts: [ForecastResult]) -> Double {
        guard forecasts.count > 1 else { return 1.0 }
        let predictions = forecasts.map { $0.predictions }
        let maxLength = predictions.map { $0.count }.max() ?? 0
        var totalAgreement = 0.0
        var count = 0
        for i in 0..<forecasts.count {
            for j in i + 1..<forecasts.count {
                let p1 = Array(predictions[i].prefix(maxLength))
                let p2 = Array(predictions[j].prefix(maxLength))
                if p1.count == p2.count && p1.count > 1 {
                    let diff = zip(p1, p2).map { abs($0 - $1) }.reduce(0, +) / Double(p1.count)
                    totalAgreement += 1.0 / (1.0 + diff)
                    count += 1
                }
            }
        }
        return count > 0 ? totalAgreement / Double(count) : 1.0
    }

    private func calculateAccuracy(actuals: [Double], predictions: [Double]) -> ForecastResult.AccuracyMetrics {
        guard actuals.count == predictions.count, actuals.count > 0 else { return .empty }
        let n = Double(actuals.count)
        let errors = zip(actuals, predictions).map { $0 - $1 }
        let mae = errors.map { abs($0) }.reduce(0, +) / n
        let mse = errors.map { $0 * $0 }.reduce(0, +) / n
        let rmse = sqrt(mse)
        let mape = zip(actuals, predictions).map { actuals, pred in actuals != 0 ? abs((actuals - pred) / actuals) : 0 }.reduce(0, +) / n * 100
        let smape = zip(actuals, predictions).map { abs(pred - actuals) / ((abs(pred) + abs(actuals)) / 2) }.reduce(0, +) / n * 100
        let meanActual = actuals.reduce(0, +) / n
        let ssTot = actuals.map { pow($0 - meanActual, 2) }.reduce(0, +)
        let ssRes = errors.map { $0 * $0 }.reduce(0, +)
        let rSquared = ssTot > 0 ? 1 - ssRes / ssTot : 0
        return ForecastResult.AccuracyMetrics(mae: mae, mse: mse, rmse: rmse, mape: mape, smape: smape, rSquared: rSquared, mase: 0, bias: errors.reduce(0, +) / n, theilsU: rmse / (sqrt(ssTot / n) + mae))
    }

    private func calculateResiduals(_ series: [Double], predictions: [Double]) -> [Double] {
        return zip(series, predictions).map { $0 - $1 }
    }

    private func computeConfidenceIntervals(predictions: [Double], residuals: [Double], confidenceLevel: Double) -> (lower: [Double], upper: [Double]) {
        let meanResidual = residuals.reduce(0, +) / Double(max(1, residuals.count))
        let stdResidual = sqrt(residuals.map { pow($0 - meanResidual, 2) }.reduce(0, +) / Double(max(1, residuals.count)))
        let zScore = confidenceLevel == 0.95 ? 1.96 : confidenceLevel == 0.99 ? 2.576 : 1.645
        let lower = predictions.map { $0 - zScore * stdResidual }
        let upper = predictions.map { $0 + zScore * stdResidual }
        return (lower, upper)
    }
}

enum EnsembleMethod: String, Codable, CaseIterable {
    case simpleAverage = "SIMPLE_AVERAGE"
    case weightedAverage = "WEIGHTED_AVERAGE"
    case median = "MEDIAN"
    case trimmedMean = "TRIMMED_MEAN"
    case stacking = "STACKING"
    case blending = "BLENDING"
}

extension Array where Element: Comparable {
    func mid() -> Element { sorted()[count / 2] }
}

private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
    guard x.count == y.count, x.count > 1 else { return 0 }
    let n = Double(x.count)
    let meanX = x.reduce(0, +) / n
    let meanY = y.reduce(0, +) / n
    var num = 0.0, denX = 0.0, denY = 0.0
    for i in 0..<x.count {
        let dx = x[i] - meanX
        let dy = y[i] - meanY
        num += dx * dy
        denX += dx * dx
        denY += dy * dy
    }
    let den = sqrt(max(0, denX * denY))
    return den == 0 ? 0 : num / den
}
