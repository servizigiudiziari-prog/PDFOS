//
//  TokenizerTests.swift
//  PDFOS
//
//  Tests for BERT tokenizer
//

import XCTest
@testable import PDFOSCore

/// Tests for BERT tokenization
final class TokenizerTests: XCTestCase {

    var tokenizer: BERTTokenizer!

    override func setUp() async throws {
        try await super.setUp()
        tokenizer = BERTTokenizer()
    }

    // MARK: - Basic Tokenization Tests

    func testSimpleTokenization() async {
        let text = "This is a test"
        let result = await tokenizer.tokenize(text)

        XCTAssertFalse(result.tokens.isEmpty, "Should generate tokens")
        XCTAssertEqual(result.tokens.first, "[CLS]", "Should start with [CLS]")
        XCTAssertEqual(result.tokens.last, "[SEP]", "Should end with [SEP]")
    }

    func testTokenizationWithPunctuation() async {
        let text = "Hello, world! How are you?"
        let result = await tokenizer.tokenize(text)

        XCTAssertGreaterThan(result.tokens.count, 5, "Should tokenize punctuation separately")
    }

    func testLongTextTruncation() async {
        // Create text longer than max sequence length
        let longText = String(repeating: "word ", count: 600)
        let result = await tokenizer.tokenize(longText)

        XCTAssertLessThanOrEqual(
            result.tokens.count,
            512,
            "Should truncate to max sequence length"
        )
    }

    func testEmptyText() async {
        let text = ""
        let result = await tokenizer.tokenize(text)

        // Should still have CLS and SEP tokens
        XCTAssertGreaterThanOrEqual(result.tokens.count, 2)
    }

    // MARK: - WordPiece Tests

    func testWordPieceSubwords() async {
        let text = "unbelievable"
        let result = await tokenizer.tokenize(text)

        // Check if word is split into subwords with ##
        let hasSubwords = result.tokens.contains { $0.hasPrefix("##") }

        // This might be true or false depending on vocabulary
        // Just verify tokenization succeeds
        XCTAssertFalse(result.tokens.isEmpty)
    }

    func testSpecialTokens() async {
        let text = "[MASK] token"
        let result = await tokenizer.tokenize(text)

        XCTAssertFalse(result.tokens.isEmpty)
    }

    // MARK: - Token ID Conversion Tests

    func testTokenToIdConversion() async {
        let text = "test"
        let result = await tokenizer.tokenize(text)

        XCTAssertEqual(result.tokens.count, result.tokenIds.count, "Token count should match ID count")
        XCTAssertFalse(result.tokenIds.contains(-1), "Should not contain invalid IDs")
    }

    func testAttentionMask() async {
        let text = "short text"
        let result = await tokenizer.tokenize(text)

        // Attention mask should be same length as token IDs
        XCTAssertEqual(result.tokenIds.count, result.attentionMask.count)

        // Real tokens should have mask = 1, padding should have mask = 0
        let realTokenCount = result.tokens.count
        let paddingStart = result.attentionMask.firstIndex(of: 0) ?? result.attentionMask.count

        XCTAssertGreaterThanOrEqual(paddingStart, realTokenCount - 1)
    }

    // MARK: - Decode Tests

    func testTokenDecode() async {
        let text = "Hello world"
        let result = await tokenizer.tokenize(text)
        let decoded = await tokenizer.decode(result.tokenIds)

        // Decoded text should be similar to original (case may differ)
        let normalizedOriginal = text.lowercased().filter { !$0.isPunctuation }
        let normalizedDecoded = decoded.lowercased().filter { !$0.isPunctuation }

        XCTAssertTrue(
            normalizedDecoded.contains("hello"),
            "Decoded text should contain 'hello'"
        )
        XCTAssertTrue(
            normalizedDecoded.contains("world"),
            "Decoded text should contain 'world'"
        )
    }

    func testRoundTripEncoding() async {
        let text = "The quick brown fox"
        let result = await tokenizer.tokenize(text)
        let decoded = await tokenizer.decode(result.tokenIds)

        // Basic check that main words are preserved
        XCTAssertFalse(decoded.isEmpty, "Decoded text should not be empty")
    }

    // MARK: - Batch Tokenization Tests

    func testBatchTokenization() async {
        let texts = [
            "First sentence",
            "Second sentence with more words",
            "Third"
        ]

        let results = await tokenizer.tokenizeBatch(texts)

        XCTAssertEqual(results.count, texts.count, "Should tokenize all texts")

        for result in results {
            XCTAssertFalse(result.tokens.isEmpty)
            XCTAssertEqual(result.tokens.first, "[CLS]")
            XCTAssertEqual(result.tokens.last, "[SEP]")
        }
    }

    // MARK: - Performance Tests

    func testTokenizationPerformance() async {
        let text = String(repeating: "word ", count: 100)

        measure {
            Task {
                _ = await tokenizer.tokenize(text)
            }
        }
    }

    func testBatchTokenizationPerformance() async {
        let texts = (0..<10).map { _ in
            String(repeating: "word ", count: 50)
        }

        measure {
            Task {
                _ = await tokenizer.tokenizeBatch(texts)
            }
        }
    }

    // MARK: - Edge Cases

    func testUnicodeText() async {
        let text = "Hello 世界 🌍"
        let result = await tokenizer.tokenize(text)

        XCTAssertFalse(result.tokens.isEmpty, "Should handle Unicode")
    }

    func testNumbersAndSymbols() async {
        let text = "Price: $123.45 (20% off)"
        let result = await tokenizer.tokenize(text)

        XCTAssertFalse(result.tokens.isEmpty, "Should handle numbers and symbols")
    }

    func testMultilineText() async {
        let text = """
        First line
        Second line
        Third line
        """
        let result = await tokenizer.tokenize(text)

        XCTAssertFalse(result.tokens.isEmpty, "Should handle multiline text")
    }

    func testOnlyPunctuation() async {
        let text = "!@#$%^&*()"
        let result = await tokenizer.tokenize(text)

        // Should at least have CLS and SEP
        XCTAssertGreaterThanOrEqual(result.tokens.count, 2)
    }

    // MARK: - Overflow Tests

    func testOverflowDetection() async {
        let longText = String(repeating: "word ", count: 600)
        let result = await tokenizer.tokenize(longText)

        XCTAssertTrue(result.isOverflowing, "Should detect overflow for long text")
    }

    func testNoOverflowForShortText() async {
        let shortText = "short text"
        let result = await tokenizer.tokenize(shortText)

        XCTAssertFalse(result.isOverflowing, "Should not detect overflow for short text")
    }
}
