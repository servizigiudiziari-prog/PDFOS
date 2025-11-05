//
//  TimelineView.swift
//  PDFOS
//
//  Timeline view for time-travel debugging
//

#if canImport(SwiftUI)
import SwiftUI

/// Timeline view for document history
struct TimelineView: View {
    // MARK: - Properties

    @StateObject private var viewModel: TimelineViewModel
    @State private var currentDate: Date
    @State private var playbackSpeed: Float = 1.0
    @State private var isPlaying = false

    // MARK: - Initialization

    init(document: PDFDocument) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(document: document))
        _currentDate = State(initialValue: Date())
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Timeline header
            HStack {
                Text("Document Timeline")
                    .font(.headline)

                Spacer()

                Text(currentDate, style: .date)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Timeline slider
            TimelineSlider(
                currentDate: $currentDate,
                events: viewModel.events,
                dateRange: viewModel.dateRange
            )
            .frame(height: 60)

            // Modification heatmap
            if let heatmap = viewModel.heatmap {
                ModificationHeatmapView(heatmap: heatmap)
                    .frame(height: 40)
            }

            // Playback controls
            PlaybackControls(
                isPlaying: $isPlaying,
                speed: $playbackSpeed,
                onPlay: {
                    startPlayback()
                },
                onPause: {
                    pausePlayback()
                },
                onReset: {
                    resetPlayback()
                }
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            await viewModel.loadTimeline()
        }
        .onChange(of: currentDate) { _, newDate in
            Task {
                await viewModel.timeTravel(to: newDate)
            }
        }
    }

    // MARK: - Private Methods

    private func startPlayback() {
        // TODO: Implement playback animation
        isPlaying = true
    }

    private func pausePlayback() {
        isPlaying = false
    }

    private func resetPlayback() {
        isPlaying = false
        currentDate = viewModel.dateRange.lowerBound
    }
}

// MARK: - Timeline Slider

struct TimelineSlider: View {
    @Binding var currentDate: Date
    let events: [TimelineEvent]
    let dateRange: ClosedRange<Date>

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                // Event markers
                ForEach(events) { event in
                    let position = calculatePosition(
                        for: event.timestamp,
                        in: geometry.size.width
                    )

                    Circle()
                        .fill(colorForEventType(event.type))
                        .frame(width: 8, height: 8)
                        .offset(x: position)
                }

                // Current position indicator
                let currentPosition = calculatePosition(
                    for: currentDate,
                    in: geometry.size.width
                )

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 30)
                    .offset(x: currentPosition)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percentage = value.location.x / geometry.size.width
                        let timeInterval = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
                        let offset = timeInterval * Double(percentage)
                        currentDate = dateRange.lowerBound.addingTimeInterval(offset)
                    }
            )
        }
    }

    private func calculatePosition(for date: Date, in width: CGFloat) -> CGFloat {
        let totalDuration = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let offset = date.timeIntervalSince(dateRange.lowerBound)
        let percentage = offset / totalDuration
        return width * CGFloat(percentage)
    }

    private func colorForEventType(_ type: PDFEvent.EventType) -> Color {
        switch type {
        case .textEdit, .textInsert: return .blue
        case .textDelete: return .red
        case .imageInsert, .imageDelete: return .purple
        case .annotationAdd, .annotationRemove: return .orange
        default: return .gray
        }
    }
}

// MARK: - Modification Heatmap View

struct ModificationHeatmapView: View {
    let heatmap: ModificationHeatmap

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<100, id: \.self) { index in
                Rectangle()
                    .fill(intensityColor(for: index))
                    .frame(width: 4)
            }
        }
    }

    private func intensityColor(for index: Int) -> Color {
        // TODO: Calculate actual intensity from heatmap data
        let intensity = Double.random(in: 0...1)
        return Color.accentColor.opacity(intensity)
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @Binding var isPlaying: Bool
    @Binding var speed: Float
    let onPlay: () -> Void
    let onPause: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack {
            Button(action: onReset) {
                Image(systemName: "backward.end.fill")
            }

            Button(action: isPlaying ? onPause : onPlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }

            Spacer()

            Text("Speed: \(String(format: "%.1f", speed))x")
                .foregroundColor(.secondary)

            Slider(value: $speed, in: 0.5...4.0, step: 0.5)
                .frame(width: 150)
        }
    }
}

// MARK: - Timeline View Model

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var events: [TimelineEvent] = []
    @Published var heatmap: ModificationHeatmap?
    @Published var dateRange: ClosedRange<Date>

    private let document: PDFDocument
    private let versioningService: VersioningService

    init(document: PDFDocument) {
        self.document = document
        self.versioningService = VersioningService()

        // Set initial date range (last 30 days)
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 86400)
        self.dateRange = thirtyDaysAgo...now
    }

    func loadTimeline() async {
        events = await versioningService.getTimeline(for: document)

        heatmap = await versioningService.getModificationHeatmap(
            document: document,
            timeRange: dateRange
        )
    }

    func timeTravel(to date: Date) async {
        // TODO: Implement time travel
    }
}

// MARK: - Preview

#Preview {
    let metadata = DocumentMetadata(
        title: "Sample Document",
        author: "User",
        subject: nil,
        keywords: [],
        pageCount: 10,
        fileSize: 1024000,
        documentType: .general
    )

    let delta = SemanticDelta(
        changes: [],
        commitMessage: "Initial",
        importance: 0
    )

    let version = Version(
        parentIds: [],
        semanticDelta: delta,
        eventIds: [],
        author: "system",
        message: "Initial"
    )

    let document = PDFDocument(
        url: URL(fileURLWithPath: "/tmp/test.pdf"),
        metadata: metadata,
        currentVersion: version
    )

    return TimelineView(document: document)
        .frame(width: 800, height: 200)
}
#endif
