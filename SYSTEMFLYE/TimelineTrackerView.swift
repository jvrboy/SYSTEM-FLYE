import SwiftUI

struct TimelineTrackerView: View {
    @State private var events: [TimelineEvent] = []
    @State private var ranges: [TimelineRange] = []
    @State private var selectedEvent: TimelineEvent?
    @State private var selectedRange: TimelineRange?
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var currentTime: Date = Date()
    @State private var isPlaying = false
    @State private var showEventDetails = true
    @State private var filterCategory: EventCategory = .all
    @State private var isDraggingHandle = false
    @State private var showingAddEvent = false
    @State private var showingAddRange = false
    @State private var activeTab: TimelineTab = .timeline
    @State private var viewMode: ViewMode = .day
    @State private var showWeekNumbers = true
    @State private var showMiniMap = true
    @State private var snapToGrid = true
    @State private var gridSize: CGFloat = 30
    @State private var eventHeight: CGFloat = 40
    @State private var rangeHeight: CGFloat = 24
    @State private var timeScale: TimeScale = .hour
    @State private var currentHour: Int = 0
    @State private var currentDay: Date = Date()
    @State private var eventsByDay: [Date: [TimelineEvent]] = [:]
    @State private var navigationOffset: CGFloat = 0
    @State private var selectedTimeRange: TimeRange = .today

    enum TimelineTab: String, CaseIterable { case timeline = "Timeline"; case calendar = "Calendar"; case list = "List"; case settings = "Settings" }
    enum ViewMode: String, CaseIterable { case day = "Day"; case week = "Week"; case month = "Month"; case year = "Year" }
    enum TimeScale: String, CaseIterable { case minute = "Minute"; case hour = "Hour"; case day = "Day"; case week = "Week" }
    enum EventCategory: String, CaseIterable, Identifiable {
        case all = "All"; case meeting = "Meetings"; case task = "Tasks"; case milestone = "Milestones"; case reminder = "Reminders"; case system = "System"; var id: String { rawValue }
    }
    enum TimeRange: String, CaseIterable { case today = "Today"; case thisWeek = "This Week"; case thisMonth = "This Month"; case thisYear = "This Year"; case custom = "Custom" }

    struct TimelineEvent: Identifiable {
        let id = UUID()
        var title: String
        var description: String
        var timestamp: Date
        var duration: TimeInterval
        var category: EventCategory
        var color: Color
        var isAllDay: Bool = false
        var location: String = ""
        var isRecurring: Bool = false
        var recurrenceRule: String = ""
        var isCompleted: Bool = false
        var priority: Priority = .medium
        enum Priority { case low, medium, high, urgent }
    }

    struct TimelineRange: Identifiable {
        let id = UUID()
        var title: String
        var start: Date
        var end: Date
        var color: Color
        var isDraggable: Bool = true
        var isResizable: Bool = true
        var opacity: Double = 0.3
    }

