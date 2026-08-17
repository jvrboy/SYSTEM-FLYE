import Foundation

struct AdvancedTechnicalIndicators: Codable, Equatable {
    let adx: Double
    let plusDI: Double
    let minusDI: Double
    let cci: Double
    let williamsR: Double
    let roc: Double
    let obv: Double
    let vwap: Double
    let keltnerUpper: Double
    let keltnerMiddle: Double
    let keltnerLower: Double
    let ichimokuConversion: Double
    let ichimokuBase: Double
    let ichimokuLeadingA: Double
    let ichimokuLeadingB: Double
    let pivotPoint: Double
    let pivotR1: Double
    let pivotS1: Double
    let pivotR2: Double
    let pivotS2: Double
    let fibonacciRetracement382: Double
    let fibonacciRetracement618: Double
    let trendStrength: Double
    let signalScore: Double
    let superTrend: Double
    let mfi: Double
    let trix: Double
    let aroonUp: Double
    let aroonDown: Double
    let donchianUpper: Double
    let donchianLower: Double
    let trueRangePercent: Double
    let heikinAshiClose: Double
    let squeezeOn: Bool

    static let empty = AdvancedTechnicalIndicators(adx: 0, plusDI: 0, minusDI: 0, cci: 0, williamsR: -50, roc: 0, obv: 0, vwap: 0, keltnerUpper: 0, keltnerMiddle: 0, keltnerLower: 0, ichimokuConversion: 0, ichimokuBase: 0, ichimokuLeadingA: 0, ichimokuLeadingB: 0, pivotPoint: 0, pivotR1: 0, pivotS1: 0, pivotR2: 0, pivotS2: 0, fibonacciRetracement382: 0, fibonacciRetracement618: 0, trendStrength: 0, signalScore: 0, superTrend: 0, mfi: 50, trix: 0, aroonUp: 0, aroonDown: 0, donchianUpper: 0, donchianLower: 0, trueRangePercent: 0, heikinAshiClose: 0, squeezeOn: false)
}

