import Foundation
import Combine

enum ServiceRegistrationError: Error {
    case alreadyRegistered
    case notRegistered
    case circularDependency
}

protocol ServiceProtocol: AnyObject {}

@MainActor
final class ServiceLocator: ObservableObject {
    static let shared = ServiceLocator()
    @Published private(set) var registeredServices: [String: ServiceProtocol] = [:]
    @Published private(set) var factoryFunctions: [String: () -> ServiceProtocol] = [:]
    @Published private(set) var singletonInstances: [String: ServiceProtocol] = [:]

    private var resolutionStack: [String] = []
    private let lock = NSLock()

    private init() {
        registerCoreServices()
    }

    func register<T: ServiceProtocol>(_ type: T.Type, name: String = "\\(T.self)", factory: @escaping () -> T) throws {
        lock.lock(); defer { lock.unlock() }
        guard registeredServices[name] == nil else { throw ServiceRegistrationError.alreadyRegistered }
        factoryFunctions[name] = factory as? () -> ServiceProtocol
        registeredServices[name] = nil
    }

    func registerSingleton<T: ServiceProtocol>(_ instance: T, name: String = "\\(T.self)") throws {
        lock.lock(); defer { lock.unlock() }
        guard registeredServices[name] == nil else { throw ServiceRegistrationError.alreadyRegistered }
        singletonInstances[name] = instance
        registeredServices[name] = instance
    }

    func resolve<T: ServiceProtocol>(_ type: T.Type, name: String = "\\(T.self)") -> T? {
        lock.lock(); defer { lock.unlock() }
        if let existing = singletonInstances[name] as? T { return existing }
        if let factory = factoryFunctions[name] as? () -> T {
            let instance = factory()
            singletonInstances[name] = instance
            registeredServices[name] = instance
            return instance
        }
        return nil
    }

    func remove<T: ServiceProtocol>(_ type: T.Type, name: String = "\\(T.self)") {
        lock.lock(); defer { lock.unlock() }
        factoryFunctions.removeValue(forKey: name)
        singletonInstances.removeValue(forKey: name)
        registeredServices.removeValue(forKey: name)
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        factoryFunctions.removeAll()
        singletonInstances.removeAll()
        registeredServices.removeAll()
        resolutionStack.removeAll()
        registerCoreServices()
    }

    private func registerCoreServices() {
        do {
            try registerSingleton(APIClientManager.shared, name: "APIClientManager")
            try registerSingleton(DatabaseManager.shared, name: "DatabaseManager")
            try registerSingleton(EncryptionService.shared, name: "EncryptionService")
            try registerSingleton(AuthService.shared, name: "AuthService")
            try registerSingleton(WebSocketManager.shared, name: "WebSocketManager")
            try registerSingleton(BackgroundSyncScheduler.shared, name: "BackgroundSyncScheduler")
            try registerSingleton(MetricsCollector.shared, name: "MetricsCollector")
            try registerSingleton(LoggingService.shared, name: "LoggingService")
            try registerSingleton(CrashReporter.shared, name: "CrashReporter")
            try registerSingleton(RemoteConfigService.shared, name: "RemoteConfigService")
            try registerSingleton(PushNotificationService.shared, name: "PushNotificationService")
            try registerSingleton(AppUpdateService.shared, name: "AppUpdateService")
            try registerSingleton(DataExporter.shared, name: "DataExporter")
            try registerSingleton(ImportExportService.shared, name: "ImportExportService")
            try registerSingleton(BiometricAuthService.shared, name: "BiometricAuthService")
            try registerSingleton(CloudSyncService.shared, name: "CloudSyncService")
            try registerSingleton(KeychainService.shared, name: "KeychainService")
            try registerSingleton(RateLimiter.shared, name: "RateLimiter")
            try registerSingleton(CircuitBreaker.shared, name: "CircuitBreaker")
            try registerSingleton(RetryPolicyEngine.shared, name: "RetryPolicyEngine")
            try registerSingleton(EventBus.shared, name: "EventBus")
            try registerSingleton(CacheManager.shared, name: "CacheManager")
            try registerSingleton(OperationalBackendStore.shared, name: "OperationalBackendStore")
            try registerSingleton(BackendServiceManager.shared, name: "BackendServiceManager")
            try registerSingleton(ForexTradingBackend.shared, name: "ForexTradingBackend")
            try registerSingleton(AnalyticsEngine.shared, name: "AnalyticsEngine")
            try registerSingleton(AdvancedStore.shared, name: "AdvancedStore")
            try registerSingleton(FeaturePlatformStore.shared, name: "FeaturePlatformStore")
            try registerSingleton(ProductionStore.shared, name: "ProductionStore")
            try registerSingleton(MarketDataManager.shared, name: "MarketDataManager")
            try registerSingleton(SignalGenerator.shared, name: "SignalGenerator")
            try registerSingleton(GranularSynthesizer.shared, name: "GranularSynthesizer")
            try registerSingleton(AudioFileManager.shared, name: "AudioFileManager")
            try registerSingleton(AudioPlayerManager.shared, name: "AudioPlayerManager")
            try registerSingleton(LoopReshapingEngine.shared, name: "LoopReshapingEngine")
            try registerSingleton(NewsSentimentService.shared, name: "NewsSentimentService")
        } catch {
            print("Core service registration failed: \\(error)")
        }
    }
}

protocol ServiceLocatorResolvable {
    static func registerServices(in locator: ServiceLocator)
}

extension ServiceLocatorResolvable {
    static func registerServices(in locator: ServiceLocator) {}
}
