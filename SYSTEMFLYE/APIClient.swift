import Foundation
import Combine

// MARK: - API Client Protocol
protocol ForexAPIProvider {
    func fetchPrices(for pairs: [String]) async throws -> [String: Double]
    func fetchHistoricalData(pair: String, timeframe: String, limit: Int) async throws -> [PriceData]
    func getMarketStatus() async throws -> MarketStatus
}

// MARK: - Market Status
struct MarketStatus: Codable {
    let isOpen: Bool
    let currentTime: Date
    let nextOpenTime: Date?
    let nextCloseTime: Date?
    let region: String
}

// MARK: - OANDA API Client
class OANDAClient: ForexAPIProvider {
    private let apiKey: String
    private let accountID: String
    private let baseURL = "https://api-fxpractice.oanda.com"
    
    init(apiKey: String, accountID: String) {
        self.apiKey = apiKey
        self.accountID = accountID
    }
    
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        let pairString = pairs.joined(separator: ",")
        var components = URLComponents(string: "\(baseURL)/v3/accounts/\(accountID)/pricing")
        components?.queryItems = [URLQueryItem(name: "instruments", value: pairString)]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, httpResponse) = try await FlyeHTTPClient.shared.data(for: request)
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let priceResponse = try decoder.decode(OANDAPriceResponse.self, from: data)
        
        var prices: [String: Double] = [:]
        for price in priceResponse.prices {
            let bid = Double(price.bids.first?.price ?? "0") ?? 0
            let ask = Double(price.asks.first?.price ?? "0") ?? 0
            let midPrice = (bid + ask) / 2
            prices[price.instrument] = midPrice
        }
        
        return prices
    }
    
    func fetchHistoricalData(pair: String, timeframe: String, limit: Int) async throws -> [PriceData] {
        var components = URLComponents(string: "\(baseURL)/v3/instruments/\(pair)/candles")
        components?.queryItems = [URLQueryItem(name: "granularity", value: timeframe), URLQueryItem(name: "count", value: String(limit))]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, httpResponse) = try await FlyeHTTPClient.shared.data(for: request)
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let candleResponse = try decoder.decode(OANDACandleResponse.self, from: data)
        
        return candleResponse.candles.map { candle in
            PriceData(
                id: "\(pair)-\(candle.time)",
                timestamp: candle.time,
                open: Double(candle.bid.o) ?? 0,
                high: Double(candle.bid.h) ?? 0,
                low: Double(candle.bid.l) ?? 0,
                close: Double(candle.bid.c) ?? 0,
                volume: candle.volume
            )
        }
    }
    
    func getMarketStatus() async throws -> MarketStatus {
        guard let url = URL(string: "\(baseURL)/v3/accounts/\(accountID)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, httpResponse) = try await FlyeHTTPClient.shared.data(for: request)
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let accountResponse = try decoder.decode(OANDAAccountResponse.self, from: data)
        
        return MarketStatus(
            isOpen: accountResponse.account.tradingStatus == "OPEN",
            currentTime: Date(),
            nextOpenTime: nil,
            nextCloseTime: nil,
            region: "US"
        )
    }
}

// MARK: - Twelve Data Client
class TwelveDataClient: ForexAPIProvider {
    private let apiKey: String
    private let baseURL = "https://api.twelvedata.com"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        let symbols = pairs.joined(separator: ",")
        let endpoint = "\(baseURL)/quote?symbol=\(symbols)&apikey=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        let (data, httpResponse) = try await FlyeHTTPClient.shared.data(for: URLRequest(url: url))
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let priceResponse = try decoder.decode(TwelveDataResponse.self, from: data)
        
        var prices: [String: Double] = [:]
        for quote in priceResponse.data {
            if let price = Double(quote.last) {
                prices[quote.symbol] = price
            }
        }
        
