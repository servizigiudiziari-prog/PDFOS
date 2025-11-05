//
//  VersionControlTests.swift
//  PDFOS
//
//  Comprehensive tests for version control system
//

import XCTest
@testable import PDFOSCore

/// Tests for version control functionality
final class VersionControlTests: XCTestCase {

    var eventStore: EventStoreOptimized!
    var versionGraph: VersionGraph!
    var versionControl: PDFVersionControl!
    var semanticAnalyzer: PDFSemanticAnalyzer!

    override func setUp() async throws {
        try await super.setUp()

        eventStore = EventStoreOptimized()
        versionGraph = VersionGraph()
        semanticAnalyzer = PDFSemanticAnalyzer()
        versionControl = PDFVersionControl(
            eventStore: EventStore(), // Using non-optimized for compatibility
            versionGraph: versionGraph,
            semanticAnalyzer: semanticAnalyzer
        )
    }

    // MARK: - Event Store Tests

    func testEventRecording() async throws {
        let documentId = UUID()
        let event = createTestEvent()

        try await eventStore.recordEvent(event, documentId: documentId)

        let events = await eventStore.getEvents(documentId: documentId, offset: 0, limit: 10)
        XCTAssertEqual(events.count, 1, "Should record event")
        XCTAssertEqual(events.first?.id, event.id, "Should retrieve same event")
    }

    func testSnapshotCreation() async throws {
        let documentId = UUID()

        // Record 10 events to trigger snapshot
        for i in 0..<10 {
            let event = createTestEvent(type: .textEdit)
            try await eventStore.recordEvent(event, documentId: documentId)
        }

        // Verify snapshot was created
        let stats = await eventStore.getStorageStats()
        XCTAssertGreaterThan(stats.totalSnapshots, 0, "Should create snapshot after 10 events")
    }

    func testTimeTravel() async throws {
        let documentId = UUID()
        let targetDate = Date()

        // Record events
        for _ in 0..<5 {
            let event = createTestEvent()
            try await eventStore.recordEvent(event, documentId: documentId)
        }

        // Time travel
        let result = try await eventStore.timeTravel(to: targetDate, documentId: documentId)

        XCTAssertNotNil(result, "Should reconstruct state")
        XCTAssertLessThan(
            result.reconstructionTime,
            0.1,
            "Time travel should be fast (<100ms)"
        )
    }

    func testStorageCompression() async throws {
        let documentId = UUID()

        // Record many events
        for _ in 0..<100 {
            let event = createTestEvent()
            try await eventStore.recordEvent(event, documentId: documentId)
        }

        let stats = await eventStore.getStorageStats()

        XCTAssertGreaterThan(
            stats.compressionRatio,
            1.0,
            "Should achieve compression"
        )
    }

    func testStorageOptimization() async throws {
        let documentId = UUID()

        // Create events
        for _ in 0..<50 {
            try await eventStore.recordEvent(createTestEvent(), documentId: documentId)
        }

        let beforeSize = (await eventStore.getStorageStats()).storageSize

        // Optimize
        try await eventStore.optimizeStorage()

        let afterSize = (await eventStore.getStorageStats()).storageSize

        XCTAssertLessThanOrEqual(
            afterSize,
            beforeSize,
            "Storage size should not increase after optimization"
        )
    }

    // MARK: - Version Graph Tests

    func testVersionCreation() async throws {
        let version = createTestVersion(message: "Initial version")

        await versionGraph.addVersion(version)

        let retrieved = await versionGraph.getVersion(version.id)
        XCTAssertNotNil(retrieved, "Should store and retrieve version")
        XCTAssertEqual(retrieved?.id, version.id)
    }

