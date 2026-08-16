import XCTest
@testable import SYSTEMFLYE

final class AdvancedCoreTests: XCTestCase {
    @MainActor func testPipelineHasOrderedExecutionStages() {
        let store = AdvancedStore()
        XCTAssertEqual(store.pipeline.count, 4)
        XCTAssertEqual(store.pipeline.first?.state, .complete)
        XCTAssertEqual(store.pipeline[2].state, .active)
    }

    @MainActor func testSignalsExposeRiskAndRegime() {
        let store = AdvancedStore()
        XCTAssertFalse(store.signals.isEmpty)
        XCTAssertTrue(store.signals.allSatisfy { !$0.regime.isEmpty && !$0.risk.isEmpty })
    }

    @MainActor func testNeuralTrainingProgresses() async {
        let store = AdvancedStore()
        store.train()
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThan(store.neuralEpoch, 0)
    }
}
