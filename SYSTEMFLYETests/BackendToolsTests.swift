import XCTest
@testable import SYSTEMFLYE

final class BackendToolsTests: XCTestCase {
    func testCircuitBreakerOpensAfterRepeatedFailures() async {
        let breaker = CircuitBreaker(maxFailures: 3, resetInterval: 5)
        for _ in 0..<3 {
            do { try await breaker.execute { throw BackendError.serviceUnavailable } }
            catch { /* expected */ }
        }
        do { try await breaker.execute { "ok" } }
        catch BackendError.circuitOpen { /* expected */ }
        catch { XCTFail("Expected circuit open") }
    }
    
    func testRateLimiterThrottlesRequests() async {
        let limiter = TokenBucketRateLimiter(capacity: 2, refillRate: 1)
        await limiter.waitIfNeeded()
        await limiter.waitIfNeeded()
        let start = Date()
        await limiter.waitIfNeeded()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(elapsed, 0.5, "Rate limiter should throttle after capacity exceeded")
    }
    
    func testMetricsCollectorTracksSuccessRate() {
        let collector = MetricsCollector.shared
        collector.record(success: true, latency: 0.1)
        collector.record(success: true, latency: 0.2)
        collector.record(success: false, latency: 0.3)
        XCTAssertEqual(collector.requestCount, 3)
        XCTAssertEqual(collector.successRate, 2.0/3.0)
        XCTAssertEqual(collector.failureRate, 1.0/3.0)
    }
    
    func testInterceptedRequestIsLogged() async {
        let chain = RequestInterceptorChain.shared
        await chain.add(LoggingInterceptor())
        var request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        request.httpMethod = "POST"
        let result = await chain.intercept(request: request)
        XCTAssertEqual(result.httpMethod, "POST")
    }
    
    func testCacheManagerRoundTripsCodable() async {
        let manager = CacheManager.shared
        struct TestPayload: Codable { let value: Int }
        let payload = TestPayload(value: 42)
        manager.set(payload, for: "test-key", ttl: 60)
        let decoded: TestPayload? = manager.get(TestPayload.self, for: "test-key")
        XCTAssertEqual(decoded?.value, 42)
    }
}
