import SwiftUI

struct ProviderConfigurationView: View {
    @EnvironmentObject private var apiClient: APIClientManager
    @State private var primaryProvider = "OANDA"
    @State private var fallbackProvider = "Twelve Data"
    @State private var primaryKey = ""
    @State private var primaryAccount = ""
    @State private var fallbackKey = ""
    @State private var fallbackAccount = ""
    @State private var status = "Credentials are stored in Keychain"
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE FOREX PROVIDERS").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    Text("Primary + automated failover").font(.title3.weight(.semibold)).foregroundStyle(.white)
                }
                Spacer()
                Toggle("Failover", isOn: $apiClient.failoverEnabled).labelsHidden().tint(.green)
            }

            providerForm(title: "Primary provider", selection: $primaryProvider, key: $primaryKey, account: $primaryAccount, showsAccount: primaryProvider == "OANDA")
            providerForm(title: "Fallback provider", selection: $fallbackProvider, key: $fallbackKey, account: $fallbackAccount, showsAccount: fallbackProvider == "OANDA")

            HStack(spacing: 10) {
                Button("Save Keychain credentials") { saveCredentials() }
                    .buttonStyle(.borderedProminent).tint(.cyan)
                Button(isTesting ? "Testing…" : "Test primary") { testConnection() }
                    .buttonStyle(.bordered).disabled(isTesting || apiClient.provider == nil)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(status).font(.caption).foregroundStyle(status.contains("failed") ? .red : .secondary)
                Text("Primary: \(apiClient.primaryProviderName)  ·  Fallback: \(apiClient.fallbackProviderName)").font(.caption2.monospacedDigit()).foregroundStyle(.cyan)
                Text("Last successful: \(apiClient.lastSuccessfulProvider)  ·  Failovers: \(apiClient.failoverCount)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }

            HStack {
                Button("Clear primary") { apiClient.clearCredentials(fallback: false); status = "Primary credentials cleared" }.buttonStyle(.bordered).tint(.red)
                Button("Clear fallback") { apiClient.clearCredentials(fallback: true); status = "Fallback credentials cleared" }.buttonStyle(.bordered).tint(.red)
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .task {
            apiClient.loadCredentialsFromKeychain()
        }
    }

    @ViewBuilder
    private func providerForm(title: String, selection: Binding<String>, key: Binding<String>, account: Binding<String>, showsAccount: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.white)
            Picker(title, selection: selection) {
                Text("OANDA").tag("OANDA")
                Text("Twelve Data").tag("Twelve Data")
            }
            .pickerStyle(.segmented)
            SecureField("API key", text: key).textFieldStyle(.roundedBorder)
            if showsAccount { SecureField("OANDA account ID", text: account).textFieldStyle(.roundedBorder) }
        }
    }

    private func saveCredentials() {
        do {
            try apiClient.saveCredentials(provider: primaryProvider == "OANDA" ? .oanda : .twelveData, apiKey: primaryKey, accountID: primaryAccount)
            if !fallbackKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try apiClient.saveCredentials(provider: fallbackProvider == "OANDA" ? .oanda : .twelveData, apiKey: fallbackKey, accountID: fallbackAccount, asFallback: true)
            }
            status = "Credentials saved securely to Keychain"
        } catch { status = "Save failed: \(error.localizedDescription)" }
    }

    private func testConnection() {
        isTesting = true
        Task {
            await apiClient.testConnection()
            await MainActor.run {
                isTesting = false
                status = apiClient.isConnected ? "Primary connection successful" : "Primary connection failed"
            }
        }
    }
}
