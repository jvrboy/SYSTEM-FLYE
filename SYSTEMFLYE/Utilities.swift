import Foundation
import SwiftUI

// MARK: - Number Formatting
struct PriceFormatter {
    static func formatPrice(_ price: Double, decimals: Int = 5) -> String {
        return String(format: "%.\(decimals)f", price)
    }
    
    static func formatCurrency(_ amount: Double, symbol: String = "$") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol)0.00"
    }
    
    static func formatPercent(_ value: Double, decimals: Int = 2) -> String {
        return String(format: "%.\(decimals)f%%", value)
    }
    
    static func formatPips(_ value: Double) -> String {
        return String(format: "%.1f pips", value * 10000)
    }
}

// MARK: - Date Formatting
struct DateFormatter {
    static let iso8601: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
    
    static func formatTime(_ date: Date, format: String = "HH:mm:ss") -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    static func formatDate(_ date: Date, format: String = "MMM dd, yyyy") -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    static func formatDateTime(_ date: Date) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static func timeAgoFromNow(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "now"
        }
    }
}

// MARK: - Calculation Utilities
struct MathUtilities {
    /// Calculate percentage change
    static func percentageChange(from: Double, to: Double) -> Double {
        guard from != 0 else { return 0 }
        return ((to - from) / from) * 100
    }
    
    /// Calculate pips difference
    static func pipsDifference(from: Double, to: Double) -> Double {
        return (to - from) * 10000
    }
    
    /// Calculate compound annual growth rate
    static func cagr(startValue: Double, endValue: Double, years: Double) -> Double {
        guard startValue > 0, years > 0 else { return 0 }
        return (pow(endValue / startValue, 1 / years) - 1) * 100
    }
    
    /// Calculate moving average
    static func movingAverage(_ values: [Double], period: Int) -> Double {
        let relevantValues = values.suffix(period)
        guard !relevantValues.isEmpty else { return 0 }
        return relevantValues.reduce(0, +) / Double(relevantValues.count)
    }
    
    /// Calculate standard deviation
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
    
    /// Calculate correlation between two series
    static func correlation(_ series1: [Double], _ series2: [Double]) -> Double {
        guard series1.count == series2.count, series1.count > 1 else { return 0 }
        
        let n = Double(series1.count)
        let mean1 = series1.reduce(0, +) / n
        let mean2 = series2.reduce(0, +) / n
        
        var numerator = 0.0
        var denominator1 = 0.0
        var denominator2 = 0.0
        
        for i in 0..<series1.count {
            let diff1 = series1[i] - mean1
            let diff2 = series2[i] - mean2
            numerator += diff1 * diff2
            denominator1 += diff1 * diff1
            denominator2 += diff2 * diff2
        }
        
        let denominator = sqrt(denominator1 * denominator2)
        guard denominator != 0 else { return 0 }
        
        return numerator / denominator
    }
}

// MARK: - Color Utilities
struct ColorUtilities {
    /// Get color based on value (red for negative, green for positive)
    static func priceColor(value: Double) -> Color {
        if value > 0 {
            return Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1))
        } else if value < 0 {
            return Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
        } else {
            return .gray
        }
    }
    
    /// Get color for RSI value
    static func rsiColor(rsi: Double) -> Color {
        if rsi > 70 {
            return Color(UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)) // Overbought
        } else if rsi < 30 {
            return Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)) // Oversold
        } else {
            return .gray // Neutral
        }
    }
    
    /// Get color for signal strength
    static func signalStrengthColor(_ strength: SignalStrength) -> Color {
        switch strength {
        case .strong:
            return Color(UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1))
        case .moderate:
            return Color(UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1))
        case .weak:
            return .gray
        }
    }
}

// MARK: - String Extensions
extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }
    
    var isValidAPIKey: Bool {
        return self.count >= 20 && !self.isEmpty
    }
    
    func truncated(to length: Int) -> String {
        return self.count > length ? String(self.prefix(length)) + "..." : self
    }
}

// MARK: - Double Extensions
extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var asPips: String {
        return PriceFormatter.formatPips(self)
    }
    
    var asPercentage: String {
        return PriceFormatter.formatPercent(self)
    }
    
    var asCurrency: String {
        return PriceFormatter.formatCurrency(self)
    }
}

// MARK: - Array Extensions
extension Array where Element == PriceData {
    var averagePrice: Double {
        guard !isEmpty else { return 0 }
        return map { $0.close }.reduce(0, +) / Double(count)
    }
    
    var highestPrice: Double {
        return map { $0.high }.max() ?? 0
    }
    
    var lowestPrice: Double {
        return map { $0.low }.min() ?? 0
    }
    
    var priceRange: Double {
        return highestPrice - lowestPrice
    }
}

// MARK: - Localization
struct Localization {
    static func tradingSignalDescription(_ signal: TradingSignal) -> String {
        let type = signal.signalType == .buy ? "Buy" : "Sell"
        let strength = signal.strength.rawValue
        
        return "\(type) Signal - \(strength) Strength (\(Int(signal.confidence))%)"
    }
    
    static func marketConditionDescription(_ condition: MarketCondition) -> String {
        switch condition {
        case .strongUptrend:
            return "Strong upward trend with strong momentum"
        case .uptrend:
            return "Upward trend in progress"
        case .neutral:
            return "No clear trend, neutral market conditions"
        case .downtrend:
            return "Downward trend in progress"
        case .strongDowntrend:
            return "Strong downward trend with strong momentum"
        }
    }
    
