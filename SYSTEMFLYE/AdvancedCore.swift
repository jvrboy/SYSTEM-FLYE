import Foundation
import SwiftUI

struct AgentDefinition: Identifiable, Hashable {
    let id: UUID
    var name: String
    var role: String
    var status: AgentStatus
    var tools: [String]
    var confidence: Double
    var lastRun: String
    var accent: Color
}

enum AgentStatus: String, CaseIterable { case ready = "READY", running = "RUNNING", paused = "PAUSED" }

struct PipelineStep: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var kind: String
    var detail: String
    var state: PipelineState
    var duration: String
}

enum PipelineState: String { case complete = "COMPLETE", active = "ACTIVE", queued = "QUEUED" }

struct NeuralMetric: Identifiable { let id = UUID(); var label: String; var value: String; var detail: String; var tint: Color }

struct QuantSignal: Identifiable { let id = UUID(); var pair: String; var direction: String; var score: Double; var regime: String; var risk: String }

@MainActor
final class AdvancedStore: ObservableObject {
    @Published var selectedWorkspace = "Command"
    @Published var agents: [AgentDefinition] = [
        AgentDefinition(id: UUID(), name: "ORBIT", role: "Market reconnaissance", status: .ready, tools: ["Price feed", "Regime map", "Risk check"], confidence: 0.94, lastRun: "2m ago", accent: .cyan),
        AgentDefinition(id: UUID(), name: "MIXER", role: "Generative sound designer", status: .ready, tools: ["Synth graph", "Sample forge", "Master bus"], confidence: 0.88, lastRun: "8m ago", accent: .purple),
        AgentDefinition(id: UUID(), name: "SENTINEL", role: "Portfolio risk monitor", status: .paused, tools: ["Exposure", "Drawdown", "Alerts"], confidence: 0.97, lastRun: "18m ago", accent: .orange)
    ]
    @Published var pipeline: [PipelineStep] = [
        PipelineStep(name: "Ingest telemetry", kind: "SOURCE", detail: "EURUSD / 1H candles", state: .complete, duration: "0.4s"),
        PipelineStep(name: "Detect regime", kind: "MODEL", detail: "On-device transformer", state: .complete, duration: "1.2s"),
        PipelineStep(name: "Stress portfolio", kind: "TOOL", detail: "12 Monte Carlo paths", state: .active, duration: "running"),
        PipelineStep(name: "Draft action", kind: "AGENT", detail: "Awaiting policy gate", state: .queued, duration: "—")
    ]
    @Published var isLive = true
    @Published var runCount = 1284
    @Published var selectedPair = "EUR/USD"
    @Published var neuralEpoch = 42
    @Published var isTraining = false
    @Published var signalBias = 0.67

    var signals: [QuantSignal] { [
        QuantSignal(pair: "EUR/USD", direction: "LONG", score: 0.82, regime: "Trend", risk: "0.8R"),
        QuantSignal(pair: "GBP/JPY", direction: "SHORT", score: 0.74, regime: "Volatile", risk: "1.2R"),
        QuantSignal(pair: "AUD/USD", direction: "WATCH", score: 0.51, regime: "Range", risk: "0.4R")
    ] }

    func runAgent(_ id: UUID) {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }
        agents[index].status = .running
        runCount += 1
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, let currentIndex = self.agents.firstIndex(where: { $0.id == id }) else { return }
            self.agents[currentIndex].status = .ready
        }
    }

    func train() {
        guard !isTraining else { return }
        isTraining = true
        neuralEpoch = 0
        Task { @MainActor [weak self] in
            guard let self else { return }
            for epoch in 1...50 {
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                self.neuralEpoch = epoch
                self.signalBias = min(0.97, 0.67 + Double(epoch) * 0.006)
            }
            self.isTraining = false
        }
    }
}

struct SystemFlyeTheme {
    static let ink = Color(red: 0.035, green: 0.045, blue: 0.065)
    static let panel = Color(red: 0.075, green: 0.09, blue: 0.13)
    static let line = Color.white.opacity(0.11)
    static let cyan = Color(red: 0.25, green: 0.9, blue: 0.95)
    static let violet = Color(red: 0.64, green: 0.45, blue: 1.0)
}

struct MetricTile: View {
    let label: String; let value: String; let detail: String; let tint: Color
    var body: some View { VStack(alignment: .leading, spacing: 8) { Text(label.uppercased()).font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(.secondary); Text(value).font(.title2.weight(.bold).monospacedDigit()); Text(detail).font(.caption).foregroundStyle(tint) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(SystemFlyeTheme.panel).overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line)) }
}

struct SectionHeader: View { let eyebrow: String; let title: String; var body: some View { VStack(alignment: .leading, spacing: 5) { Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(2).foregroundStyle(SystemFlyeTheme.cyan); Text(title).font(.title.weight(.bold)).foregroundStyle(.white) } } }

struct Sparkline: Shape { var values: [CGFloat]; func path(in rect: CGRect) -> Path { guard values.count > 1 else { return Path() }; let minValue = values.min() ?? 0; let maxValue = values.max() ?? 1; let range = max(maxValue - minValue, 0.01); var path = Path(); for (index, value) in values.enumerated() { let x = rect.minX + CGFloat(index) / CGFloat(values.count - 1) * rect.width; let y = rect.maxY - (value - minValue) / range * rect.height; index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y)) }; return path } }
