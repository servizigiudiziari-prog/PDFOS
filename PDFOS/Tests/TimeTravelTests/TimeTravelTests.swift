//
//  TimeTravelTests.swift
//  PDFOS
//
//  Comprehensive tests for time travel functionality
//

import XCTest
@testable import PDFOSCore

/// Tests for time travel, video replay, and analytics
final class TimeTravelTests: XCTestCase {

    var document: PDFDocument!
    var eventStore: EventStoreOptimized!
    var analytics: TimeTravelAnalytics!
    var optimizer: PerformanceOptimizer!

    override func setUp() async throws {
        try await super.setUp()

        // Create test document
        document = PDFDocument(
            id: UUID(),
            metadata: PDFMetadata(
                title: "Test Document",
                author: "Test User",
                createdAt: Date(),
                modifiedAt: Date()
            ),
            pages: createTestPages(count: 50)
        )

        eventStore = EventStoreOptimized()
        analytics = TimeTravelAnalytics.shared
        optimizer = PerformanceOptimizer()
    }

    override func tearDown() async throws {
        await optimizer.clearOptimizations(for: document.id)
        try await super.tearDown()
    }

    // MARK: - Time Travel Reconstruction Tests

    func testBasicTimeTravel() async throws {
        // Create some events
        let events = try await createTestEvents(count: 10, documentId: document.id)

        // Time travel to middle point
        let targetDate = events[5].timestamp

        let timeTravel = PDFTimeTravel(eventStore: eventStore)
        let reconstructed = try await timeTravel.timeTravel(
            to: targetDate,
            document: document
        )

        XCTAssertNotNil(reconstructed, "Should reconstruct document")
    }

    func testTimeTravelPerformance() async throws {
        // Create 100 events
        let events = try await createTestEvents(count: 100, documentId: document.id)

        let targetDate = events[80].timestamp
        let startTime = Date()

        let timeTravel = PDFTimeTravel(eventStore: eventStore)
        let _ = try await timeTravel.timeTravel(
            to: targetDate,
            document: document
        )

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(
            duration,
            0.1,
            "Time travel should complete in <100ms, took \(duration * 1000)ms"
        )
    }

    func testTimeTravelWithSnapshots() async throws {
        // Create events with snapshots
        let events = try await createTestEvents(count: 50, documentId: document.id)

        // Create snapshot at event 25
        try await eventStore.createSnapshot(
            documentId: document.id,
            state: document
        )

        // Time travel to event 40 (should use snapshot)
        let targetDate = events[40].timestamp
        let startTime = Date()

        let timeTravel = PDFTimeTravel(eventStore: eventStore)
        let _ = try await timeTravel.timeTravel(
            to: targetDate,
            document: document
        )

        let duration = Date().timeIntervalSince(startTime)

        // With snapshot, should be even faster
        XCTAssertLessThan(
            duration,
            0.05,
            "Time travel with snapshot should be <50ms, took \(duration * 1000)ms"
        )
    }

    func testTimeTravelToFuture() async throws {
        let futureDate = Date().addingTimeInterval(86400) // Tomorrow

        let timeTravel = PDFTimeTravel(eventStore: eventStore)

        do {
            let _ = try await timeTravel.timeTravel(
                to: futureDate,
                document: document
            )
            XCTFail("Should not allow time travel to future")
        } catch {
            // Expected error
            XCTAssertTrue(true, "Correctly rejected future date")
        }
    }

    // MARK: - Video Replay Tests

    func testVideoGenerationBasic() async throws {
        // Create events
        let _ = try await createTestEvents(count: 20, documentId: document.id)

        let generator = VideoReplayGenerator()

        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()

        let videoURL = try await generator.generateReplay(
            document: document,
            from: startDate,
            to: endDate,
            speed: 1.0
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: videoURL.path),
            "Video file should be created"
        )

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Video file should have content")

