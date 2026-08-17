import SwiftUI

struct SecurityDashboardView: View {
    @State private var authHistory: [AuthEvent] = []
    @State private var encryptionStatus: EncryptionStatus = .active
    @State private var threatDetections: [ThreatDetection] = []
    @State private var securityScore: Double = 85
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var selectedEvent: AuthEvent?
    @State private var showThreatMap = true
    @State private var showAuthLog = true
    @State private var twoFactorEnabled = true
    @State private var biometricEnabled = true
    @State private var autoLockEnabled = true
    @State private var autoLockTimeout: Double = 300
    @State private var lastScanDate: Date = Date()
    @State private var activeTab: SecurityTab = .overview
    @State private var sessionCount: Int = 0
    @State private var failedAttempts: Int = 0
    @State private var suspiciousIPs: [String] = []
    @State private var firewallRules: [FirewallRule] = []
    @State private var encryptionKeys: [EncryptionKey] = []
    @State private var complianceReports: [ComplianceReport] = []
    @State private var selectedThreat: ThreatDetection?
    @State private var showingSecurityReport = false

    struct AuthEvent: Identifiable {
        let id = UUID()
        let eventType: AuthEventType
        let user: String
        let ipAddress: String
        let device: String
        let timestamp: Date
        let success: Bool
        let location: String
        enum AuthEventType { case login, logout, failedAttempt, passwordChange, mfaChallenge }
    }

    struct EncryptionStatus {
        var status: StatusType
        var algorithm: String
        var keyLength: Int
        var lastRotated: Date
        var certificateExpiry: Date
        enum StatusType { case active, warning, expired }
    }

    struct ThreatDetection: Identifiable {
        let id = UUID()
        let type: ThreatType
        let severity: ThreatSeverity
        let description: String
        let source: String
        let timestamp: Date
        let isResolved: Bool
        enum ThreatType { case bruteForce, phishing, malware, ddos, dataLeak, suspiciousIP }
        enum ThreatSeverity { case low, medium, high, critical }
    }

    struct FirewallRule: Identifiable {
        let id = UUID()
        let name: String
        let action: String
        let protocol: String
        let port: Int
        let isActive: Bool
    }

    struct EncryptionKey: Identifiable {
        let id = UUID()
        let name: String
        let algorithm: String
        let keyLength: Int
        let createdAt: Date
        let expiresAt: Date
    }

    struct ComplianceReport: Identifiable {
        let id = UUID()
        let title: String
        let status: String
        let date: Date
        let score: Double
    }

    enum SecurityTab: String, CaseIterable { case overview = "Overview"; case threats = "Threats"; case encryption = "Encryption"; case firewall = "Firewall" }

    enum SecurityLevel: String { case low = "Low"; case medium = "Medium"; case high = "High"; case critical = "Critical" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  S E C U R I T Y", title: "Dashboard")
                        Spacer()
                        Label("SCORE \(Int(securityScore))", systemImage: "shield.fill").font(.caption2.weight(.bold)).foregroundStyle(securityScoreColor)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(securityScoreColor.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Security Score", value: "\(Int(securityScore))%", detail: "overall rating", tint: securityScoreColor)
                        MetricTile(label: "Threats", value: "\(threatDetections.count)", detail: "active detections", tint: threatColor)
                        MetricTile(label: "Auth Events", value: "\(authHistory.count)", detail: "24h log", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Encryption", value: encryptionStatus.status == .active ? "Active" : "Warning", detail: encryptionStatus.algorithm, tint: encryptionStatus.status == .active ? .green : .orange)
                    }

                    HStack(spacing: 12) {
                        Button { runSecurityScan() }
                            label: { Label(isScanning ? "Scanning…" : "Run Security Scan", systemImage: isScanning ? "arrow.triangle.2.circlepath" : "shield.lefthalf.filled").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan).disabled(isScanning)
                        if isScanning { ProgressView(value: scanProgress).tint(SystemFlyeTheme.cyan).frame(width: 120) }
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showThreatMap.toggle() } }
                            label: { Label(showThreatMap ? "Hide Threats" : "Threats", systemImage: "exclamationmark.triangle.fill").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(showThreatMap ? .orange : .secondary)
                        Button { showingSecurityReport = true }
                            label: { Label("Report", systemImage: "doc.text.fill").font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(.green)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("SECURITY CONTROLS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        VStack(spacing: 12) {
                            ToggleRow(title: "Two-Factor Authentication", subtitle: "Require 2FA for all logins", isOn: $twoFactorEnabled)
                            ToggleRow(title: "Biometric Login", subtitle: "Use Face ID / Touch ID", isOn: $biometricEnabled)
                            ToggleRow(title: "Auto-Lock", subtitle: "Lock after inactivity", isOn: $autoLockEnabled)
                            HStack { Text("Auto-Lock Timeout").font(.caption).foregroundStyle(.secondary); Spacer(); Slider(value: $autoLockTimeout, in: 60...900, step: 60).tint(SystemFlyeTheme.cyan); Text("\(Int(autoLockTimeout / 60))m").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 30) }
                            .padding(.horizontal, 4)
                        }
                        .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
                    }

