//
//  VersionGraph.swift
//  PDFOS
//
//  Graph-based version control system
//

import Foundation

/// Manages the version graph using a directed acyclic graph (DAG)
actor VersionGraph {
    // MARK: - Properties

    private var versions: [UUID: Version] = [:]
    private var branches: [String: Branch] = [:]
    private var edges: [UUID: Set<UUID>] = [:] // parent -> children
    private let storageURL: URL

    // MARK: - Initialization

    init(storageURL: URL? = nil) {
        let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PDFOS")
            .appendingPathComponent("VersionGraph")

        self.storageURL = storageURL ?? defaultURL ?? FileManager.default.temporaryDirectory

        try? FileManager.default.createDirectory(at: self.storageURL, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Adds a new version to the graph
    /// - Parameter version: The version to add
    func addVersion(_ version: Version) async {
        versions[version.id] = version

        // Update edges
        for parentId in version.parentIds {
            edges[parentId, default: []].insert(version.id)
        }

        // Persist to disk
        await persistVersion(version)
    }

    /// Gets a version by ID
    /// - Parameter id: The version ID
    /// - Returns: The version, if found
    func getVersion(_ id: UUID) async -> Version? {
        versions[id]
    }

    /// Gets the complete history from a version
    /// - Parameter versionId: The starting version ID
    /// - Returns: Array of versions in chronological order
    func getHistory(from versionId: UUID) async -> [Version] {
        var history: [Version] = []
        var visited: Set<UUID> = []
        var queue: [UUID] = [versionId]

        while !queue.isEmpty {
            let currentId = queue.removeFirst()

            guard !visited.contains(currentId),
                  let version = versions[currentId] else {
                continue
            }

            visited.insert(currentId)
            history.append(version)

            // Add parents to queue
            queue.append(contentsOf: version.parentIds)
        }

        // Sort chronologically
        return history.sorted { $0.timestamp < $1.timestamp }
    }

    /// Finds the common ancestor of two versions
    /// - Parameters:
    ///   - version1: First version ID
    ///   - version2: Second version ID
    /// - Returns: The common ancestor version, if found
    func findCommonAncestor(version1: UUID, version2: UUID) async -> Version? {
        let ancestors1 = await getAncestors(version1)
        let ancestors2 = await getAncestors(version2)

        // Find common ancestors
        let commonAncestors = ancestors1.intersection(ancestors2)

        // Return the most recent common ancestor
        let commonVersions = commonAncestors.compactMap { versions[$0] }
        return commonVersions.max { $0.timestamp < $1.timestamp }
    }

    /// Gets all ancestors of a version
    /// - Parameter versionId: The version ID
    /// - Returns: Set of ancestor version IDs
    func getAncestors(_ versionId: UUID) async -> Set<UUID> {
        var ancestors: Set<UUID> = []
        var queue: [UUID] = [versionId]

        while !queue.isEmpty {
            let currentId = queue.removeFirst()

            guard !ancestors.contains(currentId),
                  let version = versions[currentId] else {
                continue
            }

            ancestors.insert(currentId)
            queue.append(contentsOf: version.parentIds)
        }

        return ancestors
    }

    /// Gets all children of a version
    /// - Parameter versionId: The version ID
    /// - Returns: Array of child versions
    func getChildren(_ versionId: UUID) async -> [Version] {
        let childIds = edges[versionId] ?? []
        return childIds.compactMap { versions[$0] }
    }

    /// Adds a branch
    /// - Parameter branch: The branch to add
    func addBranch(_ branch: Branch) async {
        branches[branch.name] = branch
        await persistBranch(branch)
    }

    /// Gets a branch by name
    /// - Parameter name: The branch name
    /// - Returns: The branch, if found
    func getBranch(_ name: String) async -> Branch? {
        branches[name]
    }

    /// Gets all branches
    /// - Returns: Array of all branches
    func getAllBranches() async -> [Branch] {
        Array(branches.values)
    }

    /// Updates the head of a branch
    /// - Parameters:
    ///   - branchName: The branch name
    ///   - newHead: The new head version ID
    func updateBranch(_ branchName: String, newHead: UUID) async {
        guard var branch = branches[branchName] else { return }

        branch = Branch(
            id: branch.id,
            name: branch.name,
            headVersion: newHead,
            createdAt: branch.createdAt
        )

        branches[branchName] = branch
        await persistBranch(branch)
    }

    /// Visualizes the version graph
    /// - Returns: A graph representation suitable for visualization
    func visualize() async -> GraphVisualization {
        var nodes: [GraphNode] = []
        var graphEdges: [GraphEdge] = []

        for (id, version) in versions {
            let node = GraphNode(
                id: id,
                label: version.message,
                timestamp: version.timestamp,
                author: version.author
            )
            nodes.append(node)

            // Create edges
            for parentId in version.parentIds {
                let edge = GraphEdge(from: parentId, to: id)
                graphEdges.append(edge)
            }
        }

        return GraphVisualization(
            nodes: nodes,
            edges: graphEdges,
            branches: Array(branches.values)
        )
    }

    /// Prunes old versions to save space
    /// - Parameter keepDays: Number of days of history to keep
    func pruneOldVersions(keepDays: Int = 30) async {
        let cutoffDate = Date().addingTimeInterval(-Double(keepDays) * 86400)

        let oldVersions = versions.filter { $0.value.timestamp < cutoffDate }

        for (id, _) in oldVersions {
            versions.removeValue(forKey: id)
            edges.removeValue(forKey: id)

            // Remove references in edges
            for (parent, children) in edges {
                edges[parent] = children.filter { $0 != id }
            }
        }
    }

    // MARK: - Private Methods

    /// Persists a version to disk
    private func persistVersion(_ version: Version) async {
        let versionURL = storageURL.appendingPathComponent("\(version.id.uuidString).json")

        do {
            let data = try JSONEncoder().encode(version)
            try data.write(to: versionURL)
        } catch {
            print("Error persisting version: \(error)")
        }
    }

    /// Persists a branch to disk
    private func persistBranch(_ branch: Branch) async {
        let branchURL = storageURL.appendingPathComponent("branches.json")

        do {
            let allBranches = Array(branches.values)
            let data = try JSONEncoder().encode(allBranches)
            try data.write(to: branchURL)
        } catch {
            print("Error persisting branch: \(error)")
        }
    }

    /// Loads versions from disk
    func loadVersions() async throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)

        for url in contents where url.pathExtension == "json" && url.lastPathComponent != "branches.json" {
            let data = try Data(contentsOf: url)
            let version = try JSONDecoder().decode(Version.self, from: data)
            await addVersion(version)
        }
    }
}

// MARK: - Supporting Types

/// Represents a node in the version graph
struct GraphNode: Identifiable {
    let id: UUID
    let label: String
    let timestamp: Date
    let author: String
}

/// Represents an edge in the version graph
struct GraphEdge {
    let from: UUID
    let to: UUID
}

/// Represents the entire graph for visualization
struct GraphVisualization {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let branches: [Branch]
}
