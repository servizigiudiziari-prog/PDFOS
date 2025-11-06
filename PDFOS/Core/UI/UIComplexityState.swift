//
//  UIComplexityState.swift
//  PDFOS
//
//  Defines UI complexity states that adapt to user behavior
//

import Foundation
import SwiftUI

/// UI complexity levels that adapt to user behavior
enum UIComplexityState: String, Codable, CaseIterable {
    case minimal    // Clean reading experience
    case reading    // Basic navigation
    case editing    // Common editing tools
    case power      // All features visible

    // MARK: - Properties

    /// Display name
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .reading: return "Reading"
        case .editing: return "Editing"
        case .power: return "Power User"
        }
    }

    /// Description of the mode
    var description: String {
        switch self {
        case .minimal:
            return "Clean, distraction-free reading. Only the document is visible."
        case .reading:
            return "Basic navigation tools for moving through the document."
        case .editing:
            return "Common editing tools for making changes to the document."
        case .power:
            return "All features available for advanced document manipulation."
        }
    }

    /// Icon name
    var iconName: String {
        switch self {
        case .minimal: return "doc.text"
        case .reading: return "book"
        case .editing: return "pencil"
        case .power: return "gearshape.2"
        }
    }

    /// Visible UI components in this state
    var visibleComponents: Set<UIComponent> {
        switch self {
        case .minimal:
            return [.documentView]

        case .reading:
            return [
                .documentView,
                .navigationBar,
                .pageIndicator,
                .searchBox,
                .zoomControls
            ]

        case .editing:
            return [
                .documentView,
                .navigationBar,
                .pageIndicator,
                .toolbar,
                .propertiesPanel,
                .annotationTools,
                .textTools,
                .versionBadge
            ]

        case .power:
            return Set(UIComponent.allCases)
        }
    }

    /// Animation duration for transitions
    var transitionDuration: TimeInterval {
        switch self {
        case .minimal: return 0.4
        case .reading: return 0.3
        case .editing: return 0.35
        case .power: return 0.4
        }
    }

    /// Minimum time before auto-switching (prevents rapid changes)
    var minimumDuration: TimeInterval {
        return 3.0
    }
}

/// Individual UI components
enum UIComponent: String, Codable, CaseIterable {
    // Core
    case documentView
    case navigationBar
    case statusBar

    // Navigation
    case pageIndicator
    case thumbnailSidebar
    case outlineView
    case searchBox
    case zoomControls

    // Editing
    case toolbar
    case propertiesPanel
    case annotationTools
    case textTools
    case imageTools
    case formTools

    // Version Control
    case versionBadge
    case timeline
    case versionHistory
    case diffViewer

    // Advanced
    case semanticPanel
    case analyticsPanel
    case conflictResolver
    case exportOptions

    /// Display name
    var displayName: String {
        rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized
    }

    /// Is this component essential (always visible)?
    var isEssential: Bool {
        switch self {
        case .documentView, .statusBar:
            return true
        default:
            return false
        }
    }
}

/// Transition configuration between states
struct StateTransition {
    let from: UIComplexityState
    let to: UIComplexityState
    let reason: TransitionReason
    let timestamp: Date

    enum TransitionReason: String, Codable {
        case userAction         // User explicitly changed state
        case behaviorDetected   // ML model detected behavior change
        case gazePattern        // Gaze tracking indicated state change
        case inactivity         // User inactive, return to minimal
        case toolUsage          // User used a tool only available in higher state
        case keyboardShortcut   // User pressed state change shortcut
    }
}

/// UI state configuration
struct UIStateConfiguration: Codable {
    // Behavior triggers
    var autoTransitionEnabled: Bool = true
    var transitionThreshold: Double = 0.7  // Confidence threshold for auto-transition
    var inactivityTimeout: TimeInterval = 120  // Seconds before returning to minimal

    // Component overrides (user preferences)
    var alwaysVisible: Set<UIComponent> = []
    var neverVisible: Set<UIComponent> = []

    // Animation preferences
    var animationsEnabled: Bool = true
    var transitionSpeed: TransitionSpeed = .normal

    enum TransitionSpeed: String, Codable {
        case instant
        case fast
        case normal
        case slow

        var multiplier: Double {
            switch self {
            case .instant: return 0
            case .fast: return 0.5
            case .normal: return 1.0
            case .slow: return 1.5
            }
        }
    }
}

/// View modifiers for state transitions
struct UIStateModifier: ViewModifier {
    let state: UIComplexityState
    let component: UIComponent
    let configuration: UIStateConfiguration

    @State private var isVisible: Bool = false

    func body(content: Content) -> some View {
        let shouldShow = shouldShowComponent()

        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .animation(
                configuration.animationsEnabled
                    ? .easeInOut(duration: state.transitionDuration * configuration.transitionSpeed.multiplier)
                    : nil,
                value: isVisible
            )
            .onAppear {
                isVisible = shouldShow
            }
            .onChange(of: state) { _ in
                isVisible = shouldShow
            }
    }

    private func shouldShowComponent() -> Bool {
        // Always show essential components
        if component.isEssential {
            return true
        }

        // Check user overrides
        if configuration.alwaysVisible.contains(component) {
            return true
        }

        if configuration.neverVisible.contains(component) {
            return false
        }

        // Check state configuration
        return state.visibleComponents.contains(component)
    }
}

