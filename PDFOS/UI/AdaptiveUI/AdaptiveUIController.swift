//
//  AdaptiveUIController.swift
//  PDFOS
//
//  Controller for adaptive UI complexity management
//

import Foundation
import SwiftUI

/// Controls UI complexity based on user behavior and cognitive load
@MainActor
class AdaptiveUIController: ObservableObject {
    // MARK: - Published Properties

    @Published var currentComplexity: UIComplexity = .editing
    @Published var cognitiveLoad: CognitiveLoad?

    // MARK: - Private Properties

    private var userIntent: UserIntent = .idle
    private var intentHistory: RingBuffer<UserIntent>
    private var adaptationEnabled = true

    // MARK: - Initialization

    init() {
        self.intentHistory = RingBuffer(capacity: 10)
    }

    // MARK: - Public Methods

    /// Updates the UI complexity based on current context
    /// - Parameters:
    ///   - intent: The detected user intent
    ///   - cognitive: The current cognitive load
    func adaptUI(intent: UserIntent, cognitive: CognitiveLoad) {
        guard adaptationEnabled else { return }

        userIntent = intent
        cognitiveLoad = cognitive
        intentHistory.append(intent)

        // Apply adaptation rules
        applyAdaptationRules()
    }

    /// Manually sets UI complexity
    /// - Parameter complexity: The desired complexity level
    func setComplexity(_ complexity: UIComplexity) {
        currentComplexity = complexity
    }

    /// Enables or disables automatic adaptation
    /// - Parameter enabled: Whether adaptation is enabled
    func setAdaptationEnabled(_ enabled: Bool) {
        adaptationEnabled = enabled
    }

    /// Gets the recommended tools for the current context
    /// - Returns: Array of recommended tools
    func getRecommendedTools() -> [String] {
        switch (currentComplexity, userIntent) {
        case (.minimal, _):
            return []

        case (.reading, .reading):
            return ["Navigate", "Search", "Bookmark"]

        case (.editing, .editing):
            return ["Text", "Highlight", "Annotate", "Undo"]

        case (.power, .editing):
            return ["Text", "Highlight", "Annotate", "Shape", "Image", "Form", "Version Control"]

        default:
            return ["Navigate", "Search"]
        }
    }

    // MARK: - Private Methods

    private func applyAdaptationRules() {
        guard let load = cognitiveLoad else { return }

        // Rule 1: High cognitive load → Reduce complexity
        if load.load > 0.8 {
            reduceComplexity()
            return
        }

        // Rule 2: Intent-based adaptation
        switch userIntent {
        case .reading:
            if currentComplexity == .power || currentComplexity == .editing {
                transitionTo(.reading)
            }

        case .editing:
            if currentComplexity == .minimal || currentComplexity == .reading {
                transitionTo(.editing)
            }

        case .searching:
            // Keep current complexity but ensure search is visible
            break

        case .navigating:
            if currentComplexity == .minimal {
                transitionTo(.reading)
            }

        case .confused:
            // User is confused, simplify
            reduceComplexity()

        case .idle:
            // After extended idle, reduce to reading mode
            if isExtendedIdle() {
                transitionTo(.reading)
            }
        }

        // Rule 3: Pattern-based adaptation
        if detectPowerUserPattern() {
            transitionTo(.power)
        }
    }

    private func reduceComplexity() {
        switch currentComplexity {
        case .power:
            transitionTo(.editing)
        case .editing:
            transitionTo(.reading)
        case .reading:
            transitionTo(.minimal)
        case .minimal:
            break // Already minimal
        }
    }

    private func transitionTo(_ complexity: UIComplexity, animated: Bool = true) {
        guard complexity != currentComplexity else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentComplexity = complexity
            }
        } else {
            currentComplexity = complexity
        }

        logTransition(to: complexity)
    }

    private func isExtendedIdle() -> Bool {
        let recentIntents = intentHistory.toArray()
        let idleCount = recentIntents.filter { $0 == .idle }.count
        return idleCount > 5 // More than 5 consecutive idle detections
    }

    private func detectPowerUserPattern() -> Bool {
        let recentIntents = intentHistory.toArray()

        // Look for rapid switching between different intents
        var uniqueIntents = Set<UserIntent>()
        for intent in recentIntents.suffix(5) {
            uniqueIntents.insert(intent)
        }

        // If user is using many different intents, they're likely a power user
        return uniqueIntents.count >= 4
    }

    private func logTransition(to complexity: UIComplexity) {
        #if DEBUG
        print("UI Complexity transition to: \(complexity)")
        #endif
    }
}

// MARK: - Ring Buffer

/// Simple ring buffer for storing fixed-size history
struct RingBuffer<T> {
    private var buffer: [T]
    private var head = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = []
        self.buffer.reserveCapacity(capacity)
    }

    mutating func append(_ element: T) {
        if buffer.count < capacity {
            buffer.append(element)
        } else {
            buffer[head] = element
            head = (head + 1) % capacity
        }
    }

    func toArray() -> [T] {
        if buffer.count < capacity {
            return buffer
        } else {
            return Array(buffer[head..<capacity]) + Array(buffer[0..<head])
        }
    }
}
