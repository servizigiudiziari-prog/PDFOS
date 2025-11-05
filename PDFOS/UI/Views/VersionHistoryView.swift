//
//  VersionHistoryView.swift
//  PDFOS
//
//  Version history and comparison view
//

#if canImport(SwiftUI)
import SwiftUI

/// View for browsing version history
struct VersionHistoryView: View {
    // MARK: - Properties

    @StateObject private var viewModel: VersionHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersion: Version?
    @State private var comparisonVersion: Version?

    // MARK: - Initialization

    init(document: PDFDocument) {
        _viewModel = StateObject(wrappedValue: VersionHistoryViewModel(document: document))
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            // Version list
            VersionListView(
                versions: viewModel.versions,
                selectedVersion: $selectedVersion,
                comparisonVersion: $comparisonVersion
            )
        } detail: {
            // Version detail
            if let selected = selectedVersion {
                VersionDetailView(
                    version: selected,
                    comparisonVersion: comparisonVersion,
                    onRestore: {
                        Task {
                            await viewModel.restore(version: selected)
                            dismiss()
                        }
                    },
                    onCreateBranch: {
                        Task {
                            await viewModel.createBranch(from: selected)
                        }
                    }
                )
            } else {
                Text("Select a version to view details")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await viewModel.loadVersions()
        }
    }
}

// MARK: - Version List View

struct VersionListView: View {
    let versions: [Version]
    @Binding var selectedVersion: Version?
    @Binding var comparisonVersion: Version?

    var body: some View {
        List(selection: $selectedVersion) {
            ForEach(versions) { version in
                VersionRowView(
                    version: version,
                    isComparison: comparisonVersion?.id == version.id
                )
                .tag(version)
                .contextMenu {
                    Button("Compare with selected") {
                        comparisonVersion = version
                    }

                    Button("Clear comparison") {
                        comparisonVersion = nil
                    }
                }
            }
        }
        .navigationTitle("Version History")
    }
}

// MARK: - Version Row View

struct VersionRowView: View {
    let version: Version
    let isComparison: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(version.message)
                    .font(.headline)

                if isComparison {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.accentColor)
                }
            }

            Text(version.author)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(version.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)

            if !version.semanticDelta.changes.isEmpty {
                Text("\(version.semanticDelta.changes.count) changes")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Version Detail View

struct VersionDetailView: View {
    let version: Version
    let comparisonVersion: Version?
    let onRestore: () -> Void
    let onCreateBranch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(version.message)
                        .font(.title)

                    Text("By \(version.author) • \(version.timestamp, style: .date)")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Restore", action: onRestore)
                    .buttonStyle(.borderedProminent)

                Button("Create Branch", action: onCreateBranch)
            }
            .padding()

            Divider()

            // Changes
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Changes")
                        .font(.headline)

                    if let comparison = comparisonVersion {
                        Text("Comparing with: \(comparison.message)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    ForEach(version.semanticDelta.changes.indices, id: \.self) { index in
                        ChangeRowView(change: version.semanticDelta.changes[index])
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Change Row View

struct ChangeRowView: View {
    let change: SemanticChange

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForChangeType(change.changeType))
                .foregroundColor(colorForChangeType(change.changeType))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(labelForChangeType(change.changeType))
                    .font(.headline)

                Text("Page \(change.location.pageIndex + 1)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if change.changeType == .modified {
                    Text("Similarity: \(String(format: "%.1f%%", change.similarity * 100))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if !change.affectedSections.isEmpty {
                    Text("Affects: \(change.affectedSections.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func iconForChangeType(_ type: SemanticChange.ChangeType) -> String {
        switch type {
        case .identical: return "equal.circle"
        case .modified: return "pencil.circle"
        case .added: return "plus.circle"
        case .removed: return "minus.circle"
        }
    }

    private func colorForChangeType(_ type: SemanticChange.ChangeType) -> Color {
        switch type {
        case .identical: return .gray
        case .modified: return .orange
        case .added: return .green
        case .removed: return .red
        }
    }

    private func labelForChangeType(_ type: SemanticChange.ChangeType) -> String {
        switch type {
        case .identical: return "Identical"
        case .modified: return "Modified"
        case .added: return "Added"
        case .removed: return "Removed"
        }
    }
}

// MARK: - Version History View Model

@MainActor
class VersionHistoryViewModel: ObservableObject {
    @Published var versions: [Version] = []
    @Published var isLoading = false

    private let document: PDFDocument
    private let documentService: DocumentService
    private let versioningService: VersioningService

    init(document: PDFDocument) {
        self.document = document
        self.documentService = DocumentService()
        self.versioningService = VersioningService()
    }

    func loadVersions() async {
        isLoading = true
        defer { isLoading = false }

        versions = await documentService.getHistory(for: document)
    }

    func restore(version: Version) async {
        // TODO: Implement version restoration
    }

    func createBranch(from version: Version) async {
        // TODO: Implement branch creation
        do {
            _ = try await versioningService.createBranch(
                from: version,
                name: "branch-\(Date().timeIntervalSince1970)"
            )
        } catch {
            print("Failed to create branch: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    let metadata = DocumentMetadata(
        title: "Sample Document",
        author: "User",
        subject: nil,
        keywords: [],
        pageCount: 10,
        fileSize: 1024000,
        documentType: .general
    )

    let delta = SemanticDelta(
        changes: [
            SemanticChange(
                changeType: .modified,
                location: DocumentLocation(pageIndex: 0),
                semanticEmbedding: [],
                similarity: 0.8,
                affectedSections: ["Introduction"]
            )
        ],
        commitMessage: "Updated introduction",
        importance: 0.7
    )

    let version = Version(
        parentIds: [],
        semanticDelta: delta,
        eventIds: [],
        author: "John Doe",
        message: "Updated introduction"
    )

    let document = PDFDocument(
        url: URL(fileURLWithPath: "/tmp/test.pdf"),
        metadata: metadata,
        currentVersion: version
    )

    return VersionHistoryView(document: document)
}
#endif
