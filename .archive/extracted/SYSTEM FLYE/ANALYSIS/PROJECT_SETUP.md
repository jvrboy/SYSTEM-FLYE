# Forex Analyzer - Xcode Project Setup Guide

## Create New Xcode Project

### Step 1: Create Project in Xcode

1. Open Xcode
2. File → New → Project
3. Select "App" template
4. Configure project:
   - **Product Name**: ForexAnalyzer
   - **Team ID**: Your Apple Developer Team ID
   - **Organization Identifier**: com.yourcompany
   - **Bundle Identifier**: com.yourcompany.forexanalyzer
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployment**: iOS 15.0
   - **Devices**: iPhone

### Step 2: Replace Default Files

1. **Delete** these auto-generated files:
   - `ContentView.swift`
   - `Assets.xcassets/AppIcon.appiconset` (you'll create custom icons)

2. **Add** the following files to your project:
   ```
   ForexAnalyzerApp.swift
   Models.swift
   MarketDataManager.swift
   SignalGenerator.swift
   PortfolioManager.swift
   DashboardView.swift
   SignalsView.swift
   AnalysisView.swift
   PortfolioView.swift
   SettingsView.swift
   ```

### Step 3: Configure Project Settings

#### Build Settings
1. Select **ForexAnalyzer** project in Xcode
2. Select **ForexAnalyzer** target
3. Go to **Build Settings**

Set these values:
```
Swift Language Version: Swift 5.9
Minimum Deployment Target: iOS 15.0
Supported Platforms: iOS
Build For Running: Yes
```

#### Info.plist Configuration

Add these keys to Info.plist:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>ForexAnalyzer needs access to your local network to sync data</string>

<key>NSBonjourServices</key>
<array>
  <string>_http._tcp</string>
</array>

<key>NSURLSessionUseLocalCache</key>
<true/>

<key>UILaunchScreen</key>
<dict>
  <key>UIColorName</key>
  <string>LaunchScreenBackground</string>
</dict>

<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

### Step 4: Configure App Icons

1. **Create App Icons** (1024×1024 PNG):
   - Use a design tool or online icon generator
   - Design a professional forex/trading themed icon
   - Suggested colors: Blues, greens, professional finance aesthetic

2. **Add to Assets**:
   - Assets.xcassets → AppIcon
   - Drag all required icon sizes
   - Or use Xcode's automatic resizing

### Step 5: Capabilities

Enable these capabilities in Project → Target → Signing & Capabilities:

1. **Background Modes**
   - ✓ Background fetch
   - ✓ Remote notifications

2. **Push Notifications** (for future)
   - ✓ Push Notifications

3. **Network** (for future)
   - ✓ Outgoing Connections (Client)

## File Organization

### Recommended Folder Structure in Xcode

```
ForexAnalyzer
├── App
│   ├── ForexAnalyzerApp.swift
│   └── Assets.xcassets
├── Models
│   └── Models.swift
├── Services
│   ├── MarketDataManager.swift
│   ├── SignalGenerator.swift
│   └── PortfolioManager.swift
├── Views
│   ├── DashboardView.swift
│   ├── SignalsView.swift
│   ├── AnalysisView.swift
│   ├── PortfolioView.swift
│   └── SettingsView.swift
└── Resources
    └── Localizable.strings
```

To create this structure in Xcode:
1. Right-click on project
2. New Group
3. Add files to appropriate groups

## Dependencies (Optional)

### CocoaPods Setup

Create a `Podfile`:

```ruby
platform :ios, '15.0'

target 'ForexAnalyzer' do
  # Networking
  pod 'Alamofire', '~> 5.7'
  
  # Charts
  pod 'Charts', '~> 4.1'
  
  # Database
  pod 'Realm', '~> 10.0'
  
  # API Client
  pod 'SwiftyJSON', '~> 5.0'
  
  # Notifications
  pod 'UserNotifications'
end
```

Install with:
```bash
pod install
```

Then open `.xcworkspace` instead of `.xcodeproj`

### Swift Package Manager (Recommended)

Add packages via Xcode:
1. File → Add Packages
2. Enter package URL
3. Select version and add to target

Recommended packages:
- No external dependencies required for MVP (uses only Foundation & SwiftUI)

## Build Phases

### Custom Build Script

Add a build phase for automatic versioning:

1. Target → Build Phases → + New Run Script Phase

```bash
#!/bin/bash

# Update build number
buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFOPLIST_FILE")
buildNumber=$(($buildNumber + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "$INFOPLIST_FILE"

echo "Build number updated to: $buildNumber"
```

## Run Configurations

### Create Multiple Schemes

1. **Production**
   - Real API keys
   - Production servers
   - Release build settings

2. **Development**
   - Mock data enabled
   - Development servers
   - Debug symbols included

3. **Testing**
   - Test data
   - Network mocking
   - Coverage enabled

Configure in: Product → Scheme → Edit Scheme

## Environment Variables

Create an `Environment.swift` file:

```swift
enum Environment {
    static let isDevelopment = true
    static let isProduction = !isDevelopment
    
    static var apiBaseURL: String {
        isDevelopment ? "https://dev-api.example.com" : "https://api.example.com"
    }
    
    static var apiKey: String {
        isDevelopment ? "DEV_KEY" : "PROD_KEY"
    }
}
```

## Simulator Testing

### Test on Different Devices

```bash
# List available simulators
xcrun simctl list

# Launch specific simulator
open -a Simulator --args -CurrentDeviceUDID [UUID]

# Test on iPhone 15 Pro
Product → Destination → iPhone 15 Pro (Simulator)
```

### Network Debugging

Enable Network Link Conditioner for testing:
1. Xcode → Additional Tools
2. Download "Hardware IO Tools"
3. Install Network Link Conditioner
4. Simulate various network conditions:
   - 3G
   - LTE
   - WiFi
   - Offline

## Performance Optimization

### Memory Management

Add memory warnings handler:

```swift
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { _ in
    // Clear caches
    URLCache.shared.removeAllCachedResponses()
}
```

### Battery Usage

Profile with Xcode's Energy Impact gauge:
1. Product → Profile
2. Select "Energy Impact"
3. Identify battery drains

Optimization tips:
- Use `Timer` instead of `DispatchSourceTimer` for periodic updates
- Batch network requests
- Disable updates when app is backgrounded

## Debugging

### Enable Logging

Create a logging utility:

```swift
struct Logger {
    static func debug(_ message: String) {
        #if DEBUG
        print("[DEBUG] \(message)")
        #endif
    }
    
    static func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}
```

### Breakpoints

Set conditional breakpoints:
1. Click line number to create breakpoint
2. Right-click → Edit Breakpoint
3. Add condition: `rsi > 70`

### View Hierarchy Debugging

In Xcode:
- Debug → View Hierarchy (when running)
- Inspect SwiftUI views in real-time
- Check frame sizes and safe areas

## Testing

### Unit Tests

Create `ForexAnalyzerTests.swift`:

```swift
import XCTest
@testable import ForexAnalyzer

class SignalGeneratorTests: XCTestCase {
    var sut: SignalGenerator!
    
    override func setUp() {
        super.setUp()
        sut = SignalGenerator()
    }
    
    func testRSIOverbought() {
        let indicators = createMockIndicators(rsi: 75)
        let signal = sut.checkSellSignals(..., indicators)
        XCTAssertNotNil(signal)
    }
}
```

### UI Tests

Create `ForexAnalyzerUITests.swift`:

```swift
import XCTest

class ForexAnalyzerUITests: XCTestCase {
    func testDashboardLoads() {
        let app = XCUIApplication()
        app.launch()
        
        XCTAssert(app.staticTexts["Market Analysis"].exists)
    }
}
```

## Code Signing

### Development Certificate

1. Apple Developer Account → Certificates
2. Create iOS Development Certificate
3. Download and install
4. Xcode → Settings → Accounts
5. Download manual profiles or enable auto-signing

### Provisioning Profile

Xcode handles this automatically with auto-signing.

Manual setup:
1. Xcode → Preferences → Accounts
2. View Details
3. Download All Profiles

## Version Management

### Semantic Versioning

Format: `MAJOR.MINOR.PATCH`

Example progression:
- `1.0.0` - Initial release
- `1.0.1` - Bug fixes
- `1.1.0` - New features
- `2.0.0` - Breaking changes

Update in:
1. Info.plist → `CFBundleShortVersionString`
2. Info.plist → `CFBundleVersion`

## Release Checklist

Before App Store submission:

- [ ] Update version number (Info.plist)
- [ ] Update build number
- [ ] Run full test suite (Cmd + U)
- [ ] Profile for memory leaks (Product → Profile)
- [ ] Test on real device
- [ ] Create release notes
- [ ] Archive build (Product → Archive)
- [ ] Validate in App Store Connect
- [ ] Submit for review

## Troubleshooting

### Build Errors

**Error**: "Module not found"
```bash
# Solution: Clean build folder
Cmd + Shift + K
Then rebuild: Cmd + B
```

**Error**: "Code signing failed"
```bash
# Solution: Reset signing
Target → Signing & Capabilities → Reset
```

### Runtime Issues

**App crashes on launch**
- Check console output (Cmd + Shift + C)
- Add breakpoint at app launch
- Check Info.plist for syntax errors

**Simulator issues**
```bash
# Hard reset simulator
xcrun simctl erase all
```

## Continuous Integration

### GitHub Actions

Create `.github/workflows/build.yml`:

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: xcodebuild -scheme ForexAnalyzer
      - name: Test
        run: xcodebuild test -scheme ForexAnalyzer
```

## Local Development Server (Optional)

For API testing without real APIs:

```bash
# Install Node.js if needed
# Create mock server in: mock-server/
npm install json-server -g
json-server --watch db.json --port 3000
```

Then point app to: `http://localhost:3000`

---

**Next Steps**:
1. Create Xcode project following this guide
2. Copy all `.swift` files to appropriate groups
3. Build and run on simulator
4. Test all tabs and features
5. Configure your API keys
6. Deploy to App Store

For questions, refer to the main README.md
