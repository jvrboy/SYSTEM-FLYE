import Foundation
import Accelerate

// MARK: - Advanced Indicators Extension
// Adds 20+ advanced technical indicators beyond what's already in
// TechnicalAnalysisExpansion.swift. Each indicator is a pure function
// over a `[Double]` price (and volume where required) array, returning
// either a single value or a small struct.

public enum AdvancedIndicators {
    // MARK: - Volatility

    /// Choppiness Index (CHOP) — measures whether a market is trending or choppy.
    /// > 61.8 = choppy, < 38.2 = trending.
    public static func choppinessIndex(highs: [Double], lows: [Double], closes: [Double], period: Int = 14) -> Double {
        guard closes.count >= period, highs.count == lows.count, highs.count == closes.count else { return 50 }
        let sliceHi = highs.suffix(period)
        let sliceLo = lows.suffix(period)
        let trueRange = zip(sliceHi, sliceLo).map { $0 - $1 }
        let atrSum = trueRange.reduce(0, +)
        let highHigh = sliceHi.max() ?? 0
        let lowLow = sliceLo.min() ?? 0
        let range = highHigh - lowLow
        guard range > 0, atrSum > 0 else { return 50 }
        return 100 * log10(atrSum / range) / log10(Double(period))
    }

    /// Historical Volatility — annualised standard deviation of log returns.
    public static func historicalVolatility(closes: [Double], period: Int = 20, annualisationFactor: Double = 252) -> Double {
        guard closes.count > period else { return 0 }
        let returns = zip(closes.dropFirst(), closes.dropLast()).map { (later, earlier) in log(later / earlier) }
        let window = returns.suffix(period)
        let mean = window.reduce(0, +) / Double(window.count)
        let variance = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(window.count)
        return sqrt(variance * annualisationFactor)
    }

    /// Parkinson Volatility — uses intraday high-low range.
    public static func parkinsonVolatility(highs: [Double], lows: [Double], period: Int = 20) -> Double {
        guard highs.count == lows.count, highs.count >= period else { return 0 }
        let factor = 1.0 / (4.0 * log(2.0))
        let sum = zip(highs.suffix(period), lows.suffix(period))
            .map { log($0 / $1) * log($0 / $1) }
            .reduce(0, +)
        return sqrt(factor * sum / Double(period))
    }

    /// Garman-Klass Volatility — extension of Parkinson using OHLC.
    public static func garmanKlassVolatility(opens: [Double], highs: [Double], lows: [Double], closes: [Double], period: Int = 20) -> Double {
        guard opens.count == highs.count, highs.count == lows.count, lows.count == closes.count, closes.count >= period else { return 0 }
        var sum = 0.0
        let n = min(period, closes.count)
        let startIdx = closes.count - n
        for i in startIdx..<closes.count {
            let hl = log(highs[i] / lows[i])
            let co = log(closes[i] / opens[i])
            sum += 0.5 * hl * hl - (2 * log(2) - 1) * co * co
        }
        return sqrt(sum / Double(n))
    }

    // MARK: - Momentum

    /// Know Sure Thing (KST) — a summed smoothed-ROC oscillator.
    public static func knowSureThing(closes: [Double]) -> (kst: Double, signal: Double) {
        let roc1 = rateOfChange(closes: closes, period: 10)
        let roc2 = rateOfChange(closes: closes, period: 15)
        let roc3 = rateOfChange(closes: closes, period: 20)
        let roc4 = rateOfChange(closes: closes, period: 30)
        let kst = roc1 + 2 * roc2 + 3 * roc3 + 4 * roc4
        let signal = (kst + rateOfChange(closes: closes, period: 9)) / 2
        return (kst, signal)
    }

    /// Pretty Good Oscillator — distance of price from its SMA in ATR units.
    public static func prettyGoodOscillator(closes: [Double], highs: [Double], lows: [Double], period: Int = 14) -> Double {
        guard closes.count >= period else { return 0 }
        let sma = closes.suffix(period).reduce(0, +) / Double(period)
        let trueRanges = zip(zip(closes.dropFirst(), closes.dropLast()), zip(highs.dropFirst(), lows.dropFirst()))
            .map { ((h, l), (c, _)) in max(h - l, abs(h - c), abs(l - c)) }
        let atr = trueRanges.suffix(period - 1).reduce(0, +) / Double(period - 1)
        guard atr > 0 else { return 0 }
        return (closes.last! - sma) / atr
    }

