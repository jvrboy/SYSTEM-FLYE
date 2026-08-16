# Forex Analyzer - Quick Start Guide

Get your professional FOREX trading app running in **5 minutes**.

## 🚀 Installation

### Prerequisites
```
✓ Xcode 15+ installed
✓ iOS 15+ compatible iPhone/Simulator
✓ 2GB free disk space
```

### Step 1: Create Xcode Project (2 minutes)

```bash
# In Xcode: File → New → Project
# Template: App
# Name: ForexAnalyzer
# Interface: SwiftUI
# Language: Swift
# Minimum iOS: 15.0
```

### Step 2: Copy Code Files (1 minute)

Copy these 11 Swift files to your project:
1. `ForexAnalyzerApp.swift` - Main app
2. `Models.swift` - Data structures
3. `MarketDataManager.swift` - Market data
4. `SignalGenerator.swift` - Signal engine
5. `PortfolioManager.swift` - Trade tracking
6. `DashboardView.swift` - Main screen
7. `SignalsView.swift` - Signals screen
8. `AnalysisView.swift` - Analysis screen
9. `PortfolioView.swift` - Portfolio screen
10. `SettingsView.swift` - Settings screen

### Step 3: Build & Run (2 minutes)

```
1. Select target iPhone device/simulator
2. Press Cmd + R
3. Wait for build to complete
4. App launches on device!
```

## 📊 What You Get

### Dashboard Tab
- 📍 Live forex prices
- 🎯 Active trading signals
- 📈 Market analysis
- ⚡ Strong signals count

### Signals Tab
- 🔴 All active signals
- 💚 Buy/Sell breakdown
- 📋 Historical signals
- 🎲 Signal strength & confidence

### Analysis Tab
- 📊 Price charts
- 🔍 6 technical indicators
- 📏 Bollinger Bands
- 🏃 Moving averages
- 🎢 RSI, MACD, Stochastic

### Portfolio Tab
- 💰 Account balance
- 📊 P&L tracking
- 🏆 Win rate statistics
- 📝 Trade history
- 📈 Performance metrics

### Settings Tab
- 🔔 Notification control
- 🎨 Theme selection
- ⚙️ Risk adjustment
- 🔑 API configuration
- 👀 Pair selection

## 🎯 Key Features

### Real-Time Updates
```swift
// Automatic price updates every 2 seconds
// Historical data loaded on startup
// All calculations instant
```

### Multi-Indicator Trading Signals
```
Signal triggered when 3+ indicators align:
✓ RSI < 30 (oversold) → BUY
✓ MACD bullish crossover → BUY
✓ Price at BB lower band → BUY
✓ MA alignment confirmed → BUY

Confidence: 45-95% (calculated automatically)
```

### Advanced Risk Management
```
Entry: Current price
Stop Loss: Entry ± (ATR × 1.5)
Take Profit: Entry ± (ATR × 3.0)
Risk:Reward: Auto-calculated
```

### Performance Analytics
```
📊 Win Rate: % of winning trades
📊 Profit Factor: Wins / Losses
📊 Expected Value: EV per trade
📊 Max Drawdown: Peak-to-trough decline
```

## 🔧 Configuration

### Enable Real Market Data

In `MarketDataManager.swift`:

```swift
// Replace loadMockData() with real API call:

let apiKey = "YOUR_API_KEY"
let endpoint = "https://api.example.com/forex"

Task {
    let data = await fetchLiveData(endpoint: endpoint)
    // Update UI with real prices
}
```

### Connect Your Broker API

In `SettingsView.swift`:

1. Go to Settings → API Configuration
2. Enter your broker's API credentials
3. Select data provider
4. Tap "Connect"

Supported APIs:
- OANDA (Recommended)
- Twelve Data
- Alpha Vantage
- Finnhub

### Add Your Trading Pairs

In `MarketDataManager.swift`:

```swift
var selectedPairs = ["EURUSD", "GBPUSD", "USDJPY"] // Default

// Add more pairs:
@Published var selectedPairs: [String] = [
    "EURUSD", "GBPUSD", "USDJPY", 
    "USDCHF", "AUDUSD", "NZDUSD"
]
```

Or use the Settings tab to toggle pairs.

## 📱 UI Customization

### Change Theme Color

In `DashboardView.swift`:

```swift
// Current: Dark blue theme
Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1))

// Change to your color:
Color(UIColor(red: R, green: G, blue: B, alpha: 1.0))
// Use values 0.0 to 1.0
```

### Modify Signal Strength Threshold

In `SignalGenerator.swift`:

```swift
// Current: Minimum 3 indicators must align
guard buySignalStrength >= 3 else { return nil }

// Change to require 4 indicators:
guard buySignalStrength >= 4 else { return nil }
```

### Adjust Technical Indicators

In `MarketDataManager.swift`:

```swift
// RSI Period (default 14)
let rsi = calculateRSI(history: history, period: 14)

// Bollinger Bands Period (default 20)
let bb = calculateBollingerBands(history: history, period: 20)

// Change values to test different sensitivities
```