extension View {
    /// Applies UI state visibility rules to a view
    func uiStateVisible(
        _ component: UIComponent,
        state: UIComplexityState,
        configuration: UIStateConfiguration = UIStateConfiguration()
    ) -> some View {
        modifier(UIStateModifier(state: state, component: component, configuration: configuration))
    }
}

/// Behavior patterns that trigger state changes
enum BehaviorPattern: String, Codable {
    // Reading patterns
    case continuousScrolling     // Scrolling through pages
    case pageFlipping           // Moving page by page
    case sustainedReading       // Eyes focused on text
    case skimming               // Quick scanning

    // Editing patterns
    case textSelection          // Selecting text
    case toolHovering          // Mouse over editing tools
    case frequentUndo          // Multiple undo operations
    case annotationDrawing     // Drawing annotations

    // Power user patterns
    case keyboardShortcuts     // Using keyboard shortcuts
    case rapidToolSwitching    // Switching between tools quickly
    case versionControlUsage   // Using version control features
    case multipleDocuments     // Working with multiple documents

    // Idle patterns
    case noInput               // No keyboard/mouse input
    case gazeWandering        // Gaze not focused on document
    case minimized            // Window minimized or background

    /// Suggested state for this pattern
    var suggestedState: UIComplexityState {
        switch self {
        case .continuousScrolling, .pageFlipping, .sustainedReading, .skimming:
            return .reading

        case .textSelection, .toolHovering, .frequentUndo, .annotationDrawing:
            return .editing

        case .keyboardShortcuts, .rapidToolSwitching, .versionControlUsage, .multipleDocuments:
            return .power

        case .noInput, .gazeWandering, .minimized:
            return .minimal
        }
    }

    /// Confidence level for this detection
    var detectionConfidence: Double {
        switch self {
        case .continuousScrolling, .pageFlipping, .textSelection:
            return 0.9  // High confidence

        case .sustainedReading, .toolHovering, .keyboardShortcuts:
            return 0.8

        case .skimming, .annotationDrawing, .rapidToolSwitching:
            return 0.75

        case .frequentUndo, .versionControlUsage, .multipleDocuments:
            return 0.7

        case .noInput, .gazeWandering, .minimized:
            return 0.95  // Very high confidence
        }
    }
}

/// Detected behavior with metadata
struct DetectedBehavior {
    let pattern: BehaviorPattern
    let confidence: Double
    let timestamp: Date
    let metadata: [String: Any]

    var suggestedState: UIComplexityState {
        pattern.suggestedState
    }
}

/// State transition animator
class StateTransitionAnimator: ObservableObject {
    @Published var currentState: UIComplexityState = .reading

    private var transitionInProgress: Bool = false

    /// Transitions to a new state with animation
    func transition(to newState: UIComplexityState, reason: StateTransition.TransitionReason) async {
        guard !transitionInProgress, newState != currentState else { return }

        transitionInProgress = true

        // Create transition record
        let transition = StateTransition(
            from: currentState,
            to: newState,
            reason: reason,
            timestamp: Date()
        )

        print("UI State: \(transition.from.rawValue) → \(transition.to.rawValue) (\(reason.rawValue))")

        // Animate transition
        await MainActor.run {
            withAnimation(.easeInOut(duration: newState.transitionDuration)) {
                currentState = newState
            }
        }

        // Wait for animation to complete
        try? await Task.sleep(nanoseconds: UInt64(newState.transitionDuration * 1_000_000_000))

        transitionInProgress = false
    }

    /// Forces immediate transition without animation
    func forceTransition(to newState: UIComplexityState) {
        guard newState != currentState else { return }

        currentState = newState
        print("UI State: Forced → \(newState.rawValue)")
    }
}

/// State history tracker
actor StateHistoryTracker {
    private var history: [StateTransition] = []
    private let maxHistorySize: Int = 100

    /// Records a state transition
    func recordTransition(_ transition: StateTransition) {
        history.append(transition)

        if history.count > maxHistorySize {
            history.removeFirst()
        }
    }

    /// Gets recent transition history
    func getHistory(last: Int = 10) -> [StateTransition] {
        Array(history.suffix(last))
    }

    /// Gets statistics about state usage
    func getStatistics() -> StateStatistics {
        guard !history.isEmpty else {
            return StateStatistics()
        }

        var stateDurations: [UIComplexityState: TimeInterval] = [:]
        var transitionCounts: [UIComplexityState: Int] = [:]

        for i in 0..<history.count {
            let transition = history[i]
            transitionCounts[transition.to, default: 0] += 1

            // Calculate duration in this state
            if i < history.count - 1 {
                let duration = history[i + 1].timestamp.timeIntervalSince(transition.timestamp)
                stateDurations[transition.to, default: 0] += duration
            }
        }

        // Find most common state
        let mostCommonState = transitionCounts.max(by: { $0.value < $1.value })?.key ?? .reading

        return StateStatistics(
            totalTransitions: history.count,
            stateDurations: stateDurations,
            transitionCounts: transitionCounts,
            mostCommonState: mostCommonState
        )
    }
}

/// State usage statistics
struct StateStatistics {
    var totalTransitions: Int = 0
    var stateDurations: [UIComplexityState: TimeInterval] = [:]
    var transitionCounts: [UIComplexityState: Int] = [:]
    var mostCommonState: UIComplexityState = .reading

    /// Gets percentage of time in each state
    func timePercentage(for state: UIComplexityState) -> Double {
        let totalTime = stateDurations.values.reduce(0, +)
        guard totalTime > 0 else { return 0 }

        let stateTime = stateDurations[state] ?? 0
        return stateTime / totalTime * 100
    }
}
