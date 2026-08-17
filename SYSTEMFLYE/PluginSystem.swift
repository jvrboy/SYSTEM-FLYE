import Foundation
import Combine

enum PluginError: Error {
    case loadFailed
    case incompatibleVersion
    case missingDependency
    case securityViolation
    case alreadyLoaded
    case notLoaded
}

struct PluginManifest: Codable, Identifiable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let minAppVersion: String
    let dependencies: [String]
    let permissions: [String]
    let entryPoint: String
    let icon: String?
    let tags: [String]
    let sandboxProfile: String
}

struct PluginEvent: Codable {
    let name: String
    let payload: Data
    let timestamp: Date
}

protocol PluginProtocol: AnyObject {
    var manifest: PluginManifest { get }
    var isActive: Bool { get set }
    func load() async throws
    func unload() async throws
    func handleEvent(_ event: PluginEvent) async throws
    func executeCommand(_ command: String, arguments: [String]) async throws -> String
}

@MainActor
final class PluginSystem: ObservableObject {
    static let shared = PluginSystem()
    @Published private(set) var loadedPlugins: [PluginManifest] = []
    @Published private(set) var pluginErrors: [String: String] = [:]
    @Published private(set) var activePluginCount = 0
    @Published private(set) var totalEventCount = 0

    private var pluginInstances: [String: PluginProtocol] = [:]
    private var pluginDirectories: [URL] = []
    private let sandbox = SandboxManager()
    private let eventBus = EventBus.shared
    private let maxPlugins = 20
    private var pluginURLs: [String: URL] = [:]

    private init() {
        setupPluginDirectories()
        setupEventSubscription()
    }

    func loadPlugin(from url: URL) async throws -> PluginProtocol {
        guard loadedPlugins.count < maxPlugins else { throw PluginError.loadFailed }
        let manifest = try readManifest(from: url)
        for dependency in manifest.dependencies {
            guard loadedPlugins.contains(where: { $0.id == dependency }) else {
                throw PluginError.missingDependency
            }
        }
        guard manifest.minAppVersion <= (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") else {
            throw PluginError.incompatibleVersion
        }
        let plugin = try instantiatePlugin(manifest: manifest, from: url)
        try await plugin.load()
        loadedPlugins.append(manifest)
        pluginInstances[manifest.id] = plugin
        activePluginCount = loadedPlugins.count
        try sandbox.applyProfile(manifest.sandboxProfile, for: manifest.id)
        return plugin
    }

    func unloadPlugin(id: String) async throws {
        guard let plugin = pluginInstances[id] else { throw PluginError.notLoaded }
        try await plugin.unload()
        pluginInstances.removeValue(forKey: id)
        loadedPlugins.removeAll { $0.id == id }
        try sandbox.removeProfile(for: id)
        activePluginCount = loadedPlugins.count
    }

    func executePluginCommand(pluginId: String, command: String, arguments: [String]) async throws -> String {
        guard let plugin = pluginInstances[pluginId] else { throw PluginError.notLoaded }
        return try await plugin.executeCommand(command, arguments: arguments)
    }

    func sendEventToPlugin(pluginId: String, event: PluginEvent) async throws {
        guard let plugin = pluginInstances[pluginId] else { throw PluginError.notLoaded }
        try await plugin.handleEvent(event)
        totalEventCount += 1
    }

    func broadcastEvent(_ event: PluginEvent) async {
        for (id, plugin) in pluginInstances where plugin.isActive {
            do {
                try await plugin.handleEvent(event)
                totalEventCount += 1
            } catch {
                pluginErrors[id] = error.localizedDescription
            }
        }
    }

    func pluginInstances() -> [PluginProtocol] { Array(pluginInstances.values) }

    private func readManifest(from url: URL) throws -> PluginManifest {
        let manifestURL = url.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder.flye.decode(PluginManifest.self, from: data)
    }

    private func instantiatePlugin(manifest: PluginManifest, from url: URL) throws -> PluginProtocol {
        guard let pluginURL = pluginURLs[manifest.id] else { throw PluginError.loadFailed }
        let binaryURL = pluginURL.appendingPathComponent(manifest.entryPoint)
        guard FileManager.default.fileExists(atPath: binaryURL.path) else { throw PluginError.loadFailed }
        return try SandboxManager.loadPluginBinary(at: binaryURL, manifest: manifest)
    }

    private func setupPluginDirectories() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        pluginDirectories = [paths[0].appendingPathComponent("SYSTEMFLYE/Plugins", isDirectory: true)]
        for dir in pluginDirectories {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func setupEventSubscription() {
        eventBus.subscribe(name: "plugin.event") { [weak self] (event: PluginEvent) in
            Task { await self?.broadcastEvent(event) }
        }
    }
}

@MainActor
final class SandboxManager {
    static func applyProfile(_ profile: String, for pluginId: String) throws {
        let sandboxDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SYSTEMFLYE/Plugins/\\(pluginId)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandboxDir, withIntermediateDirectories: true)
    }

    static func removeProfile(for pluginId: String) throws {
        let sandboxDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SYSTEMFLYE/Plugins/\\(pluginId)", isDirectory: true)
        try? FileManager.default.removeItem(at: sandboxDir)
    }

    static func loadPluginBinary(at url: URL, manifest: PluginManifest) throws -> PluginProtocol {
        struct PlaceholderPlugin: PluginProtocol {
            let manifest: PluginManifest
            var isActive: Bool = false
            func load() async throws {}
            func unload() async throws {}
            func handleEvent(_ event: PluginEvent) async throws {}
            func executeCommand(_ command: String, arguments: [String]) async throws -> String { "not_implemented" }
        }
        return PlaceholderPlugin(manifest: manifest)
    }
}
