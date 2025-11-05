//
//  VersioningService.swift
//  PDFOS
//
//  Specialized service for version control operations
//

import Foundation

/// Service for advanced version control operations
actor VersioningService {
    // MARK: - Properties

    private let versionControl: PDFVersionControl
    private let timeTravel: PDFTimeTravel
    private let eventStore: EventStore

    // MARK: - Initialization

    init(
        versionControl: PDFVersionControl,
        timeTravel: PDFTimeTravel,
        eventStore: EventStore
    ) {
        self.versionControl = versionControl
        self.timeTravel = timeTravel
        self.eventStore = eventStore
    }

    convenience init() {
        let eventStore = EventStore()
        let versionGraph = VersionGraph()
        let semanticAnalyzer = PDFSemanticAnalyzer()
        let versionControl = PDFVersionControl(
            eventStore: eventStore,
            versionGraph: versionGraph,
            semanticAnalyzer: semanticAnalyzer
        )
        let timeTravel = PDFTimeTravel(eventStore: eventStore)

        self.init(
            versionControl: versionControl,
            timeTravel: timeTravel,
            eventStore: eventStore
        )
    }

    // MARK: - Time Travel Operations

    /// Time travels to a specific date
    /// - Parameters:
    ///   - date: The target date
    ///   - document: The document
    /// - Returns: The document state at that date
    func timeTravel(to date: Date, document: PDFDocument) async throws -> PDFDocument {
        try await timeTravel.timeTravel(to: date, document: document)
    }

    /// Generates a replay video
    /// - Parameters:
    ///   - from: Start date
    ///   - to: End date
    ///   - document: The document
    ///   - speed: Playback speed
    /// - Returns: URL to the video file
    func generateReplayVideo(
        from: Date,
        to: Date,
        document: PDFDocument,
        speed: Float = 1.0
    ) async throws -> URL {
        try await timeTravel.generateReplayVideo(
            from: from,
            to: to,
            document: document,
            speed: speed
        )
    }

    /// Gets modification heatmap
    /// - Parameters:
    ///   - document: The document
    ///   - timeRange: The time range
    /// - Returns: Heatmap data
    func getModificationHeatmap(
        document: PDFDocument,
        timeRange: ClosedRange<Date>
    ) async -> ModificationHeatmap {
        await timeTravel.getModificationHeatmap(
            document: document,
            timeRange: timeRange
        )
    }

    /// Gets timeline of changes
    /// - Parameter document: The document
    /// - Returns: Array of timeline events
    func getTimeline(for document: PDFDocument) async -> [TimelineEvent] {
        await timeTravel.getTimeline(for: document)
    }

    // MARK: - Branch Operations

    /// Creates a new branch
    /// - Parameters:
    ///   - version: The version to branch from
    ///   - name: The branch name
    /// - Returns: The new branch
    func createBranch(from version: Version, name: String) async throws -> Branch {
        try await versionControl.createBranch(from: version, name: name)
    }

    /// Compares two versions
    /// - Parameters:
    ///   - version1: First version
    ///   - version2: Second version
    /// - Returns: Comparison result
    func compareVersions(
        _ version1: Version,
        _ version2: Version
    ) async -> VersionComparison {
        let changes1 = version1.semanticDelta.changes
        let changes2 = version2.semanticDelta.changes

        return VersionComparison(
            version1: version1,
            version2: version2,
            addedInV2: changes2.filter { c2 in
                !changes1.contains { c1 in
                    locationsMatch(c1.location, c2.location)
                }
            },
            removedInV2: changes1.filter { c1 in
                !changes2.contains { c2 in
                    locationsMatch(c1.location, c2.location)
                }
            },
            modifiedInV2: changes2.filter { c2 in
                changes1.contains { c1 in
                    locationsMatch(c1.location, c2.location) &&
                    c1.changeType != c2.changeType
                }
            }
        )
    }

    /// Generates a diff view between two versions
    /// - Parameters:
    ///   - version1: First version
    ///   - version2: Second version
    /// - Returns: Diff data for visualization
    func generateDiff(
        version1: Version,
        version2: Version
    ) async -> DiffView {
        let comparison = await compareVersions(version1, version2)

        return DiffView(
            comparison: comparison,
            hunks: generateDiffHunks(comparison)
        )
    }

    // MARK: - Conflict Resolution

    /// Resolves a merge conflict
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - resolution: The chosen resolution
    /// - Returns: The resolved version
    func resolveConflict(
        _ conflict: MergeConflict,
        resolution: ConflictResolution
    ) async throws -> Version {
        switch resolution {
        case .useCurrentVersion:
            return conflict.currentVersion
        case .useIncomingVersion:
            return conflict.incomingVersion
        case .custom(let semanticDelta):
            // Create a new version with custom resolution
            return Version(
                parentIds: [conflict.currentVersion.id, conflict.incomingVersion.id],
                semanticDelta: semanticDelta,
                eventIds: conflict.currentVersion.eventIds + conflict.incomingVersion.eventIds,
                author: "user",
                message: "Resolved conflict: \(conflict.description)"
            )
        }
    }

    // MARK: - Private Methods

    private func locationsMatch(_ loc1: DocumentLocation, _ loc2: DocumentLocation) -> Bool {
        loc1.pageIndex == loc2.pageIndex &&
        loc1.paragraphIndex == loc2.paragraphIndex
    }

    private func generateDiffHunks(_ comparison: VersionComparison) -> [DiffHunk] {
        var hunks: [DiffHunk] = []

        // Group changes by page
        var changesByPage: [Int: [SemanticChange]] = [:]

        for change in comparison.addedInV2 {
            changesByPage[change.location.pageIndex, default: []].append(change)
        }

        for change in comparison.removedInV2 {
            changesByPage[change.location.pageIndex, default: []].append(change)
        }

        for change in comparison.modifiedInV2 {
            changesByPage[change.location.pageIndex, default: []].append(change)
        }

        // Create hunks
        for (pageIndex, changes) in changesByPage {
            let hunk = DiffHunk(
                pageIndex: pageIndex,
                changes: changes,
                contextBefore: "", // TODO: Extract context
                contextAfter: ""
            )
            hunks.append(hunk)
        }

        return hunks.sorted { $0.pageIndex < $1.pageIndex }
    }
}

// MARK: - Supporting Types

/// Represents a comparison between two versions
struct VersionComparison {
    let version1: Version
    let version2: Version
    let addedInV2: [SemanticChange]
    let removedInV2: [SemanticChange]
    let modifiedInV2: [SemanticChange]

    var totalChanges: Int {
        addedInV2.count + removedInV2.count + modifiedInV2.count
    }
}

/// Represents a diff view for UI display
struct DiffView {
    let comparison: VersionComparison
    let hunks: [DiffHunk]
}

/// Represents a hunk of changes in a diff
struct DiffHunk {
    let pageIndex: Int
    let changes: [SemanticChange]
    let contextBefore: String
    let contextAfter: String
}

/// Conflict resolution options
enum ConflictResolution {
    case useCurrentVersion
    case useIncomingVersion
    case custom(SemanticDelta)
}
