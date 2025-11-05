//
//  CalibrationView.swift
//  PDFOS
//
//  Calibration UI for gaze tracking
//

import SwiftUI

/// Gaze tracking calibration view
struct CalibrationView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CalibrationViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full screen background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                if viewModel.isCalibrating {
                    calibrationContent
                } else if viewModel.isComplete {
                    completionContent
                } else {
                    instructionsContent
                }
            }
            .padding()

            // Calibration point
            if viewModel.isCalibrating,
               let point = viewModel.currentCalibrationPoint {
                calibrationTarget(at: point)
            }
        }
    }

    // MARK: - Instructions Content

    private var instructionsContent: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Gaze Tracking Calibration")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This process will calibrate gaze tracking for the adaptive UI.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 15) {
                InstructionRow(
                    icon: "1.circle.fill",
                    text: "Look at each target point as it appears"
                )

                InstructionRow(
                    icon: "2.circle.fill",
                    text: "Keep your head still and focus on the target"
                )

                InstructionRow(
                    icon: "3.circle.fill",
                    text: "The calibration will take about 30 seconds"
                )
            }
            .padding(.top, 20)

            Spacer()

            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Start Calibration") {
                    Task {
                        await viewModel.startCalibration()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .font(.title3)
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Calibration Content

    private var calibrationContent: some View {
        VStack(spacing: 20) {
            Text("Look at the target")
                .font(.title)
                .fontWeight(.semibold)

            ProgressView(
                value: Double(viewModel.currentPointIndex),
                total: Double(viewModel.totalPoints)
            )
            .frame(width: 300)

            Text("\(viewModel.currentPointIndex + 1) of \(viewModel.totalPoints)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 50)
    }

    // MARK: - Completion Content

    private var completionContent: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Calibration Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let accuracy = viewModel.calibrationAccuracy {
                VStack(spacing: 10) {
                    Text("Accuracy")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f%%", accuracy * 100))
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(accuracyColor(accuracy))
                }
                .padding(.top, 20)
            }

            Text("The adaptive UI is now ready to use.")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .font(.title3)
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Calibration Target

    private func calibrationTarget(at point: CGPoint) -> some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                .frame(width: 60, height: 60)

            // Inner circle
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)

            // Animated pulse
            Circle()
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: 40, height: 40)
                .scaleEffect(viewModel.pulseAnimation ? 1.5 : 1.0)
                .opacity(viewModel.pulseAnimation ? 0.0 : 1.0)
                .animation(
                    .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                    value: viewModel.pulseAnimation
                )
        }
        .position(point)
        .onAppear {
            viewModel.pulseAnimation = true
        }
    }

    // MARK: - Helper Methods

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.9 {
            return .green
        } else if accuracy >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - View Model

@MainActor
class CalibrationViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isCalibrating: Bool = false
    @Published var isComplete: Bool = false
    @Published var currentPointIndex: Int = 0
    @Published var totalPoints: Int = 9
    @Published var currentCalibrationPoint: CGPoint?
    @Published var calibrationAccuracy: Double?
    @Published var pulseAnimation: Bool = false

    // MARK: - Private Properties

    private let gazeTracker = GazeTracker.shared
    private var calibrationSession: CalibrationSession?
    private var calibrationPoints: [CGPoint] = []

    // MARK: - Public Methods

    func startCalibration() async {
        isCalibrating = true

        do {
            // Start gaze tracking if not already running
            try await gazeTracker.startTracking()

            // Start calibration session
            calibrationSession = try await gazeTracker.startCalibration()
            calibrationPoints = calibrationSession?.points ?? []
            totalPoints = calibrationPoints.count

            // Show first point
            await showNextCalibrationPoint()

        } catch {
            print("Calibration error: \(error)")
            isCalibrating = false
        }
    }

    // MARK: - Private Methods

    private func showNextCalibrationPoint() async {
        guard let session = calibrationSession,
              currentPointIndex < calibrationPoints.count else {
            await completeCalibration()
            return
        }

        let point = calibrationPoints[currentPointIndex]
        currentCalibrationPoint = point

        // Wait for user to focus
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay

        // Record calibration point
        do {
            calibrationSession = try await gazeTracker.recordCalibrationPoint(
                expectedPoint: point,
                session: session
            )

            currentPointIndex += 1

            // Move to next point
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s between points
            await showNextCalibrationPoint()

        } catch {
            print("Error recording calibration point: \(error)")
            isCalibrating = false
        }
    }

    private func completeCalibration() async {
        guard let session = calibrationSession else { return }

        do {
            // Complete calibration
            try await gazeTracker.completeCalibration(session: session)

            // Calculate accuracy
            calibrationAccuracy = calculateAccuracy(session: session)

            isCalibrating = false
            isComplete = true

        } catch {
            print("Error completing calibration: \(error)")
            isCalibrating = false
        }
    }

    private func calculateAccuracy(session: CalibrationSession) -> Double {
        guard !session.measurements.isEmpty else { return 0 }

        var totalError: CGFloat = 0

        for measurement in session.measurements {
            let error = hypot(
                measurement.expectedPoint.x - measurement.measuredPoint.x,
                measurement.expectedPoint.y - measurement.measuredPoint.y
            )
            totalError += error
        }

        let avgError = totalError / CGFloat(session.measurements.count)

        // Convert error to accuracy (0-1)
        // Assume perfect accuracy at 0 error, 0% at 100 pixels error
        let accuracy = max(0, 1.0 - Double(avgError) / 100.0)

        return accuracy
    }
}

// MARK: - Preview

#Preview {
    CalibrationView()
}