    /// TSI (True Strength Index) — double-smoothed momentum.
    public static func trueStrengthIndex(closes: [Double], r: Int = 25, s: Int = 13) -> Double {
        guard closes.count > r + s else { return 0 }
        let m = zip(closes.dropFirst(), closes.dropLast()).map { $0 - $1 }
        let absM = m.map { abs($0) }
        let mEMA1 = emaSeries(m, period: r)
        let mEMA2 = emaSeries(mEMA1, period: s)
        let absEMA1 = emaSeries(absM, period: r)
        let absEMA2 = emaSeries(absEMA1, period: s)
        guard let lastAbs = absEMA2.last, lastAbs > 0 else { return 0 }
        return 100 * (mEMA2.last! / lastAbs)
    }

    /// Ultimate Oscillator (UO) — weighted average of 7/14/28-period averages.
    public static func ultimateOscillator(highs: [Double], lows: [Double], closes: [Double]) -> Double {
        guard highs.count == lows.count, highs.count == closes.count, closes.count >= 28 else { return 50 }
        let bp = zip(zip(closes.dropFirst(), lows.dropFirst()), lows.dropLast())
            .map { ((c, _), prevLow) in c - min(prevLow, lows[0]) }
        let tr = zip(zip(zip(highs.dropFirst(), lows.dropFirst()), closes.dropLast()), lows.dropFirst())
            .map { (((h, l), _), prevLow) in max(h - l, abs(h - prevLow), abs(l - prevLow)) }
        let avg7 = bp.suffix(7).reduce(0, +) / max(tr.suffix(7).reduce(0, +), 1e-9)
        let avg14 = bp.suffix(14).reduce(0, +) / max(tr.suffix(14).reduce(0, +), 1e-9)
        let avg28 = bp.suffix(28).reduce(0, +) / max(tr.suffix(28).reduce(0, +), 1e-9)
        return 100 * (4 * avg7 + 2 * avg14 + avg28) / 7
    }

    // MARK: - Volume

    /// Volume Oscillator (VO) — difference between fast and slow volume EMAs.
    public static func volumeOscillator(volumes: [Double], fast: Int = 5, slow: Int = 10) -> Double {
        guard volumes.count >= slow else { return 0 }
        let fastEMA = emaSeries(volumes, period: fast).last ?? 0
        let slowEMA = emaSeries(volumes, period: slow).last ?? 0
        guard slowEMA > 0 else { return 0 }
        return fastEMA - slowEMA
    }

    /// Negative Volume Index (NVI) — tracks smart-money accumulation on quiet days.
    public static func negativeVolumeIndex(closes: [Double], volumes: [Double]) -> Double {
        guard closes.count == volumes.count, closes.count > 1 else { return 1000 }
        var nvi = 1000.0
        for i in 1..<closes.count {
            if volumes[i] < volumes[i - 1] {
                let pctChange = (closes[i] - closes[i - 1]) / closes[i - 1]
                nvi += nvi * pctChange
            }
        }
        return nvi
    }

    /// Positive Volume Index (PVI) — tracks crowd activity on busy days.
    public static func positiveVolumeIndex(closes: [Double], volumes: [Double]) -> Double {
        guard closes.count == volumes.count, closes.count > 1 else { return 1000 }
        var pvi = 1000.0
        for i in 1..<closes.count {
            if volumes[i] > volumes[i - 1] {
                let pctChange = (closes[i] - closes[i - 1]) / closes[i - 1]
                pvi += pvi * pctChange
            }
        }
        return pvi
    }

    /// Chaikin Money Flow (CMF) — accumulation/distribution over N periods.
    public static func chaikinMoneyFlow(highs: [Double], lows: [Double], closes: [Double], volumes: [Double], period: Int = 20) -> Double {
        guard highs.count == lows.count, highs.count == closes.count, closes.count == volumes.count, closes.count >= period else { return 0 }
        var mfSum = 0.0
        var volSum = 0.0
        for i in (closes.count - period)..<closes.count {
            let range = highs[i] - lows[i]
            let mfm = range > 0 ? ((closes[i] - lows[i]) - (highs[i] - closes[i])) / range : 0
            mfSum += mfm * volumes[i]
            volSum += volumes[i]
        }
        guard volSum > 0 else { return 0 }
        return mfSum / volSum
    }

    // MARK: - Trend / Channels

