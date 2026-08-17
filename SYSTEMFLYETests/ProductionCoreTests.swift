import XCTest
@testable import SYSTEMFLYE

final class ProductionCoreTests: XCTestCase {
    func testSnapshotEnvelopeRoundTrips() throws {
        var snapshot = LocalWorkspaceSnapshot()
        snapshot.selectedPair = "GBP/JPY"
        let data = try JSONEncoder.flye.encode(FlyeEnvelope(schemaVersion: 1, updatedAt: Date(), payload: snapshot))
        let decoded = try JSONDecoder.flye.decode(FlyeEnvelope<LocalWorkspaceSnapshot>.self, from: data)
        XCTAssertEqual(decoded.payload.selectedPair, "GBP/JPY")
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testOfflineQueueUsesBackoffAndRemovesSuccess() async {
        let queue = OfflineQueue()
        await queue.enqueue(kind: "pipeline.run", payload: "demo")
        let ready = await queue.readyOperations()
        XCTAssertEqual(ready.count, 1)
        await queue.markFailed(ready[0].id)
        XCTAssertEqual(await queue.readyOperations().count, 0)
        await queue.markSucceeded(ready[0].id)
        XCTAssertEqual(await queue.count(), 0)
    }
}