    static func indicatorExplanation(_ indicator: String) -> String {
        switch indicator {
        case "RSI":
            return "Relative Strength Index measures momentum. Values above 70 indicate overbought conditions, below 30 indicate oversold."
        case "MACD":
            return "Moving Average Convergence Divergence identifies trend changes. Positive histogram indicates bullish momentum."
        case "BB":
            return "Bollinger Bands measure volatility. Prices above upper band suggest overbought, below lower band suggest oversold."
        case "MA":
            return "Moving Averages smooth price data to identify trends. Price crossing above MA indicates bullish signal."
        case "Stochastic":
            return "Stochastic Oscillator compares closing price to range. Values above 80 indicate overbought, below 20 indicate oversold."
        case "ATR":
            return "Average True Range measures volatility. Higher ATR indicates higher volatility, lower ATR indicates lower volatility."
        default:
            return "Technical indicator for market analysis"
        }
    }
}

// MARK: - User Preferences
class UserPreferences {
    static let shared = UserPreferences()
    
    private let defaults = UserDefaults.standard
    private let keyPrefix = "com.forexanalyzer."
    
    // MARK: - Keys
    private let enableNotificationsKey = "enableNotifications"
    private let soundEnabledKey = "soundEnabled"
    private let selectedThemeKey = "selectedTheme"
    private let riskLevelKey = "riskLevel"
    private let updateIntervalKey = "updateInterval"
    private let watchedPairsKey = "watchedPairs"
    private let apiKeyKey = "apiKey"
    private let lastUpdateKey = "lastUpdate"
    
    // MARK: - Getters & Setters
    var enableNotifications: Bool {
        get { defaults.bool(forKey: keyPrefix + enableNotificationsKey) }
        set { defaults.set(newValue, forKey: keyPrefix + enableNotificationsKey) }
    }
    
    var soundEnabled: Bool {
        get { defaults.bool(forKey: keyPrefix + soundEnabledKey) }
        set { defaults.set(newValue, forKey: keyPrefix + soundEnabledKey) }
    }
    
    var selectedTheme: String {
        get { defaults.string(forKey: keyPrefix + selectedThemeKey) ?? "Dark" }
        set { defaults.set(newValue, forKey: keyPrefix + selectedThemeKey) }
    }
    
    var riskLevel: Double {
        get { defaults.double(forKey: keyPrefix + riskLevelKey) == 0 ? 2.0 : defaults.double(forKey: keyPrefix + riskLevelKey) }
        set { defaults.set(newValue, forKey: keyPrefix + riskLevelKey) }
    }
    
    var updateInterval: Double {
        get { defaults.double(forKey: keyPrefix + updateIntervalKey) == 0 ? 2.0 : defaults.double(forKey: keyPrefix + updateIntervalKey) }
        set { defaults.set(newValue, forKey: keyPrefix + updateIntervalKey) }
    }
    
    var watchedPairs: [String] {
        get { defaults.stringArray(forKey: keyPrefix + watchedPairsKey) ?? ["EURUSD", "GBPUSD", "USDJPY"] }
        set { defaults.set(newValue, forKey: keyPrefix + watchedPairsKey) }
    }
    
    var apiKey: String {
        get { defaults.string(forKey: keyPrefix + apiKeyKey) ?? "" }
        set { defaults.set(newValue, forKey: keyPrefix + apiKeyKey) }
    }
    
    var lastUpdate: Date? {
        get { defaults.object(forKey: keyPrefix + lastUpdateKey) as? Date }
        set { defaults.set(newValue, forKey: keyPrefix + lastUpdateKey) }
    }
    
    // MARK: - Reset
    func reset() {
        enableNotifications = true
        soundEnabled = true
        selectedTheme = "Dark"
        riskLevel = 2.0
        updateInterval = 2.0
        watchedPairs = ["EURUSD", "GBPUSD", "USDJPY"]
        apiKey = ""
    }
}

// MARK: - Logging
struct Logger {
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.formatTime(Date())
        print("[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)")
        #endif
    }
    
    static func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    static func info(_ message: String) {
        log(message, level: .info)
    }
    
    static func warning(_ message: String) {
        log(message, level: .warning)
    }
    
    static func error(_ message: String) {
        log(message, level: .error)
    }
}

// MARK: - JSON Encoding/Decoding Helpers
extension JSONEncoder {
    static let `default`: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let `default`: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - Validation Utilities
struct ValidationUtilities {
    static func isValidRiskLevel(_ level: Double) -> Bool {
        return level >= 0.1 && level <= 10.0
    }
    
    static func isValidConfidenceLevel(_ confidence: Double) -> Bool {
        return confidence >= 0 && confidence <= 100
    }
    
    static func isValidPrice(_ price: Double) -> Bool {
        return price > 0 && price.isFinite
    }
    
    static func isValidTradeSize(_ size: Double) -> Bool {
        return size > 0 && size <= 100 && size.isFinite
    }
}

// MARK: - Notification Center Helper
extension NotificationCenter {
    func post(name: NSNotification.Name, userInfo: [AnyHashable: Any]? = nil) {
        post(name: name, object: nil, userInfo: userInfo)
    }
}

// MARK: - URL Extensions
extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
        
        return queryItems.reduce(into: [:]) { $0[$1.name] = $1.value }
    }
}