    /// Linear Regression Slope — least-squares slope over the last `period` closes.
    public static func linearRegressionSlope(closes: [Double], period: Int = 20) -> Double {
        guard closes.count >= period else { return 0 }
        let n = Double(period)
        let xs = Array(0..<period).map { Double($0) }
        let ys = Array(closes.suffix(period))
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map { $0 * $1 }.reduce(0, +)
        let sumXX = xs.map { $0 * $0 }.reduce(0, +)
        let denom = (n * sumXX - sumX * sumX)
        guard denom > 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }

    /// Pearson Correlation Coefficient of price vs time — strength of trend.
    public static func trendCorrelation(closes: [Double], period: Int = 20) -> Double {
        guard closes.count >= period else { return 0 }
        let xs = Array(0..<period).map { Double($0) }
        let ys = Array(closes.suffix(period))
        let n = Double(period)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map { $0 * $1 }.reduce(0, +)
        let sumXX = xs.map { $0 * $0 }.reduce(0, +)
        let sumYY = ys.map { $0 * $0 }.reduce(0, +)
        let num = n * sumXY - sumX * sumY
        let den = sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY))
        guard den > 0 else { return 0 }
        return num / den
    }

    /// Hilbert Transform Trend Mode — simplified phase-rate-of-change classifier.
    public static func hilbertTrendMode(closes: [Double]) -> Bool {
        guard closes.count > 12 else { return false }
        let recent = closes.suffix(6)
        let earlier = closes.dropLast(6).suffix(6)
        let recentSlope = recent.last! - recent.first!
        let earlierSlope = earlier.last! - earlier.first!
        return abs(recentSlope) > abs(earlierSlope) * 1.2 && sign(recentSlope) == sign(earlierSlope)
    }

    // MARK: - Composite / Hybrid

    /// Awesome Oscillator — 5-period SMA minus 34-period SMA of median price.
    public static func awesomeOscillator(highs: [Double], lows: [Double]) -> Double {
        guard highs.count == lows.count, highs.count >= 34 else { return 0 }
        let medians = zip(highs, lows).map { ($0 + $1) / 2 }
        let fast = medians.suffix(5).reduce(0, +) / 5
        let slow = medians.suffix(34).reduce(0, +) / 34
        return fast - slow
    }

    /// Acceleration/Deceleration (AC) — AO minus its 5-period SMA.
    public static func accelerationDeceleration(highs: [Double], lows: [Double]) -> Double {
        guard highs.count == lows.count, highs.count >= 39 else { return 0 }
        let medians = Array(zip(highs, lows).map { ($0 + $1) / 2 })
        var ao: [Double] = []
        for i in 33..<medians.count {
            let fast = medians[(i - 4)...i].reduce(0, +) / 5
            let slow = medians[(i - 33)...i].reduce(0, +) / 34
            ao.append(fast - slow)
        }
        let aoSMA = ao.suffix(5).reduce(0, +) / 5
        return (ao.last ?? 0) - aoSMA
    }

    /// Vortex Indicator (+VI / -VI).
    public static func vortex(highs: [Double], lows: [Double], closes: [Double], period: Int = 14) -> (plusVI: Double, minusVI: Double) {
        guard highs.count == lows.count, highs.count == closes.count, closes.count > period else { return (1, 1) }
        var plusVM = 0.0
        var minusVM = 0.0
        var tr = 0.0
        for i in (closes.count - period)..<closes.count {
            let up = abs(highs[i] - lows[i - 1])
            let down = abs(lows[i] - highs[i - 1])
            plusVM += up
            minusVM += down
            tr += max(highs[i] - lows[i], abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1]))
        }
        guard tr > 0 else { return (1, 1) }
        return (plusVM / tr, minusVM / tr)
    }

    /// TTM Squeeze momentum — linear-regression value of mid-close over lookback.
    public static func squeezeMomentum(closes: [Double], highs: [Double], lows: [Double], period: Int = 20) -> Double {
        guard closes.count >= period + 1 else { return 0 }
        let midpoints = zip(highs, lows).map { ($0 + $1) / 2 }
        let series = Array(midpoints.suffix(period + 1))
        let avgX = (0...period).map { Double($0) }.reduce(0, +) / Double(period + 1)
        let avgY = series.reduce(0, +) / Double(period + 1)
        var num = 0.0
        var den = 0.0
        for i in 0...period {
            let dx = Double(i) - avgX
            num += dx * (series[i] - avgY)
            den += dx * dx
        }
        let slope = den > 0 ? num / den : 0
        let intercept = avgY - slope * avgX
        return slope * Double(period) + intercept - series.last!
    }

    /// Chande Kroll Stop — ATR-based trailing stop.
    public static func chandeKrollStop(highs: [Double], lows: [Double], closes: [Double], p: Int = 10, q: Int = 9, mult: Double = 1.0) -> (stopLong: Double, stopShort: Double) {
        guard closes.count > p + q else { return (0, 0) }
        let firstHighStop = highs.suffix(p).max() ?? 0
        let firstLowStop = lows.suffix(p).min() ?? 0
        let trs = zip(zip(highs.dropFirst(), lows.dropFirst()), closes.dropLast())
            .map { ((h, l), c) in max(h - l, abs(h - c), abs(l - c)) }
            .suffix(p)
            .reduce(0, +) / Double(p)
        let stopLong = firstLowStop - mult * trs
        let stopShort = firstHighStop + mult * trs
        return (stopLong, stopShort)
    }

    // MARK: - Statistical

    /// Z-Score of the latest close vs lookback mean and stddev.
    public static func zScore(closes: [Double], period: Int = 20) -> Double {
        guard closes.count >= period else { return 0 }
        let window = closes.suffix(period)
        let mean = window.reduce(0, +) / Double(period)
        let variance = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(period)
        let std = sqrt(variance)
        guard std > 0 else { return 0 }
        return (closes.last! - mean) / std
    }

    /// Skewness of returns over `period`.
    public static func skewness(closes: [Double], period: Int = 30) -> Double {
        guard closes.count > period else { return 0 }
        let returns = zip(closes.dropFirst(), closes.dropLast()).map { (l, e) in log(l / e) }.suffix(period)
        let n = Double(returns.count)
        let mean = returns.reduce(0, +) / n
        let m2 = returns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let m3 = returns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) * ($1 - mean) } / n
        guard m2 > 0 else { return 0 }
        return m3 / pow(m2, 1.5)
    }

    /// Kurtosis of returns over `period` (excess kurtosis).
    public static func kurtosis(closes: [Double], period: Int = 30) -> Double {
        guard closes.count > period else { return 0 }
        let returns = zip(closes.dropFirst(), closes.dropLast()).map { (l, e) in log(l / e) }.suffix(period)
        let n = Double(returns.count)
        let mean = returns.reduce(0, +) / n
        let m2 = returns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let m4 = returns.reduce(0) { $0 + pow($1 - mean, 4) } / n
        guard m2 > 0 else { return 0 }
        return m4 / (m2 * m2) - 3
    }

    /// Hurst Exponent estimate via rescaled range (simplified).
    public static func hurstExponent(closes: [Double], maxLag: Int = 20) -> Double {
        guard closes.count > maxLag else { return 0.5 }
        let logReturns = zip(closes.dropFirst(), closes.dropLast()).map { (l, e) in log(l / e) }
        var rs: [(Double, Double)] = []
        for lag in [2, 4, 8, 16] where lag <= maxLag {
            let window = logReturns.suffix(lag)
            let mean = window.reduce(0, +) / Double(lag)
            var cumDev = 0.0
            var maxDev = -Double.infinity
            var minDev = Double.infinity
            var sumSq = 0.0
            for v in window {
                cumDev += (v - mean)
                maxDev = max(maxDev, cumDev)
                minDev = min(minDev, cumDev)
                sumSq += (v - mean) * (v - mean)
            }
            let r = maxDev - minDev
            let s = sqrt(sumSq / Double(lag))
            if s > 0 {
                rs.append((log(Double(lag)), log(r / s)))
            }
        }
        guard rs.count >= 2 else { return 0.5 }
        let n = Double(rs.count)
        let sumX = rs.reduce(0) { $0 + $1.0 }
        let sumY = rs.reduce(0) { $0 + $1.1 }
        let sumXY = rs.reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = rs.reduce(0) { $0 + $1.0 * $1.0 }
        let denom = n * sumXX - sumX * sumX
        guard denom > 0 else { return 0.5 }
        return (n * sumXY - sumX * sumY) / denom
    }

    // MARK: - Helpers

    public static func rateOfChange(closes: [Double], period: Int) -> Double {
        guard closes.count > period else { return 0 }
        let past = closes[closes.count - 1 - period]
        guard past > 0 else { return 0 }
        return ((closes.last! - past) / past) * 100
    }

    /// Standard EMA series over a 0-indexed Double array.
    public static func emaSeries(_ values: [Double], period: Int) -> [Double] {
        guard values.count >= period, period > 0 else { return values.isEmpty ? [] : [values[0]] }
        let k = 2.0 / (Double(period) + 1)
        var ema: [Double] = [values.prefix(period).reduce(0, +) / Double(period)]
        for v in values.dropFirst(period) {
            ema.append(v * k + ema.last! * (1 - k))
        }
        return ema
    }
}

