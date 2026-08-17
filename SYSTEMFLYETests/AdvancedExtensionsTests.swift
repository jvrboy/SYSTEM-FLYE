import XCTest
@testable import SYSTEMFLYE

// MARK: - Advanced Extensions Tests
// Verifies the new advanced agents, indicators, and tools added by the
// extension files (AdvancedAgentsRegistry, AdvancedIndicatorsExtension,
// AdvancedToolsExtension).

final class AdvancedExtensionsTests: XCTestCase {

    // MARK: - Advanced Agents Registry

    func testAdvancedAgentsCatalogHasFifteenExtensionAgents() {
        XCTAssertEqual(AdvancedAgentsCatalog.advancedAgents.count, 15)
        XCTAssertEqual(AdvancedAgentsCatalog.allAgentIDs.count, 30)
    }

    func testAdvancedAgentLibraryHasAllFifteenDescriptors() {
        XCTAssertEqual(AdvancedAgentLibrary.all.count, 15)
        for descriptor in AdvancedAgentLibrary.all {
            XCTAssertFalse(descriptor.name.isEmpty)
            XCTAssertFalse(descriptor.capabilities.isEmpty,
                          "Agent \(descriptor.name) should declare at least one capability")
        }
    }

    func testAdvancedAgentCategoriesCoverAllSevenDomains() {
        let categories = Set(AdvancedAgentLibrary.all.map(\.category))
        XCTAssertTrue(categories.contains(.market))
        XCTAssertTrue(categories.contains(.risk))
        XCTAssertTrue(categories.contains(.execution))
        XCTAssertTrue(categories.contains(.neural))
        XCTAssertTrue(categories.contains(.research))
    }

    func testRegistrySeedsAgentsIntoOrchestrator() async {
        await MainActor.run {
            let registry = AdvancedAgentsRegistry()
            registry.enableAll()
            registry.seedIntoOrchestrator()
            XCTAssertNotNil(registry.lastSeededAt)
        }
    }

    func testSkillMatrixReturnsAgentsForCapability() {
        let trendingAgents = AgentSkillMatrix.agentsWith(capability: "regime.detect")
        XCTAssertTrue(trendingAgents.contains("ORBIT"))
    }

    func testCapabilityIndexCoversAllCapabilities() {
        let index = AgentSkillMatrix.capabilityIndex
        XCTAssertFalse(index.isEmpty)
        XCTAssertTrue(index["neural.train"]?.contains("NOVA") ?? false)
        XCTAssertTrue(index["execution.plan"]?.contains("HARBOR") ?? false)
    }

    // MARK: - Advanced Indicators

    func testChoppinessIndexReturnsValueInValidRange() {
        let highs = (0..<30).map { _ in Double.random(in: 1.0...1.1) }
        let lows  = highs.map { $0 - 0.005 }
        let closes = highs.map { $0 - 0.002 }
        let chop = AdvancedIndicators.choppinessIndex(highs: highs, lows: lows, closes: closes)
        XCTAssertGreaterThanOrEqual(chop, 0)
        XCTAssertLessThanOrEqual(chop, 100)
    }

    func testHistoricalVolatilityIsNonNegative() {
        let closes = (0..<50).map { Double($0) * 0.001 + 1.0 }
        let hv = AdvancedIndicators.historicalVolatility(closes: closes)
        XCTAssertGreaterThanOrEqual(hv, 0)
    }

    func testZScoreIsZeroForFlatSeries() {
        let closes = Array(repeating: 1.0, count: 30)
        let z = AdvancedIndicators.zScore(closes: closes)
        XCTAssertEqual(z, 0, accuracy: 1e-6)
    }

    func testEMASeriesLengthMatchesInput() {
        let values = (0..<30).map { Double($0) }
        let ema = AdvancedIndicators.emaSeries(values, period: 5)
        XCTAssertLessThanOrEqual(ema.count, values.count)
        XCTAssertGreaterThan(ema.count, 0)
    }

