import SwiftUI

struct NetworkTopologyView: View {
    @State private var nodes: [NetworkNode] = []
    @State private var connections: [NetworkConnection] = []
    @State private var selectedNode: NetworkNode?
    @State private var selectedConnection: NetworkConnection?
    @State private var trafficFlow: [TrafficFlow] = []
    @State private var isSimulatingTraffic = false
    @State private var showLabels = true
    @State private var showGrid = true
    @State private var showBandwidth = true
    @State private var showLatency = true
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isDraggingNode: Bool = false
    @State private var draggedNode: NetworkNode?
    @State private var showingAddNode = false
    @State private var showingAddConnection = false
    @State private var selectedTab: NetworkTab = .topology
    @State private var nodeCount: Int = 0
    @State private var connectionCount: Int = 0
    @State private var totalBandwidth: Double = 0
    @State private var avgLatency: Double = 0
    @State private var healthScore: Double = 0.95
    @State private var trafficHistory: [TrafficHistoryEntry] = []
    @State private var showingTrafficHistory = false
    @State private var filterType: NodeType? = nil
    @State private var searchText = ""

    enum NetworkTab: String, CaseIterable { case topology = "Topology"; case metrics = "Metrics"; case traffic = "Traffic"; case settings = "Settings" }

    struct NetworkNode: Identifiable {
        let id = UUID()
        var name: String
        var type: NodeType
        var position: CGPoint
        var status: NodeStatus
        var load: Double
        var connectionsCount: Int
        var color: Color
        var ipAddress: String
        var uptime: TimeInterval
    }

    enum NodeType: String, CaseIterable {
        case server = "Server"; case database = "Database"; case loadBalancer = "Load Balancer"; case gateway = "Gateway"; case client = "Client"; case cache = "Cache"; case messageQueue = "Message Queue"; case storage = "Storage"; case firewall = "Firewall"; case proxy = "Proxy"
    }

    enum NodeStatus: String {
        case healthy = "Healthy"; case degraded = "Degraded"; case offline = "Offline"; case maintenance = "Maintenance"
    }

    struct NetworkConnection: Identifiable {
        let id = UUID()
        var from: UUID
        var to: UUID
        var bandwidth: Double
        var latency: Double
        var utilization: Double
        var status: ConnectionStatus
        var protocol: String
    }

    enum ConnectionStatus: String { case active = "Active"; case saturated = "Saturated"; case idle = "Idle"; case down = "Down" }

    struct TrafficFlow: Identifiable {
        let id = UUID()
        var fromNode: UUID
        var toNode: UUID
        var packetsPerSecond: Double
        var bandwidth: Double
        var color: Color
    }

