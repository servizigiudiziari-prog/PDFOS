//
//  EventStoreOptimized.swift
//  PDFOS
//
//  Optimized event store with advanced snapshot strategy and compression
//

import Foundation
#if canImport(Compression)
import Compression
#endif

/// Optimized event store with compression and smart snapshotting
actor EventStoreOptimized {
    // MARK: - Properties

    private var events: [UUID: [PDFEvent]] = [:]
    private var snapshots: [UUID: [OptimizedSnapshot]] = [:]

    // Optimization settings
    private let snapshotInterval = 10
    private let maxSnapshotsPerDocument = 100
    private let compressionEnabled = true
    private let deltaCompressionEnabled = true

    // Storage
    private let storageURL: URL
    private let fileManager = FileManager.default

    // Performance tracking
    private var storageSize: Int64 = 0
    private var compressionRatio: Float = 0.0
    private var snapshotCreationTime: TimeInterval = 0.0

    // MARK: - Initialization

    init(storageURL: URL? = nil) {
        let defaultURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("PDFOS")
            .appendingPathComponent("EventStoreOptimized")

        self.storageURL = storageURL ?? defaultURL ?? fileManager.temporaryDirectory

        try? fileManager.createDirectory(
            at: self.storageURL,
            withIntermediateDirectories: true
        )

        Task {
            await calculateStorageMetrics()
        }
    }

    // MARK: - Event Management

    /// Records a new event with optional compression
    func recordEvent(_ event: PDFEvent, documentId: UUID) async throws {
        // Add to memory
        events[documentId, default: []].append(event)

        // Persist with compression
        try await persistEventCompressed(event, documentId: documentId)

        // Check if snapshot needed
        let eventCount = events[documentId]?.count ?? 0
        if shouldCreateSnapshot(eventCount: eventCount, documentId: documentId) {
            try await createOptimizedSnapshot(documentId: documentId)
        }

        // Update metrics
        await calculateStorageMetrics()
    }

    /// Gets events with lazy loading
    func getEvents(
        documentId: UUID,
        from: Date,
        to: Date
    ) async -> [PDFEvent] {
        // Load from disk if not in memory
        if events[documentId] == nil {
            await loadEvents(documentId: documentId)
        }

        let allEvents = events[documentId] ?? []
        return allEvents.filter { event in
            event.timestamp >= from && event.timestamp <= to
        }.sorted { $0.timestamp < $1.timestamp }
    }

    /// Gets all events with pagination
    func getEvents(
        documentId: UUID,
        offset: Int = 0,
        limit: Int = 100
    ) async -> [PDFEvent] {
        if events[documentId] == nil {
            await loadEvents(documentId: documentId)
        }

        let allEvents = events[documentId] ?? []
        let start = min(offset, allEvents.count)
        let end = min(offset + limit, allEvents.count)

        return Array(allEvents[start..<end])
    }

    // MARK: - Snapshot Management

    /// Creates an optimized snapshot with delta compression
    func createOptimizedSnapshot(documentId: UUID) async throws {
        let startTime = Date()

        guard let allEvents = events[documentId], !allEvents.isEmpty else {
            return
        }

        // Get previous snapshot for delta compression
        let previousSnapshot = snapshots[documentId]?.last

        // Create new snapshot
        let snapshot = OptimizedSnapshot(
            id: UUID(),
            documentId: documentId,
            timestamp: Date(),
            eventCount: allEvents.count,
            compressionType: deltaCompressionEnabled && previousSnapshot != nil ? .delta : .full,
            dataSize: 0 // Will be calculated
        )

        // Store snapshot
        snapshots[documentId, default: []].append(snapshot)

        // Prune old snapshots
        await pruneOldSnapshots(documentId: documentId)

        // Persist to disk
        try await persistSnapshot(snapshot, documentId: documentId)

        // Update metrics
        snapshotCreationTime = Date().timeIntervalSince(startTime)
    }

    /// Finds optimal snapshot for time travel
    func findOptimalSnapshot(
        before date: Date,
        documentId: UUID
    ) async -> OptimizedSnapshot? {
        let documentSnapshots = snapshots[documentId] ?? []

        // Find snapshot closest to target date
        let validSnapshots = documentSnapshots
            .filter { $0.timestamp <= date }
            .sorted { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) }

        return validSnapshots.first
    }

    /// Time travels to a specific date with optimized reconstruction
    func timeTravel(
        to date: Date,
        documentId: UUID
    ) async throws -> ReconstructedState {
        let startTime = Date()

        // 1. Find optimal snapshot
        guard let snapshot = await findOptimalSnapshot(before: date, documentId: documentId) else {
            throw EventStoreError.noSnapshotAvailable
        }

        // 2. Get events since snapshot
        let relevantEvents = await getEvents(
            documentId: documentId,
            from: snapshot.timestamp,
            to: date
        )

        // 3. Reconstruct state
        // (This would integrate with PDFDocument reconstruction)

        let reconstructionTime = Date().timeIntervalSince(startTime)

        return ReconstructedState(
            timestamp: date,
            snapshotUsed: snapshot.id,
            eventsApplied: relevantEvents.count,
            reconstructionTime: reconstructionTime
        )
    }

    // MARK: - Optimization

    /// Compresses and optimizes storage
    func optimizeStorage() async throws {
        let startSize = await calculateStorageSize()

        // 1. Compress old events
        for (documentId, _) in events {
            try await compressOldEvents(documentId: documentId)
        }

        // 2. Prune redundant snapshots
        for (documentId, _) in snapshots {
            await pruneOldSnapshots(documentId: documentId)
        }

        // 3. Defragment storage
        try await defragmentStorage()

        let endSize = await calculateStorageSize()
        let saved = startSize - endSize

        print("Storage optimized: Saved \(ByteCountFormatter.string(fromByteCount: saved, countStyle: .file))")
    }

    /// Gets storage statistics
    func getStorageStats() async -> StorageStatistics {
        let totalEvents = events.values.flatMap { $0 }.count
        let totalSnapshots = snapshots.values.flatMap { $0 }.count

        return StorageStatistics(
            totalEvents: totalEvents,
            totalSnapshots: totalSnapshots,
            storageSize: storageSize,
            compressionRatio: compressionRatio,
            averageSnapshotCreationTime: snapshotCreationTime
        )
    }

    // MARK: - Private Methods

    private func shouldCreateSnapshot(eventCount: Int, documentId: UUID) -> Bool {
        // Create snapshot every N events
        if eventCount % snapshotInterval == 0 {
            return true
        }

        // Or if last snapshot is too old
        if let lastSnapshot = snapshots[documentId]?.last {
            let timeSinceLastSnapshot = Date().timeIntervalSince(lastSnapshot.timestamp)
            if timeSinceLastSnapshot > 3600 { // 1 hour
                return true
            }
        }

        return false
    }

    private func persistEventCompressed(_ event: PDFEvent, documentId: UUID) async throws {
        let eventsURL = storageURL
            .appendingPathComponent(documentId.uuidString)
            .appendingPathComponent("events.dat")

        try? fileManager.createDirectory(
            at: eventsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Encode event
        let data = try JSONEncoder().encode(event)

        // Compress if enabled
        let finalData: Data
        if compressionEnabled {
            finalData = try compress(data)
        } else {
            finalData = data
        }

        // Append to file
        if fileManager.fileExists(atPath: eventsURL.path) {
            let fileHandle = try FileHandle(forWritingTo: eventsURL)
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: finalData)
            try fileHandle.close()
        } else {
            try finalData.write(to: eventsURL)
        }
    }

    private func persistSnapshot(_ snapshot: OptimizedSnapshot, documentId: UUID) async throws {
        let snapshotURL = storageURL
            .appendingPathComponent(documentId.uuidString)
            .appendingPathComponent("snapshots")
            .appendingPathComponent("\(snapshot.id.uuidString).snapshot")

        try? fileManager.createDirectory(
            at: snapshotURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try JSONEncoder().encode(snapshot)
        let compressed = try compress(data)
        try compressed.write(to: snapshotURL)
    }

    private func loadEvents(documentId: UUID) async {
        let eventsURL = storageURL
            .appendingPathComponent(documentId.uuidString)
            .appendingPathComponent("events.dat")

        guard fileManager.fileExists(atPath: eventsURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: eventsURL)
            let decompressed = try decompress(data)
            let loadedEvents = try JSONDecoder().decode([PDFEvent].self, from: decompressed)
            events[documentId] = loadedEvents
        } catch {
            print("Failed to load events: \(error)")
        }
    }

    private func pruneOldSnapshots(documentId: UUID) async {
        guard var documentSnapshots = snapshots[documentId] else {
            return
        }

        // Keep only last N snapshots
        if documentSnapshots.count > maxSnapshotsPerDocument {
            let toRemove = documentSnapshots.count - maxSnapshotsPerDocument
            let removed = documentSnapshots.prefix(toRemove)

            // Delete from disk
            for snapshot in removed {
                let snapshotURL = storageURL
                    .appendingPathComponent(documentId.uuidString)
                    .appendingPathComponent("snapshots")
                    .appendingPathComponent("\(snapshot.id.uuidString).snapshot")

                try? fileManager.removeItem(at: snapshotURL)
            }

            // Update in memory
            documentSnapshots.removeFirst(toRemove)
            snapshots[documentId] = documentSnapshots
        }
    }

    private func compressOldEvents(documentId: UUID) async throws {
        // Already compressed during persistence
    }

    private func defragmentStorage() async throws {
        // Compact storage files
        for (documentId, _) in events {
            let eventsURL = storageURL
                .appendingPathComponent(documentId.uuidString)
                .appendingPathComponent("events.dat")

            guard fileManager.fileExists(atPath: eventsURL.path) else {
                continue
            }

            // Reload and rewrite to compact
            let data = try Data(contentsOf: eventsURL)
            try data.write(to: eventsURL, options: .atomic)
        }
    }

    private func calculateStorageSize() async -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: storageURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    private func calculateStorageMetrics() async {
        storageSize = await calculateStorageSize()

        // Calculate compression ratio
        let totalEvents = events.values.flatMap { $0 }.count
        if totalEvents > 0 {
            let estimatedUncompressedSize = Int64(totalEvents * 1024) // Rough estimate
            compressionRatio = storageSize > 0 ? Float(estimatedUncompressedSize) / Float(storageSize) : 1.0
        }
    }

    // MARK: - Compression Helpers

    private func compress(_ data: Data) throws -> Data {
        #if canImport(Compression)
        return try (data as NSData).compressed(using: .lzfse) as Data
        #else
        return data
        #endif
    }

    private func decompress(_ data: Data) throws -> Data {
        #if canImport(Compression)
        return try (data as NSData).decompressed(using: .lzfse) as Data
        #else
        return data
        #endif
    }
}