        return prices
    }
    
    func fetchHistoricalData(pair: String, timeframe: String, limit: Int) async throws -> [PriceData] {
        let endpoint = "\(baseURL)/time_series?symbol=\(pair)&interval=\(timeframe)&outputsize=\(limit)&apikey=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        let (data, httpResponse) = try await FlyeHTTPClient.shared.data(for: URLRequest(url: url))
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let timeSeriesResponse = try decoder.decode(TwelveDataTimeSeriesResponse.self, from: data)
        
        let formatter = ISO8601DateFormatter()
        
        return timeSeriesResponse.values.map { value in
            PriceData(
                id: "\(pair)-\(value.datetime)",
                timestamp: formatter.date(from: value.datetime) ?? Date(),
                open: Double(value.open) ?? 0,
                high: Double(value.high) ?? 0,
                low: Double(value.low) ?? 0,
                close: Double(value.close) ?? 0,
                volume: Int(value.volume) ?? 0
            )
        }
    }
    
    func getMarketStatus() async throws -> MarketStatus {
        // Simplified status - in production, implement proper market hours
        return MarketStatus(
            isOpen: isMarketOpen(),
            currentTime: Date(),
            nextOpenTime: nextMarketOpen(),
            nextCloseTime: nextMarketClose(),
            region: "US"
        )
    }
    
    private func isMarketOpen() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        // Forex markets open Sun 5pm-Fri 4pm EST
        if weekday == 1 { return hour >= 21 } // Sunday
        if weekday == 7 { return hour < 21 } // Friday (closes at 4pm EST = 9pm UTC = 21:00)
        return true // Mon-Fri open
    }
    
    private func nextMarketOpen() -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
        
        components.hour = 21 // 9pm UTC = 5pm EST
        if let nextOpen = calendar.date(from: components) {
            return nextOpen > Date() ? nextOpen : calendar.date(byAdding: .day, value: 1, to: nextOpen)
        }
        return nil
    }
    
    private func nextMarketClose() -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
        
        components.hour = 21 // 9pm UTC = 5pm EST
        return calendar.date(from: components)
    }
}

// MARK: - API Error Types
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case networkError(String)
    case authenticationError
    case rateLimitExceeded
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid"
        case .invalidResponse:
            return "The server response was invalid"
        case .decodingError:
            return "Failed to decode the response"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationError:
            return "Authentication failed. Check your API key."
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .serverError:
            return "Server error. Please try again later."
        }
    }
}

// MARK: - OANDA API Response Models
struct OANDAPriceResponse: Codable {
    struct Price: Codable {
        let instrument: String
        let bids: [PriceLevel]
        let asks: [PriceLevel]
        
        struct PriceLevel: Codable {
            let price: String
            let liquidity: Int
        }
    }
    
    let prices: [Price]
}

struct OANDACandleResponse: Codable {
    struct Candle: Codable {
        let time: Date
        let bid: OHLC
        let ask: OHLC
        let volume: Int
        
        struct OHLC: Codable {
            let o: String
            let h: String
            let l: String
            let c: String
        }
    }
    
    let candles: [Candle]
}

struct OANDAAccountResponse: Codable {
    struct Account: Codable {
        let tradingStatus: String
    }
    
    let account: Account
}

// MARK: - Twelve Data Response Models
struct TwelveDataResponse: Codable {
    struct Quote: Codable {
        let symbol: String
        let last: String
    }
    
    let data: [Quote]
}

struct TwelveDataTimeSeriesResponse: Codable {
    struct TimeSeries: Codable {
        let datetime: String
        let open: String
        let high: String
        let low: String
        let close: String
        let volume: String
    }
    
    let values: [TimeSeries]
}

// MARK: - API Client Manager
@MainActor
class APIClientManager: ObservableObject {
    static let shared = APIClientManager()
    @Published var provider: ForexAPIProvider?
    @Published var fallbackProvider: ForexAPIProvider?
    @Published var error: APIError?
    @Published var isConnected = false
    @Published private(set) var primaryProviderName = "Not configured"
    @Published private(set) var fallbackProviderName = "Not configured"
    @Published private(set) var lastSuccessfulProvider = "None"
    @Published private(set) var failoverCount = 0
    @Published var failoverEnabled = true
    private let credentials = SecureCredentialStore()
    
    enum ProviderType: Equatable {
        case oanda
        case twelveData
        case mock
    }
    
    func configure(with type: ProviderType, apiKey: String, accountID: String = "", asFallback: Bool = false) {
        let configured: ForexAPIProvider
        switch type {
        case .oanda: configured = OANDAClient(apiKey: apiKey, accountID: accountID)
        case .twelveData: configured = TwelveDataClient(apiKey: apiKey)
        case .mock: configured = MockAPIClient()
        }
        let name = type == .oanda ? "OANDA" : type == .twelveData ? "Twelve Data" : "Mock"
        if asFallback {
            fallbackProvider = configured
            fallbackProviderName = name
        } else {
            provider = configured
            primaryProviderName = name
        }
        isConnected = provider != nil
    }

