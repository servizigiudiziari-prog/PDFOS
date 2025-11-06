//
//  GazeTracker.swift
//  PDFOS
//
//  Vision framework integration for gaze tracking
//

import Foundation
#if canImport(Vision) && canImport(AVFoundation) && canImport(AppKit)
import Vision
import AVFoundation
import AppKit
#endif

/// Tracks user gaze using Vision framework for adaptive UI
actor GazeTracker {
    // MARK: - Singleton

    static let shared = GazeTracker()

    // MARK: - Properties

    #if canImport(Vision) && canImport(AVFoundation)
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.pdfos.gazetracking", qos: .userInteractive)
    #endif

    private var isTracking: Bool = false
    private var isCalibrated: Bool = false
    private var calibrationData: CalibrationData?

    // Gaze data
    private var currentGazePoint: CGPoint?
    private var gazeHistory: [GazeData] = []
    private let maxHistorySize: Int = 100

    // Callbacks
    private var gazeUpdateHandlers: [UUID: (GazeData) -> Void] = [:]

    // Performance
    private var lastProcessingTime: Date?
    private var averageProcessingTime: TimeInterval = 0
    private var processedFrames: Int = 0

    // MARK: - Initialization

    private init() {
        #if canImport(Vision) && canImport(AVFoundation)
        setupCaptureSession()
        #endif
    }

    // MARK: - Public Methods

    /// Starts gaze tracking
    func startTracking() async throws {
        guard !isTracking else { return }

        #if canImport(Vision) && canImport(AVFoundation)
        guard let session = captureSession else {
            throw GazeTrackingError.captureSessionNotAvailable
        }

        // Request camera permission
        let authorized = await requestCameraPermission()
        guard authorized else {
            throw GazeTrackingError.cameraPermissionDenied
        }

        // Start capture session
        session.startRunning()
        isTracking = true

        print("Gaze tracking started")
        #else
        throw GazeTrackingError.visionFrameworkNotAvailable
        #endif
    }

    /// Stops gaze tracking
    func stopTracking() async {
        guard isTracking else { return }

        #if canImport(Vision) && canImport(AVFoundation)
        captureSession?.stopRunning()
        isTracking = false

        print("Gaze tracking stopped")
        #endif
    }

    /// Registers a handler for gaze updates
    /// - Parameter handler: Closure called when gaze data updates
    /// - Returns: Handler ID for deregistration
    func registerGazeHandler(_ handler: @escaping (GazeData) -> Void) -> UUID {
        let id = UUID()
        gazeUpdateHandlers[id] = handler
        return id
    }

    /// Unregisters a gaze handler
    func unregisterGazeHandler(_ id: UUID) {
        gazeUpdateHandlers.removeValue(forKey: id)
    }

    /// Gets current gaze point
    func getCurrentGaze() -> GazeData? {
        guard let point = currentGazePoint else { return nil }

        return GazeData(
            point: point,
            timestamp: Date(),
            confidence: 0.8
        )
    }

    /// Gets gaze history
    func getGazeHistory(last seconds: TimeInterval = 5.0) -> [GazeData] {
        let cutoff = Date().addingTimeInterval(-seconds)
        return gazeHistory.filter { $0.timestamp >= cutoff }
    }

    /// Checks if user is looking at a specific region
    func isLookingAt(region: CGRect, threshold: CGFloat = 50) -> Bool {
        guard let gaze = currentGazePoint else { return false }

        // Expand region by threshold
        let expandedRegion = region.insetBy(dx: -threshold, dy: -threshold)
        return expandedRegion.contains(gaze)
    }

    /// Gets gaze statistics
    func getStatistics() -> GazeStatistics {
        let recentHistory = getGazeHistory(last: 60) // Last minute

        guard !recentHistory.isEmpty else {
            return GazeStatistics()
        }

        let avgConfidence = recentHistory.map { $0.confidence }.reduce(0, +) / Double(recentHistory.count)

        // Calculate fixation points (where gaze stays relatively still)
        let fixations = calculateFixations(from: recentHistory)

        return GazeStatistics(
            isTracking: isTracking,
            isCalibrated: isCalibrated,
            averageConfidence: avgConfidence,
            samplesPerSecond: Double(recentHistory.count) / 60.0,
            fixationCount: fixations.count,
            averageProcessingTime: averageProcessingTime
        )
    }

    // MARK: - Calibration

    /// Starts calibration process
    func startCalibration() async throws -> CalibrationSession {
        guard isTracking else {
            throw GazeTrackingError.trackingNotStarted
        }

        return CalibrationSession(
            id: UUID(),
            startTime: Date(),
            points: generateCalibrationPoints(),
            currentIndex: 0
        )
    }

    /// Records calibration point
    func recordCalibrationPoint(
        expectedPoint: CGPoint,
        session: CalibrationSession
    ) async throws -> CalibrationSession {
        // Record gaze data for this calibration point
        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second

        let gazeSamples = getGazeHistory(last: 1.0)
        guard !gazeSamples.isEmpty else {
            throw GazeTrackingError.noGazeData
        }

        // Average the gaze points
        let avgX = gazeSamples.map { $0.point.x }.reduce(0, +) / Double(gazeSamples.count)
        let avgY = gazeSamples.map { $0.point.y }.reduce(0, +) / Double(gazeSamples.count)
        let measuredPoint = CGPoint(x: avgX, y: avgY)

        var updatedSession = session
        updatedSession.measurements.append(
            CalibrationMeasurement(
                expectedPoint: expectedPoint,
                measuredPoint: measuredPoint,
                timestamp: Date()
            )
        )
        updatedSession.currentIndex += 1

        return updatedSession
    }

    /// Completes calibration
    func completeCalibration(session: CalibrationSession) async throws {
        guard session.measurements.count >= session.points.count else {
            throw GazeTrackingError.incompleteCalibration
        }

        // Calculate calibration transform
        let data = calculateCalibrationData(from: session)
        calibrationData = data
        isCalibrated = true

        print("Calibration complete with \(session.measurements.count) points")
    }

    // MARK: - Private Methods

    #if canImport(Vision) && canImport(AVFoundation)
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Find front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Warning: No front camera available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Setup video output
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(
                VideoOutputDelegate(gazeTracker: self),
                queue: processingQueue
            )

            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
            }

            captureSession = session
        } catch {
            print("Error setting up capture session: \(error)")
        }
    }

    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        let startTime = Date()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Create face detection request
        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }

            Task {
                await self.handleFaceDetection(request: request, error: error)
            }
        }

        // Perform request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([faceRequest])
        } catch {
            print("Face detection error: \(error)")
        }

        // Track performance
        let duration = Date().timeIntervalSince(startTime)
        updatePerformanceMetrics(duration: duration)
    }

    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNFaceObservation],
              let face = results.first,
              let landmarks = face.landmarks else {
            return
        }

        // Calculate gaze point from eye positions
        let gazePoint = calculateGazePoint(from: landmarks)

        // Apply calibration if available
        let calibratedPoint = applyCalibration(to: gazePoint)

        // Update current gaze
        currentGazePoint = calibratedPoint

        // Create gaze data
        let gazeData = GazeData(
            point: calibratedPoint,
            timestamp: Date(),
            confidence: Double(face.confidence)
        )

        // Add to history
        gazeHistory.append(gazeData)
        if gazeHistory.count > maxHistorySize {
            gazeHistory.removeFirst()
        }

        // Notify handlers
        for handler in gazeUpdateHandlers.values {
            handler(gazeData)
        }
    }
    #endif

    private func calculateGazePoint(from landmarks: VNFaceLandmarks2D) -> CGPoint {
        #if canImport(Vision)
        // Get eye positions
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return .zero
        }

        // Calculate center point between eyes
        let leftPoints = leftEye.normalizedPoints
        let rightPoints = rightEye.normalizedPoints

        let leftCenter = averagePoint(leftPoints)
        let rightCenter = averagePoint(rightPoints)

        let eyeCenter = CGPoint(
            x: (leftCenter.x + rightCenter.x) / 2,
            y: (leftCenter.y + rightCenter.y) / 2
        )

        // Convert to screen coordinates (simplified)
        // In production, this would use more sophisticated gaze estimation
        let screenPoint = CGPoint(
            x: eyeCenter.x * 1920, // Assuming 1920x1080 screen
            y: (1.0 - eyeCenter.y) * 1080
        )

        return screenPoint
        #else
        return .zero
        #endif
    }

    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        let sum = points.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + point.x, y: result.y + point.y)
        }

        return CGPoint(
            x: sum.x / CGFloat(points.count),
            y: sum.y / CGFloat(points.count)
        )
    }

    private func applyCalibration(to point: CGPoint) -> CGPoint {
        guard let calibration = calibrationData else {
            return point
        }

        // Apply affine transform
        return CGPoint(
            x: point.x * calibration.scaleX + calibration.offsetX,
            y: point.y * calibration.scaleY + calibration.offsetY
        )
    }

    private func calculateFixations(from history: [GazeData]) -> [Fixation] {
        var fixations: [Fixation] = []
        var currentFixation: [GazeData] = []
        let fixationThreshold: CGFloat = 30 // pixels

        for gaze in history {
            if let last = currentFixation.last {
                let distance = hypot(gaze.point.x - last.point.x, gaze.point.y - last.point.y)

                if distance < fixationThreshold {
                    currentFixation.append(gaze)
                } else {
                    // Save current fixation if long enough
                    if currentFixation.count >= 3 {
                        fixations.append(createFixation(from: currentFixation))
                    }
                    currentFixation = [gaze]
                }
            } else {
                currentFixation.append(gaze)
            }
        }

        // Add final fixation
        if currentFixation.count >= 3 {
            fixations.append(createFixation(from: currentFixation))
        }

        return fixations
    }

    private func createFixation(from gazeData: [GazeData]) -> Fixation {
        let avgX = gazeData.map { $0.point.x }.reduce(0, +) / CGFloat(gazeData.count)
        let avgY = gazeData.map { $0.point.y }.reduce(0, +) / CGFloat(gazeData.count)

        return Fixation(
            point: CGPoint(x: avgX, y: avgY),
            startTime: gazeData.first!.timestamp,
            endTime: gazeData.last!.timestamp,
            duration: gazeData.last!.timestamp.timeIntervalSince(gazeData.first!.timestamp)
        )
    }

    private func generateCalibrationPoints() -> [CGPoint] {
        // 9-point calibration grid
        let screenSize = CGSize(width: 1920, height: 1080)
        let margin: CGFloat = 100

        return [
            // Top row
            CGPoint(x: margin, y: margin),
            CGPoint(x: screenSize.width / 2, y: margin),
            CGPoint(x: screenSize.width - margin, y: margin),

            // Middle row
            CGPoint(x: margin, y: screenSize.height / 2),
            CGPoint(x: screenSize.width / 2, y: screenSize.height / 2),
            CGPoint(x: screenSize.width - margin, y: screenSize.height / 2),

            // Bottom row
            CGPoint(x: margin, y: screenSize.height - margin),
            CGPoint(x: screenSize.width / 2, y: screenSize.height - margin),
            CGPoint(x: screenSize.width - margin, y: screenSize.height - margin)
        ]
    }

    private func calculateCalibrationData(from session: CalibrationSession) -> CalibrationData {
        let measurements = session.measurements

        // Calculate average offsets
        var totalOffsetX: CGFloat = 0
        var totalOffsetY: CGFloat = 0
        var totalScaleX: CGFloat = 0
        var totalScaleY: CGFloat = 0

        for measurement in measurements {
            totalOffsetX += measurement.expectedPoint.x - measurement.measuredPoint.x
            totalOffsetY += measurement.expectedPoint.y - measurement.measuredPoint.y

            if measurement.measuredPoint.x != 0 {
                totalScaleX += measurement.expectedPoint.x / measurement.measuredPoint.x
            }
            if measurement.measuredPoint.y != 0 {
                totalScaleY += measurement.expectedPoint.y / measurement.measuredPoint.y
            }
        }

        let count = CGFloat(measurements.count)

        return CalibrationData(
            offsetX: totalOffsetX / count,
            offsetY: totalOffsetY / count,
            scaleX: totalScaleX / count,
            scaleY: totalScaleY / count,
            timestamp: Date()
        )
    }

    private func updatePerformanceMetrics(duration: TimeInterval) {
        processedFrames += 1

        // Running average
        let alpha = 0.1 // Smoothing factor
        averageProcessingTime = (1 - alpha) * averageProcessingTime + alpha * duration

        lastProcessingTime = Date()
    }

    private func requestCameraPermission() async -> Bool {
        #if canImport(AVFoundation)
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
        #else
        return false
        #endif
    }
}

