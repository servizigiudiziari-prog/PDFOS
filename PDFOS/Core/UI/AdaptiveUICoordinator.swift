//
//  AdaptiveUICoordinator.swift
//  PDFOS
//
//  Coordinates adaptive UI behavior based on gaze tracking and user behavior
//

import Foundation
import SwiftUI

/// Coordinates adaptive UI transitions based on user behavior
@MainActor
class AdaptiveUICoordinator: ObservableObject {
    // MARK: - Singleton

    static let shared = AdaptiveUICoordinator()

    // MARK: - Published Properties

    @Published var currentState: UIComplexityState = .reading
    @Published var configuration: UIStateConfiguration = UIStateConfiguration()
    @Published var isEnabled: Bool = true

    // MARK: - Private Properties

    private let gazeTracker = GazeTracker.shared
    private let behaviorAnalyzer = BehaviorAnalyzer()
    private let stateHistory = StateHistoryTracker()
    private let intentPredictor = IntentPredictor()

    private var gazeHandlerId: UUID?
    private var lastStateChange: Date = Date()
    private var lastActivityTime: Date = Date()

    private var monitoringTask: Task<Void, Never>?

    // Behavior tracking
    private var recentBehaviors: [DetectedBehavior] = []
    private let behaviorWindowSize: Int = 10

    // MARK: - Initialization

    private init() {
        setupGazeTracking()
        startMonitoring()
    }

    // MARK: - Public Methods

    /// Enables adaptive UI
    func enable() async throws {
        guard !isEnabled else { return }

        isEnabled = true

        // Start gaze tracking
        try await gazeTracker.startTracking()

        // Register for gaze updates
        setupGazeTracking()

        // Resume monitoring
        startMonitoring()

        print("Adaptive UI enabled")
    }

    /// Disables adaptive UI
    func disable() async {
        guard isEnabled else { return }

        isEnabled = false

        // Stop gaze tracking
        await gazeTracker.stopTracking()

        // Unregister gaze handler
        if let id = gazeHandlerId {
            await gazeTracker.unregisterGazeHandler(id)
            gazeHandlerId = nil
        }

        // Stop monitoring
        monitoringTask?.cancel()
        monitoringTask = nil

        print("Adaptive UI disabled")
    }

    /// Manually transitions to a specific state
    func transitionTo(_ state: UIComplexityState, animated: Bool = true) async {
        await recordTransition(to: state, reason: .userAction)

        if animated {
            withAnimation(.easeInOut(duration: state.transitionDuration * configuration.transitionSpeed.multiplier)) {
                currentState = state
            }
        } else {
            currentState = state
        }

        lastStateChange = Date()
    }

    /// Records user activity (keyboard, mouse, etc.)
    func recordActivity(type: ActivityType, metadata: [String: Any] = [:]) async {
        lastActivityTime = Date()

        await behaviorAnalyzer.recordActivity(type: type, metadata: metadata)

        // Analyze recent activity for behavior patterns
        if let behavior = await behaviorAnalyzer.detectBehavior() {
            recentBehaviors.append(behavior)

            if recentBehaviors.count > behaviorWindowSize {
                recentBehaviors.removeFirst()
            }

            // Check if we should transition
            await evaluateStateTransition(basedOn: behavior)
        }
    }

    /// Gets current adaptive UI statistics
    func getStatistics() async -> AdaptiveUIStatistics {
        let stateStats = await stateHistory.getStatistics()
        let gazeStats = await gazeTracker.getStatistics()
        let behaviorStats = await behaviorAnalyzer.getStatistics()

        return AdaptiveUIStatistics(
            currentState: currentState,
            isEnabled: isEnabled,
            stateStatistics: stateStats,
            gazeStatistics: gazeStats,
            behaviorStatistics: behaviorStats,
            recentBehaviors: recentBehaviors
        )
    }

    /// Updates configuration
    func updateConfiguration(_ newConfig: UIStateConfiguration) {
        configuration = newConfig
    }

    // MARK: - Private Methods

    private func setupGazeTracking() {
        Task {
            gazeHandlerId = await gazeTracker.registerGazeHandler { [weak self] gazeData in
                Task { @MainActor in
                    await self?.handleGazeUpdate(gazeData)
                }
            }
        }
    }