    var upcomingEvents: [TimelineEvent] {
        let filtered = events.filter { event in filterCategory == .all || event.category == filterCategory }
        return filtered.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        SectionHeader(eyebrow: "F L Y E  /  T I M E L I N E", title: "Tracker")
                        Spacer()
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPlaying.toggle() } }
                            label: { Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.borderedProminent).tint(isPlaying ? .orange : SystemFlyeTheme.cyan)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(label: "Events", value: "\(events.count)", detail: "scheduled", tint: SystemFlyeTheme.cyan)
                        MetricTile(label: "Ranges", value: "\(ranges.count)", detail: "time blocks", tint: SystemFlyeTheme.violet)
                        MetricTile(label: "Selected", value: selectedEvent != nil || selectedRange != nil ? "1" : "0", detail: "active item", tint: .green)
                        MetricTile(label: "Zoom", value: "\(Int(zoomLevel * 100))%", detail: "current view", tint: .orange)
                    }

                    HStack(spacing: 12) {
                        Button { showingAddEvent = true }
                            label: { Label("Add Event", systemImage: "plus.circle.fill").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.borderedProminent).tint(SystemFlyeTheme.cyan)
                        Button { showingAddRange = true }
                            label: { Label("Add Range", systemImage: "rectangle.on.rectangle").font(.caption.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8) }
                            .buttonStyle(.bordered).tint(SystemFlyeTheme.violet)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(EventCategory.allCases) { category in
                                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filterCategory = category } }
                                        label: { Text(category.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(filterCategory == category ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(filterCategory == category ? .black : .white.opacity(0.7)) }
                                }
                            }
                        }
                        Spacer()
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showEventDetails.toggle() } }
                            label: { Image(systemName: showEventDetails ? "info.circle.fill" : "info.circle").font(.caption).foregroundStyle(showEventDetails ? SystemFlyeTheme.cyan : .secondary) }
                            .buttonStyle(.bordered).tint(showEventDetails ? SystemFlyeTheme.cyan : .secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimelineTab.allCases) { tab in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { activeTab = tab } }
                                    label: { Text(tab.rawValue).font(.caption.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(activeTab == tab ? SystemFlyeTheme.cyan : SystemFlyeTheme.panel, in: Capsule()).foregroundStyle(activeTab == tab ? .black : .white.opacity(0.7)) }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 10)
                    }

                    switch activeTab {
                    case .timeline: timelineView
                    case .calendar: calendarView
                    case .list: listView
                    case .settings: settingsView
                    }

                    if showEventDetails {
                        VStack(spacing: 0) {
                            if let event = selectedEvent { eventDetailCard(event).padding(.top, 4) }
                            if let range = selectedRange { rangeDetailCard(range).padding(.top, 4) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("UPCOMING").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        LazyVStack(spacing: 8) {
                            ForEach(upcomingEvents.prefix(10)) { event in
                                eventRow(event).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedEvent = event; selectedRange = nil } }
                            }
                        }
                    }
                    .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
                }
                .padding(18).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Timeline Tracker").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddEvent) { addEventView }
            .sheet(isPresented: $showingAddRange) { addRangeView }
            .onAppear { generateTimelineData() }
        }
    }

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TIMELINE VIEW").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02))
                timelineCanvas.padding(.horizontal, 8).padding(.top, 8)
            }
            .frame(height: 320)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
            .scaleEffect(x: zoomLevel, y: 1, anchor: .center)
            .gesture(MagnificationGesture().onChanged { value in zoomLevel = min(3.0, max(0.5, value)) })
            .gesture(DragGesture().onChanged { value in panOffset = value.translation.width / zoomLevel }.onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { panOffset = 0 } })
            if showMiniMap { miniMapView.padding(.top, 4) }
        }
    }

    private var calendarView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CALENDAR VIEW").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            CalendarView(events: upcomingEvents, selectedDate: $currentDay)
                .frame(height: 320)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.02)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LIST VIEW").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            LazyVStack(spacing: 8) {
                ForEach(upcomingEvents) { event in
                    HStack(spacing: 12) {
                        Circle().fill(event.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(event.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(event.duration / 60))m").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TIMELINE SETTINGS").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("View Mode").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $viewMode) { ForEach(ViewMode.allCases) { mode in Text(mode.rawValue).tag(mode) } }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Scale").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $timeScale) { ForEach(TimeScale.allCases) { scale in Text(scale.rawValue).tag(scale) } }
                    .pickerStyle(.segmented)
                }
                ToggleRow(title: "Show Week Numbers", subtitle: "Display week numbers on timeline", isOn: $showWeekNumbers)
                ToggleRow(title: "Show Mini Map", subtitle: "Display navigation overview", isOn: $showMiniMap)
                ToggleRow(title: "Snap to Grid", subtitle: "Snap events to grid", isOn: $snapToGrid)
                if snapToGrid {
                    HStack {
                        Text("Grid Size").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Slider(value: $gridSize, in: 10...100, step: 5).tint(SystemFlyeTheme.cyan)
                        Text("\(Int(gridSize))px").font(.caption.monospacedDigit()).foregroundStyle(SystemFlyeTheme.cyan).frame(width: 35)
                    }
                }
            }
            .padding(16).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SystemFlyeTheme.line))
        }
    }

    private var timelineCanvas: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let centerY = height / 2
            ZStack {
                Path { p in p.move(to: CGPoint(x: 20, y: centerY)); p.addLine(to: CGPoint(x: width - 20, y: centerY)) }
                .stroke(SystemFlyeTheme.cyan, lineWidth: 2)
                ForEach(Array(upcomingEvents.enumerated()), id: \.element.id) { index, event in
                    let x = 40 + (CGFloat(index) / CGFloat(max(upcomingEvents.count - 1, 1))) * (width - 80) + panOffset
                    let clampedX = max(20, min(width - 20, x))
                    Circle().fill(event.color).frame(width: 12, height: 12).position(x: clampedX, y: centerY)
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 2))
                    if zoomLevel > 0.7 {
                        Text(event.title).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            .rotationEffect(.degrees(-45)).position(x: clampedX, y: centerY - 24)
                    }
                }
                ForEach(ranges) { range in
                    let startX: CGFloat = 40
                    let endX: CGFloat = width - 40
                    let y: CGFloat = 40 + CGFloat(ranges.firstIndex(where: { $0.id == range.id }) ?? 0) * 36
                    RoundedRectangle(cornerRadius: 8).fill(range.color.opacity(range.opacity)).frame(width: endX - startX, height: rangeHeight).position(x: (startX + endX) / 2, y: y)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(range.color.opacity(0.5), lineWidth: 1.5))
                    Text(range.title).font(.caption2.weight(.semibold)).foregroundStyle(range.color).position(x: startX + 10, y: y)
                }
                if isPlaying {
                    Path { p in
                        let x = 40 + (currentTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 10) / 10) * (width - 80)
                        p.move(to: CGPoint(x: x, y: 10)); p.addLine(to: CGPoint(x: x, y: height - 10))
                    }
                    .stroke(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
        }
    }

    private var miniMapView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OVERVIEW").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                Path { p in p.move(to: CGPoint(x: 0, y: height / 2)); p.addLine(to: CGPoint(x: width, y: height / 2)) }
                .stroke(SystemFlyeTheme.cyan.opacity(0.3), lineWidth: 1)
                ForEach(upcomingEvents.prefix(8)) { event in
                    let x = CGFloat.random(in: 10...(width - 10))
                    Circle().fill(event.color.opacity(0.6)).frame(width: 4, height: 4).position(x: x, y: CGFloat.random(in: 5...(height - 5)))
                }
                ForEach(ranges) { range in
                    RoundedRectangle(cornerRadius: 3).fill(range.color.opacity(0.4)).frame(width: CGFloat.random(in: 20...(width - 20)), height: 8).position(x: width / 2, y: CGFloat.random(in: 5...(height - 5)))
                }
            }
            .frame(height: 40)
        }
    }

    private func eventDetailCard(_ event: TimelineEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(event.title.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text(event.category.rawValue).font(.caption.weight(.semibold)).foregroundStyle(SystemFlyeTheme.cyan).padding(.horizontal, 10).padding(.vertical, 5).background(SystemFlyeTheme.cyan.opacity(0.1), in: Capsule())
            }
            Divider().background(SystemFlyeTheme.line)
            Text(event.description).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) { Text("Start").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(event.timestamp, style: .time).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text("Duration").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text("\(Int(event.duration / 60)) min").font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
            }
            if !event.location.isEmpty {
                HStack(spacing: 8) { Image(systemName: "location.fill").font(.caption).foregroundStyle(.secondary); Text(event.location).font(.caption).foregroundStyle(.secondary) }
            }
            HStack(spacing: 10) {
                Button { if let idx = events.firstIndex(where: { $0.id == event.id }) { events.remove(at: idx); selectedEvent = nil } }
                    label: { Label("Delete", systemImage: "trash").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered()).tint(.red)
                Button { if let idx = events.firstIndex(where: { $0.id == event.id }) { events[idx].timestamp = events[idx].timestamp.addingTimeInterval(3600) } }
                    label: { Label("+1h", systemImage: "arrow.right").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.secondary)
                Button { if let idx = events.firstIndex(where: { $0.id == event.id }) { events[idx].isCompleted.toggle() } }
                    label: { Label(event.isCompleted ? "Undo" : "Complete", systemImage: event.isCompleted ? "arrow.uturn.backward" : "checkmark").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.green)
            }
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private func rangeDetailCard(_ range: TimelineRange) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(range.title.uppercased()).font(.headline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text("Range").font(.caption.weight(.semibold)).foregroundStyle(SystemFlyeTheme.violet).padding(.horizontal, 10).padding(.vertical, 5).background(SystemFlyeTheme.violet.opacity(0.1), in: Capsule())
            }
            Divider().background(SystemFlyeTheme.line)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) { Text("Start").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(range.start, style: .time).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text("End").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.secondary); Text(range.end, style: .time).font(.subheadline.weight(.semibold)).foregroundStyle(.white).monospacedDigit() }
            }
            Text("Duration: \(Int(range.end.timeIntervalSince(range.start) / 60)) minutes").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button { if let idx = ranges.firstIndex(where: { $0.id == range.id }) { ranges.remove(at: idx); selectedRange = nil } }
                    label: { Label("Delete", systemImage: "trash").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered()).tint(.red)
                Button { if let idx = ranges.firstIndex(where: { $0.id == range.id }) { ranges[idx].start = ranges[idx].start.addingTimeInterval(1800); ranges[idx].end = ranges[idx].end.addingTimeInterval(1800) } }
                    label: { Label("+30m", systemImage: "arrow.right").font(.caption.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.bordered).tint(.secondary)
            }
        }
        .padding(20).background(SystemFlyeTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SystemFlyeTheme.line))
    }

    private func eventRow(_ event: TimelineEvent) -> some View {
        HStack(spacing: 12) {
            Circle().fill(event.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) { Text(event.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white); Text(event.timestamp, style: .time).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text("\(Int(event.duration / 60))m").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12).background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private var addEventView: some View {
        NavigationStack {
            Form {
                Section("New Event") { TextField("Title", text: .constant("")); DatePicker("Time", selection: .constant(Date())); TextField("Description", text: .constant(""), axis: .vertical).lineLimit(2...4) }
            }
            .navigationTitle("Add Event").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddEvent = false } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { showingAddEvent = false } } }
        }
    }

    private var addRangeView: some View {
        NavigationStack {
            Form {
                Section("New Range") { TextField("Title", text: .constant("")); DatePicker("Start", selection: .constant(Date())); DatePicker("End", selection: .constant(Date().addingTimeInterval(3600))) }
            }
            .navigationTitle("Add Range").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddRange = false } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { showingAddRange = false } } }
        }
    }

    private func generateTimelineData() {
        let categories: [EventCategory] = [.meeting, .task, .milestone, .reminder, .system]
        let titles = ["Team Standup", "Code Review", "Design Sync", "Sprint Planning", "Deployment", "Client Call", "Training Session", "Quarterly Review", "System Backup", "Security Audit", "Performance Review", "Board Meeting"]
        let colors: [Color] = [SystemFlyeTheme.cyan, SystemFlyeTheme.violet, .green, .orange, .pink, .purple, .blue, .teal]
        events = (0..<24).map { i in
            TimelineEvent(title: titles.randomElement()!, description: "Automated event entry #\(1000 + i)", timestamp: Date().addingTimeInterval(Double(i) * 3600 - 86400), duration: Double.random(in: 900...7200), category: categories.randomElement()!, color: colors.randomElement()!, isAllDay: Bool.random(), location: ["Conference Room A", "Zoom", "Office", "Remote"].randomElement()!, isRecurring: Bool.random(), priority: [.low, .medium, .high, .urgent].randomElement()!)
        }
        ranges = [
            TimelineRange(title: "Focus Time", start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600), color: SystemFlyeTheme.cyan),
            TimelineRange(title: "Lunch Break", start: Date().addingTimeInterval(3600), end: Date().addingTimeInterval(7200), color: .green),
            TimelineRange(title: "Deep Work", start: Date().addingTimeInterval(7200), end: Date().addingTimeInterval(10800), color: SystemFlyeTheme.violet),
            TimelineRange(title: "Meeting Block", start: Date().addingTimeInterval(10800), end: Date().addingTimeInterval(12600), color: .orange)
        ]
    }
}

struct TimelineTrackerView_Previews: PreviewProvider {
    static var previews: some View { TimelineTrackerView().preferredColorScheme(.dark) }
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
