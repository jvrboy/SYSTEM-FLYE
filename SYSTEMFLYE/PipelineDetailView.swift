import SwiftUI

struct PipelineDetailView: View {
    @EnvironmentObject private var store: AdvancedStore
    @State private var pipelineSteps: [PipelineStep]
    @State private var selectedStepID: UUID?
    @State private var showingReorderAlert = false
    @State private var draggedStep: PipelineStep?
    @State private var isSimulating = false
    @State private var simulationProgress: Double = 0
    @State private var executionHistory: [ExecutionRecord] = []
    @State private var activeStepIndex: Int = 0

    struct ExecutionRecord: Identifiable {
        let id = UUID()
        let stepName: String
        let timestamp: Date
        let duration: Double
        let status: ExecutionStatus
    }

    enum ExecutionStatus: String {
        case success = "Success"
        case failed = "Failed"
        case running = "Running"
        case pending = "Pending"
    }

    init() {
        _pipelineSteps = State(initialValue: [
            PipelineStep(name: "Ingest telemetry", kind: "SOURCE", detail: "EURUSD / 1H candles", state: .complete, duration: "0.4s"),
            PipelineStep(name: "Detect regime", kind: "MODEL", detail: "On-device transformer", state: .active, duration: "running"),
            PipelineStep(name: "Stress portfolio", kind: "TOOL", detail: "12 Monte Carlo paths", state: .queued, duration: "—"),
            PipelineStep(name: "Draft action", kind: "AGENT", detail: "Awaiting policy gate", state: .queued, duration: "—")
        ])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  P I P E L I N E", title: "Pipeline Detail")
                        Spacer()
                        Label("LIVE", systemImage: "circle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSimulating ? .orange : .green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background((isSimulating ? Color.orange : Color.green).opacity(0.12), in: Capsule())
                    }

                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                runPipelineSimulation()
                            }
                        } label: {
                            Label(isSimulating ? "Simulating…" : "Run Pipeline", systemImage: isSimulating ? "arrow.triangle.2.circlepath" : "play.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SystemFlyeTheme.cyan)
                        .disabled(isSimulating)

                        Button {
                            resetPipeline()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)

                        if isSimulating {
                            ProgressView(value: simulationProgress)
                                .tint(SystemFlyeTheme.cyan)
                                .frame(width: 120)
                        }
                    }

                    if isSimulating {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SIMULATION PROGRESS")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(.secondary)
                            ProgressView(value: simulationProgress)
                                .tint(SystemFlyeTheme.cyan)
                            Text("\(Int(simulationProgress * 100))% complete")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(SystemFlyeTheme.cyan)
                        }
                        .padding(16)
                        .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("PIPELINE STAGES")
                            .font(.caption2.weight(.bold))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)

                        ForEach(Array(pipelineSteps.enumerated()), id: \.element.id) { index, step in
                            PipelineStepRow(
                                step: step,
                                index: index,
                                total: pipelineSteps.count,
                                isActive: index == activeStepIndex,
                                isSelected: selectedStepID == step.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedStepID = step.id
                                }
                            }
                            .onLongPressGesture {
                                draggedStep = step
                                showingReorderAlert = true
                            }
                        }
                    }
                    .padding(16)
                    .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))

                    if let selected = selectedStepID, let step = pipelineSteps.first(where: { $0.id == selected }) {
                        stepDetailCard(step)
                            .padding(.top, 4)
                    }

                    executionLogView
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Pipeline Detail")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reorder Pipeline", isPresented: $showingReorderAlert) {
                Button("Cancel", role: .cancel) { draggedStep = nil }
                Button("Move Up") { moveStepUp() }
                Button("Move Down") { moveStepDown() }
            } message: {
                Text("Drag and drop or use buttons to reorder pipeline stages.")
            }
        }
    }

    private func stepDetailCard(_ step: PipelineStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(step.name.uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(step.kind)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SystemFlyeTheme.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(SystemFlyeTheme.cyan.opacity(0.1), in: Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(step.state.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(stepStateColor(step.state))
                    Text(step.duration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Divider().background(SystemFlyeTheme.line)

            Text(step.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("STEP CONFIGURATION")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ConfigRow(label: "Timeout", value: "30s")
                    ConfigRow(label: "Retries", value: "3")
                    ConfigRow(label: "Queue priority", value: "Normal")
                    ConfigRow(label: "Resource limit", value: "512 MB")
                    ConfigRow(label: "Parallelism", value: "4 workers")
                    ConfigRow(label: "Fallback", value: "Enabled")
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let idx = pipelineSteps.firstIndex(where: { $0.id == step.id }) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            pipelineSteps[idx].state = .active
                        }
                        runSingleStep(step)
                    }
                } label: {
                    Label("Execute", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(SystemFlyeTheme.cyan)
                .disabled(step.state == .active || step.state == .complete)

                Button {
                    if let idx = pipelineSteps.firstIndex(where: { $0.id == step.id }) {
                        pipelineSteps[idx].state = .queued
                    }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(20)
        .background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private var executionLogView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("EXECUTION HISTORY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    executionHistory.removeAll()
                }
                .font(.caption)
                .tint(.secondary)
            }

            if executionHistory.isEmpty {
                ContentUnavailableView("No executions yet", systemImage: "list.bullet") {
                    Text("Run the pipeline to see execution history here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(executionHistory) { record in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(statusColor(record.status))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.stepName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(record.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(record.status.rawValue)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(statusColor(record.status))
                                Text(String(format: "%.2fs", record.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func stepStateColor(_ state: PipelineState) -> Color {
        switch state {
        case .complete: return .green
        case .active: return .orange
        case .queued: return .secondary
        }
    }

    private func statusColor(_ status: ExecutionStatus) -> Color {
        switch status {
        case .success: return .green
        case .failed: return .red
        case .running: return .orange
        case .pending: return .secondary
        }
    }

    private func runPipelineSimulation() {
        isSimulating = true
        simulationProgress = 0
        executionHistory.removeAll()

        Task { @MainActor in
            for (index, step) in pipelineSteps.enumerated() {
                activeStepIndex = index
                if let idx = pipelineSteps.firstIndex(where: { $0.id == step.id }) {
                    pipelineSteps[idx].state = .active
                }

                let startTime = Date()
                let duration = Double.random(in: 0.5...2.0)
                let progressStep = 1.0 / Double(pipelineSteps.count)

                for i in 0..20 {
                    try? await Task.sleep(for: .milliseconds(50))
                    simulationProgress = Double(index) / Double(pipelineSteps.count) + (Double(i) / 20.0) * progressStep
                }

                let endTime = Date()
                let success = Bool.random() || step.state == .complete
                if let idx = pipelineSteps.firstIndex(where: { $0.id == step.id }) {
                    pipelineSteps[idx].state = success ? .complete : .queued
                    pipelineSteps[idx].duration = String(format: "%.1fs", endTime.timeIntervalSince(startTime))
                }

                executionHistory.append(ExecutionRecord(
                    stepName: step.name,
                    timestamp: Date(),
                    duration: endTime.timeIntervalSince(startTime),
                    status: success ? .success : .failed
                ))
            }

            isSimulating = false
            simulationProgress = 1.0
            activeStepIndex = 0
        }
    }

    private func runSingleStep(_ step: PipelineStep) {
        Task { @MainActor in
            let start = Date()
            try? await Task.sleep(for: .seconds(1.5))
            let end = Date()
            if let idx = pipelineSteps.firstIndex(where: { $0.id == step.id }) {
                pipelineSteps[idx].state = .complete
                pipelineSteps[idx].duration = String(format: "%.1fs", end.timeIntervalSince(start))
            }
            executionHistory.append(ExecutionRecord(
                stepName: step.name,
                timestamp: Date(),
                duration: end.timeIntervalSince(start),
                status: .success
            ))
        }
    }

    private func resetPipeline() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            for i in pipelineSteps.indices {
                pipelineSteps[i].state = .queued
                pipelineSteps[i].duration = "—"
            }
            activeStepIndex = 0
            simulationProgress = 0
            executionHistory.removeAll()
        }
    }

    private func moveStepUp() {
        guard let step = draggedStep,
              let currentIndex = pipelineSteps.firstIndex(where: { $0.id == step.id }),
              currentIndex > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            pipelineSteps.swapAt(currentIndex, currentIndex - 1)
        }
        draggedStep = nil
    }

    private func moveStepDown() {
        guard let step = draggedStep,
              let currentIndex = pipelineSteps.firstIndex(where: { $0.id == step.id }),
              currentIndex < pipelineSteps.count - 1 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            pipelineSteps.swapAt(currentIndex, currentIndex + 1)
        }
        draggedStep = nil
    }
}

struct PipelineStepRow: View {
    let step: PipelineStep
    let index: Int
    let total: Int
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(stepStateBg)
                        .frame(width: 32, height: 32)
                    Image(systemName: stepStateIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(stepStateColor)
                }
                if index < total - 1 {
                    Rectangle()
                        .fill(SystemFlyeTheme.line)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(step.kind) · \(step.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(step.duration)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(SystemFlyeTheme.cyan)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(index + 1)/\(total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(step.state.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(stepStateColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stepStateColor.opacity(0.15), in: Capsule())
            }
        }
        .padding(14)
        .background(isSelected ? SystemFlyeTheme.cyan.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? SystemFlyeTheme.cyan.opacity(0.4) : SystemFlyeTheme.line, lineWidth: isSelected ? 1.5 : 1)
        )
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }

    private var stepStateColor: Color {
        switch step.state {
        case .complete: return .green
        case .active: return .orange
        case .queued: return .secondary
        }
    }

    private var stepStateBg: Color {
        switch step.state {
        case .complete: return Color.green.opacity(0.15)
        case .active: return Color.orange.opacity(0.15)
        case .queued: return Color.white.opacity(0.05)
        }
    }

    private var stepStateIcon: String {
        switch step.state {
        case .complete: return "checkmark"
        case .active: return "play.fill"
        case .queued: return "circle"
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PipelineDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PipelineDetailView()
            .environmentObject(AdvancedStore())
            .preferredColorScheme(.dark)
    }
}

