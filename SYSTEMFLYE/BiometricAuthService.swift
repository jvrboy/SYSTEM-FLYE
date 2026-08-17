import Foundation
import LocalAuthentication
import Security
import Combine

// MARK: - Biometric Errors

enum BiometricError: LocalizedError {
    case notAvailable
    case lockout
    case userCancel
    case fallbackRequired
    case systemCancel
    case passcodeNotSet
    case biometryNotEnrolled
    case biometryNotSupported
    case authenticationFailed(String)
    case invalidContext

    var errorDescription: String? {
        switch self {
        case .notAvailable: "Biometric authentication is not available."
        case .lockout: "Biometric authentication is locked out."
        case .userCancel: "User cancelled biometric authentication."
        case .fallbackRequired: "Fallback authentication is required."
        case .systemCancel: "System cancelled biometric authentication."
        case .passcodeNotSet: "Passcode is not set on device."
        case .biometryNotEnrolled: "Biometrics are not enrolled."
        case .biometryNotSupported: "Biometry is not supported on this device."
        case .authenticationFailed(let msg): "Authentication failed: \(msg)"
        case .invalidContext: "Invalid LAContext."
        }
    }
}

// MARK: - Biometric Type

enum BiometricType: String, Codable, Sendable {
    case none = "NONE"
    case touchID = "TOUCH_ID"
    case faceID = "FACE_ID"
    case opticID = "OPTIC_ID"
    case unknown = "UNKNOWN"
}

// MARK: - Auth Mode

enum AuthMode: String, Codable, Sendable {
    case biometric = "BIOMETRIC"
    case passcode = "PASSCODE"
    case devicePasscode = "DEVICE_PASSCODE"
    case fallback = "FALLBACK"
    case disabled = "DISABLED"
}

// MARK: - Biometric Configuration

struct BiometricConfiguration: Codable, Sendable {
    let policy: LAPolicy
    let allowFallback: Bool
    let maxAttempts: Int
    let lockoutDuration: TimeInterval
    let trackingEnabled: Bool
    let reason: String
    let domainStatePersistenceEnabled: Bool
    let keychainAccessControl: BiometricKeychainAccessControl
    let notificationOnLockout: Bool

    enum BiometricKeychainAccessControl: String, Codable, Sendable {
        case userPresence = "USER_PRESENCE"
        case biometricAny = "BIOMETRIC_ANY"
        case biometricCurrentSet = "BIOMETRIC_CURRENT_SET"
        case devicePasscode = "DEVICE_PASSCODE"
        case applicationPassword = "APPLICATION_PASSWORD"
    }

    static let `default` = BiometricConfiguration(
        policy: .deviceOwnerAuthenticationWithBiometrics,
        allowFallback: true,
        maxAttempts: 5,
        lockoutDuration: 300,
        trackingEnabled: true,
        reason: "Authenticate to access SYSTEM FLYE.",
        domainStatePersistenceEnabled: true,
        keychainAccessControl: .biometricAny,
        notificationOnLockout: true
    )
}

// MARK: - Biometric Event

struct BiometricEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let biometricType: BiometricType
    let success: Bool
    let failureReason: String?
    let duration: TimeInterval
    let deviceId: String

    enum EventType: String, Codable, Sendable {
        case authentication = "AUTHENTICATION"
        case enrollmentChange = "ENROLLMENT_CHANGE"
        case lockout = "LOCKOUT"
        case unlock = "UNLOCK"
        case fallbackUsed = "FALLBACK_USED"
        case policyEvaluation = "POLICY_EVALUATION"
    }
}

// MARK: - Biometric Auth Service

