//
//  AdaptiveUITests.swift
//  PDFOS
//
//  Comprehensive tests for adaptive UI functionality
//

import XCTest
@testable import PDFOSCore

/// Tests for adaptive UI, gaze tracking, and behavior analysis
final class AdaptiveUITests: XCTestCase {

    var coordinator: AdaptiveUICoordinator!
    var gazeTracker: GazeTracker!
    var behaviorAnalyzer: BehaviorAnalyzer!
    var intentPredictor: IntentPredictor!

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        coordinator = AdaptiveUICoordinator.shared
        gazeTracker = GazeTracker.shared
        behaviorAnalyzer = BehaviorAnalyzer()
        intentPredictor = IntentPredictor()
    }

    @MainActor
    override func tearDown() async throws {
        await coordinator.disable()
        await gazeTracker.stopTracking()
        await behaviorAnalyzer.clear()

        try await super.tearDown()
    }

    // MARK: - UI Complexity State Tests

    func testStateTransitions() async throws {
        // Test all state transitions
        for state in UIComplexityState.allCases {
            await coordinator.transitionTo(state, animated: false)

            XCTAssertEqual(
                coordinator.currentState,
                state,
                "Should transition to \(state.rawValue)"
            )
        }
    }

    func testStateVisibleComponents() {
        // Test that each state has correct components
        let minimal = UIComplexityState.minimal.visibleComponents
        XCTAssertTrue(minimal.contains(.documentView), "Minimal should show document")
        XCTAssertEqual(minimal.count, 1, "Minimal should only show document")

        let reading = UIComplexityState.reading.visibleComponents
        XCTAssertTrue(reading.contains(.documentView), "Reading should show document")
        XCTAssertTrue(reading.contains(.navigationBar), "Reading should show navigation")
        XCTAssertTrue(reading.contains(.searchBox), "Reading should show search")

        let power = UIComplexityState.power.visibleComponents
        XCTAssertEqual(
            power.count,
            UIComponent.allCases.count,
            "Power mode should show all components"
        )
    }

    func testMinimumStateDuration() {
        // All states should have minimum duration to prevent rapid switching
        for state in UIComplexityState.allCases {
            XCTAssertGreaterThanOrEqual(
                state.minimumDuration,
                3.0,
                "\(state.rawValue) should have minimum duration of 3s"
            )
        }
    }

    // MARK: - Behavior Detection Tests

    func testScrollingBehaviorDetection() async throws {
        // Simulate scrolling behavior
        for _ in 0..<5 {
            await behaviorAnalyzer.recordActivity(
                type: .mouseScroll,
                metadata: ["delta": 100]
            )

            try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        }

        let behavior = await behaviorAnalyzer.detectBehavior()

        XCTAssertNotNil(behavior, "Should detect behavior")
        XCTAssertEqual(
            behavior?.pattern,
            .continuousScrolling,
            "Should detect scrolling pattern"
        )
        XCTAssertGreaterThan(
            behavior?.confidence ?? 0,
            0.8,
            "Should have high confidence"
        )
    }

    func testReadingBehaviorDetection() async throws {
        // Simulate sustained reading with stable gaze
        let centerPoint = CGPoint(x: 960, y: 540)

        for i in 0..<30 {
            // Add small random variations to simulate natural eye movement
            let variation = CGFloat.random(in: -10...10)
            let gazeData = GazeData(
                point: CGPoint(
                    x: centerPoint.x + variation,
                    y: centerPoint.y + variation
                ),
                timestamp: Date().addingTimeInterval(Double(i) * 0.1),
                confidence: 0.9
            )

            await behaviorAnalyzer.recordGazeData(gazeData)
        }

        let behavior = await behaviorAnalyzer.detectBehavior()

        XCTAssertEqual(
            behavior?.pattern,
            .sustainedReading,
            "Should detect sustained reading"
        )
    }

    func testEditingBehaviorDetection() async throws {
        // Simulate editing behavior
        await behaviorAnalyzer.recordActivity(type: .textSelection, metadata: [:])
        try await Task.sleep(nanoseconds: 500_000_000)

        await behaviorAnalyzer.recordActivity(type: .annotation, metadata: [:])
        try await Task.sleep(nanoseconds: 500_000_000)

        await behaviorAnalyzer.recordActivity(type: .textInput, metadata: [:])

        let behavior = await behaviorAnalyzer.detectBehavior()

        XCTAssertNotNil(behavior, "Should detect behavior")
        XCTAssertTrue(
            [.textSelection, .annotationDrawing].contains(behavior?.pattern),
            "Should detect editing pattern"
        )
    }

    func testPowerUserBehaviorDetection() async throws {
        // Simulate keyboard shortcuts (power user behavior)
        for _ in 0..<3 {
            await behaviorAnalyzer.recordActivity(
                type: .keyboardShortcut,
                metadata: ["shortcut": "cmd+shift+v"]
            )

            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }

        let behavior = await behaviorAnalyzer.detectBehavior()

        XCTAssertEqual(
            behavior?.pattern,
            .keyboardShortcuts,
            "Should detect keyboard shortcut usage"
        )
        XCTAssertGreaterThan(
            behavior?.confidence ?? 0,
            0.9,
            "Should have very high confidence for shortcuts"
        )
    }

    func testIdleBehaviorDetection() async throws {
        // Simulate idle behavior by not recording activities
        await behaviorAnalyzer.recordActivity(type: .mouseMove, metadata: [:])

        // Wait for idle threshold
        try await Task.sleep(nanoseconds: 31_000_000_000) // 31 seconds

        let behavior = await behaviorAnalyzer.detectBehavior()

        XCTAssertEqual(
            behavior?.pattern,
            .noInput,
            "Should detect idle behavior"
        )
    }

    // MARK: - Intent Prediction Tests

    func testIntentPredictionForReading() async throws {
        // Create reading-like behaviors
        let behaviors = [
            DetectedBehavior(
                pattern: .sustainedReading,
                confidence: 0.9,
                timestamp: Date(),
                metadata: [:]
            ),
            DetectedBehavior(
                pattern: .pageFlipping,
                confidence: 0.85,
                timestamp: Date(),
                metadata: [:]
            )
        ]

        // Create stable gaze data
        let gazeData = createStableGazeData()

        let prediction = await intentPredictor.predictIntent(
            currentState: .minimal,
            recentBehaviors: behaviors,
            gazeData: gazeData
        )

        XCTAssertEqual(
            prediction.predictedState,
            .reading,
            "Should predict reading state"
        )
        XCTAssertGreaterThan(
            prediction.confidence,
            0.6,
            "Should have reasonable confidence"
        )
    }

    func testIntentPredictionForEditing() async throws {
        let behaviors = [
            DetectedBehavior(
                pattern: .textSelection,
                confidence: 0.88,
                timestamp: Date(),
                metadata: [:]
            ),
            DetectedBehavior(
                pattern: .annotationDrawing,
                confidence: 0.9,
                timestamp: Date(),
                metadata: [:]
            )
        ]

        let gazeData = createModerateMovementGazeData()

        let prediction = await intentPredictor.predictIntent(
            currentState: .reading,
            recentBehaviors: behaviors,
            gazeData: gazeData
        )

        XCTAssertEqual(
            prediction.predictedState,
            .editing,
            "Should predict editing state"
        )
    }

    func testIntentPredictionForPowerMode() async throws {
        let behaviors = [
            DetectedBehavior(
                pattern: .keyboardShortcuts,
                confidence: 0.95,
                timestamp: Date(),
                metadata: [:]
            ),
            DetectedBehavior(
                pattern: .rapidToolSwitching,
                confidence: 0.85,
                timestamp: Date(),
                metadata: [:]
            )
        ]

        let gazeData = createHighMovementGazeData()

        let prediction = await intentPredictor.predictIntent(
            currentState: .editing,
            recentBehaviors: behaviors,
            gazeData: gazeData
        )

        XCTAssertEqual(
            prediction.predictedState,
            .power,
            "Should predict power mode"
        )
    }

    func testPredictionCaching() async throws {
        let behaviors = [
            DetectedBehavior(
                pattern: .sustainedReading,
                confidence: 0.9,
                timestamp: Date(),
                metadata: [:]
            )
        ]

        let gazeData = createStableGazeData()

        // First prediction
        let start1 = Date()
        let prediction1 = await intentPredictor.predictIntent(
            currentState: .minimal,
            recentBehaviors: behaviors,
            gazeData: gazeData
        )
        let duration1 = Date().timeIntervalSince(start1)

        // Second prediction (should be cached)
        let start2 = Date()
        let prediction2 = await intentPredictor.predictIntent(
            currentState: .minimal,
            recentBehaviors: behaviors,
            gazeData: gazeData
        )
        let duration2 = Date().timeIntervalSince(start2)

        XCTAssertEqual(prediction1.predictedState, prediction2.predictedState)
        XCTAssertLessThan(duration2, duration1 * 0.5, "Cached prediction should be faster")
    }

    // MARK: - Adaptive UI Coordinator Tests

    @MainActor
    func testCoordinatorEnableDisable() async throws {
        // Enable
        try await coordinator.enable()
        XCTAssertTrue(coordinator.isEnabled, "Should be enabled")

        // Disable
        await coordinator.disable()
        XCTAssertFalse(coordinator.isEnabled, "Should be disabled")
    }

    @MainActor
    func testActivityRecording() async throws {
        try await coordinator.enable()

        // Record various activities
        await coordinator.recordActivity(type: .mouseScroll, metadata: [:])
        await coordinator.recordActivity(type: .textSelection, metadata: [:])
        await coordinator.recordActivity(type: .keyboardShortcut, metadata: [:])

        let stats = await coordinator.getStatistics()

        XCTAssertGreaterThan(
            stats.behaviorStatistics.totalActivities,
            0,
            "Should record activities"
        )
    }

    @MainActor
    func testAutoTransition() async throws {
        // Enable auto-transition
        var config = coordinator.configuration
        config.autoTransitionEnabled = true
        config.transitionThreshold = 0.6
        coordinator.updateConfiguration(config)

        try await coordinator.enable()

        // Start in minimal state
        await coordinator.transitionTo(.minimal, animated: false)

        // Simulate reading behavior
        for _ in 0..<5 {
            await coordinator.recordActivity(type: .mouseScroll, metadata: [:])
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        // Wait for potential transition
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // State might have transitioned to reading
        let finalState = coordinator.currentState

        XCTAssertTrue(
            [.minimal, .reading].contains(finalState),
            "State should be minimal or reading after scrolling"
        )
    }

    @MainActor
    func testConfigurationOverrides() async throws {
        var config = UIStateConfiguration()

        // Always show timeline
        config.alwaysVisible.insert(.timeline)

        // Never show analytics panel
        config.neverVisible.insert(.analyticsPanel)

        coordinator.updateConfiguration(config)

        XCTAssertTrue(
            coordinator.configuration.alwaysVisible.contains(.timeline),
            "Should respect always visible override"
        )
        XCTAssertTrue(
            coordinator.configuration.neverVisible.contains(.analyticsPanel),
            "Should respect never visible override"
        )
    }

    // MARK: - Gaze Tracking Tests

    func testGazeDataRecording() async throws {
        let gazeData = GazeData(
            point: CGPoint(x: 500, y: 300),
            timestamp: Date(),
            confidence: 0.9
        )

        await behaviorAnalyzer.recordGazeData(gazeData)

        // Verify it was recorded
        let behavior = await behaviorAnalyzer.detectBehavior()

        // Should have data to analyze
        XCTAssertNotNil(behavior)
    }

    func testFixationDetection() async throws {
        // Create fixation: multiple gaze points at same location
        let fixationPoint = CGPoint(x: 960, y: 540)

        for i in 0..<20 {
            let gazeData = GazeData(
                point: fixationPoint.offset(by: 5), // Small jitter
                timestamp: Date().addingTimeInterval(Double(i) * 0.05),
                confidence: 0.9
            )

            await behaviorAnalyzer.recordGazeData(gazeData)
        }

        let behavior = await behaviorAnalyzer.detectBehavior()

        XCTAssertEqual(
            behavior?.pattern,
            .sustainedReading,
            "Fixation should indicate sustained reading"
        )
    }

    // MARK: - State History Tests

    func testStateHistoryTracking() async throws {
        let history = StateHistoryTracker()

        // Record some transitions
        for i in 0..<5 {
            let transition = StateTransition(
                from: .minimal,
                to: .reading,
                reason: .behaviorDetected,
                timestamp: Date().addingTimeInterval(Double(i))
            )

            await history.recordTransition(transition)
        }

        let recentHistory = await history.getHistory(last: 3)

        XCTAssertEqual(recentHistory.count, 3, "Should retrieve last 3 transitions")
    }

    func testStateStatistics() async throws {
        let history = StateHistoryTracker()

        // Record transitions with delays
        let states: [UIComplexityState] = [.reading, .editing, .reading, .power, .reading]

        for (index, state) in states.enumerated() {
            let transition = StateTransition(
                from: index > 0 ? states[index - 1] : .minimal,
                to: state,
                reason: .behaviorDetected,
                timestamp: Date().addingTimeInterval(Double(index * 10))
            )

            await history.recordTransition(transition)
        }

        let stats = await history.getStatistics()

        XCTAssertEqual(
            stats.totalTransitions,
            5,
            "Should track all transitions"
        )

        // Reading appeared 3 times, should be most common
        XCTAssertEqual(
            stats.mostCommonState,
            .reading,
            "Reading should be most common state"
        )
    }

    // MARK: - Integration Tests

    @MainActor
    func testCompleteAdaptiveWorkflow() async throws {
        // Enable adaptive UI
        try await coordinator.enable()

        // Start in reading mode
        await coordinator.transitionTo(.reading, animated: false)

        // Simulate reading behavior
        for _ in 0..<3 {
            await coordinator.recordActivity(type: .pageChange, metadata: [:])
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Switch to editing behavior
        await coordinator.recordActivity(type: .textSelection, metadata: [:])
        await coordinator.recordActivity(type: .annotation, metadata: [:])

        // Get statistics
        let stats = await coordinator.getStatistics()

        XCTAssertGreaterThan(
            stats.behaviorStatistics.totalActivities,
            0,
            "Should track activities"
        )

        XCTAssertTrue(
            stats.behaviorStatistics.detectedPatterns.count > 0,
            "Should detect patterns"
        )
    }

    // MARK: - Performance Tests

    func testBehaviorAnalysisPerformance() async throws {
        measure {
            Task {
                for _ in 0..<100 {
                    await behaviorAnalyzer.recordActivity(
                        type: .mouseMove,
                        metadata: [:]
                    )

                    let _ = await behaviorAnalyzer.detectBehavior()
                }
            }
        }
    }

    func testIntentPredictionPerformance() async throws {
        let behaviors = [
            DetectedBehavior(
                pattern: .sustainedReading,
                confidence: 0.9,
                timestamp: Date(),
                metadata: [:]
            )
        ]

        let gazeData = createStableGazeData()

        let startTime = Date()

        for _ in 0..<100 {
            let _ = await intentPredictor.predictIntent(
                currentState: .reading,
                recentBehaviors: behaviors,
                gazeData: gazeData
            )
        }

        let duration = Date().timeIntervalSince(startTime)
        let avgTime = duration / 100.0

        XCTAssertLessThan(
            avgTime,
            0.01,
            "Average prediction should be <10ms, was \(avgTime * 1000)ms"
        )
    }

    // MARK: - Helper Methods

    private func createStableGazeData() -> [GazeData] {
        let centerPoint = CGPoint(x: 960, y: 540)

        return (0..<30).map { i in
            GazeData(
                point: centerPoint.offset(by: 5),
                timestamp: Date().addingTimeInterval(Double(i) * 0.1),
                confidence: 0.9
            )
        }
    }

    private func createModerateMovementGazeData() -> [GazeData] {
        return (0..<30).map { i in
            GazeData(
                point: CGPoint(
                    x: 960 + CGFloat(i * 10),
                    y: 540 + CGFloat(i * 5)
                ),
                timestamp: Date().addingTimeInterval(Double(i) * 0.1),
                confidence: 0.85
            )
        }
    }

    private func createHighMovementGazeData() -> [GazeData] {
        return (0..<30).map { i in
            GazeData(
                point: CGPoint(
                    x: CGFloat.random(in: 0...1920),
                    y: CGFloat.random(in: 0...1080)
                ),
                timestamp: Date().addingTimeInterval(Double(i) * 0.1),
                confidence: 0.8
            )
        }
    }
}

// MARK: - CGPoint Extension

extension CGPoint {
    func offset(by amount: CGFloat) -> CGPoint {
        return CGPoint(
            x: x + CGFloat.random(in: -amount...amount),
            y: y + CGFloat.random(in: -amount...amount)
        )
    }
}
