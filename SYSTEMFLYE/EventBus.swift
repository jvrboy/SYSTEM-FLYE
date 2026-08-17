import Foundation
import Combine

enum EventBusError: Error {
    case handlerNotFound
    case circularDependency
    case queueFull
}

struct Event: Identifiable, Codable {
    let id = UUID()
    let name: String
    let payload: Data
    let metadata: [String: String]
    let timestamp: Date
    let source: String
    let priority: EventPriority
    let ttl: TimeInterval?

    enum EventPriority: Int, Codable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
    }

    func isExpired() -> Bool {
        guard let ttl = ttl else { return false }
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

struct EventHandler<T: Decodable>: Identifiable {
    let id = UUID()
    let name: String
    let queue: DispatchQueue
    let handler: (T) -> Void
    let filter: ((Event) -> Bool)?
    let once: Bool
    var isActive: Bool = true
}

@MainActor
final class EventBus: ObservableObject {
    static let shared = EventBus()
    @Published private(set) var eventCount = 0
    @Published private(set) var droppedEvents = 0
    @Published private(set) var handlerCount = 0
    @Published private(set) var recentEvents: [Event] = []

    private var handlers: [String: [AnyEventHandler]] = [:]
    private var eventQueue: [Event] = []
    private let maxQueueSize = 1000
    private let maxRecentEvents = 100
    private let processingQueue = DispatchQueue(label: "event.bus", qos: .userInitiated, attributes: .concurrent)
    private let deliveryQueue = DispatchQueue(label: "event.delivery", qos: .userInitiated, attributes: .concurrent)
    private var deliveryTask: Task<Void, Never>?
    private var isProcessing = false

    private init() {
        startDeliveryLoop()
    }

    func publish<T: Codable>(_ event: T, name: String, priority: Event.EventPriority = .normal, ttl: TimeInterval? = 60, metadata: [String: String] = [:], source: String = "unknown") {
        let payload = (try? JSONEncoder.flye.encode(event)) ?? Data()
        let event = Event(name: name, payload: payload, metadata: metadata, timestamp: Date(), source: source, priority: priority, ttl: ttl)
        processingQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.eventQueue.count >= self.maxQueueSize {
                self.droppedEvents += 1
                return
            }
            self.eventQueue.append(event)
            self.eventQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        }
        Task { @MainActor in
            self.eventCount += 1
            self.recentEvents = Array(self.eventQueue.prefix(self.maxRecentEvents))
        }
    }

    func subscribe<T: Codable>(name: String, queue: DispatchQueue = .main, filter: ((Event) -> Bool)? = nil, once: Bool = false, handler: @escaping (T) -> Void) -> UUID {
        let wrapper = AnyEventHandler { event in
            guard let data = event.payload as? Data, let decoded = try? JSONDecoder.flye.decode(T.self, from: data) else { return }
            handler(decoded)
        }
        handlers[name, default: []].append(wrapper)
        handlerCount = handlers.values.reduce(0) { $0 + $1.count }
        return wrapper.id
    }

    func unsubscribe(_ handlerId: UUID, from eventName: String) {
        handlers[eventName]?.removeAll { $0.id == handlerId }
        handlerCount = handlers.values.reduce(0) { $0 + $1.count }
    }

    func unsubscribeAll(for eventName: String) {
        handlers.removeValue(forKey: eventName)
        handlerCount = handlers.values.reduce(0) { $0 + $1.count }
    }

    func clearQueue() {
        processingQueue.async(flags: .barrier) { [weak self] in
            self?.eventQueue.removeAll()
        }
    }

    func pauseDelivery() { isProcessing = false }
    func resumeDelivery() { isProcessing = true }

    private func startDeliveryLoop() {
        deliveryTask?.cancel()
        deliveryTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                await deliverEvents()
            }
        }
    }

    private func deliverEvents() async {
        guard isProcessing else { return }
        let events: [Event]
        processingQueue.sync { events = eventQueue; eventQueue.removeAll() }
        for event in events {
            guard !event.isExpired() else { continue }
            let handlerList = handlers[event.name] ?? []
            await withTaskGroup(of: Void.self) { group in
                for handler in handlerList where handler.isActive {
                    group.addTask { [weak handler] in
                        handler?.handle(event)
                    }
                }
            }
        }
    }
}

class AnyEventHandler {
    let id: UUID
    let handle: (Event) -> Void
    var isActive: Bool = true

    init(handle: @escaping (Event) -> Void) {
        self.id = UUID()
        self.handle = handle
    }
}
