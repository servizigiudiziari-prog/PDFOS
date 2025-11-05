//
//  BERTModelManager.swift
//  PDFOS
//
//  Manages BERT model download, conversion, and loading
//

import Foundation
#if canImport(CoreML)
import CoreML
#endif

/// Manages BERT CoreML models
actor BERTModelManager {
    // MARK: - Properties

    static let shared = BERTModelManager()

    private var loadedModel: BERTModel?
    private let modelName = "bert-base-uncased"
    private let modelVersion = "v1.0"

    // Model URLs
    private let huggingFaceURL = "https://huggingface.co/bert-base-uncased"
    private let modelURL: URL
    private let cacheURL: URL

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.modelURL = appSupport
            .appendingPathComponent("PDFOS")
            .appendingPathComponent("Models")

        self.cacheURL = appSupport
            .appendingPathComponent("PDFOS")
            .appendingPathComponent("Cache")

        // Create directories
        try? FileManager.default.createDirectory(
            at: modelURL,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: cacheURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public Methods

    /// Loads or downloads the BERT model
    /// - Returns: The loaded BERT model
    func loadModel() async throws -> BERTModel {
        // Return cached model if available
        if let model = loadedModel {
            return model
        }

        // Check if model exists locally
        let modelPath = modelURL.appendingPathComponent("\(modelName).mlmodelc")

        if FileManager.default.fileExists(atPath: modelPath.path) {
            // Load existing model
            loadedModel = try await loadModelFromDisk(at: modelPath)
        } else {
            // Need to download and convert
            throw BERTModelError.modelNotFound(
                """
                BERT model not found. Please download and convert:

                1. Download BERT from Hugging Face:
                   git clone \(huggingFaceURL)

                2. Convert to CoreML:
                   python scripts/convert_bert_to_coreml.py

                3. Copy to: \(modelURL.path)

                See README.md for detailed instructions.
                """
            )
        }

        return loadedModel!
    }

    /// Checks if model is downloaded
    /// - Returns: True if model exists
    func isModelDownloaded() -> Bool {
        let modelPath = modelURL.appendingPathComponent("\(modelName).mlmodelc")
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    /// Gets model info
    /// - Returns: Model information
    func getModelInfo() -> ModelInfo {
        ModelInfo(
            name: modelName,
            version: modelVersion,
            embeddingDimension: 768,
            maxSequenceLength: 512,
            vocabSize: 30522,
            isDownloaded: isModelDownloaded()
        )
    }

    /// Unloads model from memory
    func unloadModel() {
        loadedModel = nil
    }

    // MARK: - Private Methods

    #if canImport(CoreML)
    private func loadModelFromDisk(at url: URL) async throws -> BERTModel {
        let mlModel = try MLModel(contentsOf: url)
        return BERTModel(mlModel: mlModel)
    }
    #else
    private func loadModelFromDisk(at url: URL) async throws -> BERTModel {
        throw BERTModelError.coreMLNotAvailable
    }
    #endif
}

// MARK: - BERT Model

/// Wrapper for BERT CoreML model
struct BERTModel {
    #if canImport(CoreML)
    let mlModel: MLModel

    /// Generates embeddings for tokens
    /// - Parameter tokens: Input tokens
    /// - Returns: Embedding vector
    func predict(tokens: [Int]) throws -> [Float] {
        // TODO: Implement actual CoreML prediction
        // This requires proper input/output handling based on the CoreML model

        // Placeholder: return random embeddings
        return (0..<768).map { _ in Float.random(in: -1...1) }
    }
    #endif

    /// Generates embeddings (fallback for non-CoreML platforms)
    func predict(tokens: [Int]) throws -> [Float] {
        // Deterministic hash-based embeddings as fallback
        var hasher = tokens.reduce(0) { $0 ^ $1.hashValue }
        var vector: [Float] = []

        for _ in 0..<768 {
            hasher = (hasher &* 1103515245 &+ 12345) & 0x7fffffff
            let value = Float(hasher % 1000) / 1000.0 - 0.5
            vector.append(value)
        }

        // Normalize
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        return vector.map { $0 / magnitude }
    }
}

// MARK: - Supporting Types

/// Model information
struct ModelInfo {
    let name: String
    let version: String
    let embeddingDimension: Int
    let maxSequenceLength: Int
    let vocabSize: Int
    let isDownloaded: Bool
}

/// BERT model errors
enum BERTModelError: Error {
    case modelNotFound(String)
    case downloadFailed(String)
    case conversionFailed(String)
    case coreMLNotAvailable
    case invalidModel
}

extension BERTModelError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let message):
            return "Model not found: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        case .coreMLNotAvailable:
            return "CoreML is not available on this platform"
        case .invalidModel:
            return "Invalid BERT model format"
        }
    }
}
