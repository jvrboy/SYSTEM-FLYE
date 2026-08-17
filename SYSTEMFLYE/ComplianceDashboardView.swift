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