## 🧪 Testing

### Test Signal Generation

```swift
// In MarketDataManager.swift, loadMockData():

// Create specific conditions to test signals
// Example: Create oversold RSI
for i in 0..<100 {
    prices.append(PriceData(
        // Price declining = lower RSI
        close: startPrice - Double(i) * 0.001
    ))
}
```

### Monitor Console Output

```bash
# While running:
# Xcode → View → Debug Area → Show Console
# (Cmd + Shift + C)

# Add logging:
Logger.debug("Signal generated: \(signal.reason)")
```

### Performance Profiling

```
1. Product → Profile (Cmd + I)
2. Select "System Trace"
3. Interact with app
4. Check CPU, Memory, FPS
```

## 📚 API Reference Quick

### Key Classes

**MarketDataManager**
```swift
@Published var currentPrices: [String: Double]
@Published var technicalIndicators: [String: TechnicalIndicators]

func updatePrices()
func calculateIndicators(for history: [PriceData]) → TechnicalIndicators
```

**SignalGenerator**
```swift
@Published var activeSignals: [TradingSignal]

func generateSignals(for pair: String, 
    indicators: TechnicalIndicators, 
    currentPrice: Double, 
    marketAnalysis: MarketAnalysis)
```

**PortfolioManager**
```swift
@Published var portfolio: Portfolio
@Published var openTrades: [Trade]
@Published var closedTrades: [Trade]

func addTrade(...)
func closeTrade(_ trade: Trade, atPrice: Double)
```

### Key Models

```swift
struct TradingSignal {
    let pairSymbol: String
    let signalType: SignalType // .buy or .sell
    let strength: SignalStrength // .strong, .moderate, .weak
    let entryPrice: Double
    let stopLoss: Double
    let takeProfit: Double
    let riskRewardRatio: Double
    let confidence: Double // 0-100
    let indicators: [String] // Which indicators triggered
    let reason: String
}

struct Trade {
    let pairSymbol: String
    let type: SignalType
    let entryPrice: Double
    var exitPrice: Double?
    var profitLoss: Double?
    var status: TradeStatus // .open, .closed, .pending
}
```

## 🐛 Troubleshooting

### "Module not found" Error
```bash
# Solution: Clean build
Cmd + Shift + K
Then: Cmd + B
```

### Simulator Shows Blank Screen
```bash
# Solution: Reset simulator
xcrun simctl erase all
Then rebuild: Cmd + R
```

### App Crashes on Tab Switch
```
Check: Tab views might reference missing @EnvironmentObject
Add: .environmentObject(manager) to each view
```

### Memory Warning
```
Current limits:
- Keep last 1000 price candles per pair
- Store last 50 active signals
- Archive trades > 3 months old
```

## 🚀 Next Steps

### Immediate (Day 1)
- [ ] Get app running
- [ ] Explore all 5 tabs
- [ ] Adjust settings to your preference
- [ ] Understand each indicator

### Short-term (Week 1)
- [ ] Connect real market data API
- [ ] Add your trading pairs
- [ ] Customize signal thresholds
- [ ] Test on real iPhone device

### Medium-term (Month 1)
- [ ] Implement broker API integration
- [ ] Add push notifications
- [ ] Create cloud backup
- [ ] Optimize performance

### Long-term (Ongoing)
- [ ] Add ML-based signal optimization
- [ ] Build social trading features
- [ ] Extend to iPad/macOS
- [ ] Submit to App Store

## 📖 Documentation

Full documentation available:
- **README.md** - Complete feature overview
- **PROJECT_SETUP.md** - Detailed Xcode setup
- **Code Comments** - Inline documentation in all files

## 💡 Pro Tips

1. **Test with Different Timeframes**
   - 1-minute charts for scalping
   - 4-hour charts for swing trading
   - Daily charts for position trading

2. **Adjust Risk Appetite**
   - Conservative: RSI threshold 40/60
   - Moderate: RSI threshold 30/70 (default)
   - Aggressive: RSI threshold 20/80

3. **Combine Indicators**
   - RSI: Momentum confirmation
   - MACD: Trend direction
   - Bollinger Bands: Support/Resistance
   - Moving Averages: Trend validation

4. **Risk Management**
   - Never risk more than 2% per trade
   - Minimum 1:2 Risk:Reward ratio
   - Use stop losses on every trade
   - Track your win rate monthly

## 🎓 Learning Resources

- **Technical Analysis**: Investopedia.com
- **Forex Trading**: BabyPips.com
- **Swift Development**: Developer.apple.com
- **SwiftUI**: SwiftUI Documentation

## 📞 Support

Having issues? Check:
1. Console output (Cmd + Shift + C)
2. README.md for comprehensive docs
3. Inline code comments for implementation details
4. Apple Developer forums for SwiftUI questions

---

**You're ready to trade! 🚀**

Start with the Dashboard tab, enable notifications, and watch for trading signals.

Remember: Paper trading first, real money second!

Questions? The code is well-commented. Happy trading! 📈
