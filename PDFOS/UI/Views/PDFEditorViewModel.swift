//
//  PDFEditorViewModel.swift
//  PDFOS
//
//  View model for PDF editor
//

import Foundation
#if canImport(Combine)
import Combine
#endif

/// View model for PDF editor
@MainActor
class PDFEditorViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var document: PDFDocument
    @Published var uiComplexity: UIComplexity = .editing
    @Published var statistics: DocumentStatistics?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let documentService: DocumentService
    private let versioningService: VersioningService

    // MARK: - Initialization

    init(document: PDFDocument) {
        self.document = document
        self.documentService = DocumentService()
        self.versioningService = VersioningService()

        Task {
            await loadStatistics()
        }
    }

    // MARK: - Public Methods

    /// Commits current changes
    func commit(message: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let version = try await documentService.commit(
                document: document,
                author: "current_user", // TODO: Get from user session
                message: message
            )

            // Update document
            if let updatedDoc = await documentService.getDocument(document.id) {
                document = updatedDoc
            }

            await loadStatistics()
        } catch {
            errorMessage = "Failed to commit: \(error.localizedDescription)"
        }
    }

    /// Loads document statistics
    func loadStatistics() async {
        statistics = await documentService.getStatistics(for: document)
    }

    /// Updates UI complexity
    func updateComplexity(_ complexity: UIComplexity) {
        uiComplexity = complexity
    }

    /// Performs time travel
    func timeTravel(to date: Date) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let historicalDoc = try await versioningService.timeTravel(
                to: date,
                document: document
            )
            document = historicalDoc
        } catch {
            errorMessage = "Time travel failed: \(error.localizedDescription)"
        }
    }
}
