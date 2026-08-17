import SwiftUI

struct SettingsView: View {
    @State private var enableNotifications = true
    @State private var soundEnabled = true
    @State private var selectedTheme = "Dark"
    @State private var riskLevel = 2.0
    @State private var updateInterval = 2.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text("Configure your trading preferences")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Notification Settings
                    SettingSection(title: "Notifications") {
                        SettingToggle(
                            title: "Enable Notifications",
                            subtitle: "Receive alerts for new trading signals",
                            isOn: $enableNotifications
                        )
                        
                        SettingToggle(
                            title: "Sound Alerts",
                            subtitle: "Play sound for important notifications",
                            isOn: $soundEnabled
                        )
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Display Settings
                    SettingSection(title: "Display") {
                        SettingPicker(
                            title: "Theme",
                            subtitle: "Choose your preferred color theme",
                            options: ["Dark", "Light", "Auto"],
                            selection: $selectedTheme
                        )
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Trading Settings
                    SettingSection(title: "Trading") {
                        SettingSlider(
                            title: "Risk Level",
                            subtitle: "Adjust your maximum risk tolerance",
                            value: $riskLevel,
                            range: 1...10,
                            displayValue: "\(Int(riskLevel))%"
                        )
                        
                        SettingSlider(
                            title: "Data Update Interval",
                            subtitle: "How often to refresh market data",
                            value: $updateInterval,
                            range: 1...10,
                            displayValue: "\(Int(updateInterval))s"
                        )
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Pair Selection
                    SettingSection(title: "Watched Pairs") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Customize which forex pairs to monitor")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                            
                            VStack(spacing: 8) {
                                PairToggle(pair: "EURUSD", isOn: true)
                                PairToggle(pair: "GBPUSD", isOn: true)
                                PairToggle(pair: "USDJPY", isOn: true)
                                PairToggle(pair: "USDCHF", isOn: false)
                                PairToggle(pair: "AUDUSD", isOn: false)
                                PairToggle(pair: "NZDUSD", isOn: false)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Live Forex Provider Settings
                    SettingSection(title: "Live Forex Providers") {
                        ProviderConfigurationView()
                            .environmentObject(APIClientManager.shared)
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // About
                    SettingSection(title: "About") {
                        SettingInfo(
                            title: "Version",
                            value: "1.0.0"
                        )
                        
                        SettingInfo(
                            title: "Last Updated",
                            value: "Today"
                        )
                        
                        VStack(spacing: 8) {
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check for Updates")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            
                            Divider()
                                .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "book.fill")
                                    Text("Documentation")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            
                            Divider()
                                .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Support")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Danger Zone
                    SettingSection(title: "Danger Zone") {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                
                                Text("Reset All Settings")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                
                                Text("Clear All Data")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Text("© 2024 Forex Analyzer. All rights reserved.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 20)
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }
}

struct SettingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

struct SettingToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.blue)
        }
        .padding(.vertical, 12)
    }
}

struct SettingPicker: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selection: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .tint(.blue)
        }
        .padding(.vertical, 12)
    }
}

struct SettingSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let displayValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(displayValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Slider(value: $value, in: range)
                .tint(.blue)
        }
        .padding(.vertical, 12)
    }
}

struct SettingTextField: View {
    let title: String
    let subtitle: String
    let placeholder: String
    var isSecure: Bool = false
    @State private var text = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                    .cornerRadius(6)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 12)
    }
}

struct SettingInfo: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
    }
}

struct PairToggle: View {
    let pair: String
    @State var isOn: Bool
    
    var body: some View {
        HStack {
            Text(pair)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.blue)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SettingsView()
}