enum AdvancedTechnicalAnalyzer {
    static func calculate(history: [PriceData]) -> AdvancedTechnicalIndicators {
        guard history.count >= 2 else { return .empty }
        let closes = history.map(\.close)
        let highs = history.map(\.high)
        let lows = history.map(\.low)
        let volumes = history.map { Double($0.volume) }
        let last = closes.last ?? 0
        let period = min(14, max(2, history.count - 1))

        let trueRanges = history.enumerated().dropFirst().map { index, candle in
            max(candle.high - candle.low, abs(candle.high - history[index - 1].close), abs(candle.low - history[index - 1].close))
        }
        let atr = average(Array(trueRanges.suffix(period)))
        let plusDM = history.enumerated().dropFirst().map { index, candle -> Double in
            let up = candle.high - history[index - 1].high
            let down = history[index - 1].low - candle.low
            return up > down && up > 0 ? up : 0
        }
        let minusDM = history.enumerated().dropFirst().map { index, candle -> Double in
            let up = candle.high - history[index - 1].high
            let down = history[index - 1].low - candle.low
            return down > up && down > 0 ? down : 0
        }
        let plusDI = atr > 0 ? average(Array(plusDM.suffix(period))) / atr * 100 : 0
        let minusDI = atr > 0 ? average(Array(minusDM.suffix(period))) / atr * 100 : 0
        let dx = plusDI + minusDI > 0 ? abs(plusDI - minusDI) / (plusDI + minusDI) * 100 : 0

        let typical = history.map { ($0.high + $0.low + $0.close) / 3 }
        let cciMean = average(Array(typical.suffix(period)))
        let meanDeviation = average(Array(typical.suffix(period)).map { abs($0 - cciMean) })
        let cci = meanDeviation > 0 ? (last - cciMean) / (0.015 * meanDeviation) : 0
        let recentHigh = highs.suffix(period).max() ?? last
        let recentLow = lows.suffix(period).min() ?? last
        let range = max(recentHigh - recentLow, 0.0000001)
        let williamsR = ((recentHigh - last) / range) * -100

        let rocBase = closes.count > period ? closes[closes.count - 1 - period] : closes.first ?? last
        let roc = rocBase > 0 ? (last - rocBase) / rocBase * 100 : 0
        var obv = 0.0
        for index in 1..<history.count {
            if closes[index] > closes[index - 1] { obv += volumes[index] }
            else if closes[index] < closes[index - 1] { obv -= volumes[index] }
        }
        let volumeTotal = volumes.reduce(0, +)
        let vwap = volumeTotal > 0 ? zip(typical, volumes).map { $0.0 * $0.1 }.reduce(0, +) / volumeTotal : last
        let ema = exponentialMovingAverage(closes, period: period)
        let keltnerMiddle = ema
        let keltnerUpper = ema + 2 * atr
        let keltnerLower = max(0, ema - 2 * atr)

        let conversion = midpoint(highs, lows, period: min(9, history.count))
        let base = midpoint(highs, lows, period: min(26, history.count))
        let leadingA = (conversion + base) / 2
        let leadingB = midpoint(highs, lows, period: min(52, history.count))
        let lastCandle = history.last!
        let pivot = (lastCandle.high + lastCandle.low + lastCandle.close) / 3
        let pivotR1 = 2 * pivot - lastCandle.low
        let pivotS1 = 2 * pivot - lastCandle.high
        let pivotR2 = pivot + lastCandle.high - lastCandle.low
        let pivotS2 = pivot - lastCandle.high + lastCandle.low
        let fib382 = recentHigh - range * 0.382
        let fib618 = recentHigh - range * 0.618
        let trendStrength = min(1, max(-1, (plusDI - minusDI) / 100 + roc / 100))
        let signalScore = min(1, max(0, 0.5 + trendStrength * 0.35 + (cci / 300) * 0.15))
        let superTrend = last >= keltnerMiddle ? keltnerLower : keltnerUpper
        let moneyFlows = history.suffix(period).map { candle in
            let typicalPrice = (candle.high + candle.low + candle.close) / 3
            return (typicalPrice, typicalPrice >= keltnerMiddle ? Double(candle.volume) : -Double(candle.volume))
        }
        let positiveFlow = moneyFlows.filter { $0.1 > 0 }.map { $0.0 * $0.1 }.reduce(0, +)
        let negativeFlow = abs(moneyFlows.filter { $0.1 < 0 }.map { $0.0 * $0.1 }.reduce(0, +))
        let mfi = negativeFlow > 0 ? min(100, max(0, 100 - 100 / (1 + positiveFlow / negativeFlow))) : 50
        let ema2 = exponentialMovingAverage(Array(closes.dropFirst()), period: 15)
        let ema3 = exponentialMovingAverage(Array(closes.dropFirst(2)), period: 15)
        let trix = ema3 != 0 ? (ema3 - ema2) / abs(ema2) * 100 : 0
        let highWindow = Array(highs.suffix(period))
        let lowWindow = Array(lows.suffix(period))
        let highestIndex = highWindow.indices.max { highWindow[$0] < highWindow[$1] } ?? 0
        let lowestIndex = lowWindow.indices.max { lowWindow[$0] < lowWindow[$1] } ?? 0
        let aroonUp = Double(highestIndex + 1) / Double(period) * 100
        let aroonDown = Double(lowestIndex + 1) / Double(period) * 100
        let donchianUpper = highWindow.max() ?? last
        let donchianLower = lowWindow.min() ?? last
        let trueRangePercent = last > 0 ? atr / last * 100 : 0
        let heikinAshiClose = history.suffix(3).map { ($0.open + $0.high + $0.low + $0.close) / 4 }.last ?? last
        let squeezeOn = (keltnerUpper - keltnerLower) > 0 && (recentHigh - recentLow) < (keltnerUpper - keltnerLower)

        return AdvancedTechnicalIndicators(adx: dx, plusDI: plusDI, minusDI: minusDI, cci: cci, williamsR: williamsR, roc: roc, obv: obv, vwap: vwap, keltnerUpper: keltnerUpper, keltnerMiddle: keltnerMiddle, keltnerLower: keltnerLower, ichimokuConversion: conversion, ichimokuBase: base, ichimokuLeadingA: leadingA, ichimokuLeadingB: leadingB, pivotPoint: pivot, pivotR1: pivotR1, pivotS1: pivotS1, pivotR2: pivotR2, pivotS2: pivotS2, fibonacciRetracement382: fib382, fibonacciRetracement618: fib618, trendStrength: trendStrength, signalScore: signalScore, superTrend: superTrend, mfi: mfi, trix: trix, aroonUp: aroonUp, aroonDown: aroonDown, donchianUpper: donchianUpper, donchianLower: donchianLower, trueRangePercent: trueRangePercent, heikinAshiClose: heikinAshiClose, squeezeOn: squeezeOn)
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func exponentialMovingAverage(_ values: [Double], period: Int) -> Double {
        guard let first = values.first else { return 0 }
        let multiplier = 2.0 / Double(period + 1)
        return values.dropFirst().reduce(first) { $1 * multiplier + $0 * (1 - multiplier) }
    }

    private static func midpoint(_ highs: [Double], _ lows: [Double], period: Int) -> Double {
        let high = highs.suffix(period).max() ?? 0
        let low = lows.suffix(period).min() ?? 0
        return (high + low) / 2
    }
}
