import Foundation
import Combine
import LocalAuthentication
import Security

enum AuthError: LocalizedError {
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed
    case tokenExpired
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable: return "Biometric authentication is not available on this device."
        case .biometricNotEnrolled: return "No biometrics are enrolled. Please set up Face ID or Touch ID."
        case .authenticationFailed: return "Authentication failed."
        case .tokenExpired: return "Authentication token has expired."
        case .invalidCredentials: return "Invalid username or password."
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var authToken: String?
    @Published private(set) var refreshToken: String?
    @Published private(set) var lastAuthDate: Date?
    @Published var requiresBiometric = true

    private let keychain = KeychainService()
    private let sessionExpiryInterval: TimeInterval = 3600
    private var refreshTask: Task<Void, Never>?

    struct User: Codable, Identifiable {
        let id: UUID
        let email: String
        let displayName: String
        let roles: [String]
        let preferences: UserPreferences
        let createdAt: Date
        let lastLoginAt: Date

        struct UserPreferences: Codable {
            var theme: String
            var defaultPair: String
            var notificationsEnabled: Bool
            var biometricEnabled: Bool
            var riskTolerance: Double
        }
    }

    private init() {
        restoreSession()
    }

    func login(email: String, password: String) async throws -> User {
        guard !email.isEmpty, !password.isEmpty else { throw AuthError.invalidCredentials }

        let credentials = ["email": email, "password": password]
        let request = APIRequest(endpoint: "https://api.systemflye.app/v1/auth/login", method: .post, headers: [:], body: credentials, queryItems: nil)
        let response: AuthResponse = try await APIClientManager.shared.send(request)

        authToken = response.token
        refreshToken = response.refreshToken
        lastAuthDate = Date()

        let user = User(
            id: UUID(uuidString: response.userId)!,
            email: email,
            displayName: response.displayName,
            roles: response.roles,
            preferences: UserPreferences(theme: "dark", defaultPair: "EUR/USD", notificationsEnabled: true, biometricEnabled: requiresBiometric, riskTolerance: 0.01),
            createdAt: Date(),
            lastLoginAt: Date()
        )
        currentUser = user
        isAuthenticated = true
        keychain.save(authToken!, forKey: "auth_token")
        keychain.save(refreshToken!, forKey: "refresh_token")
        keychain.save(try! JSONEncoder.flye.encode(user), forKey: "current_user")
        return user
    }

    func loginWithBiometrics() async throws -> User {
        guard isBiometricAvailable else { throw AuthError.biometricNotAvailable }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error.map { AuthError.biometricNotEnrolled } ?? AuthError.biometricNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access SYSTEM FLYE") { success, error in
                Task { @MainActor in
                    if success {
                        guard let token = self.keychain.loadString(forKey: "auth_token"),
                              let userData = self.keychain.loadData(forKey: "current_user"),
                              let user = try? JSONDecoder.flye.decode(User.self, from: userData) else {
                            continuation.resume(throwing: AuthError.tokenExpired)
                            return
                        }
                        self.authToken = token
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.lastAuthDate = Date()
                        continuation.resume(returning: user)
                    } else {
                        continuation.resume(throwing: error.map { AuthError.authenticationFailed } ?? AuthError.authenticationFailed)
                    }
                }
            }
        }
    }

    func logout() {
        keychain.delete(forKey: "auth_token")
        keychain.delete(forKey: "refresh_token")
        keychain.delete(forKey: "current_user")
        authToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshAuthToken() async throws {
        guard let refreshToken = refreshToken else { throw AuthError.tokenExpired }
        let request = APIRequest(endpoint: "https://api.systemflye.app/v1/auth/refresh", method: .post, headers: ["Authorization": "Bearer \\(refreshToken)"], body: nil, queryItems: nil)
        let response: AuthResponse = try await APIClientManager.shared.send(request)
        authToken = response.token
        self.refreshToken = response.refreshToken
        keychain.save(response.token, forKey: "auth_token")
        keychain.save(response.refreshToken, forKey: "refresh_token")
    }

    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private func restoreSession() {
        guard let token = keychain.loadString(forKey: "auth_token"),
              let userData = keychain.loadData(forKey: "current_user"),
              let user = try? JSONDecoder.flye.decode(User.self, from: userData),
              let lastDate = keychain.loadDate(forKey: "last_auth_date"),
              Date().timeIntervalSince(lastDate) < sessionExpiryInterval else { return }
        authToken = token
        currentUser = user
        isAuthenticated = true
        lastAuthDate = lastDate
    }
}

struct AuthResponse: Codable {
    let token: String
    let refreshToken: String
    let userId: String
    let displayName: String
    let roles: [String]
    let expiresIn: Int
}