@MainActor
final class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var isLockedOut: Bool = false
    @Published private(set) var lockoutUntil: Date?
    @Published private(set) var authenticationAttempts: Int = 0
    @Published private(set) var lastAuthenticationAt: Date?
    @Published private(set) var lastAuthenticationSucceeded: Bool?
    @Published private(set) var events: [BiometricEvent] = []
    @Published private(set) var currentAuthMode: AuthMode = .disabled
    @Published private(set) var domainState: Data?
    @Published private(set) var enrollmentStatus: EnrollmentStatus = .unknown

    enum EnrollmentStatus: String, Codable, Sendable {
        case unknown = "UNKNOWN"
        case enrolled = "ENROLLED"
        case notEnrolled = "NOT_ENROLLED"
        case multiple = "MULTIPLE"
    }

    private let configuration: BiometricConfiguration
    private let context = LAContext()
    private let logger = StructuredLogger.shared
    private let lock = NSLock()
    private let keychainAccessControl: SecAccessControl?
    private var cachedDomainState: Data?
    private let eventsStore = EventStore()

    init(configuration: BiometricConfiguration = .default) {
        self.configuration = configuration
        evaluateBiometricPolicy()
        setupKeychainAccessControl()
        loadDomainState()
        startMonitoring()
    }

    // MARK: - Biometric Policy

    private func evaluateBiometricPolicy() {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(configuration.policy, error: &error)
        if canEvaluate {
            biometricType = {
                switch context.biometryType {
                case .faceID: return .faceID
                case .touchID: return .touchID
                case .opticID: return .opticID
                default: return .unknown
                }
            }()
            isAvailable = true
            enrollmentStatus = .enrolled
            currentAuthMode = .biometric
        } else {
            biometricType = .none
            isAvailable = false
            if let nsError = error as NSError? {
                switch nsError.code {
                case LAError.biometryNotAvailable.rawValue:
                    enrollmentStatus = .notEnrolled
                case LAError.biometryNotEnrolled.rawValue:
                    enrollmentStatus = .notEnrolled
                case LAError.passcodeNotSet.rawValue:
                    enrollmentStatus = .unknown
                    currentAuthMode = .passcode
                default:
                    enrollmentStatus = .unknown
                }
            }
        }
    }

    // MARK: - Keychain Access Control

    private func setupKeychainAccessControl() {
        var accessControl: SecAccessControl?
        let flags: SecAccessControlCreateFlags = switch configuration.keychainAccessControlControl {
        case .userPresence: .userPresence
        case .biometricAny: .biometryAny
        case .biometricCurrentSet: .biometryCurrentSet
        case .devicePasscode: .devicePasscode
        case .applicationPassword: .applicationPassword
        }
        accessControl = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as CFString, flags, nil)
        self.keychainAccessControl = accessControl
    }

    // MARK: - Domain State

    private func loadDomainState() {
        if configuration.domainStatePersistenceEnabled {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SYSTEMFLYE/biometric-domain-state.dat")
            if let data = try? Data(contentsOf: url) {
                domainState = data
                cachedDomainState = data
            }
        }
        context.evaluatedPolicyDomainState.andThen { state in
            domainState = state
            cachedDomainState = state
        }
    }

    // MARK: - Authentication

    func authenticate(reason: String? = nil, fallbackTitle: String? = nil) async throws -> BiometricResult {
        guard isAvailable else { throw BiometricError.notAvailable }
        guard !isLockedOut else { throw BiometricError.lockout }

        let authReason = reason ?? configuration.reason
        let startTime = Date()
        currentAuthMode = .biometric

        return try await withCheckedThrowingContinuation { continuation in
            context.localizedFallbackTitle = fallbackTitle ?? "Enter Passcode"
            context.evaluatePolicy(configuration.policy, localizedReason: authReason) { [weak self] success, error in
                guard let self = self else { continuation.resume(returning: .failure(.invalidContext)); return }
                let duration = Date().timeIntervalSince(startTime)
                let event = BiometricEvent(
                    id: UUID(),
                    timestamp: Date(),
                    eventType: .authentication,
                    biometricType: self.biometricType,
                    success: success,
                    failureReason: error?.localizedDescription,
                    duration: duration,
                    deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                )
                self.recordEvent(event)

                if success {
                    Task { @MainActor in
                        self.lastAuthenticationAt = Date()
                        self.lastAuthenticationSucceeded = true
                        self.authenticationAttempts = 0
                        self.isLockedOut = false
                        self.lockoutUntil = nil
                        self.currentAuthMode = .biometric
                    }
                    continuation.resume(returning: .success)
                } else {
                    self.handleAuthenticationFailure(error)
                    if let laError = error as? LAError {
                        switch laError.code {
                        case .userCancel, .userFallback:
                            continuation.resume(returning: .failure(.userCancel))
                        case .systemCancel:
                            continuation.resume(returning: .failure(.systemCancel))
                        case .passcodeNotSet:
                            continuation.resume(returning: .failure(.passcodeNotSet))
                        case .biometryNotAvailable, .biometryNotEnrolled:
                            continuation.resume(returning: .failure(.notAvailable))
                        case .biometryLockout:
                            continuation.resume(returning: .failure(.lockout))
                        default:
                            continuation.resume(returning: .failure(.authenticationFailed(error?.localizedDescription ?? "Unknown error")))
                        }
                    } else {
                        continuation.resume(returning: .failure(.authenticationFailed(error?.localizedDescription ?? "Unknown error")))
                    }
                }
            }
        }
    }

    private func handleAuthenticationFailure(_ error: Error?) {
        Task { @MainActor in
            authenticationAttempts += 1
            lastAuthenticationSucceeded = false
            if let laError = error as? LAError, laError.code == .biometryLockout {
                isLockedOut = true
                lockoutUntil = Date().addingTimeInterval(configuration.lockoutDuration)
                currentAuthMode = .fallback
            } else if authenticationAttempts >= configuration.maxAttempts {
                isLockedOut = true
                lockoutUntil = Date().addingTimeInterval(configuration.lockoutDuration)
            }
        }
    }

    enum BiometricResult {
        case success
        case failure(BiometricError)
    }

    // MARK: - Fallback

    func requestDevicePasscode() async throws -> BiometricResult {
        guard configuration.allowFallback else { throw BiometricError.fallbackRequired }
        let startTime = Date()
        currentAuthMode = .devicePasscode
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enter your device passcode") { [weak self] success, error in
                guard let self = self else { continuation.resume(returning: .failure(.invalidContext)); return }
                let duration = Date().timeIntervalSince(startTime)
                let event = BiometricEvent(
                    id: UUID(),
                    timestamp: Date(),
                    eventType: .fallbackUsed,
                    biometricType: self.biometricType,
                    success: success,
                    failureReason: error?.localizedDescription,
                    duration: duration,
                    deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                )
                self.recordEvent(event)
                if success {
                    Task { @MainActor in
                        self.lastAuthenticationAt = Date()
                        self.lastAuthenticationSucceeded = true
                        self.authenticationAttempts = 0
                        self.isLockedOut = false
                    }
                    continuation.resume(returning: .success)
                } else {
                    continuation.resume(returning: .failure(.authenticationFailed(error?.localizedDescription ?? "Passcode authentication failed")))
                }
            }
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        NotificationCenter.default.addObserver(forName: .LAContextChange, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.evaluateBiometricPolicy() }
        }
    }

    // MARK: - Event Recording

    private func recordEvent(_ event: BiometricEvent) {
        lock.lock()
        events.insert(event, at: 0)
        if events.count > 200 { events.removeLast() }
        lock.unlock()
        if configuration.trackingEnabled {
            Task { try? await eventsStore.append(event) }
        }
        logger.log(.debug, category: "biometric", message: "Event: \(event.eventType.rawValue), success: \(event.success)")
    }

    // MARK: - Access Control

    func keychainAccessControl() -> SecAccessControl? { keychainAccessControl }

    // MARK: - Lockout Management

    func clearLockout() {
        isLockedOut = false
        lockoutUntil = nil
        authenticationAttempts = 0
        currentAuthMode = isAvailable ? .biometric : .fallback
    }

    // MARK: - Diagnostics

    func exportDiagnostics() -> [String: Any] {
        [
            "biometricType": biometricType.rawValue,
            "isAvailable": isAvailable,
            "isLockedOut": isLockedOut,
            "lockoutUntil": lockoutAt.map { DateFormatter.ISO8601Formatter.string(from: $0) } ?? "none",
            "authenticationAttempts": authenticationAttempts,
            "currentAuthMode": currentAuthMode.rawValue,
            "enrollmentStatus": enrollmentStatus.rawValue,
            "lastAuthenticationSucceeded": lastAuthenticationSucceeded as Any,
            "eventCount": events.count,
            "policy": configuration.policy == .deviceOwnerAuthentication ? "deviceOwner" : "biometrics"
        ]
    }
}

// MARK: - Event Store

actor EventStore: Sendable {
    static let shared = EventStore()
    private var events: [BiometricEvent] = []
    private let lock = NSLock()

    func append(_ event: BiometricEvent) {
        lock.lock()
        events.insert(event, at: 0)
        if events.count > 1000 { events.removeLast() }
        lock.unlock()
    }

    func all() -> [BiometricEvent] {
        lock.sync { events }
    }

    func clear() {
        lock.sync { events.removeAll() }
    }
}

// MARK: - Codable Extensions

extension JSONEncoder {
    static let flye: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let flye: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension DateFormatter {
    static let ISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Notification Extension

extension Notification.Name {
    static let LAContextChange = Notification.Name("LAContextChange")
}

// MARK: - SecAccessControlCreateFlags Extension

private extension BiometricConfiguration {
    var keychainAccessControlControl: SecAccessControlCreateFlags {
        switch keychainAccessControl {
        case .userPresence: return .userPresence
        case .biometricAny: return .biometryAny
        case .biometricCurrentSet: return .biometryCurrentSet
        case .devicePasscode: return .devicePasscode
        case .applicationPassword: return .applicationPassword
        }
    }
}
