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

    @MainActor func testBackendServiceManagerRegistersDefaultServices() {
        let manager = BackendServiceManager.shared
        XCTAssertGreaterThanOrEqual(manager.services.count, 3)
        XCTAssertEqual(manager.overallHealth, .healthy)
    }

    @MainActor func testMetricsCollectorTracksRequestCount() {
        let collector = MetricsCollector.shared
        let originalCount = collector.requestCount
        collector.record(success: true, latency: 0.1)
        XCTAssertGreaterThan(collector.requestCount, originalCount)
    }

    @MainActor func testAnalyticsEngineProducesCorrelationMatrix() {
        let engine = AnalyticsEngine.shared
        let series = [[1.0, 2.0, 3.0, 4.0, 5.0], [2.0, 3.0, 4.0, 5.0, 6.0]]
        let matrix = engine.calculateCorrelationMatrix(series: series)
        XCTAssertEqual(matrix.count, 2)
        XCTAssertEqual(matrix[0][1], matrix[1][0], accuracy: 0.01)
    }
}