// MARK: - Video Output Delegate

#if canImport(AVFoundation)
private class VideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var gazeTracker: GazeTracker?

    init(gazeTracker: GazeTracker) {
        self.gazeTracker = gazeTracker
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Task {
            await gazeTracker?.processVideoFrame(sampleBuffer)
        }
    }
}
#endif

// MARK: - Supporting Types

/// Gaze data point
struct GazeData: Codable {
    let point: CGPoint
    let timestamp: Date
    let confidence: Double
}

/// Gaze fixation (sustained attention)
struct Fixation {
    let point: CGPoint
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
}

/// Gaze tracking statistics
struct GazeStatistics {
    var isTracking: Bool = false
    var isCalibrated: Bool = false
    var averageConfidence: Double = 0
    var samplesPerSecond: Double = 0
    var fixationCount: Int = 0
    var averageProcessingTime: TimeInterval = 0
}

/// Calibration session
struct CalibrationSession {
    let id: UUID
    let startTime: Date
    let points: [CGPoint]
    var currentIndex: Int
    var measurements: [CalibrationMeasurement] = []
}

/// Calibration measurement
struct CalibrationMeasurement {
    let expectedPoint: CGPoint
    let measuredPoint: CGPoint
    let timestamp: Date
}

/// Calibration data
struct CalibrationData {
    let offsetX: CGFloat
    let offsetY: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat
    let timestamp: Date
}

/// Gaze tracking errors
enum GazeTrackingError: Error, LocalizedError {
    case visionFrameworkNotAvailable
    case captureSessionNotAvailable
    case cameraPermissionDenied
    case trackingNotStarted
    case noGazeData
    case incompleteCalibration

    var errorDescription: String? {
        switch self {
        case .visionFrameworkNotAvailable:
            return "Vision framework is not available on this platform"
        case .captureSessionNotAvailable:
            return "Camera capture session could not be created"
        case .cameraPermissionDenied:
            return "Camera permission was denied"
        case .trackingNotStarted:
            return "Gaze tracking must be started before calibration"
        case .noGazeData:
            return "No gaze data available for calibration"
        case .incompleteCalibration:
            return "Calibration is incomplete"
        }
    }
}

// MARK: - CGPoint Extensions

extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(CGFloat.self)
        let y = try container.decode(CGFloat.self)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}
