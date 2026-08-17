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

struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity, alignment: .leading)
        Toggle("", isOn: $isOn).labelsHidden().tint(SystemFlyeTheme.cyan)
    }
}

struct NetworkTopologyView_Previews: PreviewProvider {
    static var previews: some View { NetworkTopologyView().preferredColorScheme(.dark) }
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
