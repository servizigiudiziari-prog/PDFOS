//
//  IntentPredictor.swift
//  PDFOS
//
//  ML-based predictor for user intent and UI state transitions
//

import Foundation
import CoreML

/// Predicts user intent using machine learning
actor IntentPredictor {
    // MARK: - Properties

    private var model: MLModel?
    private var trainingData: [TrainingExample] = []
    private let maxTrainingExamples: Int = 1000

    // Feature weights (learned or configured)
    private var featureWeights: FeatureWeights = FeatureWeights()

    // Prediction cache
    private var predictionCache: [CacheKey: IntentPrediction] = [:]
    private let cacheExpiration: TimeInterval = 5.0 // 5 seconds

    // MARK: - Initialization

    init() {
        loadModel()
    }

    // MARK: - Public Methods

    /// Predicts user intent based on current context
    func predictIntent(
        currentState: UIComplexityState,
        recentBehaviors: [DetectedBehavior],
        gazeData: [GazeData]
    ) -> IntentPrediction {
        // Check cache
        let cacheKey = CacheKey(
            state: currentState,
            behaviorCount: recentBehaviors.count,
            gazeCount: gazeData.count
        )

        if let cached = predictionCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            return cached
        }

        // Extract features
        let features = extractFeatures(
            currentState: currentState,
            recentBehaviors: recentBehaviors,
            gazeData: gazeData
        )

        // Make prediction
        let prediction = if let model = model {
            predictWithModel(features: features)
        } else {
            predictWithRules(features: features)
        }

        // Cache result
        predictionCache[cacheKey] = prediction

        // Clean old cache entries
        cleanCache()

        return prediction
    }

    /// Records actual state transition for learning
    func recordOutcome(
        features: PredictionFeatures,
        actualState: UIComplexityState,
        wasCorrect: Bool
    ) {
        let example = TrainingExample(
            features: features,
            label: actualState,
            timestamp: Date()
        )

        trainingData.append(example)

        if trainingData.count > maxTrainingExamples {
            trainingData.removeFirst()
        }

        // Update feature weights based on outcome
        updateFeatureWeights(features: features, wasCorrect: wasCorrect)
    }

    /// Gets prediction accuracy statistics
    func getAccuracy() -> PredictionAccuracy {
        guard !trainingData.isEmpty else {
            return PredictionAccuracy()
        }

        // Calculate accuracy by state
        var correctByState: [UIComplexityState: Int] = [:]
        var totalByState: [UIComplexityState: Int] = [:]

        for example in trainingData {
            totalByState[example.label, default: 0] += 1

            // Re-predict to check if we would be correct now
            let prediction = predictWithRules(features: example.features)

            if prediction.predictedState == example.label {
                correctByState[example.label, default: 0] += 1
            }
        }

        let overallCorrect = correctByState.values.reduce(0, +)
        let overallTotal = totalByState.values.reduce(0, +)
        let overallAccuracy = Double(overallCorrect) / Double(max(1, overallTotal))

        return PredictionAccuracy(
            overallAccuracy: overallAccuracy,
            accuracyByState: correctByState.mapValues { correct in
                Double(correct) / Double(max(1, totalByState[.reading] ?? 1))
            },
            totalPredictions: overallTotal
        )
    }

    // MARK: - Feature Extraction

    private func extractFeatures(
        currentState: UIComplexityState,
        recentBehaviors: [DetectedBehavior],
        gazeData: [GazeData]
    ) -> PredictionFeatures {
        var features = PredictionFeatures()

        // Current state features
        features.currentStateIndex = UIComplexityState.allCases.firstIndex(of: currentState) ?? 0

        // Behavior features
        if !recentBehaviors.isEmpty {
            // Average confidence
            features.averageBehaviorConfidence = recentBehaviors.map { $0.confidence }.reduce(0, +) / Double(recentBehaviors.count)

            // Dominant pattern
            var patternCounts: [BehaviorPattern: Int] = [:]
            for behavior in recentBehaviors {
                patternCounts[behavior.pattern, default: 0] += 1
            }

            if let dominantPattern = patternCounts.max(by: { $0.value < $1.value })?.key {
                features.dominantPattern = dominantPattern
                features.patternConsistency = Double(patternCounts[dominantPattern]!) / Double(recentBehaviors.count)
            }

            // Time since last behavior
            if let last = recentBehaviors.last {
                features.timeSinceLastBehavior = Date().timeIntervalSince(last.timestamp)
            }
        }

        // Gaze features
        if !gazeData.isEmpty {
            // Average confidence
            features.averageGazeConfidence = gazeData.map { $0.confidence }.reduce(0, +) / Double(gazeData.count)

            // Gaze stability (variance)
            features.gazeStability = calculateGazeStability(gazeData)

            // Fixation count
            features.fixationCount = countFixations(in: gazeData)

            // Gaze velocity
            features.gazeVelocity = calculateGazeVelocity(gazeData)
        }

        return features
    }

    private func calculateGazeStability(_ gazeData: [GazeData]) -> Double {
        guard gazeData.count >= 2 else { return 1.0 }

        let points = gazeData.map { $0.point }

        // Calculate variance
        let meanX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let meanY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)

        let variance = points.map { pow($0.x - meanX, 2) + pow($0.y - meanY, 2) }.reduce(0, +) / CGFloat(points.count)

        // Normalize to 0-1 (inverse of variance, clamped)
        let stability = 1.0 / (1.0 + Double(variance) / 10000.0)

        return min(1.0, max(0.0, stability))
    }

    private func countFixations(in gazeData: [GazeData]) -> Int {
        guard gazeData.count >= 3 else { return 0 }

        var fixations = 0
        var currentFixation: [GazeData] = []

        for gaze in gazeData {
            if let last = currentFixation.last {
                let distance = hypot(gaze.point.x - last.point.x, gaze.point.y - last.point.y)

                if distance < 30 {
                    currentFixation.append(gaze)
                } else {
                    if currentFixation.count >= 3 {
                        fixations += 1
                    }
                    currentFixation = [gaze]
                }
            } else {
                currentFixation.append(gaze)
            }
        }

        if currentFixation.count >= 3 {
            fixations += 1
        }

        return fixations
    }

    private func calculateGazeVelocity(_ gazeData: [GazeData]) -> Double {
        guard gazeData.count >= 2 else { return 0 }

        var totalDistance: CGFloat = 0

        for i in 1..<gazeData.count {
            let p1 = gazeData[i - 1].point
            let p2 = gazeData[i].point
            totalDistance += hypot(p2.x - p1.x, p2.y - p1.y)
        }

        let duration = gazeData.last!.timestamp.timeIntervalSince(gazeData.first!.timestamp)

        return duration > 0 ? Double(totalDistance / CGFloat(duration)) : 0
    }

    // MARK: - Prediction Methods

    private func predictWithModel(features: PredictionFeatures) -> IntentPrediction {
        // TODO: Implement actual CoreML model prediction
        // For now, fall back to rule-based
        return predictWithRules(features: features)
    }

    private func predictWithRules(features: PredictionFeatures) -> IntentPrediction {
        var stateScores: [UIComplexityState: Double] = [
            .minimal: 0.0,
            .reading: 0.0,
            .editing: 0.0,
            .power: 0.0
        ]

        // Behavior-based scoring
        if let pattern = features.dominantPattern {
            let suggestedState = pattern.suggestedState
            stateScores[suggestedState, default: 0] += features.averageBehaviorConfidence * featureWeights.behaviorWeight
            stateScores[suggestedState, default: 0] += features.patternConsistency * featureWeights.consistencyWeight
        }

        // Gaze-based scoring
        if features.gazeStability > 0.7 {
            // High stability = reading
            stateScores[.reading, default: 0] += features.gazeStability * featureWeights.gazeStabilityWeight
        }

        if features.fixationCount >= 3 {
            // Multiple fixations = sustained reading
            stateScores[.reading, default: 0] += 0.3 * featureWeights.fixationWeight
        }

        if features.gazeVelocity > 500 {
            // High velocity = editing/power mode
            stateScores[.editing, default: 0] += 0.25 * featureWeights.velocityWeight
            stateScores[.power, default: 0] += 0.15 * featureWeights.velocityWeight
        }

        // Inactivity scoring
        if features.timeSinceLastBehavior > 30.0 {
            stateScores[.minimal, default: 0] += 0.5 * featureWeights.inactivityWeight
        }

        // Find highest scoring state
        let (predictedState, score) = stateScores.max(by: { $0.value < $1.value }) ?? (.reading, 0.5)

        // Normalize confidence
        let totalScore = stateScores.values.reduce(0, +)
        let confidence = totalScore > 0 ? score / totalScore : 0.5

        return IntentPrediction(
            predictedState: predictedState,
            confidence: min(1.0, max(0.0, confidence)),
            alternativeStates: stateScores.sorted { $0.value > $1.value }.map { $0.key },
            features: features,
            timestamp: Date()
        )
    }

    // MARK: - Learning

    private func updateFeatureWeights(features: PredictionFeatures, wasCorrect: Bool) {
        let learningRate = 0.05
        let adjustment = wasCorrect ? learningRate : -learningRate

        // Adjust weights based on which features were present
        if features.averageBehaviorConfidence > 0 {
            featureWeights.behaviorWeight = max(0.1, min(1.0, featureWeights.behaviorWeight + adjustment))
        }

        if features.gazeStability > 0 {
            featureWeights.gazeStabilityWeight = max(0.1, min(1.0, featureWeights.gazeStabilityWeight + adjustment))
        }

        if features.fixationCount > 0 {
            featureWeights.fixationWeight = max(0.1, min(1.0, featureWeights.fixationWeight + adjustment))
        }
    }

    private func loadModel() {
        // TODO: Load trained CoreML model if available
        // For now, use rule-based prediction
    }

    private func cleanCache() {
        let now = Date()
        predictionCache = predictionCache.filter { _, prediction in
            now.timeIntervalSince(prediction.timestamp) < cacheExpiration
        }
    }
}

