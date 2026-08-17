import SwiftUI

struct EnvelopeEditorView: View {
    @Binding var points: [EnvelopePoint]
    @State private var selectedPreset = "Custom"

    private let presets: [String: CustomEnvelope] = [
        "Neutral": .neutral, "Pluck": .pluck, "Pad": .pad, "Swell": .swell
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CUSTOM ENVELOPE GENERATOR")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(points.count) points")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.cyan)
            }

            EnvelopeGraph(points: points)
                .frame(height: 120)
                .padding(10)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))

            Picker("Envelope", selection: $selectedPreset) {
                Text("Custom").tag("Custom")
                ForEach(presets.keys.sorted(), id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPreset) { _, newValue in
                if let preset = presets[newValue] { points = preset.points }
            }

            ForEach(points.indices, id: \.self) { index in
                VStack(spacing: 7) {
                    HStack {
                        Text("POINT \(index + 1)")
                            .font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "t %.2f  ·  v %.2f", points[index].time, points[index].value))
                            .font(.caption2.monospacedDigit()).foregroundStyle(Color.cyan)
                    }
                    HStack(spacing: 8) {
                        Text("Time").font(.caption).foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
                        Slider(value: $points[index].time, in: 0...1).tint(Color.cyan)
                        Text("Value").font(.caption).foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
                        Slider(value: $points[index].value, in: 0...1).tint(Color.purple)
                    }
                    Picker("Curve", selection: $points[index].curve) {
                        ForEach(EnvelopeCurve.allCases, id: \.self) { curve in Text(curve.rawValue.capitalized).tag(curve) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.cyan)
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Button { points.append(EnvelopePoint(time: 0.5, value: 0.5, curve: .smooth)); points.sort { $0.time < $1.time }; selectedPreset = "Custom" } label: { Label("Add point", systemImage: "plus.circle.fill") }
                    .buttonStyle(.bordered)
                Button { if points.count > 2 { points.removeLast(); selectedPreset = "Custom" } } label: { Label("Remove point", systemImage: "minus.circle") }
                    .buttonStyle(.bordered)
                    .disabled(points.count <= 2)
                Spacer()
                Text("Curve-controlled amplitude")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.12, blue: 0.18), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct EnvelopeGraph: View {
    let points: [EnvelopePoint]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height - 1))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - 1))
                }.stroke(Color.white.opacity(0.12), lineWidth: 1)
                Path { path in
                    guard let first = points.sorted(by: { $0.time < $1.time }).first else { return }
                    let sorted = points.sorted { $0.time < $1.time }
                    path.move(to: CGPoint(x: first.time * geometry.size.width, y: geometry.size.height - first.value * geometry.size.height))
                    for point in sorted.dropFirst() {
                        path.addLine(to: CGPoint(x: point.time * geometry.size.width, y: geometry.size.height - point.value * geometry.size.height))
                    }
                }
                .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                ForEach(points) { point in
                    Circle().fill(Color.white).frame(width: 8, height: 8).position(x: point.time * geometry.size.width, y: geometry.size.height - point.value * geometry.size.height)
                }
            }
        }
    }
}
