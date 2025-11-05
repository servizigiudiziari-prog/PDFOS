//
//  EnhancedTimelineView.swift
//  PDFOS
//
//  Enhanced timeline UI with advanced playback controls
//

#if canImport(SwiftUI)
import SwiftUI

/// Enhanced timeline view with video-like controls
struct EnhancedTimelineView: View {
    // MARK: - Properties

    @StateObject private var viewModel: TimelineViewModel
    @State private var currentDate: Date
    @State private var playbackSpeed: PlaybackSpeed = .normal
    @State private var isPlaying = false
    @State private var showHeatmap = true
    @State private var selectedEvent: TimelineEvent?
    @State private var zoomLevel: ZoomLevel = .day

    // Playback
    @State private var playbackTimer: Timer?

    // MARK: - Initialization

    init(document: PDFDocument) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(document: document))
        _currentDate = State(initialValue: Date())
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with info
            timelineHeader

            Divider()

            // Main timeline area
            VStack(spacing: 12) {
                // Zoom controls
                zoomControls

                // Timeline slider with events
                timelineSlider
                    .frame(height: 80)

                // Heatmap
                if showHeatmap {
                    heatmapView
                        .frame(height: 60)
                }

                // Event details
                if let event = selectedEvent {
                    eventDetailView(event)
                        .frame(height: 100)
                }
            }
            .padding()

            Divider()

            // Playback controls
            playbackControls
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            await viewModel.loadTimeline()
        }
        .onChange(of: currentDate) { _, newDate in
            Task {
                await viewModel.timeTravel(to: newDate)
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Header

    private var timelineHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Document Timeline")
                    .font(.headline)

                if let stats = viewModel.statistics {
                    Text("\(stats.totalEvents) events • \(stats.totalVersions) versions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Current date display
            VStack(alignment: .trailing, spacing: 4) {
                Text(currentDate, style: .date)
                    .font(.headline)

                Text(currentDate, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Options menu
            Menu {
                Toggle("Show Heatmap", isOn: $showHeatmap)

                Divider()

                Button("Export Video") {
                    Task { await exportVideo() }
                }

                Button("Generate Report") {
                    Task { await generateReport() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }
        .padding()
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack {
            Text("Zoom:")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: $zoomLevel) {
                Text("Hour").tag(ZoomLevel.hour)
                Text("Day").tag(ZoomLevel.day)
                Text("Week").tag(ZoomLevel.week)
                Text("Month").tag(ZoomLevel.month)
                Text("All").tag(ZoomLevel.all)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Spacer()

            // Quick jump buttons
            Button(action: jumpToStart) {
                Label("Start", systemImage: "backward.end.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: jumpToEnd) {
                Label("End", systemImage: "forward.end.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Timeline Slider

    private var timelineSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)

                // Events overlay
                eventsOverlay(width: geometry.size.width)

                // Current position indicator
                currentPositionIndicator(width: geometry.size.width)

                // Selection handles
                selectionHandles(width: geometry.size.width)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleTimelineDrag(value, width: geometry.size.width)
                    }
            )
            .onTapGesture { location in
                handleTimelineTap(location, width: geometry.size.width)
            }
        }
    }

    private func eventsOverlay(width: CGFloat) -> some View {
        ForEach(viewModel.events) { event in
            let position = calculatePosition(
                for: event.timestamp,
                in: width
            )

            EventMarker(event: event, isSelected: selectedEvent?.id == event.id)
                .position(x: position, y: 40)
                .onTapGesture {
                    selectedEvent = event
                    currentDate = event.timestamp
                }
        }
    }

    private func currentPositionIndicator(width: CGFloat) -> some View {
        let position = calculatePosition(for: currentDate, in: width)

        return VStack(spacing: 2) {
            // Triangle indicator
            Triangle()
                .fill(Color.accentColor)
                .frame(width: 12, height: 8)

            // Line
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2)

            // Time label
            Text(currentDate, style: .time)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .offset(x: position - 6)
    }

    private func selectionHandles(width: CGFloat) -> some View {
        Group {
            if let start = viewModel.selectionStart,
               let end = viewModel.selectionEnd {
                SelectionRange(
                    start: calculatePosition(for: start, in: width),
                    end: calculatePosition(for: end, in: width)
                )
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<100, id: \.self) { index in
                    let intensity = calculateHeatmapIntensity(
                        for: index,
                        total: 100,
                        width: geometry.size.width
                    )

                    Rectangle()
                        .fill(heatmapColor(for: intensity))
                        .frame(width: geometry.size.width / 100)
                }
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func heatmapColor(for intensity: Float) -> Color {
        if intensity == 0 {
            return Color.gray.opacity(0.1)
        } else if intensity < 0.3 {
            return Color.green.opacity(Double(intensity))
        } else if intensity < 0.7 {
            return Color.orange.opacity(Double(intensity))
        } else {
            return Color.red.opacity(Double(intensity))
        }
    }

    // MARK: - Event Detail

    private func eventDetailView(_ event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: eventIcon(for: event.type))
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.description)
                    .font(.headline)

                HStack {
                    Text(event.timestamp, style: .date)
                    Text("•")
                    Text(event.timestamp, style: .time)
                    Text("•")
                    Text("by \(event.userId)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Button("Jump Here") {
                currentDate = event.timestamp
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 16) {
            // Play/Pause
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .keyboardShortcut(.space, modifiers: [])

            // Previous event
            Button(action: previousEvent) {
                Image(systemName: "backward.frame.fill")
            }
            .disabled(viewModel.events.isEmpty)

            // Next event
            Button(action: nextEvent) {
                Image(systemName: "forward.frame.fill")
            }
            .disabled(viewModel.events.isEmpty)

            Divider()
                .frame(height: 20)

            // Speed control
            Text("Speed:")
                .foregroundColor(.secondary)

            Picker("Speed", selection: $playbackSpeed) {
                Text("0.5x").tag(PlaybackSpeed.slow)
                Text("1x").tag(PlaybackSpeed.normal)
                Text("2x").tag(PlaybackSpeed.fast)
                Text("4x").tag(PlaybackSpeed.veryFast)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer()

            // Time remaining
            if isPlaying, let endDate = viewModel.dateRange.upperBound as? Date {
                let remaining = endDate.timeIntervalSince(currentDate)
                let adjusted = remaining / Double(playbackSpeed.multiplier)

                Text("Remaining: \(formatDuration(adjusted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Record button
            Button(action: { Task { await startRecording() } }) {
                Label("Record", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func calculatePosition(for date: Date, in width: CGFloat) -> CGFloat {
        guard let start = viewModel.dateRange.lowerBound as? Date,
              let end = viewModel.dateRange.upperBound as? Date else {
            return 0
        }

        let totalDuration = end.timeIntervalSince(start)
        let offset = date.timeIntervalSince(start)
        let percentage = offset / totalDuration

        return width * CGFloat(percentage)
    }

    private func calculateHeatmapIntensity(for index: Int, total: Int, width: CGFloat) -> Float {
        // Calculate time range for this segment
        guard let start = viewModel.dateRange.lowerBound as? Date,
              let end = viewModel.dateRange.upperBound as? Date else {
            return 0
        }

        let totalDuration = end.timeIntervalSince(start)
        let segmentDuration = totalDuration / Double(total)
        let segmentStart = start.addingTimeInterval(Double(index) * segmentDuration)
        let segmentEnd = segmentStart.addingTimeInterval(segmentDuration)

        // Count events in this segment
        let eventsInSegment = viewModel.events.filter { event in
            event.timestamp >= segmentStart && event.timestamp < segmentEnd
        }

        // Normalize intensity
        let maxEvents: Float = 10.0
        return min(Float(eventsInSegment.count) / maxEvents, 1.0)
    }

    private func handleTimelineDrag(_ value: DragGesture.Value, width: CGFloat) {
        guard let start = viewModel.dateRange.lowerBound as? Date,
              let end = viewModel.dateRange.upperBound as? Date else {
            return
        }

        let percentage = value.location.x / width
        let totalDuration = end.timeIntervalSince(start)
        let offset = totalDuration * Double(percentage)

        currentDate = start.addingTimeInterval(offset)
    }

    private func handleTimelineTap(_ location: CGPoint, width: CGFloat) {
        // Find nearest event
        let events = viewModel.events.map { event -> (TimelineEvent, CGFloat) in
            let eventPosition = calculatePosition(for: event.timestamp, in: width)
            let distance = abs(eventPosition - location.x)
            return (event, distance)
        }

        if let nearest = events.min(by: { $0.1 < $1.1 }), nearest.1 < 20 {
            selectedEvent = nearest.0
            currentDate = nearest.0.timestamp
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        isPlaying = true

        let interval = 0.1 / playbackSpeed.multiplier

        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard let end = viewModel.dateRange.upperBound as? Date else {
                stopPlayback()
                return
            }

            currentDate = currentDate.addingTimeInterval(1.0)

            if currentDate >= end {
                stopPlayback()
                currentDate = end
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func previousEvent() {
        if let index = viewModel.events.firstIndex(where: { $0.timestamp >= currentDate }),
           index > 0 {
            let previousEvent = viewModel.events[index - 1]
            currentDate = previousEvent.timestamp
            selectedEvent = previousEvent
        }
    }

    private func nextEvent() {
        if let nextEvent = viewModel.events.first(where: { $0.timestamp > currentDate }) {
            currentDate = nextEvent.timestamp
            selectedEvent = nextEvent
        }
    }

    private func jumpToStart() {
        if let start = viewModel.dateRange.lowerBound as? Date {
            currentDate = start
        }
    }

    private func jumpToEnd() {
        if let end = viewModel.dateRange.upperBound as? Date {
            currentDate = end
        }
    }

    private func exportVideo() async {
        // TODO: Implement in video replay component
    }

    private func generateReport() async {
        // TODO: Implement in export functionality
    }

    private func startRecording() async {
        // TODO: Implement screen recording
    }

    private func eventIcon(for type: PDFEvent.EventType) -> String {
        switch type {
        case .textEdit, .textInsert: return "pencil"
        case .textDelete: return "trash"
        case .imageInsert: return "photo"
        case .imageDelete: return "photo.on.rectangle.angled"
        case .annotationAdd: return "note.text"
        case .annotationRemove: return "note.text.badge.plus"
        case .pageAdd: return "doc.badge.plus"
        case .pageRemove: return "doc.badge.minus"
        case .pageReorder: return "arrow.up.arrow.down"
        case .metadataChange: return "info.circle"
        case .formFieldEdit: return "list.bullet.rectangle"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

// MARK: - Supporting Types

enum PlaybackSpeed: Float {
    case slow = 0.5
    case normal = 1.0
    case fast = 2.0
    case veryFast = 4.0

    var multiplier: Float {
        rawValue
    }
}

enum ZoomLevel {
    case hour
    case day
    case week
    case month
    case all
}

struct TimelineStatistics {
    let totalEvents: Int
    let totalVersions: Int
    let dateRange: ClosedRange<Date>
}

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubPath()
        return path
    }
}

struct EventMarker: View {
    let event: TimelineEvent
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? Color.accentColor : eventColor)
            .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
            )
    }

    private var eventColor: Color {
        switch event.type {
        case .textEdit, .textInsert: return .blue
        case .textDelete: return .red
        case .imageInsert, .imageDelete: return .purple
        default: return .gray
        }
    }
}

struct SelectionRange: View {
    let start: CGFloat
    let end: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.2))
            .frame(width: end - start)
            .offset(x: start)
    }
}

#endif
