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


// MARK: - Extended Implementation

struct ExtendedDetailView: View {
    @State private var items: [ExtendedItem] = []
    @State private var selectedID: UUID?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all
    @State private var sortOrder: SortOrder = .name
    @State private var isExpanded: Bool = false
    @State private var showingDetail = false
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 5
    @State private var itemsPerPage: Int = 20
    @State private var viewMode: ViewMode = .list
    @State private var gridColumns: Int = 3
    @State private var showArchived = false
    @State private var showPinned = false
    @State private var isRefreshing = false
    @State private var refreshProgress: Double = 0.0

    enum FilterMode: String, CaseIterable { case all = "All"; case active = "Active"; case completed = "Completed"; case pending = "Pending"; case archived = "Archived" }
    enum SortOrder: String, CaseIterable { case name = "Name"; case date = "Date"; case priority = "Priority"; case status = "Status" }
    enum ViewMode: String, CaseIterable { case list = "List"; case grid = "Grid"; case compact = "Compact"; case detailed = "Detailed" }

    struct ExtendedItem: Identifiable {
        let id = UUID()
        var title: String
        var subtitle: String
        var description: String
        var status: ItemStatus
        var priority: Priority
        var createdAt: Date
        var updatedAt: Date
        var tags: [String]
        var metadata: [String: String]
        var isPinned: Bool
        var isArchived: Bool
        var color: Color
    }