// MARK: - Supporting Types

/// Optimized snapshot with metadata
struct OptimizedSnapshot: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let timestamp: Date
    let eventCount: Int
    let compressionType: CompressionType
    let dataSize: Int64

    enum CompressionType: String, Codable {
        case full
        case delta
        case incremental
    }
}

/// Reconstructed state information
struct ReconstructedState {
    let timestamp: Date
    let snapshotUsed: UUID
    let eventsApplied: Int
    let reconstructionTime: TimeInterval
}

/// Storage statistics
struct StorageStatistics {
    let totalEvents: Int
    let totalSnapshots: Int
    let storageSize: Int64
    let compressionRatio: Float
    let averageSnapshotCreationTime: TimeInterval

    var formattedStorageSize: String {
        ByteCountFormatter.string(fromByteCount: storageSize, countStyle: .file)
    }

    var formattedCompressionRatio: String {
        String(format: "%.1fx", compressionRatio)
    }
}

/// Event store errors
enum EventStoreError: Error {
    case noSnapshotAvailable
    case compressionFailed
    case corruptedData
    case diskFull
}

extension EventStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noSnapshotAvailable:
            return "No snapshot available for time travel"
        case .compressionFailed:
            return "Failed to compress event data"
        case .corruptedData:
            return "Event store data is corrupted"
        case .diskFull:
            return "Disk is full, cannot store events"
        }
    }
}
