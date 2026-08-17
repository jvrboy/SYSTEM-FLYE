import Foundation
import Combine
import StoreKit

enum UpdateError: LocalizedError {
    case appStoreUnavailable
    case noUpdateAvailable
    case downloadFailed
    case installationFailed

    var errorDescription: String? {
        switch self {
        case .appStoreUnavailable: return "App Store is unavailable."
        case .noUpdateAvailable: return "No update available."
        case .downloadFailed: return "Update download failed."
        case .installationFailed: return "Update installation failed."
        }
    }
}

enum UpdateState: String, Codable {
    case checking = "CHECKING"
    case available = "AVAILABLE"
    case downloading = "DOWNLOADING"
    case installing = "INSTALLING"
    case upToDate = "UP_TO_DATE"
    case failed = "FAILED"
}

struct AppVersion: Codable, Comparable, Identifiable {
    let id = UUID()
    let version: String
    let buildNumber: String
    let releaseNotes: String
    let minimumOSVersion: String
    let downloadSize: Int64
    let releaseDate: Date
    let isMandatory: Bool

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        return lhs.version.compare(rhs.version, options: .numeric) == .orderedAscending
    }
}

@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()
    @Published private(set) var currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    @Published private(set) var latestVersion: AppVersion?
    @Published private(set) var updateState: UpdateState = .upToDate
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var updateHistory: [AppVersion] = []

    private let checkInterval: TimeInterval = 86400
    private var checkTask: Task<Void, Never>?
    private let storage = DatabaseManager.shared
    private let appStoreURL = "https://api.systemflye.app/v1/updates"

    private init() {
        loadUpdateHistory()
        checkForUpdates()
        schedulePeriodicChecks()
    }

    func checkForUpdates() async {
        updateState = .checking
        do {
            let request = APIRequest(endpoint: appStoreURL, method: .get, headers: [:], body: nil, queryItems: [
                URLQueryItem(name: "platform", value: "ios"),
                URLQueryItem(name: "current_version", value: currentVersion),
                URLQueryItem(name: "build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            ])
            let response: UpdateResponse = try await APIClientManager.shared.send(request)
            if let latest = response.latestVersion, latest > parseVersion(currentVersion) {
                latestVersion = latest
                updateState = .available
                if latest.isMandatory {
                    promptMandatoryUpdate(latest)
                } else {
                    promptOptionalUpdate(latest)
                }
            } else {
                updateState = .upToDate
            }
        } catch {
            updateState = .failed
        }
    }

    func downloadUpdate() async throws {
        guard let version = latestVersion else { throw UpdateError.noUpdateAvailable }
        updateState = .downloading
        downloadProgress = 0

        let request = APIRequest(endpoint: "\\(appStoreURL)/download", method: .get, headers: [:], body: nil, queryItems: [
            URLQueryItem(name: "version", value: version.version),
            URLQueryItem(name: "platform", value: "ios")
        ])
        let (data, _) = try await APIClientManager.shared.download(url: URL(string: "\\(appStoreURL)/download?version=\\(version.version)")!)

        for i in 1...100 {
            downloadProgress = Double(i) / 100.0
            try await Task.sleep(for: .milliseconds(50))
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SYSTEMFLYE_Update")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let ipaURL = tempDir.appendingPathComponent("SYSTEMFLYE_\\(version.version).ipa")
        try data.write(to: ipaURL)

        updateState = .installing
        try await installUpdate(from: ipaURL)
    }

    func skipVersion(_ version: AppVersion) {
        var skipped = UserDefaults.standard.stringArray(forKey: "skipped_versions") ?? []
        skipped.append(version.version)
        UserDefaults.standard.set(skipped, forKey: "skipped_versions")
    }

    func isVersionSkipped(_ version: AppVersion) -> Bool {
        let skipped = UserDefaults.standard.stringArray(forKey: "skipped_versions") ?? []
        return skipped.contains(version.version)
    }

    private func installUpdate(from url: URL) async throws {
        #if targetEnvironment(simulator)
        throw UpdateError.installationFailed
        #else
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let activity = try? NSUserActivity(activityType: "com.apple.installapps") else {
            throw UpdateError.installationFailed
        }
        var controller: UIViewController?
        if #available(iOS 17.0, *) {
            let config = AppStore.UpdateConfiguration()
            config.isMandatory = latestVersion?.isMandatory ?? false
            controller = UIHostingController(rootView: AnyView(EmptyView()))
        }
        #endif
    }

    private func promptMandatoryUpdate(_ version: AppVersion) {
        let alert = UIAlertController(title: "Update Required", message: "Version \\(version.version) is required. \\(version.releaseNotes)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Update Now", style: .default) { _ in
            Task { try? await self.downloadUpdate() }
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let presenter = scene.windows.first?.rootViewController {
            presenter.present(alert, animated: true)
        }
    }

    private func promptOptionalUpdate(_ version: AppVersion) {
        guard !isVersionSkipped(version) else { return }
        let alert = UIAlertController(title: "Update Available", message: "Version \\(version.version) is available.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            Task { try? await self.downloadUpdate() }
        })
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        alert.addAction(UIAlertAction(title: "Skip", style: .destructive) { _ in
            self.skipVersion(version)
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let presenter = scene.windows.first?.rootViewController {
            presenter.present(alert, animated: true)
        }
    }

    private func schedulePeriodicChecks() {
        checkTask?.cancel()
        checkTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(checkInterval))
                await checkForUpdates()
            }
        }
    }

    private func loadUpdateHistory() {
        guard let data = UserDefaults.standard.data(forKey: "update_history"),
              let history = try? JSONDecoder.flye.decode([AppVersion].self, from: data) else { return }
        updateHistory = history
    }

    private func saveUpdateHistory() {
        guard let data = try? JSONEncoder.flye.encode(updateHistory) else { return }
        UserDefaults.standard.set(data, forKey: "update_history")
    }

    private func parseVersion(_ version: String) -> AppVersion {
        return AppVersion(version: version, buildNumber: "0", releaseNotes: "", minimumOSVersion: "17.0", downloadSize: 0, releaseDate: Date(), isMandatory: false)
    }
}

struct UpdateResponse: Codable {
    let latestVersion: AppVersion?
    let fetchedAt: Date
    let environment: String
}