    struct TrafficHistoryEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let source: String
        let destination: String
        let bytesTransferred: Double
        let packets: Int
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingAddNode = true } }
                            label: { Label("Add Node", systemImage: "plus.circle.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingAddConnection = true } }
                            label: { Label("Connect", systemImage: "arrow.2.squarepath").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.violet)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isSimulatingTraffic.toggle() } }
                            label: { Label(isSimulatingTraffic ? "Stop Traffic" : "Simulate Traffic", systemImage: isSimulatingTraffic ? "stop.fill" : "waveform.path").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(isSimulatingTraffic ? .red : .orange)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showLabels.toggle() } }
                            label: { Image(systemName: showLabels ? "textformat" : "textformat.slash").font(.caption).foregroundStyle(showLabels ? SystemFlyeTheme.cyan : .secondary) }
                            .buttonStyle(.bordered).tint(showLabels ? SystemFlyeTheme.cyan : .secondary)
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingTrafficHistory.toggle() } }
                            label: { Label("History", systemImage: "clock.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(showingTrafficHistory ? .green : .secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NetworkTab.allCases) { tab in
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab } }
                                label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(selectedTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.7)) }
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }

                switch selectedTab {
                case .topology: topologyTab
                case .metrics: metricsTab
                case .traffic: trafficTab
                case .settings: settingsTab
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Network Topology").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddNode) { addNodeView }
            .sheet(isPresented: $showingAddConnection) { addConnectionView }
            .onAppear { generateNetwork(); startTrafficSimulation() }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "F L Y E  /  N E T W O R K", title: "Topology")
                Spacer()
                Label("\(nodes.count) nodes", systemImage: "circle.fill").font(.caption2.weight(.bold)).foregroundStyle(SystemFlyeTheme.cyan)
                    .padding(.horizontal, 10).padding(.vertical, 7).background(SystemFlyeTheme.cyan.opacity(0.12), in: Capsule())
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
                TextField("Search nodes...", text: $searchText).textFieldStyle(.plain).foregroundStyle(.white)
            }
            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
    }

    private var topologyTab: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
            if showGrid { gridOverlay }
            ForEach(nodes) { node in
                nodeView(node)
                    .scaleEffect(zoomLevel)
                    .offset(panOffset)
                    .gesture(DragGesture().onChanged { value in draggedNode = node; isDraggingNode = true; updateNodePosition(node, value.location) }.onEnded { _ in isDraggingNode = false; draggedNode = nil })
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedNode = node; selectedConnection = nil } }
            }
            ForEach(connections) { connection in
                if let fromNode = nodes.first(where: { $0.id == connection.from }), let toNode = nodes.first(where: { $0.id == connection.to }) {
                    connectionView(from: fromNode, to: toNode, connection: connection)
                        .scaleEffect(zoomLevel)
                        .offset(panOffset)
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedConnection = connection; selectedNode = nil } }
                }
            }
            if isSimulatingTraffic {
                ForEach(trafficFlow) { flow in
                    if let fromNode = nodes.first(where: { $0.id == flow.fromNode }), let toNode = nodes.first(where: { $0.id == flow.toNode }) {
                        trafficParticle(from: fromNode.position, to: toNode.position, color: flow.color)
                            .scaleEffect(zoomLevel)
                            .offset(panOffset)
                    }
                }
            }
            if let node = selectedNode {
                nodeDetailCard(node).padding(.top, 8).padding(.horizontal, 18)
                    .transition(.move(edge: .bottom))
            }
            if let connection = selectedConnection {
                connectionDetailCard(connection).padding(.top, 8).padding(.horizontal, 18)
                    .transition(.move(edge: .bottom))
            }
        }
        .frame(height: 420)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        .padding(.horizontal, 18)
        .gesture(MagnificationGesture().onChanged { value in withAnimation(.easeInOut) { zoomLevel = min(3.0, max(0.3, value)) } })
        .gesture(DragGesture().onChanged { value in if !isDraggingNode { withAnimation(.easeInOut) { panOffset = value.translation } } }.onEnded { _ in withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { panOffset = .zero } })
    }

    private var metricsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(label: "Nodes", value: "\(nodes.count)", detail: "active devices", tint: SystemFlyeTheme.cyan)
                MetricTile(label: "Links", value: "\(connections.count)", detail: "connections", tint: SystemFlyeTheme.violet)
                MetricTile(label: "Bandwidth", value: String(format: "%.1f Gbps", totalBandwidth), detail: "total capacity", tint: .green)
                MetricTile(label: "Latency", value: String(format: "%.1f ms", avgLatency), detail: "average", tint: .orange)
                MetricTile(label: "Health", value: "\(Int(healthScore * 100))%", detail: "network score", tint: healthScore >= 0.9 ? .green : .orange)
                MetricTile(label: "Uptime", value: "99.9%", detail: "last 30 days", tint: .green)
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("NODE HEALTH").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                ForEach(nodes) { node in
                    HStack(spacing: 12) {
                        Circle().fill(node.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("\(node.type.rawValue) · \(node.ipAddress)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(node.load * 100))%").font(.caption.monospacedDigit()).foregroundStyle(node.color)
                            Text("\(Int(node.uptime / 3600))h").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private var trafficTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TRAFFIC ANALYSIS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(label: "Packets/s", value: String(format: "%.0f", trafficFlow.map(\.packetsPerSecond).reduce(0, +)), detail: "current throughput", tint: SystemFlyeTheme.cyan)
                MetricTile(label: "Bandwidth", value: String(format: "%.1f Mbps", trafficFlow.map(\.bandwidth).reduce(0, +)), detail: "aggregate", tint: SystemFlyeTheme.violet)
                MetricTile(label: "Flows", value: "\(trafficFlow.count)", detail: "active flows", tint: .green)
                MetricTile(label: "Top Talker", value: nodes.first?.name ?? "—", detail: "highest traffic", tint: .orange)
            }
            if showingTrafficHistory {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TRAFFIC HISTORY").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    LazyVStack(spacing: 8) {
                        ForEach(trafficHistory.prefix(15)) { entry in
                            HStack(spacing: 12) {
                                Text(entry.source).font(.caption2.weight(.semibold)).foregroundStyle(.white).frame(width: 80, alignment: .leading)
                                Text("→").font(.caption).foregroundStyle(.secondary)
                                Text(entry.destination).font(.caption2.weight(.semibold)).foregroundStyle(.white).frame(width: 80, alignment: .leading)
                                Spacer()
                                Text("\(entry.packets) pkts").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan)
                                Text(String(format: "%.1f MB", entry.bytesTransferred / 1_048_576)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .padding(10).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NETWORK SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ToggleRow(title: "Auto-Discover", subtitle: "Automatically find new devices", isOn: .constant(true))
                ToggleRow(title: "Traffic Shaping", subtitle: "Prioritize critical traffic", isOn: .constant(true))
                ToggleRow(title: "QoS", subtitle: "Quality of Service", isOn: .constant(false))
                ToggleRow(title: "Jumbo Frames", subtitle: "Enable large packet support", isOn: .constant(false))
                HStack {
                    Text("MTU Size").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Slider(value: .constant(1500), in: 576...9000, step: 1).tint(SystemFlyeTheme.cyan)
                    Text("1500").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 40)
                }
                HStack {
                    Text("Keep-Alive").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Slider(value: .constant(30), in: 5...300, step: 5).tint(SystemFlyeTheme.violet)
                    Text("30s").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.violet).frame(width: 35)
                }
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
        .padding(.horizontal, 18)
    }

    private func nodeView(_ node: NetworkNode) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(node.color.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: nodeTypeIcon(node.type)).font(.system(size: 20, weight: .semibold)).foregroundStyle(node.color)
            }
            if showLabels {
                Text(node.name).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                Text("\(Int(node.load * 100))% load").font(.caption2.monospacedDigit()).foregroundStyle(node.color)
            }
        }
        .position(node.position)
    }

    private func connectionView(from: NetworkNode, to: NetworkNode, connection: NetworkConnection) -> some View {
        let midX = (from.position.x + to.position.x) / 2
        let midY = (from.position.y + to.position.y) / 2
        return ZStack {
            Path { p in p.move(to: from.position); p.addLine(to: to.position) }
            .stroke(connectionColor(connection.status), style: StrokeStyle(lineWidth: 2, dash: connection.status == .idle ? [4, 4] : []))
            if showBandwidth {
                Text("\(Int(connection.bandwidth)) Mbps").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.5), in: Capsule())
                    .position(x: midX, y: midY - 10)
            }
            if showLatency {
                Text("\(String(format: "%.1f", connection.latency))ms").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.5), in: Capsule())
                    .position(x: midX, y: midY + 14)
            }
        }
    }

    private func trafficParticle(from: CGPoint, to: CGPoint, color: Color) -> some View {
        TimelineView(.animation) { _ in
            Circle().fill(color).frame(width: 6, height: 6)
                .position(x: from.x + (to.x - from.x) * CGFloat(truncatingIfNeeded: NSDate().timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0)), y: from.y + (to.y - from.y) * CGFloat(truncatingIfNeeded: NSDate().timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0)))
                .opacity(0.8)
        }
    }

    private func nodeTypeIcon(_ type: NodeType) -> String {
        switch type {
        case .server: return "server.rack"; case .database: return "internaldrive"; case .loadBalancer: return "scalemass"; case .gateway: return "network"; case .client: return "desktopcomputer"; case .cache: return "memorychip"; case .messageQueue: return "text.bubble"; case .storage: return "externaldrive"; case .firewall: return "shield.fill"; case .proxy: return "arrow.triangle.2.circlepath"
        }
    }

    private func connectionColor(_ status: ConnectionStatus) -> Color {
        switch status { case .active: return SystemFlyeTheme.cyan; case .saturated: return .orange; case .idle: return .secondary; case .down: return .red }
    }

    private func updateNodePosition(_ node: NetworkNode, _ location: CGPoint) {
        if let idx = nodes.firstIndex(where: { $0.id == node.id }) { nodes[idx].position = location }
    }

    private var nodeDetailCard: (NetworkNode) -> some View = { node in
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(node.name.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(node.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(node.status == .healthy ? .green : node.status == .offline ? .red : .orange)
                    .padding(.horizontal, 10).padding(.vertical, 5).background((node.status == .healthy ? Color.green : node.status == .offline ? Color.red : Color.orange).opacity(0.15), in: Capsule())
            }
            Divider().background(SystemFlyeTheme.line)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Type", value: node.type.rawValue)
                StatCard(label: "Load", value: "\(Int(node.load * 100))%")
                StatCard(label: "Links", value: "\(node.connectionsCount)")
            }
            HStack(spacing: 10) {
                Button { if let idx = nodes.firstIndex(where: { $0.id == node.id }) { nodes[idx].status = .healthy } }
                    label: { Label("Restart", systemImage: "arrow.counterclockwise").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).tint(.green)
                Button { if let idx = nodes.firstIndex(where: { $0.id == node.id }) { nodes[idx].status = .maintenance } }
                    label: { Label("Maintain", systemImage: "wrench.fill").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.orange)
            }
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private var connectionDetailCard: (NetworkConnection) -> some View = { connection in
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CONNECTION DETAIL").font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(connection.status.rawValue).font(.caption2.weight(.bold)).foregroundStyle(connectionColor(connection.status))
            }
            Divider().background(SystemFlyeTheme.line)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Bandwidth", value: "\(Int(connection.bandwidth)) Mbps")
                StatCard(label: "Latency", value: "\(String(format: "%.1f", connection.latency))ms")
                StatCard(label: "Utilization", value: "\(Int(connection.utilization * 100))%")
                StatCard(label: "Protocol", value: connection.protocol)
            }
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private var addNodeView: some View {
        NavigationStack {
            Form {
                Section("New Node") { TextField("Name", text: .constant("")); Picker("Type", selection: .constant(NetworkNode.NodeType.server.rawValue)) { ForEach(NetworkNode.NodeType.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) } } }
            }
            .navigationTitle("Add Node").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddNode = false } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { showingAddNode = false }.disabled(true) } }
        }
    }

    private var addConnectionView: some View {
        NavigationStack {
            Form {
                Section("New Connection") { Picker("From", selection: .constant(nodes.first?.id ?? UUID())) { ForEach(nodes) { Text($0.name).tag($0.id) } }; Picker("To", selection: .constant(nodes.first?.id ?? UUID())) { ForEach(nodes) { Text($0.name).tag($0.id) } } }
            }
            .navigationTitle("Add Connection").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddConnection = false } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { showingAddConnection = false }.disabled(true) } }
        }
    }

    private var gridOverlay: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 30 * zoomLevel
            let cols = Int(proxy.size.width / spacing) + 1
            let rows = Int(proxy.size.height / spacing) + 1
            Group {
                ForEach(0..<cols, id: \.self) { i in Path { p in p.move(to: CGPoint(x: CGFloat(i) * spacing, y: 0)); p.addLine(to: CGPoint(x: CGFloat(i) * spacing, y: proxy.size.height)) }.stroke(Color.white.opacity(0.03), lineWidth: 1) }
                ForEach(0..<rows, id: \.self) { i in Path { p in p.move(to: CGPoint(x: 0, y: CGFloat(i) * spacing)); p.addLine(to: CGPoint(x: proxy.size.width, y: CGFloat(i) * spacing)) }.stroke(Color.white.opacity(0.03), lineWidth: 1) }
            }
        }
    }

    private func generateNetwork() {
        let centerX: CGFloat = 200; let centerY: CGFloat = 200
        nodes = [
            NetworkNode(name: "Gateway-1", type: .gateway, position: CGPoint(x: centerX, y: centerY - 120), status: .healthy, load: 0.4, connectionsCount: 3, color: SystemFlyeTheme.cyan, ipAddress: "10.0.0.1", uptime: 86400 * 30),
            NetworkNode(name: "LoadBalancer", type: .loadBalancer, position: CGPoint(x: centerX, y: centerY - 60), status: .healthy, load: 0.6, connectionsCount: 4, color: .green, ipAddress: "10.0.0.2", uptime: 86400 * 30),
            NetworkNode(name: "Server-01", type: .server, position: CGPoint(x: centerX - 100, y: centerY), status: .healthy, load: 0.7, connectionsCount: 2, color: SystemFlyeTheme.violet, ipAddress: "10.0.0.10", uptime: 86400 * 15),
            NetworkNode(name: "Server-02", type: .server, position: CGPoint(x: centerX + 100, y: centerY), status: .healthy, load: 0.5, connectionsCount: 2, color: SystemFlyeTheme.violet, ipAddress: "10.0.0.11", uptime: 86400 * 15),
            NetworkNode(name: "Database", type: .database, position: CGPoint(x: centerX - 80, y: centerY + 80), status: .healthy, load: 0.3, connectionsCount: 1, color: .orange, ipAddress: "10.0.0.20", uptime: 86400 * 60),
            NetworkNode(name: "Cache", type: .cache, position: CGPoint(x: centerX + 80, y: centerY + 80), status: .healthy, load: 0.2, connectionsCount: 1, color: .yellow, ipAddress: "10.0.0.21", uptime: 86400 * 10),
            NetworkNode(name: "Storage", type: .storage, position: CGPoint(x: centerX, y: centerY + 140), status: .healthy, load: 0.5, connectionsCount: 1, color: .blue, ipAddress: "10.0.0.30", uptime: 86400 * 90),
            NetworkNode(name: "Queue", type: .messageQueue, position: CGPoint(x: centerX + 180, y: centerY + 40), status: .healthy, load: 0.4, connectionsCount: 2, color: .pink, ipAddress: "10.0.0.40", uptime: 86400 * 7)
        ]
        connections = [
            NetworkConnection(from: nodes[0].id, to: nodes[1].id, bandwidth: 1000, latency: 1.2, utilization: 0.6, status: .active, protocol: "TCP"),
            NetworkConnection(from: nodes[1].id, to: nodes[2].id, bandwidth: 1000, latency: 0.5, utilization: 0.7, status: .active, protocol: "TCP"),
            NetworkConnection(from: nodes[1].id, to: nodes[3].id, bandwidth: 1000, latency: 0.5, utilization: 0.5, status: .active, protocol: "TCP"),
            NetworkConnection(from: nodes[2].id, to: nodes[4].id, bandwidth: 500, latency: 2.0, utilization: 0.3, status: .active, protocol: "TCP"),
            NetworkConnection(from: nodes[2].id, to: nodes[5].id, bandwidth: 500, latency: 1.0, utilization: 0.2, status: .active, protocol: "UDP"),
            NetworkConnection(from: nodes[3].id, to: nodes[5].id, bandwidth: 500, latency: 1.0, utilization: 0.4, status: .active, protocol: "UDP"),
            NetworkConnection(from: nodes[4].id, to: nodes[6].id, bandwidth: 200, latency: 3.0, utilization: 0.5, status: .active, protocol: "TCP"),
            NetworkConnection(from: nodes[3].id, to: nodes[7].id, bandwidth: 300, latency: 1.5, utilization: 0.4, status: .active, protocol: "TCP")
        ]
        totalBandwidth = connections.map(\.bandwidth).reduce(0, +)
        avgLatency = connections.map(\.latency).reduce(0, +) / Double(max(connections.count, 1))
        nodeCount = nodes.count
        connectionCount = connections.count
    }

    private func startTrafficSimulation() {
        guard !isSimulatingTraffic else { return }
        Task { @MainActor in
            while isSimulatingTraffic {
                trafficFlow = (0..<8).map { _ in
                    let fromNode = nodes.randomElement()!
                    let toNode = nodes.randomElement()!
                    return TrafficFlow(fromNode: fromNode.id, toNode: toNode.id, packetsPerSecond: Double.random(in: 100...10000), bandwidth: Double.random(in: 1...100), color: [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple].randomElement()!)
                }
                trafficHistory.append(TrafficHistoryEntry(timestamp: Date(), source: nodes.randomElement()!.name, destination: nodes.randomElement()!.name, bytesTransferred: Double.random(in: 1024...1048576), packets: Int.random(in: 100...10000)))
                if trafficHistory.count > 50 { trafficHistory.removeFirst() }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}


struct NetworkTopologyView_Previews: PreviewProvider {
    static var previews: some View { NetworkTopologyView().preferredColorScheme(.dark) }
}

