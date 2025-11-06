//
//  CloudKitSyncEngine.swift
//  PDFOS
//
//  CloudKit synchronization engine for documents and versions
//

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

/// CloudKit sync engine for cross-device synchronization
actor CloudKitSyncEngine {
    // MARK: - Properties

    static let shared = CloudKitSyncEngine()

    #if canImport(CloudKit)
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    #endif

    private var syncState: SyncState = .idle
    private var lastSyncDate: Date?
    private var pendingChanges: [UUID: [Change]] = [:]

    // Record types
    private let documentRecordType = "PDFDocument"
    private let versionRecordType = "Version"
    private let eventRecordType = "Event"

    // MARK: - Initialization

    private init() {
        #if canImport(CloudKit)
        self.container = CKContainer(identifier: "iCloud.com.pdfos.app")
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        #endif

        Task {
            await setupSubscriptions()
        }
    }

    // MARK: - Sync Operations

    /// Syncs a document to CloudKit
    func syncDocument(_ document: PDFDocument) async throws {
        #if canImport(CloudKit)
        try await performSync {
            let record = try createDocumentRecord(document)
            try await privateDatabase.save(record)
        }
        #else
        throw CloudKitSyncError.cloudKitNotAvailable
        #endif
    }

    /// Syncs a version to CloudKit
    func syncVersion(_ version: Version, for documentId: UUID) async throws {
        #if canImport(CloudKit)
        try await performSync {
            let record = try createVersionRecord(version, documentId: documentId)
            try await privateDatabase.save(record)
        }
        #else
        throw CloudKitSyncError.cloudKitNotAvailable
        #endif
    }

    /// Syncs events to CloudKit (batch)
    func syncEvents(_ events: [PDFEvent], for documentId: UUID) async throws {
        #if canImport(CloudKit)
        try await performSync {
            let records = try events.map { try createEventRecord($0, documentId: documentId) }

            // Batch save (max 400 per batch)
            for batch in records.chunked(into: 400) {
                try await privateDatabase.modifyRecords(saving: batch, deleting: [])
            }
        }
        #else
        throw CloudKitSyncError.cloudKitNotAvailable
        #endif
    }

    /// Fetches document from CloudKit
    func fetchDocument(_ documentId: UUID) async throws -> PDFDocument {
        #if canImport(CloudKit)
        let recordID = CKRecord.ID(recordName: documentId.uuidString)
        let record = try await privateDatabase.record(for: recordID)
        return try parseDocumentRecord(record)
        #else
        throw CloudKitSyncError.cloudKitNotAvailable
        #endif
    }

    /// Fetches all versions for a document
    func fetchVersions(for documentId: UUID) async throws -> [Version] {
        #if canImport(CloudKit)
        let predicate = NSPredicate(format: "documentId == %@", documentId.uuidString)
        let query = CKQuery(recordType: versionRecordType, predicate: predicate)

        let results = try await privateDatabase.records(matching: query)
        var versions: [Version] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                let version = try parseVersionRecord(record)
                versions.append(version)
            case .failure:
                continue
            }
        }

        return versions.sorted { $0.timestamp < $1.timestamp }
        #else
        throw CloudKitSyncError.cloudKitNotAvailable
        #endif
    }

    /// Performs full sync (pull then push)
    func performFullSync() async throws {
        guard syncState == .idle else {
            throw CloudKitSyncError.syncInProgress
        }

        syncState = .syncing

        do {
            // 1. Pull remote changes
            let changes = try await fetchRemoteChanges()
            try await applyRemoteChanges(changes)

            // 2. Push local changes
            try await pushLocalChanges()

            // 3. Update sync date
            lastSyncDate = Date()
            syncState = .idle

        } catch {
            syncState = .failed(error)
            throw error
        }
    }

    /// Gets sync status
    func getSyncStatus() -> CloudKitSyncStatus {
        CloudKitSyncStatus(
            state: syncState,
            lastSyncDate: lastSyncDate,
            pendingChangesCount: pendingChanges.values.flatMap { $0 }.count
        )
    }

    // MARK: - Conflict Resolution

    /// Resolves sync conflicts using CRDT strategy
    func resolveConflict(
        local: Version,
        remote: Version
    ) async throws -> Version {
        // Use timestamp as tiebreaker (Last Write Wins)
        if local.timestamp > remote.timestamp {
            return local
        } else if remote.timestamp > local.timestamp {
            return remote
        }

        // If timestamps equal, use semantic hash
        let localHash = local.semanticDelta.changes.map { $0.changeType.rawValue }.joined()
        let remoteHash = remote.semanticDelta.changes.map { $0.changeType.rawValue }.joined()

        return localHash > remoteHash ? local : remote
    }

    /// Merges conflicting changes
    func mergeConflicts(
        local: [PDFEvent],
        remote: [PDFEvent]
    ) async throws -> [PDFEvent] {
        // Merge using event IDs and timestamps
        var merged: [UUID: PDFEvent] = [:]

        for event in local {
            merged[event.id] = event
        }

        for event in remote {
            if let existing = merged[event.id] {
                // Keep newer event
                if event.timestamp > existing.timestamp {
                    merged[event.id] = event
                }
            } else {
                merged[event.id] = event
            }
        }

        return Array(merged.values).sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Private Methods

    #if canImport(CloudKit)
    private func createDocumentRecord(_ document: PDFDocument) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: document.id.uuidString)
        let record = CKRecord(recordType: documentRecordType, recordID: recordID)

        record["title"] = document.metadata.title
        record["author"] = document.metadata.author
        record["pageCount"] = document.metadata.pageCount
        record["createdAt"] = document.createdAt
        record["modifiedAt"] = document.modifiedAt

        return record
    }

    private func createVersionRecord(_ version: Version, documentId: UUID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: version.id.uuidString)
        let record = CKRecord(recordType: versionRecordType, recordID: recordID)

        record["documentId"] = documentId.uuidString
        record["author"] = version.author
        record["message"] = version.message
        record["timestamp"] = version.timestamp
        record["parentIds"] = version.parentIds.map { $0.uuidString }

        // Encode semantic delta
        let deltaData = try JSONEncoder().encode(version.semanticDelta)
        record["semanticDelta"] = deltaData

        return record
    }

    private func createEventRecord(_ event: PDFEvent, documentId: UUID) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: event.id.uuidString)
        let record = CKRecord(recordType: eventRecordType, recordID: recordID)

        record["documentId"] = documentId.uuidString
        record["type"] = event.type.rawValue
        record["timestamp"] = event.timestamp
        record["userId"] = event.userId
        record["payload"] = event.payload

        return record
    }

    private func parseDocumentRecord(_ record: CKRecord) throws -> PDFDocument {
        guard let title = record["title"] as? String,
              let pageCount = record["pageCount"] as? Int,
              let createdAt = record["createdAt"] as? Date,
              let modifiedAt = record["modifiedAt"] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }

        let metadata = DocumentMetadata(
            title: title,
            author: record["author"] as? String,
            subject: nil,
            keywords: [],
            pageCount: pageCount,
            fileSize: 0,
            documentType: .general
        )

        let initialDelta = SemanticDelta(changes: [], commitMessage: "Synced", importance: 0)
        let initialVersion = Version(
            parentIds: [],
            semanticDelta: initialDelta,
            eventIds: [],
            author: "system",
            message: "Synced from cloud"
        )

        return PDFDocument(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            url: URL(fileURLWithPath: "/tmp/\(title).pdf"),
            metadata: metadata,
            currentVersion: initialVersion,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    private func parseVersionRecord(_ record: CKRecord) throws -> Version {
        guard let author = record["author"] as? String,
              let message = record["message"] as? String,
              let timestamp = record["timestamp"] as? Date,
              let parentIdsStrings = record["parentIds"] as? [String],
              let deltaData = record["semanticDelta"] as? Data else {
            throw CloudKitSyncError.invalidRecord
        }

        let parentIds = parentIdsStrings.compactMap { UUID(uuidString: $0) }
        let semanticDelta = try JSONDecoder().decode(SemanticDelta.self, from: deltaData)

        return Version(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            parentIds: parentIds,
            timestamp: timestamp,
            semanticDelta: semanticDelta,
            eventIds: [],
            author: author,
            message: message
        )
    }
    #endif

    private func performSync(_ operation: () async throws -> Void) async throws {
        #if canImport(CloudKit)
        // Check iCloud availability
        let status = try await container.accountStatus()
        guard status == .available else {
            throw CloudKitSyncError.iCloudNotAvailable
        }

        try await operation()
        #else
        throw CloudKitSyncError.cloudKitNotAvailable
        #endif
    }

    private func setupSubscriptions() async {
        #if canImport(CloudKit)
        // Subscribe to document changes
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: documentRecordType,
            predicate: predicate,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification

        do {
            try await privateDatabase.save(subscription)
        } catch {
            print("Failed to setup subscription: \(error)")
        }
        #endif
    }

    private func fetchRemoteChanges() async throws -> [Change] {
        // TODO: Implement change fetching
        return []
    }

    private func applyRemoteChanges(_ changes: [Change]) async throws {
        // TODO: Apply changes locally
    }

    private func pushLocalChanges() async throws {
        // TODO: Push pending changes
    }
}

// MARK: - Supporting Types

/// Sync state
enum SyncState: Equatable {
    case idle
    case syncing
    case failed(Error)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

/// Sync status
struct CloudKitSyncStatus {
    let state: SyncState
    let lastSyncDate: Date?
    let pendingChangesCount: Int

    var isSyncing: Bool {
        if case .syncing = state { return true }
        return false
    }

    var formattedLastSync: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Sync change
struct Change {
    let type: ChangeType
    let recordID: String
    let data: Data

    enum ChangeType {
        case created
        case updated
        case deleted
    }
}

/// Sync errors
enum CloudKitSyncError: Error {
    case cloudKitNotAvailable
    case iCloudNotAvailable
    case syncInProgress
    case invalidRecord
    case conflictDetected
    case networkError
}

extension CloudKitSyncError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cloudKitNotAvailable:
            return "CloudKit is not available on this platform"
        case .iCloudNotAvailable:
            return "iCloud account not available. Please sign in to iCloud."
        case .syncInProgress:
            return "Sync is already in progress"
        case .invalidRecord:
            return "Invalid CloudKit record"
        case .conflictDetected:
            return "Sync conflict detected"
        case .networkError:
            return "Network error during sync"
        }
    }
}
