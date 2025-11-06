//
//  PDFModels.swift
//  PDFOS
//
//  Core data models for PDFOS
//

import Foundation

// MARK: - Event Sourcing Models

/// Represents an immutable event in the document history
struct PDFEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    let payload: Data
    let userId: String
    let semanticHash: String

    /// The type of PDF modification event
    enum EventType: String, Codable {
        case textEdit
        case textInsert
        case textDelete
        case imageInsert
        case imageDelete
        case annotationAdd
        case annotationRemove
        case pageAdd
        case pageRemove
        case pageReorder
        case metadataChange
        case formFieldEdit
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: EventType,
        payload: Data,
        userId: String,
        semanticHash: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
        self.userId = userId
        self.semanticHash = semanticHash
    }
}

// MARK: - Semantic Analysis Models

/// Represents a semantic change in the document
struct SemanticDelta: Codable {
    let id: UUID
    let changes: [SemanticChange]
    let commitMessage: String
    let importance: Float

    init(
        id: UUID = UUID(),
        changes: [SemanticChange],
        commitMessage: String,
        importance: Float
    ) {
        self.id = id
        self.changes = changes
        self.commitMessage = commitMessage
        self.importance = importance
    }
}

/// Represents a single semantic change
struct SemanticChange: Codable, Equatable {
    let changeType: ChangeType
    let location: DocumentLocation
    let semanticEmbedding: [Float]
    let similarity: Float
    let affectedSections: [String]

    enum ChangeType: String, Codable {
        case identical
        case modified
        case added
        case removed
    }

    static func == (lhs: SemanticChange, rhs: SemanticChange) -> Bool {
        lhs.changeType == rhs.changeType &&
        lhs.location == rhs.location &&
        lhs.semanticEmbedding == rhs.semanticEmbedding &&
        lhs.similarity == rhs.similarity &&
        lhs.affectedSections == rhs.affectedSections
    }
}

/// Represents a location in a PDF document
struct DocumentLocation: Codable, Equatable {
    let pageIndex: Int
    let sectionId: String?
    let paragraphIndex: Int?
    let characterRange: Range<Int>?

    init(
        pageIndex: Int,
        sectionId: String? = nil,
        paragraphIndex: Int? = nil,
        characterRange: Range<Int>? = nil
    ) {
        self.pageIndex = pageIndex
        self.sectionId = sectionId
        self.paragraphIndex = paragraphIndex
        self.characterRange = characterRange
    }

    static func == (lhs: DocumentLocation, rhs: DocumentLocation) -> Bool {
        lhs.pageIndex == rhs.pageIndex &&
        lhs.sectionId == rhs.sectionId &&
        lhs.paragraphIndex == rhs.paragraphIndex &&
        lhs.characterRange?.lowerBound == rhs.characterRange?.lowerBound &&
        lhs.characterRange?.upperBound == rhs.characterRange?.upperBound
    }
}

// MARK: - Version Control Models

/// Represents a version in the version graph
struct Version: Identifiable, Codable {
    let id: UUID
    let parentIds: [UUID]
    let timestamp: Date
    let semanticDelta: SemanticDelta
    let eventIds: [UUID]
    let author: String
    let message: String

    init(
        id: UUID = UUID(),
        parentIds: [UUID],
        timestamp: Date = Date(),
        semanticDelta: SemanticDelta,
        eventIds: [UUID],
        author: String,
        message: String
    ) {
        self.id = id
        self.parentIds = parentIds
        self.timestamp = timestamp
        self.semanticDelta = semanticDelta
        self.eventIds = eventIds
        self.author = author
        self.message = message
    }
}

/// Represents a merge conflict that requires user resolution
struct MergeConflict: Identifiable {
    let id: UUID
    let location: DocumentLocation
    let currentVersion: Version
    let incomingVersion: Version
    let conflictType: ConflictType
    let description: String

    enum ConflictType {
        case semanticConflict
        case structuralConflict
        case dependencyConflict
    }

    init(
        id: UUID = UUID(),
        location: DocumentLocation,
        currentVersion: Version,
        incomingVersion: Version,
        conflictType: ConflictType,
        description: String
    ) {
        self.id = id
        self.location = location
        self.currentVersion = currentVersion
        self.incomingVersion = incomingVersion
        self.conflictType = conflictType
        self.description = description
    }
}

/// Result of a merge operation
enum MergeResult {
    case success(Version)
    case conflict([MergeConflict])
    case failure(Error)
}

// MARK: - Adaptive UI Models

/// Represents user's gaze point
struct GazePoint {
    let x: Float
    let y: Float
    let timestamp: Date
    let confidence: Float
}

/// Represents detected user intent from behavior
enum UserIntent {
    case reading
    case searching
    case editing
    case navigating
    case confused
    case idle
}

/// Represents cognitive load level
struct CognitiveLoad {
    let load: Float // 0.0 to 1.0
    let factors: [LoadFactor]

    enum LoadFactor {
        case taskComplexity(Float)
        case timeOnTask(TimeInterval)
        case errorRate(Float)
        case backtrackingFrequency(Float)
    }
}

/// UI complexity levels
enum UIComplexity: String, Codable {
    case minimal
    case reading
    case editing
    case power
}

// MARK: - Document Models

/// Represents a PDF document with version control
struct PDFDocument: Identifiable, Codable {
    let id: UUID
    let url: URL
    let metadata: DocumentMetadata
    var currentVersion: Version
    let createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        url: URL,
        metadata: DocumentMetadata,
        currentVersion: Version,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.metadata = metadata
        self.currentVersion = currentVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Document metadata
struct DocumentMetadata: Codable {
    var title: String
    var author: String?
    var subject: String?
    var keywords: [String]
    var pageCount: Int
    var fileSize: Int64
    var documentType: DocumentType

    enum DocumentType: String, Codable {
        case contract
        case report
        case presentation
        case form
        case manuscript
        case general
    }
}

// MARK: - Performance Tracking

/// Performance metrics for monitoring kill switches
struct PerformanceMetrics {
    var semanticLatency: TimeInterval
    var falsePositiveRate: Float
    var memoryUsage: Int64
    var crashRate: Float

    /// Check if any kill switch is triggered
    func checkKillSwitches() -> [KillSwitch] {
        var triggered: [KillSwitch] = []

        if semanticLatency > 2.0 {
            triggered.append(.semanticLatency(semanticLatency))
        }
        if falsePositiveRate > 0.2 {
            triggered.append(.falsePositiveRate(falsePositiveRate))
        }
        if memoryUsage > 1_000_000_000 {
            triggered.append(.memoryUsage(memoryUsage))
        }
        if crashRate > 0.01 {
            triggered.append(.crashRate(crashRate))
        }

        return triggered
    }
}

/// Kill switches for monitoring critical metrics
enum KillSwitch {
    case semanticLatency(TimeInterval)
    case falsePositiveRate(Float)
    case memoryUsage(Int64)
    case crashRate(Float)
    case userChurn(Float)
}
