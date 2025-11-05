//
//  PerformanceOptimizer.swift
//  PDFOS
//
//  Performance optimizations for large documents (100+ pages)
//

import Foundation

/// Optimizes performance for large document operations
actor PerformanceOptimizer {
    // MARK: - Properties

    private let eventStore: EventStoreOptimized
    private let embeddingService: SemanticEmbeddingService

    // Configuration
    private let largeDocumentThreshold: Int
    private let batchSize: Int
    private let prefetchSize: Int
    private let maxMemoryUsage: Int

    // State
    private var activeOptimizations: Set<UUID> = []
    private var cachedPages: [UUID: [Int: CachedPage]] = [:]
    private var memoryPressureMode: Bool = false

    // MARK: - Initialization

    init(
        eventStore: EventStoreOptimized = EventStoreOptimized(),
        embeddingService: SemanticEmbeddingService = SemanticEmbeddingService.shared,
        largeDocumentThreshold: Int = 100,
        batchSize: Int = 10,
        prefetchSize: Int = 20,
        maxMemoryUsage: Int = 500_000_000 // 500MB
    ) {
        self.eventStore = eventStore
        self.embeddingService = embeddingService
        self.largeDocumentThreshold = largeDocumentThreshold
        self.batchSize = batchSize
        self.prefetchSize = prefetchSize
        self.maxMemoryUsage = maxMemoryUsage
    }

    // MARK: - Public Methods

    /// Optimizes document for large-scale operations
    /// - Parameter document: The document to optimize
    /// - Returns: Optimized document configuration
    func optimizeDocument(_ document: PDFDocument) async throws -> OptimizationResult {
        let startTime = Date()

        // Check if optimization is needed
        guard document.pages.count >= largeDocumentThreshold else {
            return OptimizationResult(
                documentId: document.id,
                optimizationsApplied: [],
                duration: Date().timeIntervalSince(startTime)
            )
        }

        var optimizations: [Optimization] = []

        // 1. Enable lazy loading
        if !activeOptimizations.contains(document.id) {
            activeOptimizations.insert(document.id)
            optimizations.append(.lazyLoadingEnabled)
        }

        // 2. Pre-warm caches
        await warmCaches(for: document)
        optimizations.append(.cacheWarmed)

        // 3. Optimize event store
        try await eventStore.optimizeStorage()
        optimizations.append(.storageOptimized)

        // 4. Enable memory pressure monitoring
        startMemoryMonitoring(for: document.id)
        optimizations.append(.memoryMonitoringEnabled)

        let duration = Date().timeIntervalSince(startTime)

        return OptimizationResult(
            documentId: document.id,
            optimizationsApplied: optimizations,
            duration: duration
        )
    }

    /// Loads document pages in batches for better performance
    /// - Parameters:
    ///   - document: The document
    ///   - pageRange: Range of pages to load
    ///   - progress: Progress callback
    /// - Returns: Loaded page data
    func loadPagesBatched(
        document: PDFDocument,
        pageRange: Range<Int>,
        progress: ((Double) -> Void)? = nil
    ) async throws -> [PageData] {
        var allPages: [PageData] = []
        let totalPages = pageRange.count

        // Process in batches
        for batchStart in stride(from: pageRange.lowerBound, to: pageRange.upperBound, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, pageRange.upperBound)
            let batch = batchStart..<batchEnd

            // Check memory pressure
            if memoryPressureMode {
                try await handleMemoryPressure()
            }

            // Load batch
            let batchPages = try await loadPageBatch(document: document, pages: batch)
            allPages.append(contentsOf: batchPages)

            // Report progress
            let completed = Double(allPages.count) / Double(totalPages)
            progress?(completed)

            // Prefetch next batch
            let nextBatchStart = batchEnd
            let nextBatchEnd = min(nextBatchStart + prefetchSize, pageRange.upperBound)
            if nextBatchStart < nextBatchEnd {
                Task.detached {
                    await self.prefetchPages(document: document, pages: nextBatchStart..<nextBatchEnd)
                }
            }
        }

        return allPages
    }

    /// Processes events in batches for large documents
    /// - Parameters:
    ///   - documentId: Document ID
    ///   - processor: Event processing closure
    ///   - progress: Progress callback
    func processEventsBatched(
        documentId: UUID,
        from startDate: Date,
        to endDate: Date,
        processor: @escaping ([PDFEvent]) async throws -> Void,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        // Get total event count
        let allEvents = await eventStore.getEvents(
            documentId: documentId,
            from: startDate,
            to: endDate
        )

        let totalEvents = allEvents.count

        // Process in batches
        for batchStart in stride(from: 0, to: totalEvents, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalEvents)
            let batch = Array(allEvents[batchStart..<batchEnd])

            // Process batch
            try await processor(batch)

            // Report progress
            let completed = Double(batchEnd) / Double(totalEvents)
            progress?(completed)

            // Check memory
            if memoryPressureMode {
                try await handleMemoryPressure()
            }
        }
    }

    /// Generates embeddings in optimized batches
    /// - Parameters:
    ///   - units: Semantic units to process
    ///   - progress: Progress callback
    /// - Returns: Generated embeddings
    func generateEmbeddingsBatched(
        units: [SemanticUnit],
        progress: ((Double) -> Void)? = nil
    ) async throws -> [SemanticEmbedding] {
        var embeddings: [SemanticEmbedding] = []
        let totalUnits = units.count

        // Determine optimal batch size based on available memory
        let optimalBatchSize = await calculateOptimalBatchSize()

        for batchStart in stride(from: 0, to: totalUnits, by: optimalBatchSize) {
            let batchEnd = min(batchStart + optimalBatchSize, totalUnits)
            let batch = Array(units[batchStart..<batchEnd])

            // Generate embeddings for batch
            let batchEmbeddings = try await embeddingService.generateEmbeddings(for: batch)
            embeddings.append(contentsOf: batchEmbeddings)

            // Report progress
            let completed = Double(embeddings.count) / Double(totalUnits)
            progress?(completed)

            // Yield to prevent blocking
            await Task.yield()
        }

        return embeddings
    }

    /// Time travels through large document history efficiently
    /// - Parameters:
    ///   - document: The document
    ///   - targetDate: Date to travel to
    ///   - progress: Progress callback
    /// - Returns: Reconstructed document state
    func timeTravelOptimized(
        document: PDFDocument,
        to targetDate: Date,
        progress: ((Double) -> Void)? = nil
    ) async throws -> PDFDocument {
        let startTime = Date()

        // 1. Find nearest snapshot
        let snapshot = await eventStore.getNearestSnapshot(
            documentId: document.id,
            before: targetDate
        )

        var currentState = snapshot?.state ?? document
        progress?(0.2)

        // 2. Get events from snapshot to target
        let snapshotDate = snapshot?.timestamp ?? Date.distantPast
        let events = await eventStore.getEvents(
            documentId: document.id,
            from: snapshotDate,
            to: targetDate
        )

        progress?(0.4)

        // 3. Apply events in batches
        let totalEvents = events.count
        var processedEvents = 0

        for batchStart in stride(from: 0, to: totalEvents, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, totalEvents)
            let batch = Array(events[batchStart..<batchEnd])

            // Apply batch
            for event in batch {
                currentState = try await applyEvent(event, to: currentState)
                processedEvents += 1

                // Report progress (40% - 100%)
                let eventProgress = Double(processedEvents) / Double(totalEvents)
                let totalProgress = 0.4 + (eventProgress * 0.6)
                progress?(totalProgress)
            }

            // Check memory
            if memoryPressureMode {
                try await handleMemoryPressure()
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        print("Time travel completed in \(String(format: "%.2f", duration))s")

        return currentState
    }

    /// Clears optimization caches for a document
    func clearOptimizations(for documentId: UUID) async {
        activeOptimizations.remove(documentId)
        cachedPages.removeValue(forKey: documentId)
    }

    /// Gets current memory usage
    func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    // MARK: - Private Methods

    private func warmCaches(for document: PDFDocument) async {
        // Warm up first few pages
        let pagesToWarm = min(10, document.pages.count)
        let _ = try? await loadPageBatch(
            document: document,
            pages: 0..<pagesToWarm
        )

        // Warm up recent events
        let recentDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let _ = await eventStore.getEvents(
            documentId: document.id,
            from: recentDate,
            to: Date()
        )
    }

    private func loadPageBatch(
        document: PDFDocument,
        pages: Range<Int>
    ) async throws -> [PageData] {
        var pageData: [PageData] = []

        for pageIndex in pages {
            guard pageIndex < document.pages.count else { continue }

            // Check cache first
            if let cached = cachedPages[document.id]?[pageIndex],
               !cached.isExpired {
                pageData.append(cached.data)
                continue
            }

            // Load page
            let page = document.pages[pageIndex]
            let data = PageData(
                index: pageIndex,
                pageId: page.id,
                content: page.content,
                metadata: page.metadata
            )

            pageData.append(data)

            // Cache it
            cachePagee(documentId: document.id, pageIndex: pageIndex, data: data)
        }

        return pageData
    }

    private func prefetchPages(
        document: PDFDocument,
        pages: Range<Int>
    ) async {
        let _ = try? await loadPageBatch(document: document, pages: pages)
    }

    private func cachePagee(
        documentId: UUID,
        pageIndex: Int,
        data: PageData
    ) {
        if cachedPages[documentId] == nil {
            cachedPages[documentId] = [:]
        }

        cachedPages[documentId]?[pageIndex] = CachedPage(
            data: data,
            cachedAt: Date()
        )

        // Evict old pages if cache is too large
        trimCacheIfNeeded(for: documentId)
    }

    private func trimCacheIfNeeded(for documentId: UUID) {
        guard let cache = cachedPages[documentId],
              cache.count > 50 else { return }

        // Keep only 30 most recently cached pages
        let sorted = cache.sorted { $0.value.cachedAt > $1.value.cachedAt }
        let toKeep = Dictionary(uniqueKeysWithValues: sorted.prefix(30))

        cachedPages[documentId] = toKeep
    }

    private func startMemoryMonitoring(for documentId: UUID) {
        Task {
            while activeOptimizations.contains(documentId) {
                let currentMemory = getMemoryUsage()

                if currentMemory > maxMemoryUsage {
                    memoryPressureMode = true
                } else if currentMemory < maxMemoryUsage * 80 / 100 {
                    memoryPressureMode = false
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }

    private func handleMemoryPressure() async throws {
        // Clear least recently used caches
        for documentId in cachedPages.keys {
            if let cache = cachedPages[documentId], cache.count > 10 {
                // Keep only 10 most recent
                let sorted = cache.sorted { $0.value.cachedAt > $1.value.cachedAt }
                cachedPages[documentId] = Dictionary(uniqueKeysWithValues: sorted.prefix(10))
            }
        }

        // Yield to allow garbage collection
        await Task.yield()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }

    private func calculateOptimalBatchSize() async -> Int {
        let currentMemory = getMemoryUsage()
        let availableMemory = maxMemoryUsage - currentMemory

        // Each embedding takes ~3KB (768 * 4 bytes)
        let estimatedEmbeddingSize = 3000
        let optimalSize = max(1, availableMemory / (estimatedEmbeddingSize * 10))

        return min(optimalSize, 32) // Cap at 32 for reasonable batch sizes
    }

    private func applyEvent(_ event: PDFEvent, to document: PDFDocument) async throws -> PDFDocument {
        // TODO: Implement actual event application
        // For now, return document unchanged
        return document
    }
}

// MARK: - Supporting Types

/// Cached page data
struct CachedPage {
    let data: PageData
    let cachedAt: Date
    let ttl: TimeInterval = 300 // 5 minutes

    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }
}

/// Page data structure
struct PageData {
    let index: Int
    let pageId: UUID
    let content: Data
    let metadata: PageMetadata
}

/// Page metadata
struct PageMetadata: Codable {
    let size: CGSize
    let rotation: Int
    let hasAnnotations: Bool
    let hasImages: Bool
}

/// Optimization result
struct OptimizationResult {
    let documentId: UUID
    let optimizationsApplied: [Optimization]
    let duration: TimeInterval
}

/// Applied optimizations
enum Optimization {
    case lazyLoadingEnabled
    case cacheWarmed
    case storageOptimized
    case memoryMonitoringEnabled
    case batchProcessingEnabled
}

/// Performance statistics
struct PerformanceStatistics {
    var totalOperations: Int = 0
    var averageLatency: TimeInterval = 0
    var peakMemoryUsage: Int = 0
    var cacheHitRate: Double = 0
    var optimizationsActive: Int = 0
}