    func saveCredentials(provider type: ProviderType, apiKey: String, accountID: String = "", asFallback: Bool = false) throws {
        let prefix = credentialPrefix(type: type, fallback: asFallback)
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw APIError.authenticationError }
        try credentials.save(apiKey, for: "\(prefix).apiKey")
        if type == .oanda { try credentials.save(accountID, for: "\(prefix).accountID") }
        configure(with: type, apiKey: apiKey, accountID: accountID, asFallback: asFallback)
    }

    func loadCredentialsFromKeychain() {
        let primary = loadCredential(type: .oanda, fallback: false) ?? loadCredential(type: .twelveData, fallback: false)
        let fallback = loadCredential(type: .twelveData, fallback: true) ?? loadCredential(type: .oanda, fallback: true)
        if let primary { configure(with: primary.type, apiKey: primary.apiKey, accountID: primary.accountID) }
        if let fallback { configure(with: fallback.type, apiKey: fallback.apiKey, accountID: fallback.accountID, asFallback: true) }
    }

    func clearCredentials(fallback: Bool) {
        for type in [ProviderType.oanda, .twelveData] {
            let prefix = credentialPrefix(type: type, fallback: fallback)
            credentials.delete("\(prefix).apiKey")
            credentials.delete("\(prefix).accountID")
        }
        if fallback { fallbackProvider = nil; fallbackProviderName = "Not configured" } else { provider = nil; primaryProviderName = "Not configured" }
        isConnected = provider != nil
    }

    func fetchPricesWithFailover(for pairs: [String]) async throws -> [String: Double] {
        guard let primary = provider else { throw APIError.authenticationError }
        do { let values = try await primary.fetchPrices(for: pairs); lastSuccessfulProvider = primaryProviderName; return values }
        catch {
            guard failoverEnabled, let fallback = fallbackProvider else { throw error }
            failoverCount += 1
            let values = try await fallback.fetchPrices(for: pairs)
            lastSuccessfulProvider = fallbackProviderName
            return values
        }
    }

    func fetchHistoricalWithFailover(pair: String, timeframe: String, limit: Int) async throws -> [PriceData] {
        guard let primary = provider else { throw APIError.authenticationError }
        do { let values = try await primary.fetchHistoricalData(pair: pair, timeframe: timeframe, limit: limit); lastSuccessfulProvider = primaryProviderName; return values }
        catch {
            guard failoverEnabled, let fallback = fallbackProvider else { throw error }
            failoverCount += 1
            let values = try await fallback.fetchHistoricalData(pair: pair, timeframe: timeframe, limit: limit)
            lastSuccessfulProvider = fallbackProviderName
            return values
        }
    }

    private func credentialPrefix(type: ProviderType, fallback: Bool) -> String {
        "forex.\(fallback ? "fallback" : "primary").\(type == .oanda ? "oanda" : "twelveData")"
    }

    private func loadCredential(type: ProviderType, fallback: Bool) -> (type: ProviderType, apiKey: String, accountID: String)? {
        let prefix = credentialPrefix(type: type, fallback: fallback)
        guard let storedKey = try? credentials.value(for: "\(prefix).apiKey"), let key = storedKey, !key.isEmpty else { return nil }
        let account = try? credentials.value(for: "\(prefix).accountID")
        return (type, key, account ?? "")
    }
    
    func testConnection() async {
        guard let provider = provider else {
            error = .authenticationError
            return
        }
        
        do {
            let status = try await provider.getMarketStatus()
            isConnected = true
            error = nil
        } catch let apiError as APIError {
            error = apiError
            isConnected = false
        } catch {
            self.error = .serverError
            isConnected = false
        }
    }
}

// MARK: - Mock API Client for Testing
class MockAPIClient: ForexAPIProvider {
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        for pair in pairs {
            prices[pair] = Double.random(in: 0.8...2.0)
        }
        return prices
    }
    
    func fetchHistoricalData(pair: String, timeframe: String, limit: Int) async throws -> [PriceData] {
        var data: [PriceData] = []
        var currentPrice = 1.2
        
        for i in 0..<limit {
            let timestamp = Date(timeIntervalSinceNow: TimeInterval(-i * 3600))
            let change = Double.random(in: -0.005...0.005)
            let newPrice = currentPrice * (1 + change)
            
            data.append(PriceData(
                id: "\(pair)-\(i)",
                timestamp: timestamp,
                open: currentPrice,
                high: max(currentPrice, newPrice),
                low: min(currentPrice, newPrice),
                close: newPrice,
                volume: Int.random(in: 100000...1000000)
            ))
            
            currentPrice = newPrice
        }
        
        return data.reversed()
    }
    
    func getMarketStatus() async throws -> MarketStatus {
        return MarketStatus(
            isOpen: true,
            currentTime: Date(),
            nextOpenTime: Date(timeIntervalSinceNow: 3600),
            nextCloseTime: Date(timeIntervalSinceNow: 86400),
            region: "US"
        )
    }
}
