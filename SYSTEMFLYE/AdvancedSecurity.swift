import Foundation
import LocalAuthentication
import Security
import CryptoKit

// MARK: - Biometric Gate
actor BiometricGate {
    static let shared = BiometricGate()
    private let context = LAContext()
    
    func authenticate(reason: String = "Authenticate to access advanced features") async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                continuation.resume(returning: success)
            }
        }
    }
    
    func canEvaluate() -> Bool { context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) }
    func biometryType: LABiometryType { context.biometryType }
}

// MARK: - Encrypted Storage
actor EncryptedStorage {
    static let shared = EncryptedStorage()
    private let keyTag = "com.systemflye.encryption.key"
    
    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }
    
    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    func encryptString(_ string: String) throws -> Data { try encrypt(Data(string.utf8)) }
    func decryptString(_ data: Data) throws -> String { String(try decrypt(data)) }
    
    private func getOrCreateKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyTag,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keyTag,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData
        ]
        SecItemDelete(addQuery as CFDictionary)
        guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else { throw KeychainError.unavailable(errSecInteractionNotAllowed) }
        return key
    }
}

// MARK: - Certificate Pinning
actor CertificatePinner {
    static let shared = CertificatePinner()
    private let pinnedHashes: Set<String> = []
    
    func pin(hash: String) { /* store pinned hash */ }
    func validate(serverTrust: SecTrust, for host: String) async -> Bool {
        var result = SecTrustResultType.invalid
        SecTrustEvaluate(serverTrust, &result)
        return result == .unspecified || result == .proceed
    }
}

// MARK: - Secure Data Wipe
actor SecureWiper {
    static let shared = SecureWiper()
    
    func wipeData(_ data: inout Data) {
        data.withUnsafeMutableBytes { buffer in
            memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
        }
    }
    
    func wipeFile(at url: URL) throws {
        guard let data = try? Data(contentsOf: url) else { return }
        var wiped = data
        wipeData(&wiped)
        try wiped.write(to: url)
        try FileManager.default.removeItem(at: url)
    }
}

// MARK: - Security Event Monitor
@MainActor
final class SecurityEventMonitor: ObservableObject {
    static let shared = SecurityEventMonitor()
    @Published private(set) var events: [SecurityEvent] = []
    @Published private(set) var authStatus: AuthStatus = .unknown
    
    enum AuthStatus { case unknown, authenticated, failed, locked }
    
    struct SecurityEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EventType
        let description: String
        let severity: Severity
        
        enum EventType { case biometricAuth, pinVerified, dataAccessed, suspiciousActivity, keychainAccess }
        enum Severity: String { case info, warning, critical }
    }
    
    func recordEvent(type: SecurityEvent.EventType, description: String, severity: SecurityEvent.Severity = .info) {
        let event = SecurityEvent(timestamp: Date(), type: type, description: description, severity: severity)
        events.insert(event, at: 0)
        if events.count > 100 { events.removeLast() }
    }
    
    func updateAuthStatus(_ status: AuthStatus) { authStatus = status }
}
