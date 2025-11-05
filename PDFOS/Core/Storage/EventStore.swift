//
//  EventStore.swift
//  PDFOS
//
//  Event sourcing store for PDF document events
//

import Foundation

/// Event store implementing event sourcing pattern
actor EventStore {
    // MARK: - Properties

    private var events: [UUID: [PDFEvent]] = [:] // documentId -> events
    private var snapshots: [UUID: [DocumentSnapshot]] = [:] // documentId -> snapshots
    private let snapshotInterval = 10 // Create snapshot every N events
    private let fileManager = FileManager.default
    private let storageURL: URL

    // MARK: - Initialization

    init(storageURL: URL? = nil) {
        // Use application support directory by default
        let defaultURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PDFOS")
            .appendingPathComponent("EventStore")

        self.storageURL = storageURL ?? defaultURL ?? fileManager.temporaryDirectory

        // Create storage directory if needed
        try? fileManager.createDirectory(at: self.storageURL, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Records a new event
    /// - Parameter event: The event to record
    func recordEvent(_ event: PDFEvent, documentId: UUID) async {
        // Add to in-memory store
        events[documentId, default: []].append(event)

        // Persist to disk
        await persistEvent(event, documentId: documentId)

        // Create snapshot if needed
        let eventCount = events[documentId]?.count ?? 0
        if eventCount % snapshotInterval == 0 {
            await createSnapshot(documentId: documentId)
        }
    }

    /// Gets events for a document in a time range
    /// - Parameters:
    ///   - documentId: The document ID
    ///   - from: Start date
    ///   - to: End date
    /// - Returns: Array of events
    func getEvents(
        documentId: UUID,
        from: Date,
        to: Date
    ) async -> [PDFEvent] {
        let allEvents = events[documentId] ?? []
        return allEvents.filter { event in
            event.timestamp >= from && event.timestamp <= to
        }.sorted { $0.timestamp < $1.timestamp }
    }

    /// Gets all events for a document
    /// - Parameter documentId: The document ID
    /// - Returns: Array of events
    func getAllEvents(documentId: UUID) async -> [PDFEvent] {
        events[documentId] ?? []
    }

    /// Finds the nearest snapshot before a date
    /// - Parameters:
    ///   - date: The target date
    ///   - documentId: The document ID
    /// - Returns: The nearest snapshot, if any
    func findNearestSnapshot(before date: Date, documentId: UUID) async -> PDFDocument? {
        let documentSnapshots = snapshots[documentId] ?? []

        let validSnapshots = documentSnapshots.filter { $0.timestamp <= date }
            .sorted { $0.timestamp > $1.timestamp }

        return validSnapshots.first?.document
    }

    /// Reconstructs document state at a specific date
    /// - Parameters:
    ///   - date: The target date
    ///   - documentId: The document ID
    /// - Returns: The document state
    func timeTravel(to date: Date, documentId: UUID) async throws -> PDFDocument? {
        // 1. Find nearest snapshot
        guard let snapshot = await findNearestSnapshot(before: date, documentId: documentId) else {
            return nil
        }

        // 2. Get events from snapshot to target date
        let relevantEvents = await getEvents(
            documentId: documentId,
            from: snapshot.modifiedAt,
            to: date
        )

        // 3. Replay events
        var document = snapshot
        for event in relevantEvents {
            document = try await applyEvent(event, to: document)
        }

        return document
    }

    /// Creates a snapshot of the current document state
    /// - Parameter documentId: The document ID
    func createSnapshot(documentId: UUID) async {
        // TODO: Implement snapshot creation
        // For now, this is a placeholder
    }

    /// Loads events from disk
    /// - Parameter documentId: The document ID
    func loadEvents(documentId: UUID) async throws {
        let eventsURL = storageURL
            .appendingPathComponent(documentId.uuidString)
            .appendingPathComponent("events.json")

        guard fileManager.fileExists(atPath: eventsURL.path) else {
            return
        }

        let data = try Data(contentsOf: eventsURL)
        let loadedEvents = try JSONDecoder().decode([PDFEvent].self, from: data)
        events[documentId] = loadedEvents
    }

    /// Gets event statistics
    /// - Parameter documentId: The document ID
    /// - Returns: Event statistics
    func getStatistics(documentId: UUID) async -> EventStatistics {
        let allEvents = events[documentId] ?? []

        var typeCount: [PDFEvent.EventType: Int] = [:]
        for event in allEvents {
            typeCount[event.type, default: 0] += 1
        }

        return EventStatistics(
            totalEvents: allEvents.count,
            eventsByType: typeCount,
            firstEvent: allEvents.first?.timestamp,
            lastEvent: allEvents.last?.timestamp
        )
    }

    // MARK: - Private Methods

    /// Persists an event to disk
    private func persistEvent(_ event: PDFEvent, documentId: UUID) async {
        let documentURL = storageURL.appendingPathComponent(documentId.uuidString)
        try? fileManager.createDirectory(at: documentURL, withIntermediateDirectories: true)

        let eventsURL = documentURL.appendingPathComponent("events.json")

        do {
            let allEvents = events[documentId] ?? []
            let data = try JSONEncoder().encode(allEvents)
            try data.write(to: eventsURL)
        } catch {
            print("Error persisting event: \(error)")
        }
    }

    /// Applies an event to a document (simplified version)
    private func applyEvent(_ event: PDFEvent, to document: PDFDocument) async throws -> PDFDocument {
        // TODO: Implement actual event application logic
        // For now, just return the document unchanged
        var updatedDocument = document
        updatedDocument.modifiedAt = event.timestamp
        return updatedDocument
    }
}

// MARK: - Supporting Types

/// Represents a document snapshot
struct DocumentSnapshot {
    let id: UUID
    let document: PDFDocument
    let timestamp: Date
    let eventCount: Int

    init(
        id: UUID = UUID(),
        document: PDFDocument,
        timestamp: Date = Date(),
        eventCount: Int
    ) {
        self.id = id
        self.document = document
        self.timestamp = timestamp
        self.eventCount = eventCount
    }
}

/// Statistics about events
struct EventStatistics {
    let totalEvents: Int
    let eventsByType: [PDFEvent.EventType: Int]
    let firstEvent: Date?
    let lastEvent: Date?

    var averageEventsPerDay: Double {
        guard let first = firstEvent, let last = lastEvent else {
            return 0.0
        }

        let days = last.timeIntervalSince(first) / 86400
        return days > 0 ? Double(totalEvents) / days : 0.0
    }
}
