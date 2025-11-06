//
//  ReportGenerator.swift
//  PDFOS
//
//  Generates comprehensive PDF reports of document history and analytics
//

import Foundation
#if canImport(PDFKit) && canImport(AppKit)
import PDFKit
import AppKit
#endif

/// Generates detailed PDF reports of document history
actor ReportGenerator {
    // MARK: - Properties

    private let pageSize: CGSize
    private let margins: CGFloat

    // MARK: - Initialization

    init(
        pageSize: CGSize = CGSize(width: 612, height: 792), // US Letter
        margins: CGFloat = 50
    ) {
        self.pageSize = pageSize
        self.margins = margins
    }

    // MARK: - Public Methods

    /// Generates a summary report of document history
    /// - Parameters:
    ///   - document: The document
    ///   - from: Start date for analysis
    ///   - to: End date for analysis
    /// - Returns: URL to the generated PDF report
    func generateSummaryReport(
        document: PDFDocument,
        from startDate: Date,
        to endDate: Date
    ) async throws -> URL {
        let startTime = Date()

        // Gather data
        let eventStore = EventStore()
        let events = await eventStore.getEvents(
            documentId: document.id,
            from: startDate,
            to: endDate
        )

        let statistics = calculateStatistics(events: events)

        // Create PDF
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("history_summary_\(UUID().uuidString).pdf")

        try await createPDFReport(
            outputURL: outputURL,
            document: document,
            statistics: statistics,
            events: events,
            reportType: .summary
        )

        let duration = Date().timeIntervalSince(startTime)
        print("Summary report generated in \(String(format: "%.2f", duration))s")
        print("Output: \(outputURL.path)")

        return outputURL
    }

    /// Generates a detailed report with all changes
    func generateDetailedReport(
        document: PDFDocument,
        from startDate: Date,
        to endDate: Date
    ) async throws -> URL {
        let eventStore = EventStore()
        let events = await eventStore.getEvents(
            documentId: document.id,
            from: startDate,
            to: endDate
        )

        let statistics = calculateStatistics(events: events)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("history_detailed_\(UUID().uuidString).pdf")

        try await createPDFReport(
            outputURL: outputURL,
            document: document,
            statistics: statistics,
            events: events,
            reportType: .detailed
        )

        return outputURL
    }

    /// Generates an audit trail report for compliance
    func generateAuditReport(
        document: PDFDocument,
        from startDate: Date,
        to endDate: Date
    ) async throws -> URL {
        let eventStore = EventStore()
        let events = await eventStore.getEvents(
            documentId: document.id,
            from: startDate,
            to: endDate
        )

        let statistics = calculateStatistics(events: events)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit_trail_\(UUID().uuidString).pdf")

        try await createPDFReport(
            outputURL: outputURL,
            document: document,
            statistics: statistics,
            events: events,
            reportType: .audit
        )

        return outputURL
    }

    /// Generates an analytics report with performance metrics
    func generateAnalyticsReport(
        document: PDFDocument
    ) async throws -> URL {
        let analyticsEngine = AnalyticsEngine.shared
        let reports = await analyticsEngine.generateReport(period: .allTime)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("analytics_\(UUID().uuidString).pdf")

        try await createAnalyticsPDF(
            outputURL: outputURL,
            document: document,
            reports: reports
        )

        return outputURL
    }

    // MARK: - Statistics Calculation

    private func calculateStatistics(events: [PDFEvent]) -> DetailedDocumentStatistics {
        var stats = DetailedDocumentStatistics()

        stats.totalEvents = events.count
        stats.dateRange = DateInterval(
            start: events.first?.timestamp ?? Date(),
            end: events.last?.timestamp ?? Date()
        )

        // Count by event type
        var typeCounts: [EventType: Int] = [:]
        var userCounts: [String: Int] = [:]
        var dailyCounts: [String: Int] = [:]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for event in events {
            // Type counts
            typeCounts[event.type, default: 0] += 1

            // User counts
            userCounts[event.userId, default: 0] += 1

            // Daily activity
            let day = dateFormatter.string(from: event.timestamp)
            dailyCounts[day, default: 0] += 1
        }

        stats.eventsByType = typeCounts
        stats.eventsByUser = userCounts
        stats.dailyActivity = dailyCounts

        // Calculate activity metrics
        if events.count >= 2 {
            let timespan = events.last!.timestamp.timeIntervalSince(events.first!.timestamp)
            let days = max(1, timespan / 86400)
            stats.averageEventsPerDay = Double(events.count) / days

            // Find most active day
            if let maxDay = dailyCounts.max(by: { $0.value < $1.value }) {
                stats.mostActiveDay = dateFormatter.date(from: maxDay.key)
                stats.maxEventsInDay = maxDay.value
            }
        }

        // Unique contributors
        stats.uniqueUsers = userCounts.keys.count

        return stats
    }

    // MARK: - PDF Creation

    private func createPDFReport(
        outputURL: URL,
        document: PDFDocument,
        statistics: DetailedDocumentStatistics,
        events: [PDFEvent],
        reportType: ReportType
    ) async throws {
        #if canImport(PDFKit) && canImport(AppKit)
        // Create PDF context
        guard let context = CGContext(outputURL as CFURL, mediaBox: nil, nil) else {
            throw ReportError.contextCreationFailed
        }

        var pageRect = CGRect(origin: .zero, size: pageSize)

        // Page 1: Cover and Summary
        context.beginPDFPage(nil)
        drawCoverPage(context: context, document: document, statistics: statistics, pageRect: pageRect)
        context.endPDFPage()

        // Page 2: Statistics
        context.beginPDFPage(nil)
        drawStatisticsPage(context: context, statistics: statistics, pageRect: pageRect)
        context.endPDFPage()

        // Page 3+: Timeline and Events
        if reportType == .detailed || reportType == .audit {
            let eventsPerPage = reportType == .audit ? 15 : 20
            let eventPages = (events.count + eventsPerPage - 1) / eventsPerPage

            for pageIndex in 0..<eventPages {
                context.beginPDFPage(nil)
                let start = pageIndex * eventsPerPage
                let end = min(start + eventsPerPage, events.count)
                let pageEvents = Array(events[start..<end])

                drawEventsPage(
                    context: context,
                    events: pageEvents,
                    pageRect: pageRect,
                    pageNumber: pageIndex + 3,
                    reportType: reportType
                )
                context.endPDFPage()
            }
        }

        context.closePDF()
        #else
        throw ReportError.pdfKitNotAvailable
        #endif
    }

    #if canImport(PDFKit) && canImport(AppKit)
    private func drawCoverPage(
        context: CGContext,
        document: PDFDocument,
        statistics: DetailedDocumentStatistics,
        pageRect: CGRect
    ) {
        var yPosition = pageRect.height - margins - 100

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 36),
            .foregroundColor: NSColor.black
        ]

        let title = "Document History Report"
        let titleSize = (title as NSString).size(withAttributes: titleAttributes)
        (title as NSString).draw(
            at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: yPosition),
            withAttributes: titleAttributes
        )

        yPosition -= 80

        // Document name
        let docNameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.darkGray
        ]

        let docName = document.metadata.title
        let docNameSize = (docName as NSString).size(withAttributes: docNameAttributes)
        (docName as NSString).draw(
            at: CGPoint(x: (pageRect.width - docNameSize.width) / 2, y: yPosition),
            withAttributes: docNameAttributes
        )

        yPosition -= 100

        // Summary box
        let boxRect = CGRect(
            x: margins,
            y: yPosition - 200,
            width: pageRect.width - 2 * margins,
            height: 200
        )

        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.1).cgColor)
        context.fill(boxRect)

        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let summary = """
        Document ID: \(document.id.uuidString)
        Total Events: \(statistics.totalEvents)
        Period: \(formatter.string(from: statistics.dateRange.start)) - \(formatter.string(from: statistics.dateRange.end))
        Contributors: \(statistics.uniqueUsers)
        Average Activity: \(String(format: "%.1f", statistics.averageEventsPerDay)) events/day

        Report Generated: \(formatter.string(from: Date()))
        """

        (summary as NSString).draw(
            in: boxRect.insetBy(dx: 20, dy: 20),
            withAttributes: summaryAttributes
        )

        yPosition -= 250

        // Footer
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]

        let footer = "Generated by PDFOS - Semantic PDF Version Control System"
        let footerSize = (footer as NSString).size(withAttributes: footerAttributes)
        (footer as NSString).draw(
            at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: 30),
            withAttributes: footerAttributes
        )
    }

    private func drawStatisticsPage(
        context: CGContext,
        statistics: DetailedDocumentStatistics,
        pageRect: CGRect
    ) {
        var yPosition = pageRect.height - margins

        // Page title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]

        let title = "Activity Statistics"
        (title as NSString).draw(
            at: CGPoint(x: margins, y: yPosition - 30),
            withAttributes: titleAttributes
        )

        yPosition -= 80

        // Events by type
        yPosition = drawSection(
            context: context,
            title: "Events by Type",
            yPosition: yPosition,
            pageRect: pageRect
        ) { y in
            var currentY = y
            let sorted = statistics.eventsByType.sorted { $0.value > $1.value }

            for (type, count) in sorted.prefix(10) {
                let percentage = Double(count) / Double(statistics.totalEvents) * 100
                let text = "\(describeEventType(type)): \(count) (\(String(format: "%.1f", percentage))%)"

                currentY = drawText(
                    context: context,
                    text: text,
                    yPosition: currentY,
                    xPosition: margins + 20
                )
                currentY -= 25
            }

            return currentY
        }

        yPosition -= 40

        // Activity timeline chart
        yPosition = drawSection(
            context: context,
            title: "Daily Activity",
            yPosition: yPosition,
            pageRect: pageRect
        ) { y in
            drawActivityChart(
                context: context,
                statistics: statistics,
                yPosition: y,
                pageRect: pageRect
            )
        }

        // Page number
        drawPageNumber(context: context, pageNumber: 2, pageRect: pageRect)
    }

    private func drawEventsPage(
        context: CGContext,
        events: [PDFEvent],
        pageRect: CGRect,
        pageNumber: Int,
        reportType: ReportType
    ) {
        var yPosition = pageRect.height - margins

        // Page title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 20),
            .foregroundColor: NSColor.black
        ]

        let title = reportType == .audit ? "Audit Trail" : "Event Timeline"
        (title as NSString).draw(
            at: CGPoint(x: margins, y: yPosition - 25),
            withAttributes: titleAttributes
        )

        yPosition -= 60

        // Table header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]

        let headerRect = CGRect(
            x: margins,
            y: yPosition - 20,
            width: pageRect.width - 2 * margins,
            height: 20
        )

        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(headerRect)

        ("Timestamp" as NSString).draw(
            at: CGPoint(x: margins + 5, y: yPosition - 18),
            withAttributes: headerAttributes
        )

        ("Event" as NSString).draw(
            at: CGPoint(x: margins + 120, y: yPosition - 18),
            withAttributes: headerAttributes
        )

        ("User" as NSString).draw(
            at: CGPoint(x: margins + 250, y: yPosition - 18),
            withAttributes: headerAttributes
        )

        if reportType == .audit {
            ("Hash" as NSString).draw(
                at: CGPoint(x: margins + 350, y: yPosition - 18),
                withAttributes: headerAttributes
            )
        }

        yPosition -= 25

        // Event rows
        let rowAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.black
        ]

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"

        for (index, event) in events.enumerated() {
            // Alternating row background
            if index % 2 == 0 {
                let rowRect = CGRect(
                    x: margins,
                    y: yPosition - 18,
                    width: pageRect.width - 2 * margins,
                    height: 18
                )
                context.setFillColor(NSColor.systemGray.withAlphaComponent(0.05).cgColor)
                context.fill(rowRect)
            }

            // Timestamp
            (formatter.string(from: event.timestamp) as NSString).draw(
                at: CGPoint(x: margins + 5, y: yPosition - 15),
                withAttributes: rowAttributes
            )

            // Event type
            (describeEventType(event.type) as NSString).draw(
                at: CGPoint(x: margins + 120, y: yPosition - 15),
                withAttributes: rowAttributes
            )

            // User
            let userName = event.userId.prefix(12)
            (String(userName) as NSString).draw(
                at: CGPoint(x: margins + 250, y: yPosition - 15),
                withAttributes: rowAttributes
            )

            // Hash (audit only)
            if reportType == .audit {
                let hash = event.semanticHash.prefix(10)
                (String(hash) as NSString).draw(
                    at: CGPoint(x: margins + 350, y: yPosition - 15),
                    withAttributes: rowAttributes
                )
            }

            yPosition -= 18
        }

        // Page number
        drawPageNumber(context: context, pageNumber: pageNumber, pageRect: pageRect)
    }

    private func drawActivityChart(
        context: CGContext,
        statistics: DetailedDocumentStatistics,
        yPosition: CGFloat,
        pageRect: CGRect
    ) -> CGFloat {
        let chartRect = CGRect(
            x: margins + 20,
            y: yPosition - 150,
            width: pageRect.width - 2 * margins - 40,
            height: 120
        )

        // Draw axes
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)

        context.move(to: CGPoint(x: chartRect.minX, y: chartRect.minY))
        context.addLine(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
        context.addLine(to: CGPoint(x: chartRect.maxX, y: chartRect.maxY))
        context.strokePath()

        // Draw bars
        if !statistics.dailyActivity.isEmpty {
            let sorted = statistics.dailyActivity.sorted { $0.key < $1.key }
            let maxCount = sorted.map { $0.value }.max() ?? 1
            let barWidth = chartRect.width / CGFloat(sorted.count)

            for (index, (_, count)) in sorted.enumerated() {
                let barHeight = CGFloat(count) / CGFloat(maxCount) * chartRect.height
                let barRect = CGRect(
                    x: chartRect.minX + CGFloat(index) * barWidth,
                    y: chartRect.maxY - barHeight,
                    width: max(1, barWidth - 2),
                    height: barHeight
                )

                context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.7).cgColor)
                context.fill(barRect)
            }
        }

        return yPosition - 170
    }

    private func drawSection(
        context: CGContext,
        title: String,
        yPosition: CGFloat,
        pageRect: CGRect,
        content: (CGFloat) -> CGFloat
    ) -> CGFloat {
        // Section title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]

        (title as NSString).draw(
            at: CGPoint(x: margins, y: yPosition - 20),
            withAttributes: titleAttributes
        )

        // Draw content
        let contentY = content(yPosition - 30)

        return contentY - 20
    }

    private func drawText(
        context: CGContext,
        text: String,
        yPosition: CGFloat,
        xPosition: CGFloat
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]

        (text as NSString).draw(
            at: CGPoint(x: xPosition, y: yPosition),
            withAttributes: attributes
        )

        return yPosition
    }

    private func drawPageNumber(
        context: CGContext,
        pageNumber: Int,
        pageRect: CGRect
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]

        let text = "Page \(pageNumber)"
        let size = (text as NSString).size(withAttributes: attributes)

        (text as NSString).draw(
            at: CGPoint(x: (pageRect.width - size.width) / 2, y: 20),
            withAttributes: attributes
        )
    }
    #endif

    private func createAnalyticsPDF(
        outputURL: URL,
        document: PDFDocument,
        reports: [AnalyticsReport]
    ) async throws {
        #if canImport(PDFKit) && canImport(AppKit)
        guard let context = CGContext(outputURL as CFURL, mediaBox: nil, nil) else {
            throw ReportError.contextCreationFailed
        }

        let pageRect = CGRect(origin: .zero, size: pageSize)

        // Page 1: Analytics summary
        context.beginPDFPage(nil)
        drawAnalyticsPage(context: context, document: document, reports: reports, pageRect: pageRect)
        context.endPDFPage()

        context.closePDF()
        #else
        throw ReportError.pdfKitNotAvailable
        #endif
    }

    #if canImport(PDFKit) && canImport(AppKit)
    private func drawAnalyticsPage(
        context: CGContext,
        document: PDFDocument,
        reports: [AnalyticsReport],
        pageRect: CGRect
    ) {
        var yPosition = pageRect.height - margins

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]

        ("Performance Analytics" as NSString).draw(
            at: CGPoint(x: margins, y: yPosition - 30),
            withAttributes: titleAttributes
        )

        yPosition -= 80

        // Metrics for each report period
        for report in reports.prefix(4) {
            yPosition = drawMetricsSection(
                context: context,
                report: report,
                yPosition: yPosition,
                pageRect: pageRect
            )
            yPosition -= 40
        }
    }

    private func drawMetricsSection(
        context: CGContext,
        report: AnalyticsReport,
        yPosition: CGFloat,
        pageRect: CGRect
    ) -> CGFloat {
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]

        let periodName = describePeriod(report.period)
        (periodName as NSString).draw(
            at: CGPoint(x: margins, y: yPosition),
            withAttributes: sectionAttributes
        )

        var currentY = yPosition - 25

        let metrics = [
            "Avg Semantic Latency: \(String(format: "%.1f", report.avgSemanticLatency * 1000))ms",
            "Avg Memory Usage: \(String(format: "%.1f", report.avgMemoryUsage / 1_048_576))MB",
            "Total Events: \(report.totalEvents)",
            "Cache Hit Rate: \(String(format: "%.1f", report.cacheHitRate * 100))%"
        ]

        for metric in metrics {
            currentY = drawText(
                context: context,
                text: metric,
                yPosition: currentY,
                xPosition: margins + 20
            )
            currentY -= 20
        }

        return currentY
    }
    #endif

    // MARK: - Helper Methods

    private func describeEventType(_ type: EventType) -> String {
        switch type {
        case .textEdit: return "Text Edit"
        case .textInsert: return "Text Insert"
        case .textDelete: return "Text Delete"
        case .imageInsert: return "Image Insert"
        case .imageDelete: return "Image Delete"
        case .annotationAdd: return "Annotation Add"
        case .annotationRemove: return "Annotation Remove"
        case .pageAdd: return "Page Add"
        case .pageRemove: return "Page Remove"
        case .pageReorder: return "Page Reorder"
        case .metadataChange: return "Metadata Change"
        case .formFieldEdit: return "Form Edit"
        }
    }

    private func describePeriod(_ period: AnalyticsPeriod) -> String {
        switch period {
        case .last24Hours: return "Last 24 Hours"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .allTime: return "All Time"
        }
    }
}

// MARK: - Supporting Types

/// Detailed statistics about document history for reporting
struct DetailedDocumentStatistics {
    var totalEvents: Int = 0
    var dateRange: DateInterval = DateInterval()
    var eventsByType: [PDFEvent.EventType: Int] = [:]
    var eventsByUser: [String: Int] = [:]
    var dailyActivity: [String: Int] = [:]
    var uniqueUsers: Int = 0
    var averageEventsPerDay: Double = 0
    var mostActiveDay: Date?
    var maxEventsInDay: Int = 0
}

/// Report type
enum ReportType {
    case summary    // High-level overview
    case detailed   // All events listed
    case audit      // Compliance-focused with hashes
}

/// Report generation errors
enum ReportError: Error {
    case contextCreationFailed
    case pdfKitNotAvailable
    case noData
    case writeFailed
}

extension ReportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .contextCreationFailed:
            return "Failed to create PDF context"
        case .pdfKitNotAvailable:
            return "PDFKit is not available on this platform"
        case .noData:
            return "No data available for report"
        case .writeFailed:
            return "Failed to write PDF file"
        }
    }
}
