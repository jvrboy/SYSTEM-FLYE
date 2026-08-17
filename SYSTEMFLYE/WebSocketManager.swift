import Foundation
import Combine

enum WebSocketError: LocalizedError {
    case connectionFailed
    case messageSendFailed
    case invalidState
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "WebSocket connection failed."
        case .messageSendFailed: return "Failed to send message."
        case .invalidState: return "WebSocket is in an invalid state."
        case .authenticationFailed: return "WebSocket authentication failed."
        }
    }
}

@MainActor
final class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastMessage: Date?
    @Published private(set) var messageCount = 0
    @Published private(set) var reconnectAttempts = 0

    enum ConnectionState: String {
        case connected = "CONNECTED"
        case connecting = "CONNECTING"
        case disconnected = "DISCONNECTED"
        case failed = "FAILED"
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeartTimer: Timer?
    private let pingInterval: TimeInterval = 30
    private let maxReconnectAttempts = 5
    private let reconnectBaseDelay: TimeInterval = 1.0
    private var messageHandlers: [String: (Any) -> Void] = [:]
    private var isManualDisconnect = false

    private init() {}

    func connect(url: URL, protocols: [String] = []) {
        guard connectionState != .connected else { return }
        connectionState = .connecting
        isManualDisconnect = false

        var request = URLRequest(url: url)
        request.setValue("SYSTEM-FLYE/1.0", forHTTPHeaderField: "User-Agent")
        if let token = AuthService.shared.authToken {
            request.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")
        }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: OperationQueue.main)

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessage()
        startHeartbeat()
        connectionState = .connected
        reconnectAttempts = 0
    }

    func disconnect() {
        isManualDisconnect = true
        heartbeartTimer?.invalidate()
        heartbeartTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    func send<T: Codable>(_ message: T, channel: String = "default") async throws {
        guard connectionState == .connected, let task = webSocketTask else { throw WebSocketError.invalidState }
        let payload: [String: Any] = ["channel": channel, "data": try JSONSerialization.jsonObject(with: JSONEncoder.flye.encode(message))]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let message = URLSessionWebSocketTask.Message.data(data)
        try await task.send(message)
        messageCount += 1
        lastMessage = Date()
    }

    func sendRaw(_ string: String) async throws {
        guard connectionState == .connected, let task = webSocketTask else { throw WebSocketError.invalidState }
        try await task.send(.string(string))
        messageCount += 1
        lastMessage = Date()
    }

    func on<T: Codable>(channel: String, handler: @escaping (T) -> Void) {
        messageHandlers[channel] = { any in
            guard let dict = any as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: dict),
                  let decoded = try? JSONDecoder.flye.decode(T.self, from: data) else { return }
            handler(decoded)
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.lastMessage = Date()
                self.messageCount += 1
                switch message {
                case .data(let data):
                    self.processIncomingData(data)
                case .string(let string):
                    self.processIncomingString(string)
                @unknown default: break
                }
                self.receiveMessage()
            case .failure(let error):
                self.handleDisconnection(error: error)
            }
        }
    }

    private func processIncomingData(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = json["channel"] as? String,
              let payload = json["data"] else { return }
        if let handler = messageHandlers[channel] {
            handler(payload)
        }
    }

    private func processIncomingString(_ string: String) {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = json["channel"] as? String,
              let payload = json["data"] else { return }
        if let handler = messageHandlers[channel] {
            handler(payload)
        }
    }

    private func handleDisconnection(error: Error) {
        connectionState = .failed
        heartbeartTimer?.invalidate()
        heartbeartTimer = nil
        if !isManualDisconnect && reconnectAttempts < maxReconnectAttempts {
            scheduleReconnect()
        } else {
            connectionState = .disconnected
        }
    }

    private func startHeartbeat() {
        heartbeartTimer?.invalidate()
        heartbeartTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.webSocketTask?.sendPing(pong: { error in
                    if let error = error {
                        self?.handleDisconnection(error: error)
                    }
                })
            }
        }
    }

    private func scheduleReconnect() {
        reconnectAttempts += 1
        let delay = reconnectBaseDelay * pow(2.0, Double(reconnectAttempts - 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isManualDisconnect, self.reconnectAttempts <= self.maxReconnectAttempts else { return }
            self.connect(url: URL(string: "wss://api.systemflye.app/ws")!)
        }
    }
}
