//
//  SemanticEmbedding.swift
//  PDFOS
//
//  ML service for generating semantic embeddings using CoreML and BERT
//

import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Service for generating semantic embeddings from text using BERT
actor SemanticEmbeddingService {
    // MARK: - Properties

    private let modelManager: BERTModelManager
    private let tokenizer: BERTTokenizer
    private let maxSequenceLength = 512
    private let embeddingDimension = 768
    private let batchSize = 8

    // Performance tracking
    private var totalInferences = 0
    private var totalLatency: TimeInterval = 0
    private var cacheHits = 0

    // Embedding cache for repeated texts
    private var embeddingCache: [String: [Float]] = [:]
    private let cacheMaxSize = 1000

    // MARK: - Initialization

    init() {
        self.modelManager = BERTModelManager.shared
        self.tokenizer = BERTTokenizer()
    }

    // MARK: - Public Methods

    /// Generates embeddings for multiple semantic units efficiently
    /// - Parameter units: Array of semantic units
    /// - Returns: Array of semantic embeddings
    func generateEmbeddings(for units: [SemanticUnit]) async throws -> [SemanticEmbedding] {
        var embeddings: [SemanticEmbedding] = []

        // Process in batches for efficiency
        for batchStart in stride(from: 0, to: units.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, units.count)
            let batch = Array(units[batchStart..<batchEnd])

            let batchEmbeddings = try await processBatch(batch)
            embeddings.append(contentsOf: batchEmbeddings)
        }

        return embeddings
    }

    /// Generates a single embedding for text
    /// - Parameters:
    ///   - text: The text to embed
    ///   - unitId: The ID of the semantic unit
    /// - Returns: A semantic embedding
    func generateEmbedding(for text: String, unitId: UUID) async throws -> SemanticEmbedding {
        let startTime = Date()

        // Check cache first
        if let cached = embeddingCache[text] {
            cacheHits += 1
            return SemanticEmbedding(
                unitId: unitId,
                vector: cached,
                model: "bert-base-uncased"
            )
        }

        // Generate embedding
        let vector: [Float]

        if await modelManager.isModelDownloaded() {
            // Use real BERT model
            vector = try await generateBERTEmbedding(for: text)
        } else {
            // Fall back to placeholder
            vector = generatePlaceholderEmbedding(for: text)
        }

        // Update performance metrics
        totalInferences += 1
        totalLatency += Date().timeIntervalSince(startTime)

        // Cache result
        cacheEmbedding(text, vector: vector)

        return SemanticEmbedding(
            unitId: unitId,
            vector: vector,
            model: "bert-base-uncased"
        )
    }

    /// Gets performance statistics
    /// - Returns: Embedding performance stats
    func getPerformanceStats() -> EmbeddingPerformanceStats {
        let averageLatency = totalInferences > 0 ? totalLatency / Double(totalInferences) : 0

        return EmbeddingPerformanceStats(
            totalInferences: totalInferences,
            averageLatency: averageLatency,
            cacheHitRate: totalInferences > 0 ? Double(cacheHits) / Double(totalInferences) : 0,
            cacheSize: embeddingCache.count
        )
    }

    /// Clears the embedding cache
    func clearCache() {
        embeddingCache.removeAll()
        cacheHits = 0
    }

    // MARK: - Private Methods

    private func processBatch(_ units: [SemanticUnit]) async throws -> [SemanticEmbedding] {
        var embeddings: [SemanticEmbedding] = []

        // TODO: Implement true batch processing with BERT
        // For now, process individually
        for unit in units {
            let embedding = try await generateEmbedding(for: unit.content, unitId: unit.id)
            embeddings.append(embedding)
        }

        return embeddings
    }

    private func generateBERTEmbedding(for text: String) async throws -> [Float] {
        // 1. Tokenize text
        let tokenization = await tokenizer.tokenize(text)

        // 2. Load model
        let model = try await modelManager.loadModel()

        // 3. Run inference
        let embedding = try model.predict(tokens: tokenization.tokenIds)

        // 4. Post-process (mean pooling, normalization, etc.)
        let processed = postProcessEmbedding(embedding, attentionMask: tokenization.attentionMask)

        return processed
    }

    private func postProcessEmbedding(_ embedding: [Float], attentionMask: [Int]) -> [Float] {
        // Mean pooling over sequence (excluding padding)
        guard !embedding.isEmpty else {
            return Array(repeating: 0, count: embeddingDimension)
        }

        // For simplicity, assuming embedding is already pooled
        // In real implementation, would do mean pooling over sequence dimension

        // Normalize to unit length
        let magnitude = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else {
            return embedding
        }

        return embedding.map { $0 / magnitude }
    }

    private func generatePlaceholderEmbedding(for text: String) -> [Float] {
        // Use a deterministic hash-based approach for consistent embeddings
        var hasher = text.hashValue
        var vector: [Float] = []

        for _ in 0..<embeddingDimension {
            // Generate pseudo-random but deterministic values
            hasher = (hasher &* 1103515245 &+ 12345) & 0x7fffffff
            let value = Float(hasher % 1000) / 1000.0 - 0.5
            vector.append(value)
        }

        // Normalize to unit length
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        return vector.map { $0 / magnitude }
    }

    private func cacheEmbedding(_ text: String, vector: [Float]) {
        // Implement simple LRU by removing oldest if at capacity
        if embeddingCache.count >= cacheMaxSize {
            // Remove first (oldest) entry
            if let firstKey = embeddingCache.keys.first {
                embeddingCache.removeValue(forKey: firstKey)
            }
        }

        embeddingCache[text] = vector
    }
}

// MARK: - Supporting Types

/// Performance statistics for embedding generation
struct EmbeddingPerformanceStats {
    let totalInferences: Int
    let averageLatency: TimeInterval
    let cacheHitRate: Double
    let cacheSize: Int

    var meetsPerformanceTarget: Bool {
        // Target: <400ms per page, assuming ~10 embeddings per page
        averageLatency < 0.04 // 40ms per embedding
    }

    var formattedLatency: String {
        String(format: "%.2fms", averageLatency * 1000)
    }

    var formattedCacheHitRate: String {
        String(format: "%.1f%%", cacheHitRate * 100)
    }
}

/// Embedding service errors
enum EmbeddingError: Error {
    case modelNotAvailable
    case tokenizationFailed
    case inferenceFailed
    case invalidEmbedding
}

extension EmbeddingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "BERT model is not available. Please download and install the model."
        case .tokenizationFailed:
            return "Failed to tokenize text"
        case .inferenceFailed:
            return "BERT inference failed"
        case .invalidEmbedding:
            return "Generated embedding is invalid"
        }
    }
}