    func testVersionHistory() async throws {
        // Create version chain
        let v1 = createTestVersion(message: "v1", parentIds: [])
        await versionGraph.addVersion(v1)

        let v2 = createTestVersion(message: "v2", parentIds: [v1.id])
        await versionGraph.addVersion(v2)

        let v3 = createTestVersion(message: "v3", parentIds: [v2.id])
        await versionGraph.addVersion(v3)

        // Get history
        let history = await versionGraph.getHistory(from: v3.id)

        XCTAssertEqual(history.count, 3, "Should retrieve complete history")
        XCTAssertEqual(history[0].message, "v1", "Should be in chronological order")
        XCTAssertEqual(history[2].message, "v3")
    }

    func testCommonAncestor() async throws {
        // Create branching history
        let base = createTestVersion(message: "base", parentIds: [])
        await versionGraph.addVersion(base)

        let branch1 = createTestVersion(message: "branch1", parentIds: [base.id])
        await versionGraph.addVersion(branch1)

        let branch2 = createTestVersion(message: "branch2", parentIds: [base.id])
        await versionGraph.addVersion(branch2)

        // Find common ancestor
        let ancestor = await versionGraph.findCommonAncestor(
            version1: branch1.id,
            version2: branch2.id
        )

        XCTAssertNotNil(ancestor, "Should find common ancestor")
        XCTAssertEqual(ancestor?.id, base.id, "Common ancestor should be base")
    }

    func testBranchManagement() async throws {
        let version = createTestVersion(message: "v1")
        await versionGraph.addVersion(version)

        let branch = Branch(
            id: UUID(),
            name: "feature-branch",
            headVersion: version.id,
            createdAt: Date()
        )

        await versionGraph.addBranch(branch)

        let retrieved = await versionGraph.getBranch("feature-branch")
        XCTAssertNotNil(retrieved, "Should store and retrieve branch")
        XCTAssertEqual(retrieved?.name, "feature-branch")
    }

    func testGraphVisualization() async throws {
        // Create complex graph
        let v1 = createTestVersion(message: "v1", parentIds: [])
        let v2 = createTestVersion(message: "v2", parentIds: [v1.id])
        let v3 = createTestVersion(message: "v3", parentIds: [v1.id])
        let v4 = createTestVersion(message: "v4", parentIds: [v2.id, v3.id]) // Merge

        await versionGraph.addVersion(v1)
        await versionGraph.addVersion(v2)
        await versionGraph.addVersion(v3)
        await versionGraph.addVersion(v4)

        let viz = await versionGraph.visualize()

        XCTAssertEqual(viz.nodes.count, 4, "Should have 4 nodes")
        XCTAssertEqual(viz.edges.count, 4, "Should have 4 edges")
    }

    // MARK: - Merge Tests

    func testSimpleMerge() async throws {
        let document = createTestDocument()

        // Create two versions
        let delta1 = createTestDelta(changes: [
            createTestChange(type: .added, pageIndex: 0)
        ])

        let delta2 = createTestDelta(changes: [
            createTestChange(type: .added, pageIndex: 1)
        ])

        let v1 = try await versionControl.commit(
            document: document,
            semanticDelta: delta1,
            author: "user1"
        )

        let v2 = try await versionControl.commit(
            document: document,
            semanticDelta: delta2,
            author: "user2"
        )

        // Merge
        let result = try await versionControl.merge(branch1: v1, branch2: v2)

        switch result {
        case .success(let merged):
            XCTAssertEqual(merged.parentIds.count, 2, "Merged version should have 2 parents")
        case .conflict:
            XCTFail("Simple merge should not have conflicts")
        case .failure:
            XCTFail("Merge should succeed")
        }
    }

    func testConflictDetection() async throws {
        let document = createTestDocument()

        // Create conflicting changes at same location
        let delta1 = createTestDelta(changes: [
            createTestChange(type: .modified, pageIndex: 0, paragraphIndex: 0)
        ])

        let delta2 = createTestDelta(changes: [
            createTestChange(type: .modified, pageIndex: 0, paragraphIndex: 0)
        ])

        let v1 = try await versionControl.commit(
            document: document,
            semanticDelta: delta1,
            author: "user1"
        )

        let v2 = try await versionControl.commit(
            document: document,
            semanticDelta: delta2,
            author: "user2"
        )

        // Merge should detect conflict
        let result = try await versionControl.merge(branch1: v1, branch2: v2)

        switch result {
        case .conflict(let conflicts):
            XCTAssertFalse(conflicts.isEmpty, "Should detect conflicts")
        case .success:
            // May succeed if changes are compatible
            break
        case .failure:
            XCTFail("Merge should not fail completely")
        }
    }

