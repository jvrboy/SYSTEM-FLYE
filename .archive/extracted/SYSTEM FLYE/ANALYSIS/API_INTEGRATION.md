# Forex Analyzer - API Integration Guide

Complete guide to integrate real FOREX data APIs into your app.

## Table of Contents
1. [OANDA API](#oanda-api)
2. [Twelve Data API](#twelve-data-api)
3. [Alpha Vantage API](#alpha-vantage-api)
4. [Integration Patterns](#integration-patterns)

---

## OANDA API

### Overview
OANDA provides institutional-grade FOREX data and trading capabilities.

**Pros:**
- Real-time streaming prices
- Historical data with high granularity
- Demo accounts available
- Excellent documentation
- Practice trading without real money

**Cons:**
- Requires account registration
- Limited free tier (demo accounts)
- More complex authentication

### Setup Instructions

#### Step 1: Create Demo Account

1. Visit https://www.oanda.com
2. Sign up for a demo account
3. Confirm email
4. Log in to control panel

#### Step 2: Get API Credentials

1. Go to Account Settings → API
2. Generate API Token
3. Save Account ID (starts with "001-...")
4. Save API Token (keep secret!)

#### Step 3: Update App Configuration

In `MarketDataManager.swift`:

```swift
// At the top of the file
let oandaAPIKey = "YOUR_API_TOKEN_HERE"
let oandaAccountID = "YOUR_ACCOUNT_ID_HERE"

// Initialize in setup method
override func setupPriceUpdates() {
    let oandaClient = OANDAClient(apiKey: oandaAPIKey, accountID: oandaAccountID)
    
    // Fetch live prices
    Task {
        do {
            let prices = try await oandaClient.fetchPrices(for: ["EURUSD", "GBPUSD"])
            await MainActor.run {
                self.currentPrices = prices
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

#### Step 4: Test Connection

```swift
// Add this in SettingsView or create a test method
@MainActor
func testOANDAConnection() {
    let client = OANDAClient(apiKey: oandaAPIKey, accountID: oandaAccountID)
    
    Task {
        do {
            let status = try await client.getMarketStatus()
            print("Market is \(status.isOpen ? "open" : "closed")")
        } catch {
            print("Connection failed: \(error)")
        }
    }
}
```

### Example Requests

#### Get Current Prices

```swift
let pairs = ["EURUSD", "GBPUSD", "USDJPY"]
let prices = try await oandaClient.fetchPrices(for: pairs)

// Result: ["EURUSD": 1.1234, "GBPUSD": 1.2567, ...]
```

#### Get Historical Data

```swift
let history = try await oandaClient.fetchHistoricalData(
    pair: "EURUSD",
    timeframe: "H1", // 1-hour candles
    limit: 100
)

// Returns array of PriceData with OHLC values
```

#### Supported Timeframes
- `M1` - 1 minute
- `M5` - 5 minutes
- `M15` - 15 minutes
- `H1` - 1 hour
- `H4` - 4 hours
- `D` - 1 day
- `W` - 1 week
- `M` - 1 month

### Common Issues

**Error: "Unauthorized"**
- Check API token is correct
- Verify token hasn't expired
- Ensure Account ID matches token

**Error: "Instrument not found"**
- Use correct format: "EURUSD" not "EUR/USD"
- Check pair spelling
- Verify pair is available in your account

**Error: "Timeout"**
- Check internet connection
- OANDA servers might be down
- Try alternative API temporarily

---

## Twelve Data API

### Overview
Twelve Data provides simple, reliable market data APIs.

**Pros:**
- Free tier with good limits
- Easy to use
- No registration for free tier
- Global coverage
- Competitive pricing

**Cons:**
- Limited free API calls (800/day)
- Slight delay in data
- Less documentation

### Setup Instructions

#### Step 1: Get API Key

1. Visit https://twelvedata.com
2. Sign up for free account
3. Go to Dashboard → API Keys
4. Copy your API key

#### Step 2: Update App Configuration

```swift
let twelveDataAPIKey = "YOUR_API_KEY_HERE"

let twelveDataClient = TwelveDataClient(apiKey: twelveDataAPIKey)
```

#### Step 3: Fetch Data

```swift
// Get real-time prices
let prices = try await twelveDataClient.fetchPrices(for: ["EURUSD", "GBPUSD"])

// Get historical data
let history = try await twelveDataClient.fetchHistoricalData(
    pair: "EURUSD",
    timeframe: "1h", // format differs from OANDA
    limit: 100
)
```

### Supported Timeframes
- `1min` - 1 minute
- `5min` - 5 minutes
- `15min` - 15 minutes
- `30min` - 30 minutes
- `1h` - 1 hour
- `4h` - 4 hours
- `1day` - 1 day
- `1week` - 1 week
- `1month` - 1 month

### Rate Limits

Free Plan:
- 800 API calls/day
- 1 request/second
- 5-year history

Pro Plan:
- 100,000+ calls/day
- 10+ requests/second
- Real-time data

### Example Response

```json
{
  "data": [
    {
      "symbol": "EURUSD",
      "last": "1.12345",
      "change": "0.00123",
      "change_pct": "0.11%",
      "bid": "1.12344",
      "ask": "1.12346"
    }
  ]
}
```

---

## Alpha Vantage API

### Overview
Free forex data API with extended hours support.

**Pros:**
- Completely free
- No credit card required
- Extended hours data
- Simple to use

**Cons:**
- Very limited free tier (5 calls/minute)
- Slower data updates
- Less reliable for trading

### Setup Instructions

#### Step 1: Get API Key

1. Visit https://www.alphavantage.co
2. Get free API key (instant)
3. No registration needed

#### Step 2: Create Client

```swift
class AlphaVantageClient: ForexAPIProvider {
    private let apiKey: String
    private let baseURL = "https://www.alphavantage.co/query"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        
        for pair in pairs {
            let params = [
                "function": "CURRENCY_EXCHANGE_RATE",
                "from_currency": String(pair.prefix(3)),
                "to_currency": String(pair.suffix(3)),
                "apikey": apiKey
            ]
            
            // Build URL with params
            var components = URLComponents(string: baseURL)!
            components.queryItems = params.map { URLQueryItem(name: $0, value: $1) }
            
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let response = try JSONDecoder().decode(AVResponse.self, from: data)
            
            if let rate = Double(response.rate) {
                prices[pair] = rate
            }
        }
        
        return prices
    }
}
```

### Rate Limits
- Free: 5 requests/minute
- Premium: Unlimited

---

## Integration Patterns

### Pattern 1: Single API Fallback

```swift
@MainActor
class MarketDataManager: ObservableObject {
    private var primaryClient: ForexAPIProvider
    private var fallbackClient: ForexAPIProvider
    
    func updatePrices() {
        Task {
            do {
                // Try primary
                let prices = try await primaryClient.fetchPrices(for: selectedPairs)
                self.currentPrices = prices
            } catch {
                // Fallback to secondary
                do {
                    let prices = try await fallbackClient.fetchPrices(for: selectedPairs)
                    self.currentPrices = prices
                } catch {
                    self.error = "Both APIs failed"
                }
            }
        }
    }
}
```

### Pattern 2: API Provider Selection

```swift
class APIConfiguration {
    enum Provider: String, CaseIterable {
        case oanda = "OANDA"
        case twelveData = "Twelve Data"
        case alphaVantage = "Alpha Vantage"
    }
    
    static func createClient(for provider: Provider, apiKey: String) -> ForexAPIProvider {
        switch provider {
        case .oanda:
            return OANDAClient(apiKey: apiKey, accountID: "")
        case .twelveData:
            return TwelveDataClient(apiKey: apiKey)
        case .alphaVantage:
            return AlphaVantageClient(apiKey: apiKey)
        }
    }
}
```

### Pattern 3: Caching

```swift
class CachedAPIClient: ForexAPIProvider {
    private let client: ForexAPIProvider
    private var cache: [String: (data: [String: Double], timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 60 // 1 minute
    
    init(client: ForexAPIProvider) {
        self.client = client
    }
    
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        let now = Date()
        
        // Check cache
        if let cached = cache["prices"], 
           now.timeIntervalSince(cached.timestamp) < cacheDuration {
            return cached.data
        }
        
        // Fetch fresh data
        let prices = try await client.fetchPrices(for: pairs)
        cache["prices"] = (prices, now)
        return prices
    }
}
```

### Pattern 4: Error Handling & Retry

```swift
func fetchWithRetry(
    maxAttempts: Int = 3,
    delay: TimeInterval = 1.0
) async throws -> [String: Double] {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await client.fetchPrices(for: selectedPairs)
        } catch {
            lastError = error
            
            if attempt < maxAttempts {
                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    throw lastError ?? APIError.networkError("Unknown error")
}
```

### Pattern 5: Rate Limiting

```swift
class RateLimitedClient: ForexAPIProvider {
    private let client: ForexAPIProvider
    private var lastRequestTime: Date = Date.distantPast
    private let minInterval: TimeInterval = 0.2 // 5 requests/second
    
    init(client: ForexAPIProvider) {
        self.client = client
    }
    
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        // Enforce rate limit
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        
        lastRequestTime = Date()
        return try await client.fetchPrices(for: pairs)
    }
}
```

---

## Recommended Setup

### For Development
Use **Twelve Data** + **Mock Client**
- Free tier adequate
- Good data quality
- Simple integration
- Mock fallback for testing

### For Production
Use **OANDA** + **Twelve Data**
- Primary: OANDA (institutional grade)
- Fallback: Twelve Data (reliable backup)
- Automatic switching on failure
- Caching for resilience

### Configuration Example

```swift
// In AppDelegate or startup
let apiManager = APIClientManager()

#if DEBUG
// Development: Use free APIs with fallback
apiManager.configure(with: .twelveData, apiKey: "YOUR_KEY")
#else
// Production: Use OANDA with Twelve Data fallback
let primaryClient = OANDAClient(apiKey: "OANDA_KEY", accountID: "ACCOUNT")
let fallbackClient = TwelveDataClient(apiKey: "12DATA_KEY")
// Setup fallback logic
#endif
```

---

## Security Best Practices

### 1. Store API Keys Securely

**DO NOT** hardcode API keys:
```swift
// ❌ WRONG
let apiKey = "sk_live_abc123def456"
```

**Instead**, use Environment Variables:
```swift
// ✅ CORRECT
let apiKey = ProcessInfo.processInfo.environment["FOREX_API_KEY"] ?? ""
```

Or use Keychain:
```swift
import Security

class KeychainManager {
    static func store(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func retrieve(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
```

### 2. Use HTTPS Only
All API calls should use HTTPS (already enforced in example code).

### 3. Rate Limiting
Implement backoff strategies for rate limits.

### 4. Validation
Always validate API responses before using.

---

## Testing API Integration

### Mock Testing

```swift
class MockAPIClient: ForexAPIProvider {
    var shouldFail = false
    
    func fetchPrices(for pairs: [String]) async throws -> [String: Double] {
        if shouldFail {
            throw APIError.networkError("Mock failure")
        }
        
        var prices: [String: Double] = [:]
        for pair in pairs {
            prices[pair] = Double.random(in: 0.8...2.0)
        }
        return prices
    }
}

// In tests
func testFailover() {
    let mockClient = MockAPIClient()
    mockClient.shouldFail = true
    
    // Test fallback logic
}
```

### Live Testing

```swift
@MainActor
func testLiveAPI() {
    let client = OANDAClient(apiKey: "YOUR_KEY", accountID: "YOUR_ACCOUNT")
    
    Task {
        do {
            let prices = try await client.fetchPrices(for: ["EURUSD"])
            XCTAssert(!prices.isEmpty)
        } catch {
            XCTFail("API call failed: \(error)")
        }
    }
}
```

---

## Troubleshooting

### "Invalid API Key"
- Verify key is copied correctly
- Check key hasn't been rotated
- Ensure it's the API key (not access token)

### "Insufficient permissions"
- Verify account type (demo vs live)
- Check scopes for OAuth APIs
- Ensure pair is available in your region

### "Rate limit exceeded"
- Implement exponential backoff
- Reduce update frequency
- Consider upgrading API plan

### "Timeout"
- Check network connectivity
- Verify API server status
- Increase timeout threshold

---

## Next Steps

1. ✅ Choose your API provider
2. ✅ Get API credentials
3. ✅ Implement in `APIClient.swift`
4. ✅ Test with mock data
5. ✅ Test with live data
6. ✅ Monitor for errors
7. ✅ Deploy with confidence

For more help, refer to individual API documentation:
- [OANDA Docs](https://developer.oanda.com)
- [Twelve Data Docs](https://twelvedata.com/docs)
- [Alpha Vantage Docs](https://www.alphavantage.co/documentation)
