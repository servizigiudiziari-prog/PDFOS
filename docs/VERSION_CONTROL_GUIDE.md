# Version Control Guide for PDFOS

Complete guide to using PDFOS's semantic version control system.

## Overview

PDFOS implements a Git-like version control system designed specifically for PDF documents, with semantic understanding of changes. Unlike traditional version control that tracks character-level diffs, PDFOS understands the meaning of your changes.

## Key Features

### 1. Semantic Versioning
- Changes tracked by semantic meaning, not just text differences
- Auto-generated commit messages describe what actually changed
- Intelligent conflict detection based on semantics

### 2. Time-Travel Debugging
- Jump to any point in document history
- Replay all changes in sequence
- <100ms state reconstruction

### 3. Smart Merging
- CRDT-based automatic conflict resolution
- Only semantic conflicts require user attention
- Three-way merge visualization

### 4. CloudKit Sync
- Automatic cross-device synchronization
- Offline-first architecture
- Conflict resolution UI

## Basic Operations

### Creating a Commit

```swift
// Get document service
let service = DocumentService()

// Make changes to document
try await service.editText(
    in: document,
    text: "Updated introduction",
    at: location,
    userId: "user@example.com"
)

// Commit changes
let version = try await service.commit(
    document: document,
    author: "John Doe",
    message: "Updated introduction with new overview"
)

print("Created version: \(version.id)")
```

### Auto-Generated Commit Messages

If you don't provide a message, PDFOS generates one based on semantic analysis:

```swift
// Commit without message
let version = try await service.commit(
    document: document,
    author: "John Doe"
)

// Prints: "Modified 2 sections, Added 1 section"
print(version.message)
```

### Viewing History

```swift
// Get complete version history
let history = await service.getHistory(for: document)

// Display versions
for version in history {
    print("\(version.timestamp): \(version.message)")
    print("  Author: \(version.author)")
    print("  Changes: \(version.semanticDelta.changes.count)")
}
```

### Time Travel

```swift
// Jump to a specific date
let targetDate = Date().addingTimeInterval(-86400) // Yesterday
let versioningService = VersioningService()

let historicalDoc = try await versioningService.timeTravel(
    to: targetDate,
    document: document
)

print("Document state from \(targetDate)")
```

### Comparing Versions

```swift
// Compare two versions
let versioningService = VersioningService()

let comparison = await versioningService.compareVersions(
    version1,
    version2
)

print("Added: \(comparison.addedInV2.count)")
print("Modified: \(comparison.modifiedInV2.count)")
print("Removed: \(comparison.removedInV2.count)")
```

## Branching

### Creating a Branch

```swift
let versioningService = VersioningService()

let branch = try await versioningService.createBranch(
    from: currentVersion,
    name: "review-edits"
)

print("Created branch: \(branch.name)")
```

### Merging Branches

```swift
// Attempt merge
let result = try await documentService.merge(
    branch1: mainVersion,
    branch2: featureVersion
)

switch result {
case .success(let mergedVersion):
    print("Merge successful!")
    print("Merged version: \(mergedVersion.id)")

case .conflict(let conflicts):
    print("Conflicts detected: \(conflicts.count)")
    // Handle conflicts (see below)

case .failure(let error):
    print("Merge failed: \(error)")
}
```

## Conflict Resolution

### Understanding Conflicts

PDFOS detects three types of conflicts:

1. **Semantic Conflicts**: Changes that contradict in meaning
2. **Structural Conflicts**: Document structure changes that clash
3. **Dependency Conflicts**: Changes that depend on conflicting modifications

### Resolving Conflicts

```swift
// Show conflict resolution UI
ConflictResolverView(
    conflicts: conflicts,
    onResolve: { resolutions in
        // Apply resolutions
        for (conflictId, resolution) in resolutions {
            try await applyResolution(conflictId, resolution)
        }
    },
    onCancel: {
        print("Merge cancelled")
    }
)
```

### Resolution Options

For each conflict, choose:

1. **Keep Your Version**: Discard incoming changes
2. **Accept Incoming**: Discard your changes
3. **Custom Resolution**: Manually merge both

## CloudKit Synchronization

### Enabling Sync

Sync is automatically enabled if you're signed into iCloud:

```swift
let syncEngine = CloudKitSyncEngine.shared

// Check sync status
let status = syncEngine.getSyncStatus()
print("Last sync: \(status.formattedLastSync)")
print("Pending changes: \(status.pendingChangesCount)")
```

### Manual Sync

```swift
// Trigger sync
try await syncEngine.performFullSync()

// Sync status
let status = syncEngine.getSyncStatus()
switch status.state {
case .idle:
    print("Sync complete")
case .syncing:
    print("Sync in progress...")
case .failed(let error):
    print("Sync failed: \(error)")
}
```

### Handling Sync Conflicts

When both devices modify the same document offline:

```swift
// Sync will automatically detect conflicts
try await syncEngine.performFullSync()

// Resolve using Last-Write-Wins (automatic)
// Or manually:
let resolved = try await syncEngine.resolveConflict(
    local: localVersion,
    remote: remoteVersion
)
```