// MARK: - Advanced Indicator Bundle
// One-stop struct bundling every advanced indicator value for a single OHLCV
// snapshot. The Forex backend and UI consume this struct.

public struct AdvancedIndicatorBundle: Hashable, Codable, Sendable {
    public let choppinessIndex: Double
    public let historicalVolatility: Double
    public let parkinsonVolatility: Double
    public let garmanKlassVolatility: Double
    public let kst: Double
    public let kstSignal: Double
    public let pgo: Double
    public let tsi: Double
    public let ultimateOscillator: Double
    public let volumeOscillator: Double
    public let negativeVolumeIndex: Double
    public let positiveVolumeIndex: Double
    public let chaikinMoneyFlow: Double
    public let regressionSlope: Double
    public let trendCorrelation: Double
    public let isTrendMode: Bool
    public let awesomeOscillator: Double
    public let accelerationDeceleration: Double
    public let plusVI: Double
    public let minusVI: Double
    public let squeezeMomentum: Double
    public let stopLong: Double
    public let stopShort: Double
    public let zScore: Double
    public let skewness: Double
    public let kurtosis: Double
    public let hurstExponent: Double

    public static func compute(
        opens: [Double], highs: [Double], lows: [Double], closes: [Double], volumes: [Double]
    ) -> AdvancedIndicatorBundle {
        AdvancedIndicatorBundle(
            choppinessIndex: AdvancedIndicators.choppinessIndex(highs: highs, lows: lows, closes: closes),
            historicalVolatility: AdvancedIndicators.historicalVolatility(closes: closes),
            parkinsonVolatility: AdvancedIndicators.parkinsonVolatility(highs: highs, lows: lows),
            garmanKlassVolatility: AdvancedIndicators.garmanKlassVolatility(opens: opens, highs: highs, lows: lows, closes: closes),
            kst: AdvancedIndicators.knowSureThing(closes: closes).kst,
            kstSignal: AdvancedIndicators.knowSureThing(closes: closes).signal,
            pgo: AdvancedIndicators.prettyGoodOscillator(closes: closes, highs: highs, lows: lows),
            tsi: AdvancedIndicators.trueStrengthIndex(closes: closes),
            ultimateOscillator: AdvancedIndicators.ultimateOscillator(highs: highs, lows: lows, closes: closes),
            volumeOscillator: AdvancedIndicators.volumeOscillator(volumes: volumes),
            negativeVolumeIndex: AdvancedIndicators.negativeVolumeIndex(closes: closes, volumes: volumes),
            positiveVolumeIndex: AdvancedIndicators.positiveVolumeIndex(closes: closes, volumes: volumes),
            chaikinMoneyFlow: AdvancedIndicators.chaikinMoneyFlow(highs: highs, lows: lows, closes: closes, volumes: volumes),
            regressionSlope: AdvancedIndicators.linearRegressionSlope(closes: closes),
            trendCorrelation: AdvancedIndicators.trendCorrelation(closes: closes),
            isTrendMode: AdvancedIndicators.hilbertTrendMode(closes: closes),
            awesomeOscillator: AdvancedIndicators.awesomeOscillator(highs: highs, lows: lows),
            accelerationDeceleration: AdvancedIndicators.accelerationDeceleration(highs: highs, lows: lows),
            plusVI: AdvancedIndicators.vortex(highs: highs, lows: lows, closes: closes).plusVI,
            minusVI: AdvancedIndicators.vortex(highs: highs, lows: lows, closes: closes).minusVI,
            squeezeMomentum: AdvancedIndicators.squeezeMomentum(closes: closes, highs: highs, lows: lows),
            stopLong: AdvancedIndicators.chandeKrollStop(highs: highs, lows: lows, closes: closes).stopLong,
            stopShort: AdvancedIndicators.chandeKrollStop(highs: highs, lows: lows, closes: closes).stopShort,
            zScore: AdvancedIndicators.zScore(closes: closes),
            skewness: AdvancedIndicators.skewness(closes: closes),
            kurtosis: AdvancedIndicators.kurtosis(closes: closes),
            hurstExponent: AdvancedIndicators.hurstExponent(closes: closes)
        )
    }
}

