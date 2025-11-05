//
//  PDFVersionControl.swift
//  PDFOS
//
//  Version control system for PDF documents using semantic versioning
//

import Foundation
import CryptoKit

/// Version control manager for PDF documents
actor PDFVersionControl {
    // MARK: - Properties

    private let eventStore: EventStore
    private let versionGraph: VersionGraph
    private let semanticAnalyzer: PDFSemanticAnalyzer

    // MARK: - Initialization

    init(
        eventStore: EventStore,
        versionGraph: VersionGraph,
        semanticAnalyzer: PDFSemanticAnalyzer
    ) {
        self.eventStore = eventStore
        self.versionGraph = versionGraph
        self.semanticAnalyzer = semanticAnalyzer
    }

    // MARK: - Public Methods

    /// Commits changes to a document
    /// - Parameters:
    ///   - document: The modified document
    ///   - semanticDelta: The semantic changes
    ///   - author: The author of the changes
    ///   - message: Optional commit message (auto-generated if nil)
    /// - Returns: The new version
    func commit(
        document: PDFDocument,
        semanticDelta: SemanticDelta,
        author: String,
        message: String? = nil
    ) async throws -> Version {
        // 1. Generate semantic hash
        let semanticHash = calculateSemanticHash(semanticDelta)

        // 2. Get current version as parent
        let parentIds = [document.currentVersion.id]

        // 3. Use provided message or auto-generated one
        let commitMessage = message ?? semanticDelta.commitMessage

        // 4. Create new version
        let version = Version(
            parentIds: parentIds,
            semanticDelta: semanticDelta,
            eventIds: [], // Events will be added by event store
            author: author,
            message: commitMessage
        )

        // 5. Update version graph
        await versionGraph.addVersion(version)

        // 6. Trigger sync (placeholder for CloudKit)
        // await syncToCloud(version)

        return version
    }

    /// Merges two branches
    /// - Parameters:
    ///   - branch1: The first version to merge
    ///   - branch2: The second version to merge
    /// - Returns: The merge result
    func merge(
        branch1: Version,
        branch2: Version
    ) async throws -> MergeResult {
        // 1. Find common ancestor
        guard let commonAncestor = await versionGraph.findCommonAncestor(
            version1: branch1.id,
            version2: branch2.id
        ) else {
            return .failure(VersionControlError.noCommonAncestor)
        }

        // 2. Get semantic deltas for both branches
        let delta1 = branch1.semanticDelta
        let delta2 = branch2.semanticDelta

        // 3. Identify conflicts
        let conflicts = identifySemanticConflicts(
            delta1: delta1,
            delta2: delta2,
            version1: branch1,
            version2: branch2
        )

        // 4. If no conflicts, create merge version
        if conflicts.isEmpty {
            let mergedDelta = try await mergeDeltas(delta1, delta2)
            let mergeVersion = Version(
                parentIds: [branch1.id, branch2.id],
                semanticDelta: mergedDelta,
                eventIds: branch1.eventIds + branch2.eventIds,
                author: "system",
                message: "Merged '\(branch1.message)' with '\(branch2.message)'"
            )

            await versionGraph.addVersion(mergeVersion)
            return .success(mergeVersion)
        } else {
            return .conflict(conflicts)
        }
    }

    /// Gets the complete version history
    /// - Parameter document: The document
    /// - Returns: Array of versions in chronological order
    func getHistory(for document: PDFDocument) async -> [Version] {
        await versionGraph.getHistory(from: document.currentVersion.id)
    }

    /// Creates a new branch from a version
    /// - Parameters:
    ///   - version: The version to branch from
    ///   - name: The branch name
    /// - Returns: The branch reference
    func createBranch(from version: Version, name: String) async throws -> Branch {
        let branch = Branch(
            id: UUID(),
            name: name,
            headVersion: version.id,
            createdAt: Date()
        )

        await versionGraph.addBranch(branch)
        return branch
    }

    // MARK: - Private Methods

    /// Calculates a semantic hash for a delta
    private func calculateSemanticHash(_ delta: SemanticDelta) -> String {
        // Create a deterministic representation of semantic changes
        var hashContent = ""

        for change in delta.changes.sorted(by: { $0.location.pageIndex < $1.location.pageIndex }) {
            hashContent += "\(change.changeType.rawValue):"
            hashContent += "\(change.location.pageIndex):"
            hashContent += "\(change.similarity):"
        }

        // Calculate SHA-256 hash
        let data = Data(hashContent.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Identifies semantic conflicts between two deltas
    private func identifySemanticConflicts(
        delta1: SemanticDelta,
        delta2: SemanticDelta,
        version1: Version,
        version2: Version
    ) -> [MergeConflict] {
        var conflicts: [MergeConflict] = []

        // Check for overlapping changes
        for change1 in delta1.changes {
            for change2 in delta2.changes {
                if locationsOverlap(change1.location, change2.location) {
                    // Check if they're semantically conflicting
                    let similarity = cosineSimilarity(
                        change1.semanticEmbedding,
                        change2.semanticEmbedding
                    )

                    // If similarity is low, it's a real conflict
                    if similarity < 0.7 {
                        let conflict = MergeConflict(
                            location: change1.location,
                            currentVersion: version1,
                            incomingVersion: version2,
                            conflictType: .semanticConflict,
                            description: "Conflicting changes at page \(change1.location.pageIndex)"
                        )
                        conflicts.append(conflict)
                    }
                }
            }
        }

        return conflicts
    }

    /// Checks if two document locations overlap
    private func locationsOverlap(_ loc1: DocumentLocation, _ loc2: DocumentLocation) -> Bool {
        // Same page and overlapping paragraphs/ranges
        guard loc1.pageIndex == loc2.pageIndex else { return false }

        // Check paragraph overlap
        if let p1 = loc1.paragraphIndex, let p2 = loc2.paragraphIndex {
            return p1 == p2
        }

        return true
    }

    /// Merges two semantic deltas
    private func mergeDeltas(
        _ delta1: SemanticDelta,
        _ delta2: SemanticDelta
    ) async throws -> SemanticDelta {
        // Combine changes from both deltas
        var mergedChanges = delta1.changes

        // Add non-conflicting changes from delta2
        for change2 in delta2.changes {
            let conflicts = mergedChanges.filter { change1 in
                locationsOverlap(change1.location, change2.location)
            }

            if conflicts.isEmpty {
                mergedChanges.append(change2)
            }
        }

        // Calculate combined importance
        let combinedImportance = (delta1.importance + delta2.importance) / 2

        return SemanticDelta(
            changes: mergedChanges,
            commitMessage: "Merged changes",
            importance: combinedImportance
        )
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}

// MARK: - Supporting Types

/// Represents a branch in the version graph
struct Branch: Identifiable, Codable {
    let id: UUID
    let name: String
    let headVersion: UUID
    let createdAt: Date
}

/// Errors that can occur during version control operations
enum VersionControlError: Error {
    case noCommonAncestor
    case invalidVersion
    case mergeConflict
    case branchAlreadyExists
}
