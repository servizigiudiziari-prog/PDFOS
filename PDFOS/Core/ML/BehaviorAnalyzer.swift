//
//  BehaviorAnalyzer.swift
//  PDFOS
//
//  Analyzes user behavior patterns for adaptive UI
//

import Foundation
import CoreML

/// Analyzes user behavior to detect patterns
actor BehaviorAnalyzer {
    // MARK: - Properties

    private var activities: [Activity] = []
    private var gazeDataBuffer: [GazeData] = []
    private let maxBufferSize: Int = 200

    private var statistics: BehaviorStatistics = BehaviorStatistics()

    // Pattern detection thresholds
    private let scrollingThreshold: Int = 3 // scrolls in 2 seconds
    private let keyboardShortcutThreshold: Int = 2 // shortcuts in 5 seconds
    private let toolSwitchThreshold: Int = 3 // tool changes in 10 seconds

    // MARK: - Public Methods

    /// Records an activity
    func recordActivity(type: ActivityType, metadata: [String: Any]) {
        let activity = Activity(
            type: type,
            timestamp: Date(),
            metadata: metadata
        )

        activities.append(activity)

        if activities.count > maxBufferSize {
            activities.removeFirst()
        }

        statistics.totalActivities += 1
    }

    /// Records gaze data
    func recordGazeData(_ gazeData: GazeData) {
        gazeDataBuffer.append(gazeData)

        if gazeDataBuffer.count > maxBufferSize {
            gazeDataBuffer.removeFirst()
        }
    }

    /// Detects current behavior pattern
    func detectBehavior() -> DetectedBehavior? {
        // Analyze recent activities
        let recentActivities = activities.suffix(20)

        // Try to detect patterns
        if let pattern = detectScrollingPattern(in: recentActivities) {
            return pattern
        }

        if let pattern = detectReadingPattern() {
            return pattern
        }

        if let pattern = detectEditingPattern(in: recentActivities) {
            return pattern
        }

        if let pattern = detectPowerUserPattern(in: recentActivities) {
            return pattern
        }

        if let pattern = detectIdlePattern() {
            return pattern
        }

        return nil
    }

    /// Gets behavior statistics
    func getStatistics() -> BehaviorStatistics {
        return statistics
    }

    /// Clears accumulated data
    func clear() {
        activities.removeAll()
        gazeDataBuffer.removeAll()
        statistics = BehaviorStatistics()
    }

    // MARK: - Pattern Detection

    private func detectScrollingPattern(in activities: ArraySlice<Activity>) -> DetectedBehavior? {
        let recentScrolls = activities.filter { activity in
            activity.type == .mouseScroll &&
            Date().timeIntervalSince(activity.timestamp) < 2.0
        }

        if recentScrolls.count >= scrollingThreshold {
            let pattern = BehaviorPattern.continuousScrolling
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.85,
                timestamp: Date(),
                metadata: ["scroll_count": recentScrolls.count]
            )
        }

        // Check for page flipping
        let recentPageChanges = activities.filter { activity in
            activity.type == .pageChange &&
            Date().timeIntervalSince(activity.timestamp) < 3.0
        }

        if recentPageChanges.count >= 2 {
            let pattern = BehaviorPattern.pageFlipping
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.9,
                timestamp: Date(),
                metadata: ["page_changes": recentPageChanges.count]
            )
        }

        return nil
    }

    private func detectReadingPattern() -> DetectedBehavior? {
        // Analyze gaze data for sustained focus
        let recentGaze = gazeDataBuffer.suffix(50)

        guard recentGaze.count >= 20 else { return nil }

        // Calculate gaze variance (low variance = sustained reading)
        let points = recentGaze.map { $0.point }
        let variance = calculateVariance(points)

        if variance < 5000 { // Low variance = focused reading
            let pattern = BehaviorPattern.sustainedReading
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.88,
                timestamp: Date(),
                metadata: ["gaze_variance": variance]
            )
        }

        // High variance = skimming
        if variance > 20000 {
            let pattern = BehaviorPattern.skimming
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.75,
                timestamp: Date(),
                metadata: ["gaze_variance": variance]
            )
        }

        return nil
    }

    private func detectEditingPattern(in activities: ArraySlice<Activity>) -> DetectedBehavior? {
        let editingActivities = activities.filter { activity in
            [.textSelection, .annotation, .textInput, .toolSelected].contains(activity.type) &&
            Date().timeIntervalSince(activity.timestamp) < 5.0
        }

        if editingActivities.count >= 2 {
            // Determine specific editing pattern
            let hasTextSelection = editingActivities.contains { $0.type == .textSelection }
            let hasAnnotation = editingActivities.contains { $0.type == .annotation }
            let hasTextInput = editingActivities.contains { $0.type == .textInput }

            var pattern: BehaviorPattern
            var confidence: Double

            if hasAnnotation {
                pattern = .annotationDrawing
                confidence = 0.9
            } else if hasTextSelection {
                pattern = .textSelection
                confidence = 0.85
            } else {
                pattern = .textSelection // Default
                confidence = 0.75
            }

            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: confidence,
                timestamp: Date(),
                metadata: ["editing_activities": editingActivities.count]
            )
        }

        // Check for frequent undo
        let undoCount = activities.filter { activity in
            activity.type == .undoRedo &&
            Date().timeIntervalSince(activity.timestamp) < 10.0
        }.count

        if undoCount >= 2 {
            let pattern = BehaviorPattern.frequentUndo
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.8,
                timestamp: Date(),
                metadata: ["undo_count": undoCount]
            )
        }

        return nil
    }

    private func detectPowerUserPattern(in activities: ArraySlice<Activity>) -> DetectedBehavior? {
        // Keyboard shortcuts
        let shortcuts = activities.filter { activity in
            activity.type == .keyboardShortcut &&
            Date().timeIntervalSince(activity.timestamp) < 5.0
        }

        if shortcuts.count >= keyboardShortcutThreshold {
            let pattern = BehaviorPattern.keyboardShortcuts
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.95,
                timestamp: Date(),
                metadata: ["shortcut_count": shortcuts.count]
            )
        }

        // Rapid tool switching
        let toolChanges = activities.filter { activity in
            activity.type == .toolSelected &&
            Date().timeIntervalSince(activity.timestamp) < 10.0
        }

        if toolChanges.count >= toolSwitchThreshold {
            let pattern = BehaviorPattern.rapidToolSwitching
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.82,
                timestamp: Date(),
                metadata: ["tool_changes": toolChanges.count]
            )
        }

        // Version control usage
        let versionControlActions = activities.filter { activity in
            activity.type == .versionControlAction &&
            Date().timeIntervalSince(activity.timestamp) < 30.0
        }

        if !versionControlActions.isEmpty {
            let pattern = BehaviorPattern.versionControlUsage
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.9,
                timestamp: Date(),
                metadata: ["vc_actions": versionControlActions.count]
            )
        }

        return nil
    }

    private func detectIdlePattern() -> DetectedBehavior? {
        // Check time since last activity
        guard let lastActivity = activities.last else { return nil }

        let idleTime = Date().timeIntervalSince(lastActivity.timestamp)

        if idleTime > 30.0 { // 30 seconds of inactivity
            let pattern = BehaviorPattern.noInput
            statistics.detectedPatterns[pattern, default: 0] += 1

            return DetectedBehavior(
                pattern: pattern,
                confidence: 0.95,
                timestamp: Date(),
                metadata: ["idle_duration": idleTime]
            )
        }

        // Check gaze wandering
        let recentGaze = gazeDataBuffer.suffix(30)

        if recentGaze.count >= 20 {
            let points = recentGaze.map { $0.point }
            let variance = calculateVariance(points)

            // Very high variance = unfocused/wandering
            if variance > 50000 {
                let pattern = BehaviorPattern.gazeWandering
                statistics.detectedPatterns[pattern, default: 0] += 1

                return DetectedBehavior(
                    pattern: pattern,
                    confidence: 0.85,
                    timestamp: Date(),
                    metadata: ["gaze_variance": variance]
                )
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    private func calculateVariance(_ points: [CGPoint]) -> Double {
        guard points.count > 1 else { return 0 }

        // Calculate mean
        let meanX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let meanY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)

        // Calculate variance
        let varianceX = points.map { pow($0.x - meanX, 2) }.reduce(0, +) / CGFloat(points.count)
        let varianceY = points.map { pow($0.y - meanY, 2) }.reduce(0, +) / CGFloat(points.count)

        return Double(varianceX + varianceY)
    }
}

// MARK: - Supporting Types

/// Recorded activity
struct Activity {
    let type: ActivityType
    let timestamp: Date
    let metadata: [String: Any]
}
