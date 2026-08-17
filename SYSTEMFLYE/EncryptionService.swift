import Foundation
import CryptoKit
import Security

enum EncryptionError: LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case keychainError(OSStatus)
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Key generation failed."
        case .encryptionFailed: return "Encryption failed."
        case .decryptionFailed: return "Decryption failed."
        case .keychainError(let status): return "Keychain error: \\(status)"
        case .invalidKey: return "Invalid encryption key."
        }
    }
}

@MainActor
final class EncryptionService: ObservableObject {
    static let shared = EncryptionService()
    @Published private(set) var isEncryptionReady = false
    @Published private(set) var lastEncryptionDate: Date?

    private let symmetricKeyTag = "com.jvrboy.systemflye.symmetric.key"
    private var symmetricKey: SymmetricKey?
    private let keychain = KeychainService()

    private init() {
        loadOrGenerateKey()
    }

    func encrypt(_ data: Data) throws -> Data {
        guard let key = symmetricKey else { throw EncryptionError.invalidKey }
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(_ data: Data) throws -> Data {
        guard let key = symmetricKey else { throw EncryptionError.invalidKey }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else { throw EncryptionError.encryptionFailed }
        let encrypted = try encrypt(data)
        return encrypted.base64EncodedString()
    }

    func decryptString(_ string: String) throws -> String {
        guard let data = Data(base64Encoded: string) else { throw EncryptionError.decryptionFailed }
        let decrypted = try decrypt(data)
        guard let result = String(data: decrypted, encoding: .utf8) else { throw EncryptionError.decryptionFailed }
        return result
    }

    func hash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func hashString(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return hash(data)
    }

    func generateKeyPair() throws -> (privateKey: P256.KeyAgreement.PrivateKey, publicKey: P256.KeyAgreement.PublicKey) {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        return (privateKey, publicKey)
    }

    func performKeyExchange(privateKey: P256.KeyAgreement.PrivateKey, publicKey: P256.KeyAgreement.PublicKey) throws -> SharedSecret {
        return try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
    }

    func deriveSymmetricKey(from sharedSecret: SharedSecret) -> SymmetricKey {
        return sharedSecret.x963DerivedSymmetricKey(using: SHA256.self, sharedInfo: Data(), outputByteCount: 32)
    }

    func sign(data: Data, with privateKey: P256.Signing.PrivateKey) -> Data {
        let signature = try! privateKey.signature(for: data)
        return signature.rawRepresentation
    }

    func verify(data: Data, signature: Data, using publicKey: P256.Signing.PublicKey) -> Bool {
        guard let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else { return false }
        return publicKey.isValidSignature(sig, for: data)
    }

    private func loadOrGenerateKey() {
        if let existingKey = keychain.loadSymmetricKey(tag: symmetricKeyTag) {
            symmetricKey = existingKey
            isEncryptionReady = true
            return
        }
        do {
            let key = SymmetricKey(size: .bits256)
            symmetricKey = key
            keychain.saveSymmetricKey(key, tag: symmetricKeyTag)
            isEncryptionReady = true
        } catch {
            print("Key generation failed: \\(error)")
        }
    }

    func rotateKey() throws {
        guard let oldKey = symmetricKey else { return }
        let newKey = SymmetricKey(size: .bits256)
        symmetricKey = newKey
        keychain.saveSymmetricKey(newKey, tag: symmetricKeyTag)
        lastEncryptionDate = Date()
    }

    func certificatePinningPublicKeys() -> [SecKey]? {
        guard let certPath = Bundle.main.path(forResource: "SYSTEMFLYE", ofType: "cer") else { return nil }
        guard let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)) else { return nil }
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else { return nil }
        let policy = SecPolicyCreateSSL(true, nil)
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        guard status == errSecSuccess, let trust = trust else { return nil }
        var publicKeys: [SecKey] = []
        let count = SecTrustGetCertificateCount(trust)
        for i in 0..<count {
            if let cert = SecTrustGetCertificateAtIndex(trust, i),
               let key = SecCertificateCopyKey(cert) {
                publicKeys.append(key)
            }
        }
        return publicKeys.isEmpty ? nil : publicKeys
    }
}

extension SharedSecret {
    func hexString() -> String {
        let data = withUnsafeBytes { Data($0) }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}