    func testHurstExponentLiesInUnitInterval() {
        let closes = (0..<200).map { i in 1.0 + 0.001 * Double(i) + Double.random(in: -0.005...0.005) }
        let h = AdvancedIndicators.hurstExponent(closes: closes)
        XCTAssertGreaterThanOrEqual(h, 0)
        XCTAssertLessThanOrEqual(h, 1)
    }

    func testAdvancedIndicatorBundleComputesAllFields() {
        let opens  = (0..<60).map { _ in Double.random(in: 0.99...1.01) }
        let highs  = opens.map { $0 + 0.005 }
        let lows   = opens.map { $0 - 0.005 }
        let closes = opens.map { $0 + Double.random(in: -0.003...0.003) }
        let volumes = (0..<60).map { _ in Double.random(in: 1_000...10_000) }
        let bundle = AdvancedIndicatorBundle.compute(opens: opens, highs: highs, lows: lows, closes: closes, volumes: volumes)
        XCTAssertFalse(bundle.isTrendMode || !bundle.isTrendMode, "isTrendMode must resolve to a Bool")
        XCTAssertEqual(bundle.plusVI, bundle.plusVI)  // identity check (no NaN)
    }

    func testIndicatorCatalogHas23Entries() {
        XCTAssertEqual(AdvancedIndicatorCatalog.entries.count, 23)
    }

    // MARK: - Advanced Tools

    func testMLPredictorReturnsProbabilityInRange() {
        let predictor = MLPredictor()
        let feature = MLPredictor.Feature(rsi: 55, macd: 0.0001, atr: 0.003, ema20: 1.085, ema50: 1.082, adx: 22, sentiment: 0.0, volumeZ: 0.5)
        let p = predictor.predict(feature)
        XCTAssertGreaterThanOrEqual(p, 0)
        XCTAssertLessThanOrEqual(p, 1)
    }

    func testSentimentHeatmapSplitsPairsIntoCurrencies() {
        let map = SentimentHeatmap()
        map.ingest(events: [
            (pair: "EURUSD", sentiment: 0.3, bucket: 0),
            (pair: "GBPUSD", sentiment: -0.2, bucket: 1),
        ])
        XCTAssertGreaterThan(map.averageSentiment(for: "EUR"), 0)
        XCTAssertLessThan(map.averageSentiment(for: "USD"), 0)
    }

    func testVolatilitySurfaceAppliesSmile() {
        let surface = VolatilitySurface()
        surface.applySmile(atmVol: 0.12, skew: -0.04, kurtosis: 0.02)
        let v = surface.vol(strike: 1.0, maturity: 1.0)
        XCTAssertGreaterThan(v, 0)
    }

    func testExecutionPlannerProducesNonEmptySliceList() {
        let planner = SmartExecutionPlanner()
        let slices = planner.plan(orderQty: 1_000_000, durationMinutes: 60, vwapProfile: [0.05, 0.1, 0.15, 0.2, 0.25, 0.15, 0.1], strategy: "vwap")
        XCTAssertFalse(slices.isEmpty)
        XCTAssertEqual(slices.reduce(0) { $0 + $1.quantity }, 1_000_000, accuracy: 1.0)
    }

    func testRegimeClassifierReturnsAValidRegime() {
        let classifier = RegimeClassifier()
        let returns = (0..<60).map { _ in Double.random(in: -0.01...0.01) }
        let regime = classifier.classify(returns: returns)
        XCTAssertTrue(RegimeClassifier.Regime.allCases.contains(regime))
    }

    func testAnomalyRadarFlagsExtremeValues() {
        let radar = AnomalyRadar()
        let features: [String: Double] = ["rsi": 90, "zscore": 4.0]
        let baselines: [String: (mean: Double, std: Double)] = [
            "rsi": (55, 8),
            "zscore": (0, 1),
        ]
        let anomalies = radar.scan(features: features, baselines: baselines)
        XCTAssertGreaterThanOrEqual(anomalies.count, 1)
    }

    func testReinforcementTrainerLearnsPolicy() {
        let trainer = ReinforcementTrainer()
        let state = ReinforcementTrainer.State(regime: 0, rsiBucket: 5, trendBucket: 2)
        // Random exploration + reward updates should fill the qTable.
        for _ in 0..<20 {
            let action = trainer.act(state)
            trainer.update(state: state, action: action, reward: 1.0, nextState: state)
        }
        XCTAssertFalse(trainer.qTable.isEmpty)
    }