    enum ItemStatus: String { case pending = "Pending"; case active = "Active"; case completed = "Completed"; case failed = "Failed"; case cancelled = "Cancelled" }
    enum Priority: String, CaseIterable { case low = "Low"; case medium = "Medium"; case high = "High"; case urgent = "Urgent" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    controlsView
                    contentView
                    footerView
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Extended Detail")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { generateItems() }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  E X T E N D E D", title: "Detail View")
                Spacer()
                Label("EXTENDED", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(SystemFlyeTheme.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SystemFlyeTheme.violet.opacity(0.12), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(metricTiles) { tile in
                    MetricTile(label: tile.label, value: tile.value, detail: tile.detail, tint: tile.tint)
                }
            }
        }
    }

    private var controlsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search items...", text: $searchText).textFieldStyle(.plain).foregroundStyle(.white)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterMode.allCases) { mode in
                        Button { filterMode = mode }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(filterMode == mode ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(filterMode == mode ? .black : .white.opacity(0.7)) }
                    }
                    ForEach(ViewMode.allCases) { mode in
                        Button { viewMode = mode }
                            label: { Text(mode.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(viewMode == mode ? SystemFlyeTheme.violet : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(viewMode == mode ? .black : .white.opacity(0.7)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button { generateItems() }
                    label: { Label("Refresh", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { isExpanded.toggle() }
                    label: { Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.right.and.arrow.down.left").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.green)
                Button { showingDetail = true }
                    label: { Label("Detail", systemImage: "info.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .list: listContentView
        case .grid: gridContentView
        case .compact: compactContentView
        case .detailed: detailedContentView
        }
    }

    private var listContentView: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredItems) { item in
                HStack(spacing: 14) {
                    Circle().fill(item.color).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor(item.status))
                        Text(item.priority.rawValue).font(.caption2).foregroundStyle(priorityColor(item.priority))
                    }
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var gridContentView: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumns)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Circle().fill(item.color).frame(width: 8, height: 8)
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(item.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(statusColor(item.status))
                }
                .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var compactContentView: some View {
        LazyVStack(spacing: 6) {
            ForEach(filteredItems) { item in
                HStack(spacing: 10) {
                    Circle().fill(item.color).frame(width: 6, height: 6)
                    Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(item.status.rawValue).font(.caption2).foregroundStyle(statusColor(item.status))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var detailedContentView: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredItems) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.title).font(.headline.weight(.bold)).foregroundStyle(.white)
                        Spacer()
                        Text(item.priority.rawValue).font(.caption.weight(.bold)).foregroundStyle(priorityColor(item.priority))
                            .padding(.horizontal, 10).padding(.vertical, 5).background(priorityColor(item.priority).opacity(0.15), in: Capsule())
                    }
                    Text(item.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                    HStack(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag).font(.caption2).padding(.horizontal, 8).padding(.vertical, 4).background(Color.white.opacity(0.06), in: Capsule()).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    HStack(spacing: 12) {
                        Text("Created: \(item.createdAt, style: .date)").font(.caption2).foregroundStyle(.secondary)
                        Text("Updated: \(item.updatedAt, style: .relative)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var footerView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Showing \(filteredItems.count) of \(items.count) items").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Page \(currentPage + 1) of \(totalPages)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button { currentPage = max(0, currentPage - 1) }
                    label: { Image(systemName: "chevron.left").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary).disabled(currentPage == 0)
                ForEach(0..<totalPages, id: \.self) { page in
                    Button { currentPage = page }
                        label: { Text("\(page + 1)").font(.caption2.weight(.semibold)).frame(width: 28, height: 28).background(currentPage == page ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(currentPage == page ? .black : .white.opacity(0.7)) }
                }
                Button { currentPage = min(totalPages - 1, currentPage + 1) }
                    label: { Image(systemName: "chevron.right").font(.caption).frame(width: 32, height: 32) }
                    .buttonStyle(.bordered).tint(.secondary).disabled(currentPage == totalPages - 1)
            }
        }
    }

    private var filteredItems: [ExtendedItem] {
        var base = items
        if !searchText.isEmpty { base = base.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.subtitle.localizedCaseInsensitiveContains(searchText) } }
        if filterMode != .all {
            switch filterMode {
            case .active: base = base.filter { $0.status == .active }
            case .completed: base = base.filter { $0.status == .completed }
            case .pending: base = base.filter { $0.status == .pending }
            case .archived: base = base.filter { $0.isArchived }
            default: break
            }
        }
        if showArchived { base = base.filter { $0.isArchived } }
        if showPinned { base = base.filter { $0.isPinned } }
        switch sortOrder {
        case .name: base.sort { $0.title < $1.title }
        case .date: base.sort { $0.updatedAt > $1.updatedAt }
        case .priority: base.sort { priorityRank($0.priority) > priorityRank($1.priority) }
        case .status: base.sort { $0.status.rawValue < $1.status.rawValue }
        }
        return base
    }

    private var metricTiles: [MetricTileData] {
        [
            MetricTileData(label: "Total", value: "\(items.count)", detail: "all items", tint: SystemFlyeTheme.cyan),
            MetricTileData(label: "Active", value: "\(items.filter { $0.status == .active }.count)", detail: "in progress", tint: .green),
            MetricTileData(label: "Pinned", value: "\(items.filter { $0.isPinned }.count)", detail: "starred", tint: .orange),
            MetricTileData(label: "Archived", value: "\(items.filter { $0.isArchived }.count)", detail: "hidden", tint: .secondary)
        ]
    }

    struct MetricTileData { let label: String; let value: String; let detail: String; let tint: Color }

    private func statusColor(_ status: ItemStatus) -> Color {
        switch status { case .pending: return .orange; case .active: return SystemFlyeTheme.cyan; case .completed: return .green; case .failed: return .red; case .cancelled: return .secondary }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority { case .low: return .secondary; case .medium: return .blue; case .high: return .orange; case .urgent: return .red }
    }

    private func priorityRank(_ priority: Priority) -> Int {
        switch priority { case .low: return 1; case .medium: return 2; case .high: return 3; case .urgent: return 4 }
    }

    private func generateItems() {
        isRefreshing = true
        let statuses: [ItemStatus] = [.pending, .active, .completed, .failed, .cancelled]
        let priorities: [Priority] = [.low, .medium, .high, .urgent]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        let titles = ["Project Alpha", "Task Beta", "Feature Gamma", "Bug Delta", "Epic Epsilon", "Story Zeta", "Ticket Eta", "Issue Theta"]
        let subtitles = ["In progress", "Under review", "Blocked", "Ready for testing", "Draft", "Approved", "Pending", "Shipped"]
        items = (0..<50).map { _ in
            ExtendedItem(title: titles.randomElement()!, subtitle: subtitles.randomElement()!, description: "This is a detailed description for the item providing comprehensive context and background information.", status: statuses.randomElement()!, priority: priorities.randomElement()!, createdAt: Date().addingTimeInterval(-Double.random(in: 0...86400 * 30)), updatedAt: Date().addingTimeInterval(-Double.random(in: 0...86400)), tags: ["tag1", "tag2", "tag3"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }, metadata: ["key1": "value1", "key2": "value2"], isPinned: Bool.random(), isArchived: Bool.random(), color: colors.randomElement()!)
        }
        isRefreshing = false
    }
}

struct ExtendedDetailView_Previews: PreviewProvider {
    static var previews: some View { ExtendedDetailView().preferredColorScheme(.dark) }
}


// MARK: - Additional Comprehensive Implementation

struct AdditionalDetailView: View {
    @State private var dataItems: [DataItem] = []
    @State private var selectedIndex: Int? = nil
    @State private var isActive: Bool = true
    @State private var progress: Double = 0.5
    @State private var counter: Int = 0
    @State private var items: [ListItem] = []
    @State private var sections: [SectionItem] = []
    @State private var selectedSection: SectionItem?
    @State private var searchQuery: String = ""
    @State private var filterEnabled: Bool = true
    @State private var sortAscending: Bool = true
    @State private var currentPage: Int = 1
    @State private var totalItems: Int = 0
    @State private var showAdvanced: Bool = false
    @State private var showSettings: Bool = false
    @State private var showHelp: Bool = false
    @State private var isDarkMode: Bool = true
    @State private var accentTint: Color = SystemFlyeTheme.cyan
    @State private var fontSize: CGFloat = 16
    @State private var lineSpacing: CGFloat = 1.4
    @State private var cornerRadius: CGFloat = 12
    @State private var shadowRadius: CGFloat = 8
    @State private var animationDuration: Double = 0.3
    @State private var transitionStyle: TransitionStyle = .spring
    @State private var layoutDirection: LayoutDirection = .vertical
    @State private var spacing: CGFloat = 12
    @State private var padding: CGFloat = 18
    @State private var backgroundOpacity: Double = 0.02
    @State private var overlayOpacity: Double = 0.1
    @State private var borderWidth: CGFloat = 1.0
    @State private var borderColor: Color = SystemFlyeTheme.line
    @State private var shadowColor: Color = .black
    @State private var shadowOffset: CGSize = CGSize(width: 0, height: 4)
    @State private var contentMode: ContentMode = .fit
    @State private var alignment: Alignment = .leading
    @State private var distribution: Distribution = .equalSpacing
    @State private var priority: Priority = .normal

    enum TransitionStyle: String, CaseIterable { case spring = "Spring"; case easeIn = "Ease In"; case easeOut = "Ease Out"; case linear = "Linear"; case none = "None" }
    enum LayoutDirection: String, CaseIterable { case vertical = "Vertical"; case horizontal = "Horizontal" }
    enum ContentMode: String, CaseIterable { case fit = "Fit"; case fill = "Fill"; case scaleToFit = "Scale" }
    enum Distribution: String, CaseIterable { case equalSpacing = "Equal"; case equalCentering = "Centered"; case leading = "Leading"; case trailing = "Trailing" }
    enum Priority: String, CaseIterable { case low = "Low"; case normal = "Normal"; case high = "High" }

    struct DataItem: Identifiable {
        let id = UUID()
        var title: String
        var value: Double
        var unit: String
        var trend: TrendDirection
        var metadata: [String: String]
        enum TrendDirection { case up, down, neutral, volatile }
    }

    struct ListItem: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var timestamp: Date
        var isSelected: Bool
        var tags: [String]
        var color: Color
    }

    struct SectionItem: Identifiable {
        let id = UUID()
        var title: String
        var items: [ListItem]
        var isExpanded: Bool
        var color: Color
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    controlPanel
                    contentSection
                    statisticsSection
                    actionButtons
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Additional Detail")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadData() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  A D D I T I O N A L", title: "Detail View")
                Spacer()
                Label("ACTIVE", systemImage: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isActive ? .green : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background((isActive ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(overviewTiles) { tile in
                    MetricTile(label: tile.label, value: tile.value, detail: tile.detail, tint: tile.tint)
                }
            }
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search...", text: $searchQuery).textFieldStyle(.plain).foregroundStyle(.white)
                Toggle("", isOn: $filterEnabled).labelsHidden().tint(SystemFlyeTheme.cyan)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sections.indices, id: \.self) { index in
                        Button { selectedSection = sections[index] }
                            label: { Text(sections[index].title).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedSection?.id == sections[index].id ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedSection?.id == sections[index].id ? .black : .white.opacity(0.7)) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button { loadData() }
                    label: { Label("Refresh", systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                Button { showAdvanced.toggle() }
                    label: { Label(showAdvanced ? "Hide" : "Advanced", systemImage: "gearshape.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(showAdvanced ? SystemFlyeTheme.violet : .secondary)
                Button { showHelp.toggle() }
                    label: { Label("Help", systemImage: "questionmark.circle").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let section = selectedSection {
            sectionDetailView(section)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Circle().fill(item.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(item.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(14).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(SystemFlyeTheme.line))
                }
            }
        }
    }

    private func sectionDetailView(_ section: SectionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
            LazyVStack(spacing: 8) {
                ForEach(section.items) { item in
                    HStack(spacing: 12) {
                        Circle().fill(item.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(item.description).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        ForEach(item.tags.prefix(2), id: \.self) { tag in
                            Text(tag).font(.caption2).padding(.horizontal, 6).padding(.vertical, 3).background(Color.white.opacity(0.06), in: Capsule()).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATISTICS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Items", value: "\(items.count)")
                StatCard(label: "Sections", value: "\(sections.count)")
                StatCard(label: "Selected", value: selectedIndex != nil ? "1" : "0")
                StatCard(label: "Progress", value: "\(Int(progress * 100))%")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { counter += 1 }
                label: { Label("Increment", systemImage: "plus").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
            Button { counter = max(0, counter - 1) }
                label: { Label("Decrement", systemImage: "minus").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.bordered).tint(.orange)
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { progress = Double.random(in: 0...1) } }
                label: { Label("Random", systemImage: "dice.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                .buttonStyle(.bordered).tint(.green)
            Spacer()
            Text("Count: \(counter)").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
        }
    }

    private var overviewTiles: [OverviewTile] {
        [
            OverviewTile(label: "Total", value: "\(items.count)", detail: "items loaded", tint: SystemFlyeTheme.cyan),
            OverviewTile(label: "Sections", value: "\(sections.count)", detail: "categories", tint: SystemFlyeTheme.violet),
            OverviewTile(label: "Selected", value: selectedIndex != nil ? "1" : "0", detail: "active", tint: .green),
            OverviewTile(label: "Counter", value: "\(counter)", detail: "increments", tint: .orange)
        ]
    }

    struct OverviewTile { let label: String; let value: String; let detail: String; let tint: Color }

    private func loadData() {
        let statuses: [ListItem.ItemStatus] = [.pending, .active, .completed, .failed, .cancelled]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        let titles = ["Project Alpha", "Task Beta", "Feature Gamma", "Bug Delta", "Epic Epsilon", "Story Zeta", "Ticket Eta", "Issue Theta"]
        let descriptions = ["In progress", "Under review", "Blocked", "Ready for testing", "Draft", "Approved", "Pending", "Shipped"]
        items = (0..<30).map { _ in
            ListItem(title: titles.randomElement()!, description: descriptions.randomElement()!, timestamp: Date().addingTimeInterval(-Double.random(in: 0...86400)), isSelected: Bool.random(), tags: ["tag1", "tag2", "tag3"].shuffled().prefix(Int.random(in: 1...3)).map { $0 }, color: colors.randomElement()!)
        }
        sections = [
            SectionItem(title: "Overview", items: Array(items.prefix(10)), isExpanded: true, color: SystemFlyeTheme.cyan),
            SectionItem(title: "Details", items: Array(items.suffix(10)), isExpanded: false, color: SystemFlyeTheme.violet),
            SectionItem(title: "History", items: Array(items.shuffled().prefix(10)), isExpanded: false, color: .green)
        ]
        totalItems = items.count
    }
}

struct ListItem: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var timestamp: Date
    var isSelected: Bool
    var tags: [String]
    var color: Color
    enum ItemStatus: String { case pending = "Pending"; case active = "Active"; case completed = "Completed"; case failed = "Failed"; case cancelled = "Cancelled" }
}

struct SectionItem: Identifiable {
    let id = UUID()
    var title: String
    var items: [ListItem]
    var isExpanded: Bool
    var color: Color
}

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ExtendedDetailView_Previews: PreviewProvider {
    static var previews: some View { ExtendedDetailView().preferredColorScheme(.dark) }
}
