//
//  DocumentService.swift
//  PDFOS
//
//  Service layer for PDF document operations
//

import Foundation

/// Main service for PDF document management
actor DocumentService {
    // MARK: - Properties

    private let eventStore: EventStore
    private let versionControl: PDFVersionControl
    private let semanticAnalyzer: PDFSemanticAnalyzer
    private var openDocuments: [UUID: PDFDocument] = [:]

    // MARK: - Initialization

    init() {
        self.eventStore = EventStore()
        let versionGraph = VersionGraph()
        let embeddingService = SemanticEmbeddingService()
        self.semanticAnalyzer = PDFSemanticAnalyzer(embeddingService: embeddingService)
        self.versionControl = PDFVersionControl(
            eventStore: eventStore,
            versionGraph: versionGraph,
            semanticAnalyzer: semanticAnalyzer
        )
    }

    // MARK: - Document Management

    /// Opens a PDF document
    /// - Parameter url: The URL of the PDF file
    /// - Returns: The opened document
    func openDocument(at url: URL) async throws -> PDFDocument {
        // Check if already open
        if let existing = openDocuments.values.first(where: { $0.url == url }) {
            return existing
        }

        // Load document
        let document = try await loadDocument(from: url)

        // Load event history
        try await eventStore.loadEvents(documentId: document.id)

        // Cache in open documents
        openDocuments[document.id] = document

        return document
    }

    /// Creates a new PDF document
    /// - Parameters:
    ///   - url: The URL where the document will be saved
    ///   - metadata: Document metadata
    /// - Returns: The new document
    func createDocument(at url: URL, metadata: DocumentMetadata) async throws -> PDFDocument {
        // Create initial version
        let initialDelta = SemanticDelta(
            changes: [],
            commitMessage: "Initial commit",
            importance: 0.0
        )

        let initialVersion = Version(
            parentIds: [],
            semanticDelta: initialDelta,
            eventIds: [],
            author: "system",
            message: "Initial commit"
        )

        let document = PDFDocument(
            url: url,
            metadata: metadata,
            currentVersion: initialVersion
        )

        // Cache in open documents
        openDocuments[document.id] = document

        return document
    }

    /// Saves a document
    /// - Parameter document: The document to save
    func saveDocument(_ document: PDFDocument) async throws {
        // TODO: Implement actual PDF writing with PDFKit
        // For now, just update the cache
        openDocuments[document.id] = document
    }

    /// Closes a document
    /// - Parameter documentId: The document ID
    func closeDocument(_ documentId: UUID) async {
        openDocuments.removeValue(forKey: documentId)
    }

    /// Gets an open document
    /// - Parameter id: The document ID
    /// - Returns: The document, if open
    func getDocument(_ id: UUID) async -> PDFDocument? {
        openDocuments[id]
    }

    // MARK: - Editing Operations

    /// Records a text edit
    /// - Parameters:
    ///   - document: The document
    ///   - text: The new text
    ///   - location: The location of the edit
    ///   - userId: The user making the edit
    func editText(
        in document: PDFDocument,
        text: String,
        at location: DocumentLocation,
        userId: String
    ) async throws {
        let payload = try JSONEncoder().encode(TextEditPayload(text: text, location: location))

        let event = PDFEvent(
            type: .textEdit,
            payload: payload,
            userId: userId,
            semanticHash: ""
        )

        await eventStore.recordEvent(event, documentId: document.id)
    }

    /// Records an image insertion
    /// - Parameters:
    ///   - document: The document
    ///   - imageData: The image data
    ///   - location: The location for the image
    ///   - userId: The user making the edit
    func insertImage(
        in document: PDFDocument,
        imageData: Data,
        at location: DocumentLocation,
        userId: String
    ) async throws {
        let payload = try JSONEncoder().encode(ImageInsertPayload(imageData: imageData, location: location))

        let event = PDFEvent(
            type: .imageInsert,
            payload: payload,
            userId: userId,
            semanticHash: ""
        )

        await eventStore.recordEvent(event, documentId: document.id)
    }

    // MARK: - Version Control Operations

    /// Commits current changes
    /// - Parameters:
    ///   - document: The document
    ///   - author: The author
    ///   - message: Optional commit message
    /// - Returns: The new version
    func commit(
        document: PDFDocument,
        author: String,
        message: String? = nil
    ) async throws -> Version {
        // Analyze changes since last commit
        // For now, create a simple delta
        let delta = SemanticDelta(
            changes: [],
            commitMessage: message ?? "Update",
            importance: 0.5
        )

        let version = try await versionControl.commit(
            document: document,
            semanticDelta: delta,
            author: author,
            message: message
        )

        // Update document's current version
        var updatedDocument = document
        updatedDocument.currentVersion = version
        openDocuments[document.id] = updatedDocument

        return version
    }

    /// Gets version history
    /// - Parameter document: The document
    /// - Returns: Array of versions
    func getHistory(for document: PDFDocument) async -> [Version] {
        await versionControl.getHistory(for: document)
    }

    /// Merges two versions
    /// - Parameters:
    ///   - branch1: First version
    ///   - branch2: Second version
    /// - Returns: Merge result
    func merge(
        branch1: Version,
        branch2: Version
    ) async throws -> MergeResult {
        try await versionControl.merge(branch1: branch1, branch2: branch2)
    }

    // MARK: - Analytics

    /// Gets document statistics
    /// - Parameter document: The document
    /// - Returns: Document statistics
    func getStatistics(for document: PDFDocument) async -> DocumentStatistics {
        let eventStats = await eventStore.getStatistics(documentId: document.id)
        let versions = await versionControl.getHistory(for: document)

        return DocumentStatistics(
            eventCount: eventStats.totalEvents,
            versionCount: versions.count,
            lastModified: document.modifiedAt,
            createdAt: document.createdAt,
            authors: Set(versions.map { $0.author })
        )
    }

    // MARK: - Private Methods

    private func loadDocument(from url: URL) async throws -> PDFDocument {
        // TODO: Load actual PDF with PDFKit
        // For now, create a placeholder

        let metadata = DocumentMetadata(
            title: url.lastPathComponent,
            author: nil,
            subject: nil,
            keywords: [],
            pageCount: 1,
            fileSize: 0,
            documentType: .general
        )

        let initialDelta = SemanticDelta(
            changes: [],
            commitMessage: "Loaded document",
            importance: 0.0
        )

        let initialVersion = Version(
            parentIds: [],
            semanticDelta: initialDelta,
            eventIds: [],
            author: "system",
            message: "Loaded document"
        )

        return PDFDocument(
            url: url,
            metadata: metadata,
            currentVersion: initialVersion
        )
    }
}

// MARK: - Supporting Types

/// Payload for text edit events
struct TextEditPayload: Codable {
    let text: String
    let location: DocumentLocation
}

/// Payload for image insert events
struct ImageInsertPayload: Codable {
    let imageData: Data
    let location: DocumentLocation
}

/// Document statistics
struct DocumentStatistics {
    let eventCount: Int
    let versionCount: Int
    let lastModified: Date
    let createdAt: Date
    let authors: Set<String>
}
