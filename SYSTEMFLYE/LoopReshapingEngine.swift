import Foundation

struct LoopReshapeResult {
    let samples: [Float]
    let detectedTransients: [Int]
    let operation: String
}

enum LoopReshapingEngine {
    static func process(samples: [Float], operation: String, amount: Double = 0.5, seed: UInt64 = 42) -> LoopReshapeResult {
        guard !samples.isEmpty else { return LoopReshapeResult(samples: [], detectedTransients: [], operation: operation) }
        let transients = detectTransients(samples: samples)
        let reshaped: [Float]
        switch operation {
        case "stretch": reshaped = timeStretch(samples: samples, factor: 0.75 + amount * 0.75)
        case "reverse": reshaped = Array(samples.reversed())
        case "stutter": reshaped = stutter(samples: samples, repeats: max(2, Int(amount * 7)))
        case "shuffle": reshaped = seededShuffle(samples: samples, slices: max(2, transients.count + 1), seed: seed)
        case "freeze": reshaped = spectralFreeze(samples: samples, windowSize: max(32, Int(amount * 512)))
        default: reshaped = samples
        }
        return LoopReshapeResult(samples: reshaped, detectedTransients: transients, operation: operation)
    }

    static func detectTransients(samples: [Float], threshold: Float = 0.18) -> [Int] {
        guard samples.count > 2 else { return [] }
        var results: [Int] = []
        var previous = abs(samples[0])
        for index in 1..<samples.count {
            let current = abs(samples[index])
            if current - previous > threshold { results.append(index) }
            previous = previous * 0.85 + current * 0.15
        }
        return results
    }

    private static func timeStretch(samples: [Float], factor: Double) -> [Float] {
        let outputCount = max(1, Int(Double(samples.count) / factor))
        return (0..<outputCount).map { index in
            let position = Double(index) * factor
            let lower = min(samples.count - 1, Int(position))
            let upper = min(samples.count - 1, lower + 1)
            let blend = Float(position - Double(lower))
            return samples[lower] * (1 - blend) + samples[upper] * blend
        }
    }

    private static func stutter(samples: [Float], repeats: Int) -> [Float] {
        let sliceLength = max(1, samples.count / max(repeats, 1))
        let slice = Array(samples.prefix(sliceLength))
        return Array(repeating: slice, count: repeats).flatMap { $0 }
    }

    private static func seededShuffle(samples: [Float], slices: Int, seed: UInt64) -> [Float] {
        let sliceLength = max(1, samples.count / slices)
        var chunks: [[Float]] = stride(from: 0, to: samples.count, by: sliceLength).map { start in Array(samples[start..<min(samples.count, start + sliceLength)]) }
        var state = seed
        guard chunks.count > 1 else { return chunks.flatMap { $0 } }
        for index in stride(from: chunks.count - 1, through: 1, by: -1) {
            state = state &* 2862933555777941757 &+ 3037000493
            let swapIndex = Int(state % UInt64(index + 1))
            chunks.swapAt(index, swapIndex)
        }
        return chunks.flatMap { $0 }
    }

    private static func spectralFreeze(samples: [Float], windowSize: Int) -> [Float] {
        let window = Array(samples.prefix(min(windowSize, samples.count)))
        guard !window.isEmpty else { return samples }
        let tailCount = max(0, samples.count - window.count)
        let repeated = Array(repeating: window, count: Int(ceil(Double(tailCount) / Double(window.count)))) .flatMap { $0 }
        return window + Array(repeated.prefix(tailCount))
    }
}