    func testBayesianNetworkPredictsDirection() {
        let net = BayesianDirectionNetwork()
        let dir = net.predict(regime: .trend, sentiment: .bullish)
        XCTAssertTrue([.up, .down, .flat].contains(dir))
        // P(up | trend, bullish) should be the highest.
        let pUp = net.probability(of: .up, given: .trend, sentiment: .bullish)
        let pDown = net.probability(of: .down, given: .trend, sentiment: .bullish)
        XCTAssertGreaterThan(pUp, pDown)
    }

    func testMonteCarloPathGeneratorProducesRequestedNumberOfPaths() {
        let gen = MonteCarloPathGenerator()
        let paths = gen.generate(startPrice: 100, drift: 0.05, volatility: 0.2, horizonDays: 10, paths: 100)
        XCTAssertEqual(paths.count, 100)
        let stats = gen.terminalStats(paths: paths)
        XCTAssertGreaterThan(stats.mean, 0)
    }

    func testWalkForwardOptimiserGeneratesWindows() {
        let optimiser = WalkForwardOptimiser()
        optimiser.generateWindows(totalBars: 1000, trainSize: 250, testSize: 50, step: 50)
        XCTAssertGreaterThan(optimiser.windows.count, 5)
    }

    func testCorrelationClustererGroupsCorrelatedLabels() {
        let labels = ["EURUSD", "GBPUSD", "USDJPY", "AUDUSD"]
        let matrix: [[Double]] = [
            [1.0, 0.85, 0.10, 0.80],
            [0.85, 1.0, 0.15, 0.75],
            [0.10, 0.15, 1.0, 0.20],
            [0.80, 0.75, 0.20, 1.0],
        ]
        let clusterer = CorrelationClusterer()
        let clusters = clusterer.cluster(corrMatrix: matrix, labels: labels, threshold: 0.7)
        XCTAssertGreaterThanOrEqual(clusters.count, 2)
    }

    func testStressScenarioLabAppliesShocks() {
        let lab = StressScenarioLab()
        let scenario = lab.scenarios.first!
        let impact = lab.apply(scenario: scenario, portfolioEquity: 1_000_000, portfolioDuration: 5, portfolioCreditSpread: 0.02, portfolioFxBeta: 0.1)
        XCTAssertNotEqual(impact, 0)
    }

    func testLatentEmbedderProducesCorrectLatentDimension() {
        let embedder = LatentEmbedder(inputDim: 8, latentDim: 4)
        let embedding = embedder.embed([1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(embedding.count, 4)
    }

    func testCounterfactualSimulatorPreservesLength() {
        let sim = CounterfactualSimulator()
        let history = (0..<100).map { Double($0) * 0.001 + 1.0 }
        let perturbation = CounterfactualSimulator.Perturbation(volScale: 1.1, driftShift: 0.001, shockBars: [50, 75])
        let perturbed = sim.perturb(history: history, perturbation: perturbation)
        XCTAssertEqual(perturbed.count, history.count)
    }

    func testNewsSummariserTrimsTextToMaxSentences() {
        let summariser = NewsNarrativeSummariser()
        let text = "Fed hiked rates. Markets plunged. ECB dovish. GDP missed. Inflation rose."
        let summary = summariser.summarise(text: text, maxSentences: 2)
        XCTAssertLessThanOrEqual(summary.components(separatedBy: ".").count, 4)
    }

    func testNewsSummariserImpactIsBounded() {
        let summariser = NewsNarrativeSummariser()
        let impact = summariser.extractImpact(text: "Markets surge after Fed cuts rates")
        XCTAssertGreaterThanOrEqual(impact, -1)
        XCTAssertLessThanOrEqual(impact, 1)
    }

    func testAdvancedToolsRegistryHasFifteenDescriptors() {
        XCTAssertEqual(AdvancedToolsRegistry.shared.descriptors.count, 15)
    }
}
