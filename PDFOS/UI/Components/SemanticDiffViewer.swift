//
//  SemanticDiffViewer.swift
//  PDFOS
//
//  Visual semantic diff viewer component
//

#if canImport(SwiftUI)
import SwiftUI

/// Visual diff viewer showing semantic changes between versions
struct SemanticDiffViewer: View {
    // MARK: - Properties

    let comparison: VersionComparison
    @State private var selectedChange: SemanticChange?
    @State private var filterType: ChangeFilter = .all
    @State private var groupByPage = true

    // MARK: - Body

    var body: some View {
        HSplitView {
            // Left: Change list
            changeListView
                .frame(minWidth: 300, idealWidth: 400)

            // Right: Change detail
            if let change = selectedChange {
                changeDetailView(change)
                    .frame(minWidth: 400)
            } else {
                placeholderView
            }
        }
        .toolbar {
            ToolbarItemGroup {
                filterMenu
                Divider()
                toggleGroupingButton
            }
        }
    }

    // MARK: - Change List View

    private var changeListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            changeListHeader

            Divider()

            // Changes grouped by page or type
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if groupByPage {
                        changesByPageView
                    } else {
                        changesLinearView
                    }
                }
                .padding()
            }
        }
    }

    private var changeListHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Semantic Changes")
                .font(.headline)

            HStack(spacing: 16) {
                changeStat(
                    "Added",
                    count: comparison.addedInV2.count,
                    color: .green
                )
                changeStat(
                    "Modified",
                    count: comparison.modifiedInV2.count,
                    color: .orange
                )
                changeStat(
                    "Removed",
                    count: comparison.removedInV2.count,
                    color: .red
                )
            }
        }
        .padding()
    }

    private func changeStat(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Changes by Page

    private var changesByPageView: some View {
        ForEach(groupedByPage, id: \.page) { group in
            VStack(alignment: .leading, spacing: 8) {
                // Page header
                Text("Page \(group.page + 1)")
                    .font(.headline)
                    .foregroundColor(.accentColor)

                // Changes for this page
                ForEach(group.changes.indices, id: \.self) { index in
                    changeRow(group.changes[index])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var changesLinearView: some View {
        ForEach(filteredChanges.indices, id: \.self) { index in
            changeRow(filteredChanges[index])
        }
    }

    private func changeRow(_ change: SemanticChange) -> some View {
        Button(action: {
            selectedChange = change
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Change type icon
                changeIcon(for: change.changeType)
                    .frame(width: 24)

                // Change info
                VStack(alignment: .leading, spacing: 4) {
                    Text(changeTypeLabel(change.changeType))
                        .font(.headline)
                        .foregroundColor(changeTypeColor(change.changeType))

                    Text("Page \(change.location.pageIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !change.affectedSections.isEmpty {
                        Text("Sections: \(change.affectedSections.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if change.changeType == .modified {
                        similarityBadge(change.similarity)
                    }
                }

                Spacer()

                if selectedChange?.location.pageIndex == change.location.pageIndex &&
                   selectedChange?.location.paragraphIndex == change.location.paragraphIndex {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedChange == change ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func changeIcon(for type: SemanticChange.ChangeType) -> some View {
        let (icon, color) = changeIconInfo(for: type)

        return Image(systemName: icon)
            .foregroundColor(color)
            .font(.title3)
    }

    private func changeIconInfo(for type: SemanticChange.ChangeType) -> (String, Color) {
        switch type {
        case .identical:
            return ("equal.circle", .gray)
        case .modified:
            return ("pencil.circle", .orange)
        case .added:
            return ("plus.circle", .green)
        case .removed:
            return ("minus.circle", .red)
        }
    }

    private func similarityBadge(_ similarity: Float) -> some View {
        HStack(spacing: 4) {
            Text("Similarity:")
            Text("\(Int(similarity * 100))%")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(similarityColor(similarity).opacity(0.2))
        )
        .foregroundColor(similarityColor(similarity))
    }

    private func similarityColor(_ similarity: Float) -> Color {
        if similarity > 0.9 {
            return .green
        } else if similarity > 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Change Detail View

    private func changeDetailView(_ change: SemanticChange) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Detail header
            changeDetailHeader(change)

            Divider()

            // Content comparison
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    contentSection(change)

                    if !change.affectedSections.isEmpty {
                        affectedSectionsView(change)
                    }

                    semanticSimilarityView(change)
                }
                .padding()
            }
        }
    }

    private func changeDetailHeader(_ change: SemanticChange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                changeIcon(for: change.changeType)
                Text(changeTypeLabel(change.changeType))
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Jump to Page") {
                    // TODO: Implement jump to page
                }
                .buttonStyle(.bordered)
            }

            Text("Page \(change.location.pageIndex + 1), Paragraph \(change.location.paragraphIndex ?? 0)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func contentSection(_ change: SemanticChange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content")
                .font(.headline)

            // TODO: Show actual content from document
            Text("Content preview would appear here")
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }

    private func affectedSectionsView(_ change: SemanticChange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Affected Sections")
                .font(.headline)

            ForEach(change.affectedSections, id: \.self) { section in
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.secondary)
                    Text(section)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func semanticSimilarityView(_ change: SemanticChange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Semantic Analysis")
                .font(.headline)

            if change.changeType == .modified {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Similarity Score:")
                        Spacer()
                        Text("\(Int(change.similarity * 100))%")
                            .fontWeight(.semibold)
                            .foregroundColor(similarityColor(change.similarity))
                    }

                    ProgressView(value: Double(change.similarity))
                        .tint(similarityColor(change.similarity))

                    Text(similarityExplanation(change.similarity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }

            // Embedding visualization
            Text("Embedding Vector: \(change.semanticEmbedding.count) dimensions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func similarityExplanation(_ similarity: Float) -> String {
        if similarity > 0.95 {
            return "Content is nearly identical with minor formatting changes"
        } else if similarity > 0.8 {
            return "Content has minor semantic changes"
        } else if similarity > 0.6 {
            return "Content has significant semantic changes"
        } else {
            return "Content has been substantially rewritten"
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Select a change to view details")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var filterMenu: some View {
        Menu {
            Button("All Changes") {
                filterType = .all
            }
            Button("Added Only") {
                filterType = .added
            }
            Button("Modified Only") {
                filterType = .modified
            }
            Button("Removed Only") {
                filterType = .removed
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var toggleGroupingButton: some View {
        Button(action: {
            groupByPage.toggle()
        }) {
            Label(
                groupByPage ? "Group by Page" : "Linear View",
                systemImage: groupByPage ? "square.grid.2x2" : "list.bullet"
            )
        }
    }

    // MARK: - Computed Properties

    private var filteredChanges: [SemanticChange] {
        let allChanges = comparison.addedInV2 + comparison.modifiedInV2 + comparison.removedInV2

        switch filterType {
        case .all:
            return allChanges
        case .added:
            return comparison.addedInV2
        case .modified:
            return comparison.modifiedInV2
        case .removed:
            return comparison.removedInV2
        }
    }

    private var groupedByPage: [PageGroup] {
        var groups: [Int: [SemanticChange]] = [:]

        for change in filteredChanges {
            groups[change.location.pageIndex, default: []].append(change)
        }

        return groups.map { PageGroup(page: $0.key, changes: $0.value) }
            .sorted { $0.page < $1.page }
    }

    // MARK: - Helper Methods

    private func changeTypeLabel(_ type: SemanticChange.ChangeType) -> String {
        switch type {
        case .identical: return "Identical"
        case .modified: return "Modified"
        case .added: return "Added"
        case .removed: return "Removed"
        }
    }

    private func changeTypeColor(_ type: SemanticChange.ChangeType) -> Color {
        switch type {
        case .identical: return .gray
        case .modified: return .orange
        case .added: return .green
        case .removed: return .red
        }
    }
}

// MARK: - Supporting Types

enum ChangeFilter {
    case all
    case added
    case modified
    case removed
}

struct PageGroup {
    let page: Int
    let changes: [SemanticChange]
}

// MARK: - Preview

#Preview {
    let change1 = SemanticChange(
        changeType: .modified,
        location: DocumentLocation(pageIndex: 0, paragraphIndex: 2),
        semanticEmbedding: Array(repeating: 0.5, count: 768),
        similarity: 0.85,
        affectedSections: ["Introduction", "Background"]
    )

    let change2 = SemanticChange(
        changeType: .added,
        location: DocumentLocation(pageIndex: 1, paragraphIndex: 0),
        semanticEmbedding: Array(repeating: 0.5, count: 768),
        similarity: 0.0,
        affectedSections: []
    )

    let version1 = Version(
        parentIds: [],
        semanticDelta: SemanticDelta(changes: [], commitMessage: "v1", importance: 0.5),
        eventIds: [],
        author: "user1",
        message: "Version 1"
    )

    let version2 = Version(
        parentIds: [],
        semanticDelta: SemanticDelta(changes: [], commitMessage: "v2", importance: 0.7),
        eventIds: [],
        author: "user2",
        message: "Version 2"
    )

    let comparison = VersionComparison(
        version1: version1,
        version2: version2,
        addedInV2: [change2],
        removedInV2: [],
        modifiedInV2: [change1]
    )

    return SemanticDiffViewer(comparison: comparison)
        .frame(width: 1200, height: 800)
}
#endif
