import SwiftUI

struct ComplianceDashboardView: View {
    @State private var auditLogs: [AuditLogEntry] = []
    @State private var retentionPolicies: [RetentionPolicy] = []
    @State private var privacySettings: PrivacySettings = PrivacySettings()
    @State private var complianceScore: Double = 92
    @State private var isGeneratingReport = false
    @State private var selectedCategory: AuditCategory = .all
    @State private var dateRange: DateRange = .last30Days
    @State private var showExportSheet = false
    @State private var exportFormat: ExportFormat = .json
    @State private var activeTab: ComplianceTab = .overview
    @State private var totalAuditEntries: Int = 0
    @State private var policyViolations: Int = 0
    @State private var pendingReviews: Int = 0
    @State private var lastAuditDate: Date = Date()
    @State private var nextAuditDate: Date = Date().addingTimeInterval(86400 * 30)
    @State private var regulations: [Regulation] = []
    @State private var showingAddPolicy = false
    @State private var showingAddAudit = false
    @State private var policyTemplates: [PolicyTemplate] = []

    struct AuditLogEntry: Identifiable {
        let id = UUID()
        let action: String
        let category: AuditCategory
        let user: String
        let resource: String
        let timestamp: Date
        let outcome: AuditOutcome
        let details: String
        enum AuditCategory: String, CaseIterable, Identifiable { case all = "All"; case access = "Access"; case data = "Data"; case authentication = "Authentication"; case system = "System"; case policy = "Policy"; var id: String { rawValue } }
        enum AuditOutcome { case success, failure, warning }
    }

    struct RetentionPolicy: Identifiable {
        let id = UUID()
        let name: String
        let dataType: String
        let retentionPeriod: String
        let isActive: Bool
        let lastReview: Date
    }

    struct PrivacySettings {
        var dataCollectionEnabled = true
        var analyticsSharingEnabled = false
        var thirdPartyIntegrationsEnabled = true
        var locationTrackingEnabled = false
        var personalizationEnabled = true
        var dataPortabilityEnabled = true
        var rightToErasureEnabled = true
        var consentLoggingEnabled = true
        var gdprCompliant = true
        var ccpaCompliant = true
        var dataMinimizationEnabled = true
        var purposeLimitationEnabled = true
        var userConsentRequired = true
        var dataProcessingRecord = true
        var dpiaCompleted = true
    }

    enum ExportFormat: String, CaseIterable { case json = "JSON"; case csv = "CSV"; case pdf = "PDF"; case xml = "XML" }
    enum DateRange: String, CaseIterable { case last7Days = "7 Days"; case last30Days = "30 Days"; case last90Days = "90 Days"; case lastYear = "1 Year"; case allTime = "All Time" }
    enum ComplianceTab: String, CaseIterable { case overview = "Overview"; case audit = "Audit"; case policies = "Policies"; case privacy = "Privacy"; case regulations = "Regulations" }

    struct Regulation: Identifiable {
        let id = UUID()
        let name: String
        let status: ComplianceStatus
        let lastReview: Date
        let score: Double
        enum ComplianceStatus { case compliant, nonCompliant, inProgress, notApplicable }
    }