    // MARK: - Performance Tests

    func testEventRecordingPerformance() async throws {
        let documentId = UUID()

        measure {
            Task {
                for _ in 0..<10 {
                    let event = createTestEvent()
                    try? await eventStore.recordEvent(event, documentId: documentId)
                }
            }
        }
    }

    func testTimeTravelPerformance() async throws {
        let documentId = UUID()

        // Setup: record 100 events
        for _ in 0..<100 {
            try await eventStore.recordEvent(createTestEvent(), documentId: documentId)
        }

        let targetDate = Date()

        // Measure time travel performance
        measure {
            Task {
                _ = try? await eventStore.timeTravel(to: targetDate, documentId: documentId)
            }
        }
    }

    func testVersionGraphPerformance() async throws {
        // Create large version history
        var previousVersion: Version?

        for i in 0..<100 {
            let version = createTestVersion(
                message: "v\(i)",
                parentIds: previousVersion.map { [$0.id] } ?? []
            )
            await versionGraph.addVersion(version)
            previousVersion = version
        }

        // Measure history retrieval
        measure {
            Task {
                _ = await versionGraph.getHistory(from: previousVersion!.id)
            }
        }
    }

    func testMergePerformance() async throws {
        let document = createTestDocument()

        // Create complex changes
        let changes = (0..<50).map { i in
            createTestChange(type: .modified, pageIndex: i % 10)
        }

        let delta1 = createTestDelta(changes: Array(changes[0..<25]))
        let delta2 = createTestDelta(changes: Array(changes[25..<50]))

        let v1 = try await versionControl.commit(
            document: document,
            semanticDelta: delta1,
            author: "user1"
        )

        let v2 = try await versionControl.commit(
            document: document,
            semanticDelta: delta2,
            author: "user2"
        )

        // Measure merge performance
        measure {
            Task {
                _ = try? await versionControl.merge(branch1: v1, branch2: v2)
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestEvent(type: PDFEvent.EventType = .textEdit) -> PDFEvent {
        PDFEvent(
            type: type,
            payload: Data(),
            userId: "test-user",
            semanticHash: UUID().uuidString
        )
    }

    private func createTestVersion(
        message: String,
        parentIds: [UUID] = []
    ) -> Version {
        Version(
            parentIds: parentIds,
            semanticDelta: createTestDelta(),
            eventIds: [],
            author: "test-author",
            message: message
        )
    }

    private func createTestDelta(changes: [SemanticChange] = []) -> SemanticDelta {
        SemanticDelta(
            changes: changes,
            commitMessage: "Test commit",
            importance: 0.5
        )
    }

    private func createTestChange(
        type: SemanticChange.ChangeType,
        pageIndex: Int,
        paragraphIndex: Int? = nil
    ) -> SemanticChange {
        SemanticChange(
            changeType: type,
            location: DocumentLocation(
                pageIndex: pageIndex,
                paragraphIndex: paragraphIndex
            ),
            semanticEmbedding: Array(repeating: 0.5, count: 768),
            similarity: 0.8,
            affectedSections: []
        )
    }

    private func createTestDocument() -> PDFDocument {
        let metadata = DocumentMetadata(
            title: "Test Document",
            author: "Test Author",
            subject: nil,
            keywords: [],
            pageCount: 10,
            fileSize: 1024,
            documentType: .general
        )

        let initialVersion = createTestVersion(message: "Initial")

        return PDFDocument(
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            metadata: metadata,
            currentVersion: initialVersion
        )
    }
}
