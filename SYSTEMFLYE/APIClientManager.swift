import Foundation
import Combine
import Security

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case unauthorized
    case rateLimited
    case serverError(Int)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The request URL is invalid."
        case .networkError(let error): return "Network error: \\(error.localizedDescription)"
        case .decodingError(let error): return "Response decoding failed: \\(error.localizedDescription)"
        case .unauthorized: return "Authentication required."
        case .rateLimited: return "Too many requests. Please try again later."
        case .serverError(let code): return "Server error: HTTP \\(code)"
        case .unknown: return "An unknown error occurred."
        }
    }
}

struct APIRequest<T: Codable> {
    let endpoint: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: T?
    let queryItems: [URLQueryItem]?

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
}

@MainActor
final class APIClientManager: ObservableObject {
    static let shared = APIClientManager()
    @Published private(set) var isOnline = true
    @Published private(set) var lastSync: Date?
    @Published private(set) var pendingRequests = 0
    @Published private(set) var failedRequests = 0

    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()
    private var requestInterceptor: RequestInterceptor?
    private var responseInterceptor: ResponseInterceptor?

    struct RequestInterceptor {
        let willSend: (inout URLRequest) -> Void
    }

    struct ResponseInterceptor {
        let didReceive: (URLResponse, Data) throws -> Data
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        session = URLSession(configuration: config)
        setupNetworkMonitoring()
    }

    func send<T: Codable>(_ request: APIRequest<T>) async throws -> T {
        guard isOnline else { throw APIError.networkError(NSError(domain: "offline", code: -1)) }
        guard let url = URL(string: request.endpoint) else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = defaultHeaders()
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        if let body = request.body { urlRequest.httpBody = try encoder.encode(body) }
        if let items = request.queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = items
            urlRequest.url = components?.url
        }

        requestInterceptor?.willSend(&urlRequest)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            let processedData = try responseInterceptor?.didReceive(response, data) ?? data
            guard let httpResponse = response as? HTTPURLResponse else { throw APIError.unknown }
            guard 200..<300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 401 { throw APIError.unauthorized }
                if httpResponse.statusCode == 429 { throw APIError.rateLimited }
                throw APIError.serverError(httpResponse.statusCode)
            }
            return try decoder.decode(T.self, from: processedData)
        } catch let error as APIError { throw error }
        catch { throw APIError.networkError(error) }
    }

    func upload<T: Codable>(_ request: APIRequest<T>, fileData: Data, mimeType: String, fieldName: String = "file") async throws -> T {
        guard let url = URL(string: request.endpoint) else { throw APIError.invalidURL }
        let boundary = "Boundary-\\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\\(boundary)\\r\\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\\"\\(fieldName)\\"; filename=\\"file\\"\\r\\n".data(using: .utf8)!)
        body.append("Content-Type: \\(mimeType)\\r\\n\\r\\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\\r\\n".data(using: .utf8)!)
        body.append("--\\(boundary)--\\r\\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try decoder.decode(T.self, from: data)
    }

    func download(url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = defaultHeaders()
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return (data, response)
    }

    func setRequestInterceptor(_ interceptor: RequestInterceptor?) { requestInterceptor = interceptor }
    func setResponseInterceptor(_ interceptor: ResponseInterceptor?) { responseInterceptor = interceptor }

    private func defaultHeaders() -> [String: String] {
        var headers: [String: String] = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "SYSTEM-FLYE/1.0 (iOS)",
            "X-Requested-With": "XMLHttpRequest"
        ]
        return headers
    }

    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                self?.pendingRequests = max(0, self?.pendingRequests ?? 0)
            }
        }
        let queue = DispatchQueue(label: "network.monitor")
        monitor.start(queue: queue)
    }
}

extension Data {
    mutating func append(_ string: String) { append(string.data(using: .utf8)!) }
}