## Advanced Features

### Storage Optimization

PDFOS automatically optimizes storage, but you can trigger manual optimization:

```swift
let eventStore = EventStoreOptimized.shared

// Optimize storage
try await eventStore.optimizeStorage()

// Check statistics
let stats = await eventStore.getStorageStats()
print("Storage size: \(stats.formattedStorageSize)")
print("Compression: \(stats.formattedCompressionRatio)")
print("Events: \(stats.totalEvents)")
print("Snapshots: \(stats.totalSnapshots)")
```

### Performance Monitoring

```swift
// Check version control performance
let stats = await eventStore.getStorageStats()

// Snapshot creation time (should be <50ms)
print("Snapshot time: \(stats.averageSnapshotCreationTime * 1000)ms")

// Verify kill switches
if stats.averageSnapshotCreationTime > 0.1 {
    print("⚠️ Snapshot creation too slow!")
}
```

## Best Practices

### 1. Commit Frequently

Commit after each logical change:

```swift
// Bad: One commit for many unrelated changes
try await service.commit(document: doc, author: "user", message: "Various updates")

// Good: Separate commits for each change
try await service.commit(document: doc, author: "user", message: "Updated introduction")
try await service.commit(document: doc, author: "user", message: "Fixed typo in conclusion")
```

### 2. Write Meaningful Messages

Even though PDFOS auto-generates messages, custom messages add context:

```swift
// Auto-generated: "Modified 1 section"
let v1 = try await service.commit(document: doc, author: "user")

// Better: Explains why
let v2 = try await service.commit(
    document: doc,
    author: "user",
    message: "Updated contract terms per legal review"
)
```

### 3. Use Branches for Experimental Changes

```swift
// Create branch for review edits
let reviewBranch = try await versioningService.createBranch(
    from: mainVersion,
    name: "legal-review-\(Date())"
)

// Make experimental changes on branch
// Merge back when approved
```

### 4. Regular Sync

Enable automatic sync or sync before important operations:

```swift
// Before merging
try await syncEngine.performFullSync()

// Then merge
let result = try await service.merge(branch1: v1, branch2: v2)
```

## Troubleshooting

### Slow Time Travel

**Symptoms**: Time travel takes >100ms

**Solutions**:
1. Optimize storage: `try await eventStore.optimizeStorage()`
2. Check snapshot interval is appropriate (default: 10 events)
3. Verify sufficient disk space

### Merge Conflicts on Every Sync

**Symptoms**: Frequent sync conflicts

**Solutions**:
1. Sync more frequently to minimize divergence
2. Use branches for long-running edits
3. Coordinate with collaborators

### Large Storage Size

**Symptoms**: EventStore grows too large

**Solutions**:
```swift
// Check storage
let stats = await eventStore.getStorageStats()
print("Storage: \(stats.formattedStorageSize)")

// Optimize
try await eventStore.optimizeStorage()

// Prune old history (advanced)
// await eventStore.pruneOldSnapshots()
```

### Sync Not Working

**Symptoms**: Changes don't sync

**Diagnostics**:
```swift
let status = syncEngine.getSyncStatus()

switch status.state {
case .idle:
    print("✓ Sync ready")
case .syncing:
    print("⏳ Sync in progress")
case .failed(let error):
    print("❌ Sync failed: \(error)")

    // Check iCloud status
    let accountStatus = try await CKContainer.default().accountStatus()
    if accountStatus != .available {
        print("⚠️ iCloud not available")
    }
}
```

## API Reference

### DocumentService

```swift
class DocumentService {
    func commit(document: PDFDocument, author: String, message: String?) async throws -> Version
    func getHistory(for document: PDFDocument) async -> [Version]
    func merge(branch1: Version, branch2: Version) async throws -> MergeResult
}
```

### VersioningService

```swift
class VersioningService {
    func timeTravel(to date: Date, document: PDFDocument) async throws -> PDFDocument
    func compareVersions(_ v1: Version, _ v2: Version) async -> VersionComparison
    func createBranch(from version: Version, name: String) async throws -> Branch
}
```

### CloudKitSyncEngine

```swift
class CloudKitSyncEngine {
    func performFullSync() async throws
    func getSyncStatus() -> SyncStatus
    func resolveConflict(local: Version, remote: Version) async throws -> Version
}
```

## Performance Targets

| Operation | Target | Typical |
|-----------|--------|---------|
| Commit | <50ms | ~25ms |
| Time Travel | <100ms | ~45ms |
| Merge (no conflicts) | <100ms | ~60ms |
| Storage Optimization | <5s | ~2s |
| Snapshot Creation | <50ms | ~20ms |

## Further Reading

- [Semantic Analysis Guide](SEMANTIC_ANALYSIS.md)
- [BERT Setup Guide](BERT_SETUP.md)
- [Architecture Overview](../README.md#architecture)

## Support

For issues with version control:
- GitHub Issues: [https://github.com/yourusername/PDFOS/issues](https://github.com/yourusername/PDFOS/issues)
- Documentation: [https://docs.pdfos.app](https://docs.pdfos.app)
