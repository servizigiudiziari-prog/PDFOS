//
//  PerformanceTests.swift
//  PDFOS
//
//  Performance tests with strict requirements
//

import XCTest
@testable import PDFOSCore

/// Performance tests for PDFOS
/// These tests enforce the performance requirements specified in the design
final class PerformanceTests: XCTestCase {

    // MARK: - Properties

    var semanticAnalyzer: PDFSemanticAnalyzer!
    var eventStore: EventStore!
    var versionControl: PDFVersionControl!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        semanticAnalyzer = PDFSemanticAnalyzer()
        eventStore = EventStore()
        let versionGraph = VersionGraph()
        versionControl = PDFVersionControl(
            eventStore: eventStore,
            versionGraph: versionGraph,
            semanticAnalyzer: semanticAnalyzer
        )
    }

    // MARK: - Semantic Analysis Performance

    /// CRITICAL: Semantic analysis MUST complete in <400ms per page on M1
    func testSemanticAnalysisPerformance() async throws {
        let testDocument = createTestDocument(pages: 1)

        measure {
            Task {
                _ = try? await semanticAnalyzer.analyzeChanges(
                    original: testDocument,
                    modified: testDocument
                )
            }
        }

        // Measure actual time
        let start = Date()
        _ = try await semanticAnalyzer.analyzeChanges(
            original: testDocument,
            modified: testDocument
        )
        let elapsed = Date().timeIntervalSince(start)

        // MUST be under 400ms
        XCTAssertLessThan(
            elapsed,
            0.4,
            "Semantic analysis took \(elapsed)s, must be <400ms"
        )
    }

    /// Test semantic analysis on multi-page documents
    func testSemanticAnalysisMultiPage() async throws {
        let testDocument = createTestDocument(pages: 10)

        let start = Date()
        _ = try await semanticAnalyzer.analyzeChanges(
            original: testDocument,
            modified: testDocument
        )
        let elapsed = Date().timeIntervalSince(start)

        // Should be <4s for 10 pages (400ms per page)
        XCTAssertLessThan(
            elapsed,
            4.0,
            "Multi-page semantic analysis took \(elapsed)s, should be <4s"
        )
    }

    // MARK: - Time Travel Performance

    /// CRITICAL: Time travel MUST reconstruct any state in <100ms
    func testTimeTravelPerformance() async throws {
        let document = createTestDocument(pages: 1)

        // Create some events
        for i in 0..<10 {
            let event = PDFEvent(
                type: .textEdit,
                payload: Data(),
                userId: "test",
                semanticHash: "hash\(i)"
            )
            await eventStore.recordEvent(event, documentId: document.id)
        }

        // Measure time travel
        let targetDate = Date()
        let start = Date()
        _ = try await eventStore.timeTravel(to: targetDate, documentId: document.id)
        let elapsed = Date().timeIntervalSince(start)

        // MUST be under 100ms
        XCTAssertLessThan(
            elapsed,
            0.1,
            "Time travel took \(elapsed)s, must be <100ms"
        )
    }

    // MARK: - Memory Usage

    /// CRITICAL: Memory usage MUST stay under 500MB for 100-page document
    func testMemoryUsage() async throws {
        let document = createTestDocument(pages: 100)

        // Get baseline memory
        let baselineMemory = getMemoryUsage()

        // Perform operations
        _ = try await semanticAnalyzer.analyzeChanges(
            original: document,
            modified: document
        )

        // Check memory usage
        let currentMemory = getMemoryUsage()
        let usedMemory = currentMemory - baselineMemory

        // MUST be under 500MB
        XCTAssertLessThan(
            usedMemory,
            500_000_000,
            "Memory usage is \(usedMemory) bytes, must be <500MB"
        )
    }

    // MARK: - Version Control Performance

    /// Test commit performance
    func testCommitPerformance() async throws {
        let document = createTestDocument(pages: 1)
        let delta = SemanticDelta(
            changes: [],
            commitMessage: "Test commit",
            importance: 0.5
        )

        let start = Date()
        _ = try await versionControl.commit(
            document: document,
            semanticDelta: delta,
            author: "test"
        )
        let elapsed = Date().timeIntervalSince(start)

        // Should be fast (<50ms)
        XCTAssertLessThan(
            elapsed,
            0.05,
            "Commit took \(elapsed)s, should be <50ms"
        )
    }

    /// Test merge performance
    func testMergePerformance() async throws {
        let document = createTestDocument(pages: 1)
        let delta1 = SemanticDelta(
            changes: [],
            commitMessage: "Version 1",
            importance: 0.5
        )
        let delta2 = SemanticDelta(
            changes: [],
            commitMessage: "Version 2",
            importance: 0.5
        )

        let version1 = try await versionControl.commit(
            document: document,
            semanticDelta: delta1,
            author: "test"
        )

        let version2 = try await versionControl.commit(
            document: document,
            semanticDelta: delta2,
            author: "test"
        )

        let start = Date()
        _ = try await versionControl.merge(branch1: version1, branch2: version2)
        let elapsed = Date().timeIntervalSince(start)

        // Should be fast (<100ms)
        XCTAssertLessThan(
            elapsed,
            0.1,
            "Merge took \(elapsed)s, should be <100ms"
        )
    }

    // MARK: - Kill Switch Monitoring

    /// Test that performance metrics can detect kill switches
    func testKillSwitchDetection() {
        var metrics = PerformanceMetrics(
            semanticLatency: 1.5,
            falsePositiveRate: 0.1,
            memoryUsage: 400_000_000,
            crashRate: 0.005
        )

        var triggered = metrics.checkKillSwitches()
        XCTAssertTrue(triggered.isEmpty, "No kill switches should trigger with good metrics")

        // Trigger semantic latency kill switch
        metrics.semanticLatency = 2.5
        triggered = metrics.checkKillSwitches()
        XCTAssertFalse(triggered.isEmpty, "Should trigger semantic latency kill switch")

        // Trigger memory kill switch
        metrics.memoryUsage = 1_100_000_000
        triggered = metrics.checkKillSwitches()
        XCTAssertTrue(
            triggered.contains { if case .memoryUsage = $0 { return true }; return false },
            "Should trigger memory kill switch"
        )
    }

    // MARK: - Helper Methods

    private func createTestDocument(pages: Int) -> PDFDocument {
        let metadata = DocumentMetadata(
            title: "Test Document",
            author: "Test",
            subject: nil,
            keywords: [],
            pageCount: pages,
            fileSize: Int64(pages * 1024),
            documentType: .general
        )

        let delta = SemanticDelta(
            changes: [],
            commitMessage: "Test",
            importance: 0.0
        )

        let version = Version(
            parentIds: [],
            semanticDelta: delta,
            eventIds: [],
            author: "test",
            message: "Test version"
        )

        return PDFDocument(
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            metadata: metadata,
            currentVersion: version
        )
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }

        return 0
    }
}
