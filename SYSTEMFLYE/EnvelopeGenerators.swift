import Foundation

struct EnvelopePoint: Codable, Equatable, Identifiable {
    let id: UUID
    var time: Double
    var value: Double
    var curve: EnvelopeCurve

    init(id: UUID = UUID(), time: Double, value: Double, curve: EnvelopeCurve = .linear) {
        self.id = id
        self.time = min(1, max(0, time))
        self.value = min(1, max(0, value))
        self.curve = curve
    }
}

enum EnvelopeCurve: String, Codable, CaseIterable {
    case linear
    case exponential
    case logarithmic
    case smooth
    case hold
}

struct CustomEnvelope: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var points: [EnvelopePoint]
    var loopStart: Double?
    var loopEnd: Double?
    var releaseTime: Double

    init(id: UUID = UUID(), name: String, points: [EnvelopePoint], loopStart: Double? = nil, loopEnd: Double? = nil, releaseTime: Double = 0.15) {
        self.id = id
        self.name = name
        self.points = points.sorted { $0.time < $1.time }
        self.loopStart = loopStart
        self.loopEnd = loopEnd
        self.releaseTime = max(0.001, releaseTime)
    }

    static let neutral = CustomEnvelope(name: "Neutral", points: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.08, value: 1, curve: .smooth), EnvelopePoint(time: 0.75, value: 0.72, curve: .smooth), EnvelopePoint(time: 1, value: 0)])
    static let pluck = CustomEnvelope(name: "Pluck", points: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.015, value: 1, curve: .exponential), EnvelopePoint(time: 0.18, value: 0.18, curve: .exponential), EnvelopePoint(time: 1, value: 0)])
    static let pad = CustomEnvelope(name: "Pad", points: [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.28, value: 1, curve: .smooth), EnvelopePoint(time: 0.72, value: 0.82, curve: .smooth), EnvelopePoint(time: 1, value: 0)])
    static let swell = CustomEnvelope(name: "Swell", points: [EnvelopePoint(time: 0, value: 0, curve: .logarithmic), EnvelopePoint(time: 0.62, value: 1, curve: .smooth), EnvelopePoint(time: 1, value: 0)])

    func value(at normalizedTime: Double, gateOpen: Bool = true) -> Float {
        guard !points.isEmpty else { return 0 }
        var time = min(1, max(0, normalizedTime))
        if gateOpen, let loopStart, let loopEnd, loopEnd > loopStart, time > loopEnd {
            let loopLength = loopEnd - loopStart
            time = loopStart + (time - loopStart).truncatingRemainder(dividingBy: loopLength)
        }
        if !gateOpen {
            let releaseOrigin = max(0, 1 - releaseTime)
            if time >= releaseOrigin {
                let releaseProgress = min(1, (time - releaseOrigin) / releaseTime)
                return Float(interpolate(from: points.last?.value ?? 0, to: 0, progress: releaseProgress, curve: .exponential))
            }
        }
        guard let rightIndex = points.firstIndex(where: { $0.time >= time }) else { return Float(points.last?.value ?? 0) }
        if rightIndex == 0 { return Float(points[0].value) }
        let left = points[rightIndex - 1]
        let right = points[rightIndex]
        let span = max(0.000001, right.time - left.time)
        let progress = (time - left.time) / span
        return Float(interpolate(from: left.value, to: right.value, progress: progress, curve: right.curve))
    }

    private func interpolate(from: Double, to: Double, progress: Double, curve: EnvelopeCurve) -> Double {
        let p = min(1, max(0, progress))
        let shaped: Double
        switch curve {
        case .linear: shaped = p
        case .exponential: shaped = pow(p, 2.7)
        case .logarithmic: shaped = 1 - pow(1 - p, 2.7)
        case .smooth: shaped = p * p * (3 - 2 * p)
        case .hold: shaped = p < 1 ? 0 : 1
        }
        return from + (to - from) * shaped
    }
}

enum EnvelopeGenerator {
    static func adsr(attack: Double, decay: Double, sustain: Double, release: Double, sampleCount: Int, gatePoint: Double = 0.82) -> [Float] {
        let safeCount = max(1, sampleCount)
        let attackEnd = min(gatePoint, max(0.001, attack))
        let decayEnd = min(gatePoint, attackEnd + max(0.001, decay))
        let releaseStart = max(decayEnd, min(0.99, gatePoint))
        return (0..<safeCount).map { index in
            let time = Double(index) / Double(max(1, safeCount - 1))
            if time < attackEnd { return Float(time / attackEnd) }
            if time < decayEnd { return Float(1 - (1 - sustain) * ((time - attackEnd) / max(0.001, decayEnd - attackEnd))) }
            if time < releaseStart { return Float(sustain) }
            return Float(sustain * max(0, 1 - (time - releaseStart) / max(0.001, release)))
        }
    }

    static func render(_ envelope: CustomEnvelope, sampleCount: Int, gateOpen: Bool = true) -> [Float] {
        let count = max(1, sampleCount)
        return (0..<count).map { index in envelope.value(at: Double(index) / Double(max(1, count - 1)), gateOpen: gateOpen) }
    }
}
