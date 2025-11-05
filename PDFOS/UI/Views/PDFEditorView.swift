//
//  PDFEditorView.swift
//  PDFOS
//
//  Main PDF editor view with adaptive UI
//

#if canImport(SwiftUI)
import SwiftUI

/// Main PDF editor view
struct PDFEditorView: View {
    // MARK: - Properties

    @StateObject private var viewModel: PDFEditorViewModel
    @State private var selectedTool: Tool = .select
    @State private var showTimeline = false
    @State private var showVersionHistory = false

    // MARK: - Initialization

    init(document: PDFDocument) {
        _viewModel = StateObject(wrappedValue: PDFEditorViewModel(document: document))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EditorToolbar(
                selectedTool: $selectedTool,
                complexity: viewModel.uiComplexity,
                onCommit: {
                    Task {
                        await viewModel.commit()
                    }
                },
                onShowTimeline: {
                    showTimeline.toggle()
                },
                onShowHistory: {
                    showVersionHistory.toggle()
                }
            )

            // Main content
            HStack(spacing: 0) {
                // Document view
                DocumentCanvasView(
                    document: viewModel.document,
                    selectedTool: selectedTool
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Side panel (conditional based on UI complexity)
                if viewModel.uiComplexity != .minimal {
                    Divider()

                    SidePanel(
                        document: viewModel.document,
                        statistics: viewModel.statistics,
                        complexity: viewModel.uiComplexity
                    )
                    .frame(width: 300)
                }
            }

            // Timeline (overlay)
            if showTimeline {
                TimelineView(document: viewModel.document)
                    .frame(height: 200)
                    .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showVersionHistory) {
            VersionHistoryView(document: viewModel.document)
        }
    }
}

// MARK: - Editor Toolbar

struct EditorToolbar: View {
    @Binding var selectedTool: Tool
    let complexity: UIComplexity
    let onCommit: () -> Void
    let onShowTimeline: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        HStack {
            // Basic tools (always visible)
            basicTools

            Spacer()

            // Advanced tools (based on complexity)
            if complexity == .editing || complexity == .power {
                editingTools
            }

            if complexity == .power {
                powerTools
            }

            Spacer()

            // Action buttons
            Button("Timeline") {
                onShowTimeline()
            }

            Button("History") {
                onShowHistory()
            }

            Button("Commit") {
                onCommit()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var basicTools: some View {
        HStack {
            ToolButton(tool: .select, selectedTool: $selectedTool)
            ToolButton(tool: .hand, selectedTool: $selectedTool)
        }
    }

    private var editingTools: some View {
        HStack {
            ToolButton(tool: .text, selectedTool: $selectedTool)
            ToolButton(tool: .highlight, selectedTool: $selectedTool)
            ToolButton(tool: .annotate, selectedTool: $selectedTool)
        }
    }

    private var powerTools: some View {
        HStack {
            ToolButton(tool: .shape, selectedTool: $selectedTool)
            ToolButton(tool: .image, selectedTool: $selectedTool)
            ToolButton(tool: .form, selectedTool: $selectedTool)
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: Tool
    @Binding var selectedTool: Tool

    var body: some View {
        Button(action: {
            selectedTool = tool
        }) {
            Image(systemName: tool.iconName)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .background(selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Document Canvas

struct DocumentCanvasView: View {
    let document: PDFDocument
    let selectedTool: Tool

    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)

            // TODO: Implement actual PDF rendering with PDFKit
            Text("PDF Document: \(document.metadata.title)")
                .font(.title)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Side Panel

struct SidePanel: View {
    let document: PDFDocument
    let statistics: DocumentStatistics?
    let complexity: UIComplexity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Document Info")
                .font(.headline)

            if let stats = statistics {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Pages", value: "\(document.metadata.pageCount)")
                    InfoRow(label: "Versions", value: "\(stats.versionCount)")
                    InfoRow(label: "Events", value: "\(stats.eventCount)")
                    InfoRow(label: "Authors", value: "\(stats.authors.count)")
                }
            }

            Divider()

            if complexity == .power {
                Text("Recent Activity")
                    .font(.headline)

                // TODO: Show recent events
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Tool Enum

enum Tool {
    case select
    case hand
    case text
    case highlight
    case annotate
    case shape
    case image
    case form

    var iconName: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .hand: return "hand.raised"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .annotate: return "note.text"
        case .shape: return "square.on.circle"
        case .image: return "photo"
        case .form: return "doc.text"
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
        changes: [],
        commitMessage: "Initial",
        importance: 0
    )

    let version = Version(
        parentIds: [],
        semanticDelta: delta,
        eventIds: [],
        author: "system",
        message: "Initial"
    )

    let document = PDFDocument(
        url: URL(fileURLWithPath: "/tmp/test.pdf"),
        metadata: metadata,
        currentVersion: version
    )

    return PDFEditorView(document: document)
        .frame(width: 1200, height: 800)
}
#endif
