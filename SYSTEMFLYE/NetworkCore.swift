import Foundation
import Security

struct RequestPolicy: Sendable {
    var timeout: TimeInterval = 20
    var maxRetries = 3
    var baseDelay: TimeInterval = 0.6
}

actor FlyeHTTPClient {
    static let shared = FlyeHTTPClient()
    private let session: URLSession
    private let policy: RequestPolicy

    init(policy: RequestPolicy = RequestPolicy()) {
        self.policy = policy
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = policy.timeout
        configuration.timeoutIntervalForResource = policy.timeout + 10
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        for attempt in 0...policy.maxRetries {
            do {
                try Task.checkCancellation()
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                if http.statusCode == 401 || http.statusCode == 403 { throw APIError.authenticationError }
                if http.statusCode == 429 {
                    if attempt < policy.maxRetries { try await backoff(attempt) }
                    else { throw APIError.rateLimitExceeded }
                    continue
                }
                guard 200...299 ~= http.statusCode else {
                    if http.statusCode >= 500, attempt < policy.maxRetries { try await backoff(attempt); continue }
                    throw APIError.serverError
                }
                return (data, http)
            }             catch is CancellationError { throw CancellationError() }
            catch let error as APIError {
                switch error {
                case .authenticationError, .invalidURL, .invalidResponse, .decodingError:
                    throw error
                case .networkError, .rateLimitExceeded, .serverError:
                    lastError = error
                    if attempt < policy.maxRetries { try await backoff(attempt) }
                }
            }
            catch {
                lastError = error
                if attempt < policy.maxRetries { try await backoff(attempt) }
            }
        }
        throw lastError ?? APIError.networkError("The request could not be completed.")
    }

    private func backoff(_ attempt: Int) async throws {
        let delay = UInt64(policy.baseDelay * pow(2, Double(attempt)) * 1_000_000_000)
        try await Task.sleep(nanoseconds: delay)
    }
}

struct SecureCredentialStore {
    private let service = "com.systemflye.credentials"

    func save(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unavailable(status) }
    }

    func value(for key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.unavailable(status) }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case unavailable(OSStatus)
    var errorDescription: String? { "Secure credential storage is unavailable (\(code))." }
    private var code: OSStatus { if case .unavailable(let code) = self { return code }; return -1 }
}
