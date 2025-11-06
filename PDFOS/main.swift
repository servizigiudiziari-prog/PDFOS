//
//  main.swift
//  PDFOS
//
//  Main entry point for PDFOS application
//

import Foundation
import PDFOSCore

#if canImport(SwiftUI)
import SwiftUI

@main
struct PDFOSApp: App {
    // MARK: - Properties

    @StateObject private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    Task {
                        await appState.createNewDocument()
                    }
                }
                .keyboardShortcut("n")

                Button("Open...") {
                    Task {
                        await appState.openDocument()
                    }
                }
                .keyboardShortcut("o")
            }

            // Version control menu
            CommandMenu("Version Control") {
                Button("Commit Changes") {
                    Task {
                        await appState.commitCurrentDocument()
                    }
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Show History") {
                    appState.showVersionHistory = true
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Show Timeline") {
                    appState.showTimeline.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("Create Branch") {
                    Task {
                        await appState.createBranch()
                    }
                }
            }
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let document = appState.currentDocument {
                PDFEditorView(document: document)
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 100))
                .foregroundColor(.accentColor)

            Text("Welcome to PDFOS")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The Future of PDF Editing")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Button("Create New Document") {
                    Task {
                        await appState.createNewDocument()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Open Document") {
                    Task {
                        await appState.openDocument()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("Features:")
                    .font(.headline)

                HStack(spacing: 40) {
                    FeatureBadge(
                        icon: "clock.arrow.circlepath",
                        title: "Time Travel",
                        description: "Replay any change"
                    )

                    FeatureBadge(
                        icon: "brain.head.profile",
                        title: "Semantic Versioning",
                        description: "Understand changes"
                    )

                    FeatureBadge(
                        icon: "sparkles",
                        title: "Adaptive UI",
                        description: "Learns from you"
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Feature Badge

struct FeatureBadge: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150)
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var currentDocument: PDFDocument?
    @Published var showVersionHistory = false
    @Published var showTimeline = false

    private let documentService = DocumentService()

    func createNewDocument() async {
        do {
            let metadata = DocumentMetadata(
                title: "Untitled",
                author: NSFullUserName(),
                subject: nil,
                keywords: [],
                pageCount: 1,
                fileSize: 0,
                documentType: .general
            )

            let document = try await documentService.createDocument(
                at: URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("Untitled.pdf"),
                metadata: metadata
            )

            currentDocument = document
        } catch {
            print("Failed to create document: \(error)")
        }
    }

    func openDocument() async {
        // TODO: Show file picker and open document
        // For now, create a sample document
        await createNewDocument()
    }

    func commitCurrentDocument() async {
        guard let document = currentDocument else { return }

        do {
            _ = try await documentService.commit(
                document: document,
                author: NSFullUserName()
            )
        } catch {
            print("Failed to commit: \(error)")
        }
    }

    func createBranch() async {
        // TODO: Implement branch creation UI
    }
}

#else
// Non-UI entry point for testing/CLI
@main
struct PDFOSCLIApp {
    static func main() {
        print("PDFOS - PDF Operating System")
        print("Starting in CLI mode...")

        // Run basic tests
        let eventStore = EventStore()
        let versionGraph = VersionGraph()

        print("✓ Core systems initialized")
        print("Note: This is a macOS application. Please build and run on macOS with Xcode.")
    }
}
#endif
