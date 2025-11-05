//
//  ConflictResolverView.swift
//  PDFOS
//
//  UI for resolving merge conflicts
//

#if canImport(SwiftUI)
import SwiftUI

/// Interactive conflict resolution interface
struct ConflictResolverView: View {
    // MARK: - Properties

    let conflicts: [MergeConflict]
    @State private var selectedConflict: MergeConflict?
    @State private var resolutions: [UUID: ConflictResolution] = [:]
    @State private var currentIndex = 0

    let onResolve: ([UUID: ConflictResolution]) -> Void
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            conflictHeader

            Divider()

            // Main content
            HSplitView {
                // Left: Conflict list
                conflictListView
                    .frame(minWidth: 250, idealWidth: 300)

                // Right: Resolution interface
                if let conflict = selectedConflict {
                    conflictResolutionView(conflict)
                        .frame(minWidth: 600)
                } else {
                    placeholderView
                }
            }

            Divider()

            // Footer with actions
            conflictFooter
        }
        .onAppear {
            if !conflicts.isEmpty {
                selectedConflict = conflicts[0]
            }
        }
    }

    // MARK: - Header

    private var conflictHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)

                Text("Merge Conflicts Detected")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text("\(resolvedCount)/\(conflicts.count) Resolved")
                    .foregroundColor(.secondary)
            }

            Text("Review and resolve each conflict to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: Double(resolvedCount), total: Double(conflicts.count))
        }
        .padding()
    }

    // MARK: - Conflict List

    private var conflictListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(conflicts) { conflict in
                    conflictListItem(conflict)
                }
            }
            .padding()
        }
    }

    private func conflictListItem(_ conflict: MergeConflict) -> some View {
        Button(action: {
            selectedConflict = conflict
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator
                conflictStatusIcon(conflict)

                // Conflict info
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.conflictType.label)
                        .font(.headline)

                    Text("Page \(conflict.location.pageIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if isResolved(conflict) {
                        Text("✓ Resolved")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                if selectedConflict?.id == conflict.id {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedConflict?.id == conflict.id ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isResolved(conflict) ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func conflictStatusIcon(_ conflict: MergeConflict) -> some View {
        ZStack {
            Circle()
                .fill(isResolved(conflict) ? Color.green : Color.orange)
                .frame(width: 32, height: 32)

            Image(systemName: isResolved(conflict) ? "checkmark" : "exclamationmark")
                .foregroundColor(.white)
                .font(.caption)
        }
    }

    // MARK: - Resolution View

    private func conflictResolutionView(_ conflict: MergeConflict) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Conflict details
            conflictDetailHeader(conflict)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    conflictDescription(conflict)

                    // Three-way comparison
                    threeWayComparisonView(conflict)

                    // Resolution options
                    resolutionOptions(conflict)
                }
                .padding()
            }
        }
    }

    private func conflictDetailHeader(_ conflict: MergeConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(conflict.conflictType.label)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                navigationButtons
            }

            Text(conflict.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var navigationButtons: some View {
        HStack(spacing: 8) {
            Button(action: previousConflict) {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(currentIndex == 0)

            Button(action: nextConflict) {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(currentIndex >= conflicts.count - 1)
        }
    }

    private func conflictDescription(_ conflict: MergeConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conflict Type")
                .font(.headline)

            HStack {
                Image(systemName: conflict.conflictType.icon)
                    .foregroundColor(.orange)

                Text(conflict.conflictType.description)
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func threeWayComparisonView(_ conflict: MergeConflict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare Versions")
                .font(.headline)

            HStack(spacing: 12) {
                // Current version
                versionPanel(
                    title: "Your Version",
                    version: conflict.currentVersion,
                    color: .blue
                )

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.secondary)

                // Incoming version
                versionPanel(
                    title: "Incoming Version",
                    version: conflict.incomingVersion,
                    color: .purple
                )
            }
        }
    }

    private func versionPanel(title: String, version: Version, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(version.message)
                    .font(.body)
                    .lineLimit(2)

                Text("By \(version.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(version.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(version.semanticDelta.changes.count) changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func resolutionOptions(_ conflict: MergeConflict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolution")
                .font(.headline)

            VStack(spacing: 12) {
                // Use current version
                resolutionButton(
                    title: "Keep Your Version",
                    description: "Use your changes and discard incoming",
                    icon: "arrow.left",
                    color: .blue,
                    isSelected: resolutions[conflict.id] == .useCurrentVersion
                ) {
                    resolutions[conflict.id] = .useCurrentVersion
                }

                // Use incoming version
                resolutionButton(
                    title: "Accept Incoming Version",
                    description: "Discard your changes and use incoming",
                    icon: "arrow.right",
                    color: .purple,
                    isSelected: resolutions[conflict.id] == .useIncomingVersion
                ) {
                    resolutions[conflict.id] = .useIncomingVersion
                }

                // Custom resolution
                resolutionButton(
                    title: "Create Custom Resolution",
                    description: "Manually merge both changes",
                    icon: "arrow.triangle.merge",
                    color: .orange,
                    isSelected: isCustomResolution(conflict)
                ) {
                    // TODO: Open custom resolution editor
                }
            }
        }
    }

    private func resolutionButton(
        title: String,
        description: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Select a conflict to resolve")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var conflictFooter: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Spacer()

            if allResolved {
                Button("Apply Resolutions") {
                    onResolve(resolutions)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Text("\(conflicts.count - resolvedCount) conflicts remaining")
                    .foregroundColor(.secondary)

                Button("Resolve All with Current Version") {
                    resolveAllWithCurrent()
                }
            }
        }
        .padding()
    }

    // MARK: - Helper Methods

    private var resolvedCount: Int {
        resolutions.count
    }

    private var allResolved: Bool {
        resolvedCount == conflicts.count
    }

    private func isResolved(_ conflict: MergeConflict) -> Bool {
        resolutions[conflict.id] != nil
    }

    private func isCustomResolution(_ conflict: MergeConflict) -> Bool {
        if case .custom = resolutions[conflict.id] {
            return true
        }
        return false
    }

    private func nextConflict() {
        if currentIndex < conflicts.count - 1 {
            currentIndex += 1
            selectedConflict = conflicts[currentIndex]
        }
    }

    private func previousConflict() {
        if currentIndex > 0 {
            currentIndex -= 1
            selectedConflict = conflicts[currentIndex]
        }
    }

    private func resolveAllWithCurrent() {
        for conflict in conflicts {
            if resolutions[conflict.id] == nil {
                resolutions[conflict.id] = .useCurrentVersion
            }
        }
    }
}

// MARK: - Conflict Type Extensions

extension MergeConflict.ConflictType {
    var label: String {
        switch self {
        case .semanticConflict:
            return "Semantic Conflict"
        case .structuralConflict:
            return "Structural Conflict"
        case .dependencyConflict:
            return "Dependency Conflict"
        }
    }

    var icon: String {
        switch self {
        case .semanticConflict:
            return "brain"
        case .structuralConflict:
            return "square.grid.2x2"
        case .dependencyConflict:
            return "link"
        }
    }

    var description: String {
        switch self {
        case .semanticConflict:
            return "The semantic meaning of this section conflicts between versions"
        case .structuralConflict:
            return "The document structure has changed in conflicting ways"
        case .dependencyConflict:
            return "This change depends on other conflicting changes"
        }
    }
}

// MARK: - Preview

#Preview {
    let conflict = MergeConflict(
        location: DocumentLocation(pageIndex: 0),
        currentVersion: Version(
            parentIds: [],
            semanticDelta: SemanticDelta(changes: [], commitMessage: "v1", importance: 0.5),
            eventIds: [],
            author: "Alice",
            message: "Updated introduction"
        ),
        incomingVersion: Version(
            parentIds: [],
            semanticDelta: SemanticDelta(changes: [], commitMessage: "v2", importance: 0.7),
            eventIds: [],
            author: "Bob",
            message: "Rewrote introduction"
        ),
        conflictType: .semanticConflict,
        description: "Both versions modified the introduction section"
    )

    return ConflictResolverView(
        conflicts: [conflict],
        onResolve: { _ in },
        onCancel: {}
    )
    .frame(width: 1200, height: 800)
}
#endif