    private func startMonitoring() {
        monitoringTask?.cancel()

        monitoringTask = Task {
            while !Task.isCancelled {
                await performPeriodicCheck()

                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }

    private func handleGazeUpdate(_ gazeData: GazeData) async {
        // Track gaze data for behavior analysis
        await behaviorAnalyzer.recordGazeData(gazeData)

        // Check if gaze indicates a different state
        let suggestedState = await analyzeGazeForState(gazeData)

        if let suggested = suggestedState, suggested != currentState {
            let confidence = await calculateTransitionConfidence(to: suggested)

            if confidence >= configuration.transitionThreshold {
                await evaluateStateTransition(basedOn: DetectedBehavior(
                    pattern: .sustainedReading,
                    confidence: confidence,
                    timestamp: Date(),
                    metadata: [:]
                ))
            }
        }
    }

    private func analyzeGazeForState(_ gazeData: GazeData) async -> UIComplexityState? {
        // Get recent gaze history
        let history = await gazeTracker.getGazeHistory(last: 5.0)

        guard history.count >= 10 else { return nil }

        // Analyze fixations
        let fixationCount = await countFixations(in: history)

        // High fixation count = reading
        if fixationCount >= 3 {
            return .reading
        }

        // Rapid gaze movement = scanning/navigation
        let movement = calculateGazeMovement(history)
        if movement > 500 { // pixels per second
            return .editing
        }

        // Gaze on toolbar areas = power mode
        let toolbarRegion = CGRect(x: 0, y: 0, width: 1920, height: 80)
        if await gazeTracker.isLookingAt(region: toolbarRegion) {
            return .power
        }

        return nil
    }

    private func countFixations(in history: [GazeData]) async -> Int {
        var fixations = 0
        var currentFixation: [GazeData] = []

        for gaze in history {
            if let last = currentFixation.last {
                let distance = hypot(gaze.point.x - last.point.x, gaze.point.y - last.point.y)

                if distance < 30 {
                    currentFixation.append(gaze)
                } else {
                    if currentFixation.count >= 5 {
                        fixations += 1
                    }
                    currentFixation = [gaze]
                }
            } else {
                currentFixation.append(gaze)
            }
        }

        return fixations
    }

    private func calculateGazeMovement(_ history: [GazeData]) -> CGFloat {
        guard history.count >= 2 else { return 0 }

        var totalDistance: CGFloat = 0

        for i in 1..<history.count {
            let p1 = history[i - 1].point
            let p2 = history[i].point
            totalDistance += hypot(p2.x - p1.x, p2.y - p1.y)
        }

        let duration = history.last!.timestamp.timeIntervalSince(history.first!.timestamp)
        return duration > 0 ? totalDistance / CGFloat(duration) : 0
    }

    private func evaluateStateTransition(basedOn behavior: DetectedBehavior) async {
        guard configuration.autoTransitionEnabled else { return }

        // Check if enough time has passed since last transition
        let timeSinceLastChange = Date().timeIntervalSince(lastStateChange)
        guard timeSinceLastChange >= currentState.minimumDuration else { return }

        let suggestedState = behavior.suggestedState

        // Don't transition to same state
        guard suggestedState != currentState else { return }

        // Check confidence threshold
        guard behavior.confidence >= configuration.transitionThreshold else { return }

        // Use ML predictor for additional confirmation
        let prediction = await intentPredictor.predictIntent(
            currentState: currentState,
            recentBehaviors: recentBehaviors,
            gazeData: await gazeTracker.getGazeHistory(last: 10.0)
        )

        if prediction.predictedState == suggestedState && prediction.confidence >= 0.7 {
            await recordTransition(to: suggestedState, reason: .behaviorDetected)

            withAnimation(.easeInOut(duration: suggestedState.transitionDuration * configuration.transitionSpeed.multiplier)) {
                currentState = suggestedState
            }

            lastStateChange = Date()
        }
    }

    private func performPeriodicCheck() async {
        guard isEnabled else { return }

        // Check for inactivity
        let inactiveDuration = Date().timeIntervalSince(lastActivityTime)

        if inactiveDuration >= configuration.inactivityTimeout {
            // Return to minimal state
            if currentState != .minimal {
                await recordTransition(to: .minimal, reason: .inactivity)

                withAnimation(.easeInOut(duration: UIComplexityState.minimal.transitionDuration)) {
                    currentState = .minimal
                }

                lastStateChange = Date()
            }
        }

        // Analyze accumulated behavior
        if recentBehaviors.count >= 5 {
            let consensusState = findConsensusState()

            if let consensus = consensusState, consensus != currentState {
                let confidence = await calculateTransitionConfidence(to: consensus)

                if confidence >= configuration.transitionThreshold {
                    await recordTransition(to: consensus, reason: .behaviorDetected)

                    withAnimation(.easeInOut(duration: consensus.transitionDuration)) {
                        currentState = consensus
                    }

                    lastStateChange = Date()
                }
            }
        }
    }

    private func findConsensusState() -> UIComplexityState? {
        // Count suggested states from recent behaviors
        var stateCounts: [UIComplexityState: Int] = [:]

        for behavior in recentBehaviors.suffix(5) {
            stateCounts[behavior.suggestedState, default: 0] += 1
        }

        // Find most common suggestion
        guard let (state, count) = stateCounts.max(by: { $0.value < $1.value }),
              count >= 3 else { // Need at least 3/5 consensus
            return nil
        }

        return state
    }

    private func calculateTransitionConfidence(to state: UIComplexityState) async -> Double {
        // Combine multiple confidence signals
        var confidenceFactors: [Double] = []

        // 1. Behavior confidence
        let behaviorConfidence = recentBehaviors
            .filter { $0.suggestedState == state }
            .map { $0.confidence }
            .reduce(0, +) / Double(max(1, recentBehaviors.count))

        confidenceFactors.append(behaviorConfidence)

        // 2. ML predictor confidence
        let prediction = await intentPredictor.predictIntent(
            currentState: currentState,
            recentBehaviors: recentBehaviors,
            gazeData: await gazeTracker.getGazeHistory(last: 10.0)
        )

        if prediction.predictedState == state {
            confidenceFactors.append(prediction.confidence)
        }

        // 3. Historical preference
        let stats = await stateHistory.getStatistics()
        let historicalPreference = stats.timePercentage(for: state) / 100.0
        confidenceFactors.append(historicalPreference * 0.5) // Weight historical data less

        // Calculate weighted average
        let totalConfidence = confidenceFactors.reduce(0, +) / Double(confidenceFactors.count)

        return min(1.0, max(0.0, totalConfidence))
    }

    private func recordTransition(to state: UIComplexityState, reason: StateTransition.TransitionReason) async {
        let transition = StateTransition(
            from: currentState,
            to: state,
            reason: reason,
            timestamp: Date()
        )

        await stateHistory.recordTransition(transition)
    }
}

// MARK: - Activity Types

enum ActivityType: String, Codable {
    // Mouse activities
    case mouseMove
    case mouseClick
    case mouseDoubleClick
    case mouseScroll
    case mouseHover

    // Keyboard activities
    case keyPress
    case keyboardShortcut
    case textInput
    case deleteKey
    case undoRedo

    // Document activities
    case pageChange
    case zoom
    case search
    case annotation
    case textSelection

    // Tool activities
    case toolSelected
    case menuOpened
    case panelToggled
    case versionControlAction

    var behaviorPattern: BehaviorPattern? {
        switch self {
        case .mouseScroll:
            return .continuousScrolling
        case .pageChange:
            return .pageFlipping
        case .keyboardShortcut:
            return .keyboardShortcuts
        case .textSelection, .annotation:
            return .textSelection
        case .toolSelected:
            return .rapidToolSwitching
        default:
            return nil
        }
    }
}

// MARK: - Adaptive UI Statistics

struct AdaptiveUIStatistics {
    let currentState: UIComplexityState
    let isEnabled: Bool
    let stateStatistics: StateStatistics
    let gazeStatistics: GazeStatistics
    let behaviorStatistics: BehaviorStatistics
    let recentBehaviors: [DetectedBehavior]
}

struct BehaviorStatistics {
    var totalActivities: Int = 0
    var detectedPatterns: [BehaviorPattern: Int] = [:]
    var averageConfidence: Double = 0
}
