//
//  PDFTextExtractor.swift
//  PDFOS
//
//  Extracts and structures text from PDF documents
//

import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

/// Extracts structured text from PDF documents
actor PDFTextExtractor {
    // MARK: - Properties

    private let preserveFormatting: Bool
    private let detectColumns: Bool
    private let detectHeaders: Bool

    // MARK: - Initialization

    init(
        preserveFormatting: Bool = true,
        detectColumns: Bool = true,
        detectHeaders: Bool = true
    ) {
        self.preserveFormatting = preserveFormatting
        self.detectColumns = detectColumns
        self.detectHeaders = detectHeaders
    }

    // MARK: - Public Methods

    /// Extracts all text from a PDF document
    /// - Parameter document: The PDF document
    /// - Returns: Extracted document text
    func extractText(from document: PDFDocument) async throws -> DocumentText {
        #if canImport(PDFKit)
        return try await extractTextWithPDFKit(document)
        #else
        return try await extractTextFallback(document)
        #endif
    }

    /// Extracts text from a specific page
    /// - Parameters:
    ///   - document: The PDF document
    ///   - pageIndex: The page index
    /// - Returns: Extracted page text
    func extractText(from document: PDFDocument, page pageIndex: Int) async throws -> PageText {
        #if canImport(PDFKit)
        return try await extractPageWithPDFKit(document, pageIndex: pageIndex)
        #else
        return try await extractPageFallback(document, pageIndex: pageIndex)
        #endif
    }

    /// Extracts structured content (paragraphs, sections, etc.)
    /// - Parameter document: The PDF document
    /// - Returns: Structured content
    func extractStructuredContent(from document: PDFDocument) async throws -> [ContentBlock] {
        let documentText = try await extractText(from: document)

        var blocks: [ContentBlock] = []

        for (pageIndex, page) in documentText.pages.enumerated() {
            let pageBlocks = try await analyzePageStructure(page, pageIndex: pageIndex)
            blocks.append(contentsOf: pageBlocks)
        }

        return blocks
    }

    // MARK: - Private Methods (PDFKit)

    #if canImport(PDFKit)
    private func extractTextWithPDFKit(_ document: PDFDocument) async throws -> DocumentText {
        var pages: [PageText] = []

        for pageIndex in 0..<document.metadata.pageCount {
            let page = try await extractPageWithPDFKit(document, pageIndex: pageIndex)
            pages.append(page)
        }

        return DocumentText(
            documentId: document.id,
            pages: pages,
            metadata: document.metadata
        )
    }

    private func extractPageWithPDFKit(_ document: PDFDocument, pageIndex: Int) async throws -> PageText {
        // TODO: Implement actual PDFKit text extraction
        // This would use PDFPage.string or PDFPage.attributedString

        // For now, return placeholder
        return PageText(
            pageIndex: pageIndex,
            text: "Page \(pageIndex + 1) content",
            paragraphs: [],
            boundingBox: CGRect(x: 0, y: 0, width: 612, height: 792)
        )
    }
    #endif

    // MARK: - Fallback Methods

    private func extractTextFallback(_ document: PDFDocument) async throws -> DocumentText {
        // Fallback for non-macOS platforms
        var pages: [PageText] = []

        for pageIndex in 0..<document.metadata.pageCount {
            let page = try await extractPageFallback(document, pageIndex: pageIndex)
            pages.append(page)
        }

        return DocumentText(
            documentId: document.id,
            pages: pages,
            metadata: document.metadata
        )
    }

    private func extractPageFallback(_ document: PDFDocument, pageIndex: Int) async throws -> PageText {
        // Placeholder extraction for testing/development
        return PageText(
            pageIndex: pageIndex,
            text: "Placeholder text for page \(pageIndex + 1)",
            paragraphs: [
                Paragraph(
                    text: "Placeholder paragraph",
                    range: NSRange(location: 0, length: 21),
                    boundingBox: CGRect(x: 72, y: 72, width: 468, height: 100)
                )
            ],
            boundingBox: CGRect(x: 0, y: 0, width: 612, height: 792)
        )
    }

    // MARK: - Structure Analysis

    private func analyzePageStructure(_ page: PageText, pageIndex: Int) async throws -> [ContentBlock] {
        var blocks: [ContentBlock] = []

        // Split text into paragraphs
        let paragraphTexts = page.text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for (index, paragraphText) in paragraphTexts.enumerated() {
            let block = ContentBlock(
                id: UUID(),
                type: classifyContent(paragraphText),
                text: paragraphText,
                pageIndex: pageIndex,
                blockIndex: index,
                metadata: BlockMetadata(
                    fontSize: nil,
                    fontName: nil,
                    isBold: detectBold(paragraphText),
                    isItalic: false
                )
            )
            blocks.append(block)
        }

        return blocks
    }

    private func classifyContent(_ text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Detect headers (short, potentially all caps or title case)
        if trimmed.count < 100 && (trimmed.uppercased() == trimmed || detectTitleCase(trimmed)) {
            return .header
        }

        // Detect lists
        if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
            return .listItem
        }

        // Check for numbered lists
        if trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil {
            return .numberedListItem
        }

        // Default to paragraph
        return .paragraph
    }

    private func detectBold(_ text: String) -> Bool {
        // In real implementation, this would check font attributes
        // For now, check for all caps or specific markers
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count < 50 && trimmed.uppercased() == trimmed
    }

    private func detectTitleCase(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespaces)
        let capitalizedWords = words.filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase
        }
        return Double(capitalizedWords.count) / Double(words.count) > 0.6
    }
}

// MARK: - Supporting Types

/// Represents extracted document text
struct DocumentText {
    let documentId: UUID
    let pages: [PageText]
    let metadata: DocumentMetadata
}

/// Represents text from a single page
struct PageText {
    let pageIndex: Int
    let text: String
    let paragraphs: [Paragraph]
    let boundingBox: CGRect
}

/// Represents a paragraph of text
struct Paragraph {
    let text: String
    let range: NSRange
    let boundingBox: CGRect
}

/// Represents a structured content block
struct ContentBlock: Identifiable {
    let id: UUID
    let type: ContentType
    let text: String
    let pageIndex: Int
    let blockIndex: Int
    let metadata: BlockMetadata
}

/// Content type classification
enum ContentType {
    case header
    case subheader
    case paragraph
    case listItem
    case numberedListItem
    case quote
    case code
    case table
    case footer
}

/// Metadata about a content block
struct BlockMetadata {
    let fontSize: Float?
    let fontName: String?
    let isBold: Bool
    let isItalic: Bool
}

/// CGRect for cross-platform compatibility
#if !canImport(CoreGraphics)
struct CGRect {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
#endif

/// NSRange for cross-platform compatibility
#if !canImport(Foundation.NSRange)
struct NSRange {
    let location: Int
    let length: Int
}
#endif