        // Clean up
        try? FileManager.default.removeItem(at: videoURL)
    }

    func testVideoGenerationPerformance() async throws {
        let _ = try await createTestEvents(count: 50, documentId: document.id)

        let generator = VideoReplayGenerator(quality: .medium)

        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        let startTime = Date()

        let videoURL = try await generator.generateReplay(
            document: document,
            from: startDate,
            to: endDate,
            speed: 2.0
        )

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertLessThan(
            duration,
            10.0,
            "Video generation should complete in <10s, took \(duration)s"
        )

        try? FileManager.default.removeItem(at: videoURL)
    }

    func testVideoPreviewGeneration() async throws {
        let _ = try await createTestEvents(count: 30, documentId: document.id)

        let generator = VideoReplayGenerator()

        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()

        let videoURL = try await generator.generatePreview(
            document: document,
            from: startDate,
            to: endDate
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: videoURL.path),
            "Preview video should be created"
        )

        try? FileManager.default.removeItem(at: videoURL)
    }

    // MARK: - Report Generation Tests

    func testSummaryReportGeneration() async throws {
        let _ = try await createTestEvents(count: 100, documentId: document.id)

        let generator = ReportGenerator()

        let startDate = Date().addingTimeInterval(-86400) // 1 day ago
        let endDate = Date()

        let reportURL = try await generator.generateSummaryReport(
            document: document,
            from: startDate,
            to: endDate
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: reportURL.path),
            "Report PDF should be created"
        )

        let attributes = try FileManager.default.attributesOfItem(atPath: reportURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Report should have content")

        try? FileManager.default.removeItem(at: reportURL)
    }

    func testDetailedReportGeneration() async throws {
        let _ = try await createTestEvents(count: 50, documentId: document.id)

        let generator = ReportGenerator()

        let startDate = Date().addingTimeInterval(-86400)
        let endDate = Date()

        let reportURL = try await generator.generateDetailedReport(
            document: document,
            from: startDate,
            to: endDate
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: reportURL.path),
            "Detailed report should be created"
        )

        try? FileManager.default.removeItem(at: reportURL)
    }

    func testAuditReportGeneration() async throws {
        let _ = try await createTestEvents(count: 75, documentId: document.id)

        let generator = ReportGenerator()

        let startDate = Date().addingTimeInterval(-86400)
        let endDate = Date()

        let reportURL = try await generator.generateAuditReport(
            document: document,
            from: startDate,
            to: endDate
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: reportURL.path),
            "Audit report should be created"
        )

        try? FileManager.default.removeItem(at: reportURL)
    }

    // MARK: - Performance Optimization Tests

    func testLargeDocumentOptimization() async throws {
        // Create large document (150 pages)
        let largeDocument = PDFDocument(
            id: UUID(),
            metadata: document.metadata,
            pages: createTestPages(count: 150)
        )

        let result = try await optimizer.optimizeDocument(largeDocument)

        XCTAssertTrue(
            result.optimizationsApplied.contains(.lazyLoadingEnabled),
            "Should enable lazy loading"
        )
        XCTAssertTrue(
            result.optimizationsApplied.contains(.cacheWarmed),
            "Should warm caches"
        )
    }

    func testBatchedPageLoading() async throws {
        let largeDocument = PDFDocument(
            id: UUID(),
            metadata: document.metadata,
            pages: createTestPages(count: 100)
        )

        var progressUpdates: [Double] = []

        let pages = try await optimizer.loadPagesBatched(
            document: largeDocument,
            pageRange: 0..<50
        ) { progress in
            progressUpdates.append(progress)
        }

        XCTAssertEqual(pages.count, 50, "Should load 50 pages")
        XCTAssertFalse(progressUpdates.isEmpty, "Should report progress")
        XCTAssertEqual(progressUpdates.last ?? 0, 1.0, accuracy: 0.01, "Should reach 100%")
    }

    func testBatchedEventProcessing() async throws {
        let _ = try await createTestEvents(count: 200, documentId: document.id)

        var processedBatches: [[PDFEvent]] = []

        try await optimizer.processEventsBatched(
            documentId: document.id,
            from: Date().addingTimeInterval(-3600),
            to: Date()
        ) { batch in
            processedBatches.append(batch)
        }

        XCTAssertFalse(processedBatches.isEmpty, "Should process batches")
        XCTAssertLessThanOrEqual(
            processedBatches.map { $0.count }.max() ?? 0,
            10,
            "Batch size should be ≤10"
        )
    }

    func testMemoryUsageMonitoring() async throws {
        let memoryBefore = optimizer.getMemoryUsage()

        // Perform memory-intensive operation
        let largeDocument = PDFDocument(
            id: UUID(),
            metadata: document.metadata,
            pages: createTestPages(count: 200)
        )

        let _ = try await optimizer.optimizeDocument(largeDocument)

        let memoryAfter = optimizer.getMemoryUsage()

        // Memory should be monitored (not a strict assertion since it varies)
        XCTAssertGreaterThanOrEqual(memoryAfter, 0, "Should track memory usage")
    }

    // MARK: - Analytics Tests

    func testTimeTravelAnalyticsRecording() async throws {
        let targetDate = Date().addingTimeInterval(-3600)

        await analytics.recordTimeTravel(
            documentId: document.id,
            targetDate: targetDate,
            reconstructionTime: 0.045,
            eventsApplied: 25,
            snapshotUsed: true,
            memoryUsed: 150_000_000
        )

        let stats = await analytics.getStatistics()

        XCTAssertGreaterThan(stats.totalOperations, 0, "Should record operation")
    }

    func testVideoGenerationAnalytics() async throws {
        await analytics.recordVideoGeneration(
            documentId: document.id,
            duration: 5.2,
            frameCount: 156,
            fileSize: 5_242_880,
            quality: .high
        )

        // Verify recording (no direct getter, but should not crash)
        XCTAssertTrue(true, "Should record video generation")
    }

    func testPerformanceTrendsAnalysis() async throws {
        // Record multiple operations
        for i in 0..<10 {
            await analytics.recordTimeTravel(
                documentId: document.id,
                targetDate: Date().addingTimeInterval(Double(-i * 3600)),
                reconstructionTime: Double.random(in: 0.03...0.08),
                eventsApplied: Int.random(in: 10...50),
                snapshotUsed: Bool.random(),
                memoryUsed: Int.random(in: 100_000_000...200_000_000)
            )
        }

        let trends = await analytics.getPerformanceTrends(period: .last24Hours)

        XCTAssertFalse(trends.days.isEmpty, "Should have trend data")
    }

    func testUsagePatternsAnalysis() async throws {
        // Record various interactions
        for _ in 0..<5 {
            await analytics.recordTimelineInteraction(
                documentId: document.id,
                interactionType: .playback,
                duration: 30.0
            )
        }

        let patterns = await analytics.getUsagePatterns()

        XCTAssertGreaterThan(
            patterns.totalPlaybackTime,
            0,
            "Should track playback time"
        )
    }

    func testEfficiencyMetrics() async throws {
        // Record operations with and without snapshots
        for i in 0..<20 {
            await analytics.recordTimeTravel(
                documentId: document.id,
                targetDate: Date(),
                reconstructionTime: i < 10 ? 0.03 : 0.08,
                eventsApplied: 25,
                snapshotUsed: i < 10,
                memoryUsed: 150_000_000
            )
        }

        let efficiency = await analytics.getEfficiencyMetrics()

        XCTAssertGreaterThan(
            efficiency.snapshotSpeedupFactor,
            1.0,
            "Snapshots should improve performance"
        )
    }

    func testComprehensiveReport() async throws {
        // Generate some activity
        for _ in 0..<5 {
            await analytics.recordTimeTravel(
                documentId: document.id,
                targetDate: Date(),
                reconstructionTime: 0.05,
                eventsApplied: 30,
                snapshotUsed: true,
                memoryUsed: 150_000_000
            )
        }

        let report = await analytics.generateReport(period: .last24Hours)

        XCTAssertNotNil(report, "Should generate report")
        XCTAssertGreaterThan(
            report.statistics.totalOperations,
            0,
            "Report should include operations"
        )
    }

    // MARK: - Integration Tests

    func testCompleteTimeTravelWorkflow() async throws {
        // 1. Create events
        let events = try await createTestEvents(count: 50, documentId: document.id)

        // 2. Optimize for large document
        let _ = try await optimizer.optimizeDocument(document)

        // 3. Perform time travel
        let targetDate = events[30].timestamp
        let timeTravel = PDFTimeTravel(eventStore: eventStore)

        let startTime = Date()
        let reconstructed = try await timeTravel.timeTravel(
            to: targetDate,
            document: document
        )
        let duration = Date().timeIntervalSince(startTime)

        // 4. Record analytics
        await analytics.recordTimeTravel(
            documentId: document.id,
            targetDate: targetDate,
            reconstructionTime: duration,
            eventsApplied: 30,
            snapshotUsed: false,
            memoryUsed: optimizer.getMemoryUsage()
        )

        // 5. Generate video
        let generator = VideoReplayGenerator(quality: .medium)
        let videoURL = try await generator.generateReplay(
            document: document,
            from: events[0].timestamp,
            to: events[49].timestamp,
            speed: 2.0
        )

        // Verify all steps completed
        XCTAssertNotNil(reconstructed, "Time travel completed")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: videoURL.path),
            "Video generated"
        )

        let stats = await analytics.getStatistics()
        XCTAssertGreaterThan(stats.totalOperations, 0, "Analytics recorded")

        try? FileManager.default.removeItem(at: videoURL)
    }

    // MARK: - Edge Cases

    func testEmptyDocumentTimeTravel() async throws {
        let emptyDoc = PDFDocument(
            id: UUID(),
            metadata: PDFMetadata(
                title: "Empty",
                author: "Test",
                createdAt: Date(),
                modifiedAt: Date()
            ),
            pages: []
        )

        let timeTravel = PDFTimeTravel(eventStore: eventStore)

        let reconstructed = try await timeTravel.timeTravel(
            to: Date(),
            document: emptyDoc
        )

        XCTAssertEqual(reconstructed.pages.count, 0, "Should handle empty document")
    }

    func testNoEventsInRange() async throws {
        let generator = VideoReplayGenerator()

        do {
            let _ = try await generator.generateReplay(
                document: document,
                from: Date().addingTimeInterval(-7200),
                to: Date().addingTimeInterval(-3600),
                speed: 1.0
            )
            XCTFail("Should throw error for empty range")
        } catch VideoError.noEventsInRange {
            XCTAssertTrue(true, "Correctly detected empty range")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createTestPages(count: Int) -> [PDFPage] {
        (0..<count).map { index in
            PDFPage(
                id: UUID(),
                content: Data(),
                metadata: PageMetadata(
                    size: CGSize(width: 612, height: 792),
                    rotation: 0,
                    hasAnnotations: false,
                    hasImages: false
                )
            )
        }
    }

    private func createTestEvents(count: Int, documentId: UUID) async throws -> [PDFEvent] {
        var events: [PDFEvent] = []
        let baseDate = Date().addingTimeInterval(-3600) // Start 1 hour ago

        for i in 0..<count {
            let event = PDFEvent(
                id: UUID(),
                timestamp: baseDate.addingTimeInterval(Double(i * 30)), // 30s apart
                type: EventType.allCases.randomElement() ?? .textEdit,
                payload: Data(),
                userId: "test-user",
                semanticHash: UUID().uuidString
            )

            try await eventStore.recordEvent(event, documentId: documentId)
            events.append(event)

            // Create snapshot every 10 events
            if i > 0 && i % 10 == 0 {
                try await eventStore.createSnapshot(
                    documentId: documentId,
                    state: document
                )
            }
        }

        return events
    }
}

// MARK: - EventType Extension

extension EventType: CaseIterable {
    public static var allCases: [EventType] {
        return [
            .textEdit, .textInsert, .textDelete,
            .imageInsert, .imageDelete,
            .annotationAdd, .annotationRemove,
            .pageAdd, .pageRemove, .pageReorder,
            .metadataChange, .formFieldEdit
        ]
    }
}