// MARK: - Indicator Catalog Entry
// Lightweight metadata used by the indicator picker UI.

public struct AdvancedIndicatorCatalogEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let interpretation: String

    public init(id: String, name: String, category: String, description: String, interpretation: String) {
        self.id = id; self.name = name; self.category = category
        self.description = description; self.interpretation = interpretation
    }
}

public enum AdvancedIndicatorCatalog {
    public static let entries: [AdvancedIndicatorCatalogEntry] = [
        .init(id: "chop", name: "Choppiness Index", category: "Volatility",
              description: "Measures trendedness via ATR sum vs price range.",
              interpretation: ">61.8 choppy · <38.2 trending"),
        .init(id: "hv", name: "Historical Volatility", category: "Volatility",
              description: "Annualised stddev of log returns.",
              interpretation: "Higher = more volatile"),
        .init(id: "parkinson", name: "Parkinson Volatility", category: "Volatility",
              description: "Intraday high-low based volatility estimator.",
              interpretation: "Lower noise than close-to-close"),
        .init(id: "gk", name: "Garman-Klass Volatility", category: "Volatility",
              description: "OHLC-based volatility estimator.",
              interpretation: "Most efficient classic estimator"),
        .init(id: "kst", name: "Know Sure Thing", category: "Momentum",
              description: "Weighted sum of four ROC periods.",
              interpretation: "Bullish when KST > signal"),
        .init(id: "pgo", name: "Pretty Good Oscillator", category: "Momentum",
              description: "Price deviation from SMA in ATR units.",
              interpretation: "±3 = extreme"),
        .init(id: "tsi", name: "True Strength Index", category: "Momentum",
              description: "Double-smoothed momentum ratio.",
              interpretation: ">0 bullish · <0 bearish"),
        .init(id: "uo", name: "Ultimate Oscillator", category: "Momentum",
              description: "Weighted 7/14/28 buying-pressure average.",
              interpretation: ">70 overbought · <30 oversold"),
        .init(id: "vo", name: "Volume Oscillator", category: "Volume",
              description: "Fast EMA − slow EMA of volume.",
              interpretation: "Positive = volume expansion"),
        .init(id: "nvi", name: "Negative Volume Index", category: "Volume",
              description: "Tracks smart-money accumulation on quiet days.",
              interpretation: "Rising = smart money accumulating"),
        .init(id: "pvi", name: "Positive Volume Index", category: "Volume",
              description: "Tracks crowd activity on busy days.",
              interpretation: "Rising = crowd following"),
        .init(id: "cmf", name: "Chaikin Money Flow", category: "Volume",
              description: "Accumulation/distribution over N periods.",
              interpretation: ">0.05 accumulation · <−0.05 distribution"),
        .init(id: "lrs", name: "Linear Regression Slope", category: "Trend",
              description: "Least-squares slope of close vs time.",
              interpretation: ">0 uptrend · <0 downtrend"),
        .init(id: "tc", name: "Trend Correlation", category: "Trend",
              description: "Pearson r of price vs time.",
              interpretation: "|r|>0.7 strong trend"),
        .init(id: "ao", name: "Awesome Oscillator", category: "Composite",
              description: "5-SMA − 34-SMA of median price.",
              interpretation: "Saucer = trend continuation"),
        .init(id: "ac", name: "Acceleration/Deceleration", category: "Composite",
              description: "AO minus its 5-SMA.",
              interpretation: "Above 0 = accelerating"),
        .init(id: "vi", name: "Vortex Indicator", category: "Trend",
              description: "+VI and −VI directional movement.",
              interpretation: "+VI > −VI bullish"),
        .init(id: "sqz", name: "Squeeze Momentum", category: "Volatility",
              description: "Linear-regression value of mid-price.",
              interpretation: "Positive = bullish breakout bias"),
        .init(id: "cks", name: "Chande Kroll Stop", category: "Risk",
              description: "ATR-based trailing stop levels.",
              interpretation: "Long stop below price"),
        .init(id: "z", name: "Z-Score", category: "Statistical",
              description: "(close − mean) / stddev over window.",
              interpretation: "|z|>2 = mean-reversion candidate"),
        .init(id: "sk", name: "Skewness", category: "Statistical",
              description: "Third moment of return distribution.",
              interpretation: "Positive skew = fat right tail"),
        .init(id: "ku", name: "Kurtosis", category: "Statistical",
              description: "Fourth moment (excess) of returns.",
              interpretation: "High kurtosis = tail risk"),
        .init(id: "hurst", name: "Hurst Exponent", category: "Statistical",
              description: "Long-memory estimator via R/S analysis.",
              interpretation: ">0.5 trending · <0.5 mean-reverting"),
    ]
}