// MARK: - Supporting Types

/// Features used for prediction
struct PredictionFeatures: Hashable {
    var currentStateIndex: Int = 0
    var averageBehaviorConfidence: Double = 0
    var dominantPattern: BehaviorPattern?
    var patternConsistency: Double = 0
    var timeSinceLastBehavior: TimeInterval = 0
    var averageGazeConfidence: Double = 0
    var gazeStability: Double = 0
    var fixationCount: Int = 0
    var gazeVelocity: Double = 0

    func hash(into hasher: inout Hasher) {
        hasher.combine(currentStateIndex)
        hasher.combine(Int(averageBehaviorConfidence * 100))
        hasher.combine(dominantPattern)
    }
}

/// Intent prediction result
struct IntentPrediction {
    let predictedState: UIComplexityState
    let confidence: Double
    let alternativeStates: [UIComplexityState]
    let features: PredictionFeatures
    let timestamp: Date
}

/// Training example
struct TrainingExample {
    let features: PredictionFeatures
    let label: UIComplexityState
    let timestamp: Date
}

/// Feature weights for prediction
struct FeatureWeights {
    var behaviorWeight: Double = 0.4
    var consistencyWeight: Double = 0.3
    var gazeStabilityWeight: Double = 0.3
    var fixationWeight: Double = 0.25
    var velocityWeight: Double = 0.2
    var inactivityWeight: Double = 0.35
}

/// Prediction accuracy metrics
struct PredictionAccuracy {
    var overallAccuracy: Double = 0
    var accuracyByState: [UIComplexityState: Double] = [:]
    var totalPredictions: Int = 0
}

/// Cache key for predictions
private struct CacheKey: Hashable {
    let state: UIComplexityState
    let behaviorCount: Int
    let gazeCount: Int
}