                    if showThreatMap { threatsView.padding(.top, 4) }
                    if showAuthLog { authLogView.padding(.top, 4) }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Security").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSecurityReport) { securityReportView }
            .onAppear { generateSecurityData() }
        }
    }

    private var securityScoreColor: Color {
        if securityScore >= 90 { return .green }; if securityScore >= 70 { return SystemFlyeTheme.cyan }; if securityScore >= 50 { return .orange }; return .red
    }
    private var threatColor: Color { threatDetections.filter { !$0.isResolved }.count > 0 ? .orange : .green }

    private func generateSecurityData() {
        let eventTypes: [AuthEvent.AuthEventType] = [.login, .logout, .failedAttempt, .passwordChange, .mfaChallenge]
        authHistory = (0..<20).map { i in
            AuthEvent(eventType: eventTypes.randomElement()!, user: "user_\(Int.random(in: 100...999))", ipAddress: "\(Int.random(in: 10...255)).\(Int.random(in: 0...255)).\(Int.random(in: 0...255)).\(Int.random(in: 1...255))", device: ["iPhone 15", "iPad Pro", "MacBook Pro", "iMac", "Apple Watch"].randomElement()!, timestamp: Date().addingTimeInterval(-Double(i) * 3600), success: eventTypes.randomElement() != .failedAttempt, location: ["New York, US", "London, UK", "Tokyo, JP", "Berlin, DE", "Sydney, AU"].randomElement()!)
        }.sorted { $0.timestamp > $1.timestamp }

        let threatTypes: [ThreatDetection.ThreatType] = [.bruteForce, .phishing, .malware, .ddos, .dataLeak, .suspiciousIP]
        let severities: [ThreatDetection.ThreatSeverity] = [.low, .medium, .high, .critical]
        threatDetections = (0..<Int.random(in: 2...6)).map { _ in
            ThreatDetection(type: threatTypes.randomElement()!, severity: severities.randomElement()!, description: threatDescriptions.randomElement()!, source: "\(Int.random(in: 10...255)).\(Int.random(in: 0...255)).\(Int.random(in: 0...255)).\(Int.random(in: 1...255))", timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)), isResolved: Bool.random())
        }

        encryptionStatus = EncryptionStatus(status: .active, algorithm: "AES-256-GCM", keyLength: 256, lastRotated: Date().addingTimeInterval(-86400 * 7), certificateExpiry: Date().addingTimeInterval(86400 * 90))

        firewallRules = [
            FirewallRule(name: "Allow HTTPS", action: "Allow", protocol: "TCP", port: 443, isActive: true),
            FirewallRule(name: "Block SSH", action: "Deny", protocol: "TCP", port: 22, isActive: true),
            FirewallRule(name: "Allow DNS", action: "Allow", protocol: "UDP", port: 53, isActive: true),
            FirewallRule(name: "Block Telnet", action: "Deny", protocol: "TCP", port: 23, isActive: false)
        ]

        encryptionKeys = [
            EncryptionKey(name: "Primary", algorithm: "RSA-2048", keyLength: 2048, createdAt: Date().addingTimeInterval(-86400 * 30), expiresAt: Date().addingTimeInterval(86400 * 335)),
            EncryptionKey(name: "Backup", algorithm: "ECDSA", keyLength: 256, createdAt: Date().addingTimeInterval(-86400 * 15), expiresAt: Date().addingTimeInterval(86400 * 345))
        ]

        complianceReports = [
            ComplianceReport(title: "SOC 2 Type II", status: "Compliant", date: Date().addingTimeInterval(-86400 * 7), score: 95),
            ComplianceReport(title: "GDPR Audit", status: "Compliant", date: Date().addingTimeInterval(-86400 * 30), score: 92),
            ComplianceReport(title: "HIPAA Review", status: "In Progress", date: Date().addingTimeInterval(-86400 * 3), score: 88)
        ]

        sessionCount = authHistory.filter { $0.eventType == .login && $0.success }.count
        failedAttempts = authHistory.filter { $0.eventType == .failedAttempt }.count
        suspiciousIPs = authHistory.filter { $0.eventType == .failedAttempt }.map(\.ipAddress)
    }

    private var threatsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THREAT DETECTIONS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            if threatDetections.isEmpty {
                ContentUnavailableView("No Threats Detected", systemImage: "checkmark.shield.fill") { Text("Your system appears secure.").font(.caption).foregroundStyle(.secondary) }.frame(height: 150)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(threatDetections) { threat in
                        HStack(spacing: 12) {
                            Circle().fill(threatSeverityColor(threat.severity)).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) { Text(threat.type.rawValue.capitalized).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(threat.description).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) { Text(threat.isResolved ? "Resolved" : "Active").font(.caption2.weight(.bold)).foregroundStyle(threat.isResolved ? .green : .orange); Text(threat.timestamp, style: .relative).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var authLogView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUTHENTICATION LOG").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(authHistory.prefix(10)) { event in
                    HStack(spacing: 12) {
                        Circle().fill(event.success ? .green : .red).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(event.user).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text("\(event.eventType.rawValue.capitalized) · \(event.device)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) { Text(event.ipAddress).font(.caption2.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan); Text(event.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary) }
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func threatSeverityColor(_ severity: ThreatDetection.ThreatSeverity) -> Color {
        switch severity { case .low: return .blue; case .medium: return .orange; case .high: return .red; case .critical: return .red }
    }

    private func runSecurityScan() {
        isScanning = true; scanProgress = 0
        Task { @MainActor in
            for i in 0..<20 { try? await Task.sleep(for: .milliseconds(100)); scanProgress = Double(i) / 20.0 }
            securityScore = Double.random(in: 80...95)
            lastScanDate = Date()
            isScanning = false; scanProgress = 1.0
        }
    }

    private let threatDescriptions = ["Multiple failed login attempts detected", "Suspicious login from unknown location", "Phishing attempt blocked", "Malware signature detected in upload", "DDoS traffic pattern identified", "Data exfiltration attempt prevented"]

    private var securityReportView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Security Report").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(complianceReports) { report in
                        HStack { Text(report.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); Text("\(Int(report.score))%").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan); Text(report.status).font(.caption).foregroundStyle(report.status == "Compliant" ? .green : .orange) }
                        .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Spacer()
                HStack(spacing: 12) { Button("Close") { showingSecurityReport = false }.buttonStyle(.bordered()).tint(.secondary); Button("Download") {}.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan) }
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }
}

struct SecurityDashboardView_Previews: PreviewProvider {
    static var previews: some View { SecurityDashboardView().preferredColorScheme(.dark) }
}

