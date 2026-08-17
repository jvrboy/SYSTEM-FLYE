import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedData
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound: return "Keychain item not found."
        case .duplicateItem: return "Keychain item already exists."
        case .unexpectedData: return "Unexpected data in keychain."
        case .status(let status): return "Keychain error: \\(status)"
        }
    }
}

@MainActor
final class KeychainService: ObservableObject {
    static let shared = KeychainService()
    @Published private(set) var itemCount = 0

    private let serviceName = "com.jvrboy.systemflye"
    private let accessGroup = "\\(Bundle.main.bundleIdentifier ?? "systemflye")"

    private init() {
        countItems()
    }

    func save(_ value: String, forKey key: String, accessibility: CFString = kSecAttrAccessibleWhenUnlocked) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.unexpectedData }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\\\(serviceName)",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        countItems()
    }

    func save(_ data: Data, forKey key: String, accessibility: CFString = kSecAttrAccessibleWhenUnlocked) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\\\(serviceName)",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        countItems()
    }

    func loadString(forKey key: String) -> String? {
        guard let data = loadData(forKey: key), let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\\\(serviceName)",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    func saveSymmetricKey(_ key: SymmetricKey, tag: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let tagData = tag.data(using: .utf8)!
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeAES,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrApplicationTag as String: tagData,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(attributes as CFDictionary)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    func loadSymmetricKey(tag: String) -> SymmetricKey? {
        let tagData = tag.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    func saveDate(_ date: Date, forKey key: String) throws {
        let data = try JSONEncoder.flye.encode(date)
        try save(data, forKey: key)
    }

    func loadDate(forKey key: String) -> Date? {
        guard let data = loadData(forKey: key) else { return nil }
        return try? JSONDecoder.flye.decode(Date.self, from: data)
    }

    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\\\(serviceName)",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        countItems()
    }

    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\\\(serviceName)"
        ]
        SecItemDelete(query as CFDictionary)
        countItems()
    }

    func allKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\\\(serviceName)",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    private func countItems() {
        itemCount = allKeys().count
    }
}
