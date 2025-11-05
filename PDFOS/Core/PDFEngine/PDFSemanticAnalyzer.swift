//
//  PDFSemanticAnalyzer.swift
//  PDFOS
//
//  Semantic analysis engine for PDF documents
//

import Foundation

/// Analyzes semantic changes in PDF documents using embeddings
actor PDFSemanticAnalyzer {
    // MARK: - Properties

    private let embeddingService: SemanticEmbeddingService
    private let threshold: Float = 0.3
    private let identicalThreshold: Float = 0.95
    private let modifiedThreshold: Float = 0.7

    // MARK: - Initialization

    init(embeddingService: SemanticEmbeddingService = SemanticEmbeddingService()) {
        self.embeddingService = embeddingService
    }

    // MARK: - Public Methods

    /// Analyzes changes between two PDF documents
    /// - Parameters:
    ///   - original: The original PDF document
    ///   - modified: The modified PDF document
    /// - Returns: A semantic delta representing the changes
    func analyzeChanges(
        original: PDFDocument,
        modified: PDFDocument
    ) async throws -> SemanticDelta {
        // 1. Extract text from both documents
        let originalText = try await extractText(from: original)
        let modifiedText = try await extractText(from: modified)

        // 2. Tokenize into semantic units (paragraphs)
        let originalUnits = tokenizeIntoSemanticUnits(originalText)
        let modifiedUnits = tokenizeIntoSemanticUnits(modifiedText)

        // 3. Generate embeddings for each unit
        let originalEmbeddings = try await embeddingService.generateEmbeddings(for: originalUnits)
        let modifiedEmbeddings = try await embeddingService.generateEmbeddings(for: modifiedUnits)

        // 4. Calculate similarity matrix
        let similarityMatrix = calculateSimilarityMatrix(
            original: originalEmbeddings,
            modified: modifiedEmbeddings
        )

        // 5. Identify semantic changes using Hungarian algorithm
        let changes = identifyChanges(
            originalUnits: originalUnits,
            modifiedUnits: modifiedUnits,
            originalEmbeddings: originalEmbeddings,
            modifiedEmbeddings: modifiedEmbeddings,
            similarityMatrix: similarityMatrix
        )

        // 6. Calculate importance score
        let importance = calculateImportance(changes: changes)

        // 7. Generate commit message
        let commitMessage = generateCommitMessage(changes: changes)

        return SemanticDelta(
            changes: changes,
            commitMessage: commitMessage,
            importance: importance
        )
    }

    /// Generates a human-readable commit message from semantic changes
    /// - Parameter delta: The semantic delta
    /// - Returns: A descriptive commit message
    func generateCommitMessage(delta: SemanticDelta) -> String {
        generateCommitMessage(changes: delta.changes)
    }

    // MARK: - Private Methods

    private func extractText(from document: PDFDocument) async throws -> String {
        // TODO: Implement with PDFKit on macOS
        // For now, placeholder implementation
        return ""
    }

    private func tokenizeIntoSemanticUnits(_ text: String) -> [SemanticUnit] {
        // Split text into paragraphs
        let paragraphs = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return paragraphs.enumerated().map { index, content in
            SemanticUnit(
                id: UUID(),
                content: content,
                index: index,
                type: .paragraph
            )
        }
    }

    private func calculateSimilarityMatrix(
        original: [SemanticEmbedding],
        modified: [SemanticEmbedding]
    ) -> [[Float]] {
        var matrix: [[Float]] = []

        for originalEmb in original {
            var row: [Float] = []
            for modifiedEmb in modified {
                let similarity = cosineSimilarity(
                    originalEmb.vector,
                    modifiedEmb.vector
                )
                row.append(similarity)
            }
            matrix.append(row)
        }

        return matrix
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    private func identifyChanges(
        originalUnits: [SemanticUnit],
        modifiedUnits: [SemanticUnit],
        originalEmbeddings: [SemanticEmbedding],
        modifiedEmbeddings: [SemanticEmbedding],
        similarityMatrix: [[Float]]
    ) -> [SemanticChange] {
        var changes: [SemanticChange] = []

        // Use greedy matching (simplified version of Hungarian algorithm)
        var matchedModified = Set<Int>()

        for (origIdx, originalUnit) in originalUnits.enumerated() {
            guard origIdx < similarityMatrix.count else { continue }

            // Find best match in modified units
            var bestMatchIdx = -1
            var bestSimilarity: Float = 0.0

            for (modIdx, similarity) in similarityMatrix[origIdx].enumerated() {
                if !matchedModified.contains(modIdx) && similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestMatchIdx = modIdx
                }
            }

            // Classify change based on similarity
            let changeType: SemanticChange.ChangeType
            if bestSimilarity >= identicalThreshold {
                changeType = .identical
            } else if bestSimilarity >= modifiedThreshold {
                changeType = .modified
            } else {
                changeType = .removed
            }

            if bestMatchIdx >= 0 {
                matchedModified.insert(bestMatchIdx)
            }

            if changeType != .identical {
                let change = SemanticChange(
                    changeType: changeType,
                    location: DocumentLocation(
                        pageIndex: 0, // TODO: Calculate actual page
                        paragraphIndex: originalUnit.index
                    ),
                    semanticEmbedding: originalEmbeddings[origIdx].vector,
                    similarity: bestSimilarity,
                    affectedSections: [] // TODO: Implement section tracking
                )
                changes.append(change)
            }
        }

        // Identify new additions
        for (modIdx, modifiedUnit) in modifiedUnits.enumerated() {
            if !matchedModified.contains(modIdx) {
                let change = SemanticChange(
                    changeType: .added,
                    location: DocumentLocation(
                        pageIndex: 0,
                        paragraphIndex: modifiedUnit.index
                    ),
                    semanticEmbedding: modifiedEmbeddings[modIdx].vector,
                    similarity: 0.0,
                    affectedSections: []
                )
                changes.append(change)
            }
        }

        return changes
    }

    private func calculateImportance(changes: [SemanticChange]) -> Float {
        // Weight different change types
        let weights: [SemanticChange.ChangeType: Float] = [
            .identical: 0.0,
            .modified: 0.7,
            .added: 1.0,
            .removed: 0.9
        ]

        let totalWeight = changes.reduce(0.0) { sum, change in
            sum + (weights[change.changeType] ?? 0.5)
        }

        // Normalize to 0-1 range
        let maxPossibleWeight = Float(changes.count)
        return maxPossibleWeight > 0 ? min(totalWeight / maxPossibleWeight, 1.0) : 0.0
    }

    private func generateCommitMessage(changes: [SemanticChange]) -> String {
        let addedCount = changes.filter { $0.changeType == .added }.count
        let modifiedCount = changes.filter { $0.changeType == .modified }.count
        let removedCount = changes.filter { $0.changeType == .removed }.count

        var messageParts: [String] = []

        if modifiedCount > 0 {
            messageParts.append("Modified \(modifiedCount) section\(modifiedCount > 1 ? "s" : "")")
        }
        if addedCount > 0 {
            messageParts.append("Added \(addedCount) section\(addedCount > 1 ? "s" : "")")
        }
        if removedCount > 0 {
            messageParts.append("Removed \(removedCount) section\(removedCount > 1 ? "s" : "")")
        }

        return messageParts.isEmpty ? "No changes" : messageParts.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

/// Represents a semantic unit of text
struct SemanticUnit {
    let id: UUID
    let content: String
    let index: Int
    let type: UnitType

    enum UnitType {
        case paragraph
        case section
        case clause
        case sentence
    }
}

/// Represents a semantic embedding vector
struct SemanticEmbedding {
    let unitId: UUID
    let vector: [Float]
    let model: String

    init(unitId: UUID, vector: [Float], model: String = "bert-base-uncased") {
        self.unitId = unitId
        self.vector = vector
        self.model = model
    }
}
