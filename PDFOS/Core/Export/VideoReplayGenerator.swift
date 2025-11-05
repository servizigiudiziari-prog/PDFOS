//
//  VideoReplayGenerator.swift
//  PDFOS
//
//  Generates video replay of document modifications using AVFoundation
//

import Foundation
#if canImport(AVFoundation) && canImport(CoreGraphics)
import AVFoundation
import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

/// Generates MP4 video replays of document history
actor VideoReplayGenerator {
    // MARK: - Properties

    private let frameRate: Int32
    private let resolution: CGSize
    private let quality: VideoQuality

    // MARK: - Initialization

    init(
        frameRate: Int32 = 30,
        resolution: CGSize = CGSize(width: 1920, height: 1080),
        quality: VideoQuality = .high
    ) {
        self.frameRate = frameRate
        self.resolution = resolution
        self.quality = quality
    }

    // MARK: - Public Methods

    /// Generates a video replay of document changes
    /// - Parameters:
    ///   - document: The document
    ///   - from: Start date
    ///   - to: End date
    ///   - speed: Playback speed multiplier
    /// - Returns: URL to the generated video
    func generateReplay(
        document: PDFDocument,
        from startDate: Date,
        to endDate: Date,
        speed: Float = 1.0
    ) async throws -> URL {
        let startTime = Date()

        // 1. Get events in time range
        let eventStore = EventStore()
        let events = await eventStore.getEvents(
            documentId: document.id,
            from: startDate,
            to: endDate
        )

        guard !events.isEmpty else {
            throw VideoError.noEventsInRange
        }

        // 2. Generate frames
        let frames = try await generateFrames(
            document: document,
            events: events,
            speed: speed
        )

        // 3. Create video from frames
        let outputURL = try await createVideo(
            from: frames,
            frameRate: Int32(Float(frameRate) * speed)
        )

        let duration = Date().timeIntervalSince(startTime)
        print("Video generated in \(String(format: "%.2f", duration))s")
        print("Output: \(outputURL.path)")

        return outputURL
    }

    /// Generates a quick preview video (lower quality, faster)
    func generatePreview(
        document: PDFDocument,
        from: Date,
        to: Date
    ) async throws -> URL {
        try await generateReplay(
            document: document,
            from: from,
            to: to,
            speed: 4.0
        )
    }

    // MARK: - Frame Generation

    private func generateFrames(
        document: PDFDocument,
        events: [PDFEvent],
        speed: Float
    ) async throws -> [VideoFrame] {
        var frames: [VideoFrame] = []
        var currentDocument = document

        // Add initial frame
        let initialFrame = try await renderFrame(
            document: currentDocument,
            timestamp: events.first?.timestamp ?? Date(),
            highlightedChanges: []
        )
        frames.append(initialFrame)

        // Generate frame for each significant change
        for (index, event) in events.enumerated() {
            // Apply event to document
            currentDocument = try await applyEvent(event, to: currentDocument)

            // Render frame with highlighted changes
            let frame = try await renderFrame(
                document: currentDocument,
                timestamp: event.timestamp,
                highlightedChanges: [event]
            )

            frames.append(frame)

            // Add intermediate frames for smooth animation (every 5 events)
            if index % 5 == 0 && index < events.count - 1 {
                let intermediateFrame = try await renderFrame(
                    document: currentDocument,
                    timestamp: event.timestamp,
                    highlightedChanges: []
                )
                frames.append(intermediateFrame)
            }
        }

        return frames
    }

    private func renderFrame(
        document: PDFDocument,
        timestamp: Date,
        highlightedChanges: [PDFEvent]
    ) async throws -> VideoFrame {
        #if canImport(AppKit)
        // Render PDF page to image
        let image = try await renderDocumentToImage(document)

        // Add overlay with change highlights
        let overlaidImage = addOverlay(
            to: image,
            changes: highlightedChanges,
            timestamp: timestamp
        )

        return VideoFrame(
            image: overlaidImage,
            timestamp: timestamp,
            changes: highlightedChanges
        )
        #else
        // Fallback for non-macOS platforms
        throw VideoError.renderingNotSupported
        #endif
    }

    #if canImport(AppKit)
    private func renderDocumentToImage(_ document: PDFDocument) async throws -> NSImage {
        // TODO: Implement actual PDF rendering with PDFKit
        // For now, create placeholder image

        let size = NSSize(width: resolution.width, height: resolution.height)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw document title
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let title = document.metadata.title as NSString
        title.draw(
            at: NSPoint(x: 50, y: resolution.height - 100),
            withAttributes: attributes
        )

        image.unlockFocus()

        return image
    }

    private func addOverlay(
        to image: NSImage,
        changes: [PDFEvent],
        timestamp: Date
    ) -> NSImage {
        let overlaidImage = NSImage(size: image.size)

        overlaidImage.lockFocus()

        // Draw original image
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)

        // Draw timestamp
        let timeString = formatTimestamp(timestamp)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]

        (timeString as NSString).draw(
            at: NSPoint(x: 20, y: 20),
            withAttributes: attributes
        )

        // Highlight changes
        for (index, change) in changes.enumerated() {
            let highlightRect = NSRect(
                x: 50,
                y: Double(image.size.height) - 200 - Double(index * 30),
                width: 400,
                height: 25
            )

            NSColor.yellow.withAlphaComponent(0.3).setFill()
            highlightRect.fill()

            let changeText = describeChange(change)
            (changeText as NSString).draw(
                in: highlightRect,
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.black
                ]
            )
        }

        overlaidImage.unlockFocus()

        return overlaidImage
    }
    #endif

    // MARK: - Video Creation

    private func createVideo(
        from frames: [VideoFrame],
        frameRate: Int32
    ) async throws -> URL {
        #if canImport(AVFoundation) && canImport(AppKit)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("replay_\(UUID().uuidString).mp4")

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: quality.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        writerInput.expectsMediaDataInRealTime = false

        // Pixel buffer adaptor
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: resolution.width,
                kCVPixelBufferHeightKey as String: resolution.height
            ]
        )

        writer.add(writerInput)

        guard writer.startWriting() else {
            throw VideoError.writerFailed(writer.error)
        }

        writer.startSession(atSourceTime: .zero)

        // Write frames
        var frameCount: Int64 = 0
        for frame in frames {
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            #if canImport(AppKit)
            if let pixelBuffer = createPixelBuffer(from: frame.image) {
                let presentationTime = CMTime(
                    value: frameCount,
                    timescale: frameRate
                )

                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                frameCount += 1
            }
            #endif
        }

        // Finish writing
        writerInput.markAsFinished()
        await writer.finishWriting()

        if writer.status == .completed {
            return outputURL
        } else {
            throw VideoError.writerFailed(writer.error)
        }
        #else
        throw VideoError.avFoundationNotAvailable
        #endif
    }

    #if canImport(AppKit)
    private func createPixelBuffer(from image: NSImage) -> CVPixelBuffer? {
        let width = Int(resolution.width)
        let height = Int(resolution.height)

        var pixelBuffer: CVPixelBuffer?

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        // Draw image into context
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return buffer
    }
    #endif

    // MARK: - Helper Methods

    private func applyEvent(_ event: PDFEvent, to document: PDFDocument) async throws -> PDFDocument {
        // TODO: Implement actual event application
        // For now, return document unchanged
        return document
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func describeChange(_ event: PDFEvent) -> String {
        switch event.type {
        case .textEdit: return "✏️ Text edited"
        case .textInsert: return "➕ Text inserted"
        case .textDelete: return "🗑️ Text deleted"
        case .imageInsert: return "🖼️ Image inserted"
        case .imageDelete: return "❌ Image deleted"
        case .annotationAdd: return "📝 Annotation added"
        case .annotationRemove: return "🚫 Annotation removed"
        case .pageAdd: return "📄 Page added"
        case .pageRemove: return "📄 Page removed"
        case .pageReorder: return "🔄 Pages reordered"
        case .metadataChange: return "ℹ️ Metadata changed"
        case .formFieldEdit: return "📋 Form field edited"
        }
    }
}

// MARK: - Supporting Types

/// Video frame with metadata
struct VideoFrame {
    #if canImport(AppKit)
    let image: NSImage
    #endif
    let timestamp: Date
    let changes: [PDFEvent]
}

/// Video quality settings
enum VideoQuality {
    case low
    case medium
    case high
    case ultra

    var bitrate: Int {
        switch self {
        case .low: return 2_000_000      // 2 Mbps
        case .medium: return 5_000_000   // 5 Mbps
        case .high: return 10_000_000    // 10 Mbps
        case .ultra: return 20_000_000   // 20 Mbps
        }
    }
}

/// Video generation errors
enum VideoError: Error {
    case noEventsInRange
    case renderingNotSupported
    case avFoundationNotAvailable
    case writerFailed(Error?)
    case invalidFrameData
}

extension VideoError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noEventsInRange:
            return "No events found in the specified time range"
        case .renderingNotSupported:
            return "Video rendering is not supported on this platform"
        case .avFoundationNotAvailable:
            return "AVFoundation is not available"
        case .writerFailed(let error):
            return "Video writer failed: \(error?.localizedDescription ?? "unknown error")"
        case .invalidFrameData:
            return "Invalid frame data"
        }
    }
}

#endif
