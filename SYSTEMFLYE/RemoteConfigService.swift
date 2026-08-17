import Foundation
import Combine

enum RemoteConfigError: LocalizedError {
    case fetchFailed
    case parsingFailed
    case staleConfig
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .fetchFailed: return "Failed to fetch remote configuration."
        case .parsingFailed: return "Failed to parse configuration."
        case .staleConfig: return "Configuration is stale."
        case .invalidValue: return "Invalid configuration value."
        }
    }
}

struct RemoteConfigValue: Codable, Equatable {
    let value: String
    let type: ValueType
    let lastUpdated: Date
    let source: Source

    enum ValueType: String, Codable { case string, int, double, bool, json }
    enum Source: String, Codable { case remote, local, default_ }

    func asString() -> String { value }
    func asInt() -> Int { Int(value) ?? 0 }
    func asDouble() -> Double { Double(value) ?? 0.0 }
    func asBool() -> Bool { value.lowercased() == "true" || value == "1" }
    func asJSON<T: Codable>() throws -> T { try JSONDecoder.flye.decode(T.self, from: Data(value.utf8)) }
}

@MainActor
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()
    @Published private(set) var configValues: [String: RemoteConfigValue] = [:]
    @Published private(set) var lastFetchDate: Date?
    @Published private(set) var isFetching = false
    @Published private(set) var fetchError: RemoteConfigError?

    private let configEndpoint = "https://api.systemflye.app/v1/config"
    private let localCacheKey = "remote_config_cache"
    private let minFetchInterval: TimeInterval = 300
    private let maxFetchInterval: TimeInterval = 3600
    private var fetchTask: Task<Void, Never>?
    private var experimentGroups: [String: String] = [:]

    private init() {
        loadLocalCache()
        fetchConfig()
    }

    func fetchConfig() async {
        guard !isFetching else { return }
        isFetching = true
        fetchError = nil
        defer { isFetching = false }

        do {
            let request = APIRequest(endpoint: configEndpoint, method: .get, headers: ["If-None-Match": etag], body: nil, queryItems: nil)
            let response: RemoteConfigResponse = try await APIClientManager.shared.send(request)
            applyRemoteConfig(response)
            lastFetchDate = Date()
            cacheLocally(response.values)
        } catch {
            fetchError = .fetchFailed
            if let lastDate = lastFetchDate, Date().timeIntervalSince(lastDate) > maxFetchInterval {
                await MainActor.run { self.configValues.removeAll() }
            }
        }
    }

    func value(forKey key: String) -> RemoteConfigValue? {
        return configValues[key]
    }

    func string(forKey key: String, default: String = "") -> String {
        return configValues[key]?.asString() ?? `default`
    }

    func int(forKey key: String, default: Int = 0) -> Int {
        return configValues[key]?.asInt() ?? `default`
    }

    func double(forKey key: String, default: Double = 0.0) -> Double {
        return configValues[key]?.asDouble() ?? `default`
    }

    func bool(forKey key: String, default: Bool = false) -> Bool {
        return configValues[key]?.asBool() ?? `default`
    }

    func setExperimentGroup(_ group: String, for experiment: String) {
        experimentGroups[experiment] = group
    }

    func experimentGroup(for experiment: String) -> String {
        return experimentGroups[experiment] ?? "control"
    }

    func invalidateCache() {
        configValues.removeAll()
        lastFetchDate = nil
        UserDefaults.standard.removeObject(forKey: localCacheKey)
        fetchConfig()
    }

    private var etag: String {
        return configValues.values.first?.lastUpdated.timeIntervalSince1970.description ?? ""
    }

    private func applyRemoteConfig(_ response: RemoteConfigResponse) {
        configValues.merge(response.values) { _, new in new }
    }

    private func cacheLocally(_ values: [String: RemoteConfigValue]) {
        do {
            let data = try JSONEncoder.flye.encode(values)
            UserDefaults.standard.set(data, forKey: localCacheKey)
        } catch {
            print("Failed to cache remote config: \\(error)")
        }
    }

    private func loadLocalCache() {
        guard let data = UserDefaults.standard.data(forKey: localCacheKey),
              let values = try? JSONDecoder.flye.decode([String: RemoteConfigValue].self, from: data) else { return }
        configValues = values
        lastFetchDate = UserDefaults.standard.object(forKey: "\\(localCacheKey)_date") as? Date
    }
}

struct RemoteConfigResponse: Codable {
    let values: [String: RemoteConfigValue]
    let fetchedAt: Date
    let environment: String
}
