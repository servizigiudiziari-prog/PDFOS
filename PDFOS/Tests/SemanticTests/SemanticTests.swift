//
//  SemanticTests.swift
//  PDFOS
//
//  Tests for semantic analysis functionality
//

import XCTest
@testable import PDFOSCore

/// Tests for semantic analysis engine
final class SemanticTests: XCTestCase {

    // MARK: - Properties

    var analyzer: PDFSemanticAnalyzer!
    var embeddingService: SemanticEmbeddingService!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        embeddingService = SemanticEmbeddingService()
        analyzer = PDFSemanticAnalyzer(embeddingService: embeddingService)
    }

    // MARK: - Embedding Tests

    func testEmbeddingGeneration() async throws {
        let units = [
            SemanticUnit(
                id: UUID(),
                content: "This is a test sentence.",
                index: 0,
                type: .sentence
            ),
            SemanticUnit(
                id: UUID(),
                content: "This is another test sentence.",
                index: 1,
                type: .sentence
            )
        ]

        let embeddings = try await embeddingService.generateEmbeddings(for: units)

        XCTAssertEqual(embeddings.count, 2)
        XCTAssertEqual(embeddings[0].vector.count, 768) // BERT dimension
        XCTAssertEqual(embeddings[1].vector.count, 768)
    }

    func testEmbeddingSimilarity() async throws {
        let unit1 = SemanticUnit(
            id: UUID(),
            content: "The quick brown fox jumps over the lazy dog.",
            index: 0,
            type: .sentence
        )

        let unit2 = SemanticUnit(
            id: UUID(),
            content: "The fast brown fox leaps over the sleepy dog.",
            index: 1,
            type: .sentence
        )

        let unit3 = SemanticUnit(
            id: UUID(),
            content: "Completely different content about programming.",
            index: 2,
            type: .sentence
        )

        let embedding1 = try await embeddingService.generateEmbedding(
            for: unit1.content,
            unitId: unit1.id
        )
        let embedding2 = try await embeddingService.generateEmbedding(
            for: unit2.content,
            unitId: unit2.id
        )
        let embedding3 = try await embeddingService.generateEmbedding(
            for: unit3.content,
            unitId: unit3.id
        )

        // Similar sentences should have higher similarity
        let similarity12 = cosineSimilarity(embedding1.vector, embedding2.vector)
        let similarity13 = cosineSimilarity(embedding1.vector, embedding3.vector)

        XCTAssertGreaterThan(
            similarity12,
            similarity13,
            "Similar sentences should have higher similarity"
        )
    }

    // MARK: - Change Detection Tests

    func testIdenticalDocuments() async throws {
        let document = createTestDocument(content: "This is a test document.")

        let delta = try await analyzer.analyzeChanges(
            original: document,
            modified: document
        )

        // Should detect no changes or all identical
        let nonIdenticalChanges = delta.changes.filter { $0.changeType != .identical }
        XCTAssertTrue(
            nonIdenticalChanges.isEmpty,
            "Identical documents should have no non-identical changes"
        )
    }

    func testTextModification() async throws {
        let original = createTestDocument(content: "This is the original text.")
        let modified = createTestDocument(content: "This is the modified text.")

        let delta = try await analyzer.analyzeChanges(
            original: original,
            modified: modified
        )

        // Should detect modification
        XCTAssertFalse(delta.changes.isEmpty, "Should detect changes")

        let hasModification = delta.changes.contains { $0.changeType == .modified }
        XCTAssertTrue(hasModification, "Should detect text modification")
    }

    func testTextAddition() async throws {
        let original = createTestDocument(content: "First paragraph.")
        let modified = createTestDocument(content: "First paragraph.\nSecond paragraph.")

        let delta = try await analyzer.analyzeChanges(
            original: original,
            modified: modified
        )

        let hasAddition = delta.changes.contains { $0.changeType == .added }
        XCTAssertTrue(hasAddition, "Should detect added text")
    }

    func testTextRemoval() async throws {
        let original = createTestDocument(content: "First paragraph.\nSecond paragraph.")
        let modified = createTestDocument(content: "First paragraph.")

        let delta = try await analyzer.analyzeChanges(
            original: original,
            modified: modified
        )

        let hasRemoval = delta.changes.contains { $0.changeType == .removed }
        XCTAssertTrue(hasRemoval, "Should detect removed text")
    }

    // MARK: - Commit Message Generation

    func testCommitMessageGeneration() async throws {
        let changes = [
            SemanticChange(
                changeType: .modified,
                location: DocumentLocation(pageIndex: 0),
                semanticEmbedding: [],
                similarity: 0.8,
                affectedSections: []
            ),
            SemanticChange(
                changeType: .added,
                location: DocumentLocation(pageIndex: 1),
                semanticEmbedding: [],
                similarity: 0.0,
                affectedSections: []
            )
        ]

        let delta = SemanticDelta(
            changes: changes,
            commitMessage: "",
            importance: 0.7
        )

        let message = await analyzer.generateCommitMessage(delta: delta)

        XCTAssertFalse(message.isEmpty, "Should generate commit message")
        XCTAssertTrue(
            message.contains("Modified") || message.contains("Added"),
            "Message should describe changes"
        )
    }

    // MARK: - Importance Calculation

    func testImportanceCalculation() async throws {
        // High importance: many changes
        let highImportanceChanges = (0..<10).map { i in
            SemanticChange(
                changeType: .modified,
                location: DocumentLocation(pageIndex: i),
                semanticEmbedding: [],
                similarity: 0.7,
                affectedSections: []
            )
        }

        let original = createTestDocument(content: "Test")
        let modified = createTestDocument(content: "Test modified")

        let delta = try await analyzer.analyzeChanges(
            original: original,
            modified: modified
        )

        // Importance should be between 0 and 1
        XCTAssertGreaterThanOrEqual(delta.importance, 0.0)
        XCTAssertLessThanOrEqual(delta.importance, 1.0)
    }

    // MARK: - Helper Methods

    private func createTestDocument(content: String) -> PDFDocument {
        let metadata = DocumentMetadata(
            title: "Test",
            author: "Test",
            subject: nil,
            keywords: [],
            pageCount: 1,
            fileSize: Int64(content.count),
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
            message: "Test"
        )

        return PDFDocument(
            url: URL(fileURLWithPath: "/tmp/test.pdf"),
            metadata: metadata,
            currentVersion: version
        )
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}
