//
//  BERTTokenizer.swift
//  PDFOS
//
//  WordPiece tokenizer for BERT
//

import Foundation

/// WordPiece tokenizer for BERT model
actor BERTTokenizer {
    // MARK: - Properties

    private let vocabURL: URL
    private var vocabulary: [String: Int] = [:]
    private var inverseVocab: [Int: String] = [:]

    // Special tokens
    private let clsToken = "[CLS]"
    private let sepToken = "[SEP]"
    private let padToken = "[PAD]"
    private let unkToken = "[UNK]"
    private let maskToken = "[MASK]"

    private let maxSequenceLength: Int

    // MARK: - Initialization

    init(vocabURL: URL? = nil, maxSequenceLength: Int = 512) {
        self.maxSequenceLength = maxSequenceLength

        // Default vocab URL
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.vocabURL = vocabURL ?? appSupport
            .appendingPathComponent("PDFOS")
            .appendingPathComponent("Models")
            .appendingPathComponent("vocab.txt")

        Task {
            await loadVocabulary()
        }
    }

    // MARK: - Public Methods

    /// Tokenizes text into BERT input format
    /// - Parameter text: The text to tokenize
    /// - Returns: Tokenization result
    func tokenize(_ text: String) async -> TokenizationResult {
        // Normalize text
        let normalized = normalizeText(text)

        // Basic tokenization (whitespace + punctuation)
        let basicTokens = basicTokenize(normalized)

        // WordPiece tokenization
        var wordPieceTokens: [String] = [clsToken]

        for token in basicTokens {
            let pieces = wordPieceTokenize(token)
            wordPieceTokens.append(contentsOf: pieces)
        }

        wordPieceTokens.append(sepToken)

        // Truncate if necessary
        if wordPieceTokens.count > maxSequenceLength {
            wordPieceTokens = Array(wordPieceTokens.prefix(maxSequenceLength - 1)) + [sepToken]
        }

        // Convert to IDs
        let tokenIds = tokensToIds(wordPieceTokens)

        // Create attention mask (1 for real tokens, 0 for padding)
        let attentionMask = Array(repeating: 1, count: tokenIds.count)

        // Pad to max length
        let paddedIds = padSequence(tokenIds)
        let paddedMask = padSequence(attentionMask)

        return TokenizationResult(
            tokens: wordPieceTokens,
            tokenIds: paddedIds,
            attentionMask: paddedMask,
            originalText: text
        )
    }

    /// Tokenizes multiple texts in batch
    /// - Parameter texts: Array of texts
    /// - Returns: Array of tokenization results
    func tokenizeBatch(_ texts: [String]) async -> [TokenizationResult] {
        var results: [TokenizationResult] = []

        for text in texts {
            let result = await tokenize(text)
            results.append(result)
        }

        return results
    }

    /// Decodes token IDs back to text
    /// - Parameter tokenIds: The token IDs
    /// - Returns: Decoded text
    func decode(_ tokenIds: [Int]) -> String {
        let tokens = tokenIds.compactMap { inverseVocab[$0] }

        // Remove special tokens
        let filtered = tokens.filter { token in
            ![clsToken, sepToken, padToken].contains(token)
        }

        // Join and clean up
        return filtered
            .joined(separator: " ")
            .replacingOccurrences(of: " ##", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Methods

    private func loadVocabulary() async {
        guard FileManager.default.fileExists(atPath: vocabURL.path) else {
            // Use minimal built-in vocabulary for development
            loadBuiltInVocabulary()
            return
        }

        do {
            let content = try String(contentsOf: vocabURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (index, token) in lines.enumerated() {
                guard !token.isEmpty else { continue }
                vocabulary[token] = index
                inverseVocab[index] = token
            }
        } catch {
            print("Failed to load vocabulary: \(error)")
            loadBuiltInVocabulary()
        }
    }

    private func loadBuiltInVocabulary() {
        // Minimal vocabulary for testing
        let specialTokens = [padToken, unkToken, clsToken, sepToken, maskToken]
        let commonWords = [
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
            "this", "that", "these", "those", "it", "its", "which", "who", "what",
            "document", "text", "page", "section", "paragraph", "clause"
        ]

        var index = 0
        for token in specialTokens + commonWords {
            vocabulary[token] = index
            inverseVocab[index] = token
            index += 1
        }
    }

    private func normalizeText(_ text: String) -> String {
        // Convert to lowercase (BERT base is uncased)
        let lowercased = text.lowercased()

        // Remove control characters
        let filtered = lowercased.filter { char in
            !char.isNewline && !char.isControl
        }

        // Normalize whitespace
        return filtered.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func basicTokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""

        for char in text {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else if char.isPunctuation {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    private func wordPieceTokenize(_ word: String) -> [String] {
        guard word.count <= 100 else {
            return [unkToken]
        }

        var tokens: [String] = []
        var start = 0

        while start < word.count {
            var end = word.count
            var foundSubword = false

            while start < end {
                let startIndex = word.index(word.startIndex, offsetBy: start)
                let endIndex = word.index(word.startIndex, offsetBy: end)
                var substr = String(word[startIndex..<endIndex])

                // Add ## prefix for non-initial subwords
                if start > 0 {
                    substr = "##" + substr
                }

                if vocabulary[substr] != nil {
                    tokens.append(substr)
                    foundSubword = true
                    start = end
                    break
                }

                end -= 1
            }

            if !foundSubword {
                tokens.append(unkToken)
                break
            }
        }

        return tokens
    }

    private func tokensToIds(_ tokens: [String]) -> [Int] {
        tokens.map { token in
            vocabulary[token] ?? vocabulary[unkToken] ?? 0
        }
    }

    private func padSequence(_ sequence: [Int]) -> [Int] {
        var padded = sequence

        while padded.count < maxSequenceLength {
            padded.append(vocabulary[padToken] ?? 0)
        }

        return padded
    }
}

// MARK: - Supporting Types

/// Result of tokenization
struct TokenizationResult {
    let tokens: [String]
    let tokenIds: [Int]
    let attentionMask: [Int]
    let originalText: String

    var length: Int {
        tokens.count
    }

    var isOverflowing: Bool {
        tokens.count >= 512
    }
}

/// Tokenization error
enum TokenizationError: Error {
    case vocabularyNotLoaded
    case textTooLong
    case invalidEncoding
}

extension TokenizationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .vocabularyNotLoaded:
            return "Vocabulary file not loaded"
        case .textTooLong:
            return "Text exceeds maximum sequence length"
        case .invalidEncoding:
            return "Invalid text encoding"
        }
    }
}

// MARK: - Vocabulary Builder

/// Builds vocabulary from corpus (for future use)
struct VocabularyBuilder {
    let minFrequency: Int
    let vocabSize: Int

    func build(from corpus: [String]) -> [String: Int] {
        // TODO: Implement vocabulary building from corpus
        // This would analyze the corpus and create a WordPiece vocabulary
        return [:]
    }

    func save(vocabulary: [String: Int], to url: URL) throws {
        let sorted = vocabulary.sorted { $0.value < $1.value }
        let lines = sorted.map { $0.key }
        let content = lines.joined(separator: "\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