    struct PolicyTemplate: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let category: String
        let isActive: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  C O M P L I A N C E", title: "Dashboard")
                        Spacer()
                        Label("\(Int(complianceScore))%", systemImage: "checkmark.seal.fill").font(.caption2.weight(.bold)).foregroundStyle(complianceScoreColor)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(complianceScoreColor.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Compliance", value: "\(Int(complianceScore))%", detail: "overall score", tint: complianceScoreColor)
                        MetricTile(label: "Audit Entries", value: "\(auditLogs.count)", detail: "tracked events", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Policies", value: "\(retentionPolicies.count)", detail: "active rules", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "Violations", value: "\(policyViolations)", detail: "policy breaks", tint: policyViolations > 0 ? .red : .green)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ComplianceTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .overview: overviewTab
                    case .audit: auditTab
                    case .policies: policiesTab
                    case .privacy: privacyTab
                    case .regulations: regulationsTab
                    }

                    HStack(spacing: 12) {
                        Button { generateComplianceReport() }
                            label: { Label(isGeneratingReport ? "Generating…" : "Generate Report", systemImage: isGeneratingReport ? "arrow.triangle.2.circlepath" : "doc.text.fill").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan).disabled(isGeneratingReport)
                        if isGeneratingReport { ProgressView().tint(SystemFlyeTheme.cyan).frame(width: 20) }
                        Button { showExportSheet = true }
                            label: { Label("Export", systemImage: "square.and.arrow.up").font(.caption.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 10) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.violet).sheet(isPresented: $showExportSheet) { exportOptionsView }
                    }
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Compliance").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddPolicy) { addPolicyView }
            .sheet(isPresented: $showingAddAudit) { addAuditView }
            .onAppear { generateComplianceData() }
        }
    }

    private var complianceScoreColor: Color {
        if complianceScore >= 90 { return .green }; if complianceScore >= 70 { return SystemFlyeTheme.cyan }; if complianceScore >= 50 { return .orange }; return .red
    }

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Audit Entries", value: "\(auditLogs.count)")
                StatCard(label: "Policies", value: "\(retentionPolicies.count)")
                StatCard(label: "Violations", value: "\(policyViolations)")
                StatCard(label: "Pending Reviews", value: "\(pendingReviews)")
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("COMPLIANCE SCORE").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                    VStack(spacing: 16) {
                        Text("\(Int(complianceScore))%").font(.system(size: 48, weight: .bold)).foregroundStyle(complianceScoreColor)
                        ProgressView(value: complianceScore / 100).tint(complianceScoreColor).frame(height: 8)
                        Text("Next audit: \(nextAuditDate, style: .date)").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .frame(height: 140)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            }
        }
    }

    private var auditTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AUDIT LOG").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Button { showingAddAudit = true } label: { Label("Add Entry", systemImage: "plus.circle.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dateRange = range } }
                            label: { Text(range.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(dateRange == range ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(dateRange == range ? .black : .white.opacity(0.7)) }
                    }
                }
            }
            LazyVStack(spacing: 8) {
                ForEach(auditLogs.prefix(15)) { entry in
                    HStack(spacing: 12) {
                        Circle().fill(outcomeColor(entry.outcome)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(entry.action).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text("\(entry.user) · \(entry.resource)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) { Text(entry.outcome == .success ? "Success" : entry.outcome == .failure ? "Failed" : "Warning").font(.caption2.weight(.bold)).foregroundStyle(outcomeColor(entry.outcome)); Text(entry.timestamp, style: .relative).font(.caption2).foregroundStyle(.secondary) }
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var policiesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RETENTION POLICIES").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                Spacer()
                Button { showingAddPolicy = true } label: { Label("Add Policy", systemImage: "plus.circle.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.violet)
            }
            LazyVStack(spacing: 8) {
                ForEach(retentionPolicies) { policy in
                    HStack(spacing: 12) {
                        Image(systemName: policy.isActive ? "checkmark.circle.fill" : "xmark.circle.fill").font(.caption).foregroundStyle(policy.isActive ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) { Text(policy.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text("\(policy.dataType) · \(policy.retentionPeriod)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text(policy.isActive ? "Active" : "Inactive").font(.caption2.weight(.bold)).foregroundStyle(policy.isActive ? .green : .secondary)
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PRIVACY SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ToggleRow(title: "Data Collection", subtitle: "Allow anonymous usage data collection", isOn: $privacySettings.dataCollectionEnabled)
                ToggleRow(title: "Analytics Sharing", subtitle: "Share analytics with partners", isOn: $privacySettings.analyticsSharingEnabled)
                ToggleRow(title: "Third-Party Integrations", subtitle: "Enable integrations with external services", isOn: $privacySettings.thirdPartyIntegrationsEnabled)
                ToggleRow(title: "Location Tracking", subtitle: "Allow location data collection", isOn: $privacySettings.locationTrackingEnabled)
                ToggleRow(title: "Personalization", subtitle: "Enable personalized recommendations", isOn: $privacySettings.personalizationEnabled)
                ToggleRow(title: "Data Portability", subtitle: "Allow data export and transfer", isOn: $privacySettings.dataPortabilityEnabled)
                ToggleRow(title: "Right to Erasure", subtitle: "Enable data deletion requests", isOn: $privacySettings.rightToErasureEnabled)
                ToggleRow(title: "Consent Logging", subtitle: "Log all consent changes", isOn: $privacySettings.consentLoggingEnabled)
                ToggleRow(title: "GDPR Compliant", subtitle: "General Data Protection Regulation", isOn: $privacySettings.gdprCompliant)
                ToggleRow(title: "CCPA Compliant", subtitle: "California Consumer Privacy Act", isOn: $privacySettings.ccpaCompliant)
                ToggleRow(title: "Data Minimization", subtitle: "Collect only necessary data", isOn: $privacySettings.dataMinimizationEnabled)
                ToggleRow(title: "Purpose Limitation", subtitle: "Use data only for stated purposes", isOn: $privacySettings.purposeLimitationEnabled)
                ToggleRow(title: "User Consent Required", subtitle: "Require explicit user consent", isOn: $privacySettings.userConsentRequired)
                ToggleRow(title: "DPIA Completed", subtitle: "Data Protection Impact Assessment", isOn: $privacySettings.dpiaCompleted)
            }
            .padding(16).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var regulationsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REGULATIONS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(regulations) { reg in
                    HStack(spacing: 12) {
                        Circle().fill(reg.status == .compliant ? .green : reg.status == .inProgress ? .orange : .red).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) { Text(reg.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text("Last review: \(reg.lastReview, style: .date)").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Text("\(Int(reg.score))%").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func outcomeColor(_ outcome: AuditLogEntry.AuditOutcome) -> Color {
        switch outcome { case .success: return .green; case .failure: return .red; case .warning: return .orange }
    }

    private func generateComplianceData() {
        retentionPolicies = [
            RetentionPolicy(name: "User Data", dataType: "PII", retentionPeriod: "7 years", isActive: true, lastReview: Date().addingTimeInterval(-86400 * 30)),
            RetentionPolicy(name: "Analytics", dataType: "Metrics", retentionPeriod: "2 years", isActive: true, lastReview: Date().addingTimeInterval(-86400 * 14)),
            RetentionPolicy(name: "Logs", dataType: "System", retentionPeriod: "90 days", isActive: true, lastReview: Date().addingTimeInterval(-86400 * 7)),
            RetentionPolicy(name: "Backups", dataType: "Snapshots", retentionPeriod: "1 year", isActive: false, lastReview: Date().addingTimeInterval(-86400 * 60))
        ]

        let actions = ["User login", "Data export", "Permission change", "Config update", "Policy review", "Audit query", "Encryption key rotation", "Access granted", "Data deleted", "Consent updated"]
        let categories: [AuditLogEntry.AuditCategory] = [.access, .data, .authentication, .system, .policy]
        let outcomes: [AuditLogEntry.AuditOutcome] = [.success, .success, .success, .warning, .failure]

        auditLogs = (0..<30).map { i in
            AuditLogEntry(action: actions.randomElement()!, category: categories.randomElement()!, user: "user_\(Int.random(in: 100...999))", resource: ["profile", "settings", "dashboard", "api", "database", "storage"].randomElement()!, timestamp: Date().addingTimeInterval(-Double(i) * 1800), outcome: outcomes.randomElement()!, details: "Automated audit entry #\(1000 + i)")
        }.sorted { $0.timestamp > $1.timestamp }

        regulations = [
            Regulation(name: "GDPR", status: .compliant, lastReview: Date().addingTimeInterval(-86400 * 7), score: 95),
            Regulation(name: "CCPA", status: .compliant, lastReview: Date().addingTimeInterval(-86400 * 14), score: 92),
            Regulation(name: "HIPAA", status: .inProgress, lastReview: Date().addingTimeInterval(-86400 * 3), score: 85),
            Regulation(name: "SOC 2", status: .compliant, lastReview: Date().addingTimeInterval(-86400 * 30), score: 98)
        ]

        policyTemplates = [
            PolicyTemplate(name: "Data Retention", description: "Define how long data is kept", category: "Data", isActive: true),
            PolicyTemplate(name: "Access Control", description: "Manage user permissions", category: "Security", isActive: true),
            PolicyTemplate(name: "Incident Response", description: "Handle security incidents", category: "Security", isActive: false),
            PolicyTemplate(name: "Change Management", description: "Control system changes", category: "Operations", isActive: true)
        ]

        totalAuditEntries = auditLogs.count
        policyViolations = auditLogs.filter { $0.outcome == .failure }.count
        pendingReviews = Int.random(in: 5...20)
    }

    private func generateComplianceReport() {
        isGeneratingReport = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            complianceScore = Double.random(in: 88...98)
            isGeneratingReport = false
        }
    }

    private var exportOptionsView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Export Audit Data").font(.title.weight(.bold)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Format").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(ExportFormat.allCases) { format in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { exportFormat = format } }
                            label: { HStack { Text(format.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Spacer(); if exportFormat == format { Image(systemName: "checkmark").foregroundStyle(SystemFlyeTheme.cyan) } }.padding(12).background(exportFormat == format ? SystemFlyeTheme.cyan.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)) }
                            .buttonStyle(.plain)
                    }
                }
                Spacer()
                HStack(spacing: 12) { Button("Cancel") { showExportSheet = false }.buttonStyle(.bordered()).tint(.secondary); Button("Export") { exportComplianceData(); showExportSheet = false }.buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan) }
            }
            .padding(20).background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }

    private func exportComplianceData() { print("Exporting compliance data as \(exportFormat.rawValue)...") }

    private var addPolicyView: some View {
        NavigationStack {
            Form {
                Section("New Policy") { TextField("Name", text: .constant("")); TextField("Data Type", text: .constant("")); TextField("Retention Period", text: .constant("")) }
            }
            .navigationTitle("Add Policy").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddPolicy = false } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { showingAddPolicy = false } } }
        }
    }

    private var addAuditView: some View {
        NavigationStack {
            Form {
                Section("New Audit Entry") { TextField("Action", text: .constant("")); TextField("User", text: .constant("")); TextField("Resource", text: .constant("")) }
            }
            .navigationTitle("Add Audit Entry").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddAudit = false } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { showingAddAudit = false } } }
        }
    }
}

struct ComplianceDashboardView_Previews: PreviewProvider {
    static var previews: some View { ComplianceDashboardView().preferredColorScheme(.dark) }
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
