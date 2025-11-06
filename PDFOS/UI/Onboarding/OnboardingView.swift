//
//  OnboardingView.swift
//  PDFOS
//
//  Onboarding flow for new users
//

import SwiftUI

/// Complete onboarding flow for new users
struct OnboardingView: View {
    // MARK: - Properties

    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(current: viewModel.currentStep, total: viewModel.totalSteps)
                    .padding(.top)

                // Current step content
                TabView(selection: $viewModel.currentStep) {
                    WelcomeStep()
                        .tag(0)

                    FeaturesStep()
                        .tag(1)

                    AdaptiveUIStep(viewModel: viewModel)
                        .tag(2)

                    CloudSyncStep(viewModel: viewModel)
                        .tag(3)

                    PermissionsStep(viewModel: viewModel)
                        .tag(4)

                    CompletionStep()
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack(spacing: 20) {
                    if viewModel.currentStep > 0 {
                        Button("Back") {
                            viewModel.goBack()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if viewModel.currentStep < viewModel.totalSteps - 1 {
                        Button("Continue") {
                            viewModel.goNext()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canProceed)
                    } else {
                        Button("Get Started") {
                            viewModel.completeOnboarding()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.system(size: 100))
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 15) {
                Text("Welcome to PDFOS")
                    .font(.system(size: 48, weight: .bold))

                Text("The Revolutionary PDF Editor")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Text("Let's take a quick tour of the features that make PDFOS special")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Features Step

struct FeaturesStep: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Three Revolutionary Features")
                .font(.system(size: 36, weight: .bold))
                .padding(.top, 40)

            VStack(spacing: 30) {
                FeatureCard(
                    icon: "brain.head.profile",
                    title: "Semantic Version Control",
                    description: "Track changes by meaning, not just text. BERT-powered understanding of document modifications.",
                    color: .blue
                )

                FeatureCard(
                    icon: "clock.arrow.circlepath",
                    title: "Time Travel Debugging",
                    description: "Replay document history like a video. See exactly how your document evolved over time.",
                    color: .purple
                )

                FeatureCard(
                    icon: "eye.fill",
                    title: "Adaptive Interface",
                    description: "UI that adapts to what you're doing. From minimal reading to power user mode.",
                    color: .green
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Adaptive UI Step

struct AdaptiveUIStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .padding(.top, 40)

            Text("Adaptive Interface")
                .font(.system(size: 36, weight: .bold))

            Text("The interface adapts to your behavior")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 20) {
                Toggle("Enable Adaptive UI", isOn: $viewModel.enableAdaptiveUI)
                    .toggleStyle(.switch)
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)

                if viewModel.enableAdaptiveUI {
                    VStack(alignment: .leading, spacing: 12) {
                        OnboardingInfoRow(
                            icon: "1.circle.fill",
                            text: "Minimal Mode - Clean reading"
                        )

                        OnboardingInfoRow(
                            icon: "2.circle.fill",
                            text: "Reading Mode - Navigation tools"
                        )

                        OnboardingInfoRow(
                            icon: "3.circle.fill",
                            text: "Editing Mode - Common edits"
                        )

                        OnboardingInfoRow(
                            icon: "4.circle.fill",
                            text: "Power Mode - All features"
                        )
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Cloud Sync Step

struct CloudSyncStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Cloud Synchronization")
                .font(.system(size: 36, weight: .bold))

            Text("Keep your documents in sync across all your devices")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 20) {
                Toggle("Enable iCloud Sync", isOn: $viewModel.enableCloudSync)
                    .toggleStyle(.switch)
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)

                if viewModel.enableCloudSync {
                    VStack(spacing: 15) {
                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Automatic backup to iCloud"
                        )

                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Cross-device synchronization"
                        )

                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Version history preserved"
                        )

                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Works offline, syncs when online"
                        )
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.top, 40)

            Text("Privacy & Permissions")
                .font(.system(size: 36, weight: .bold))

            Text("PDFOS respects your privacy")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(spacing: 20) {
                PermissionCard(
                    icon: "camera.fill",
                    title: "Camera Access",
                    description: "For gaze tracking in Adaptive UI (optional)",
                    isGranted: $viewModel.cameraPermissionGranted,
                    onRequest: {
                        Task {
                            await viewModel.requestCameraPermission()
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)

                        Text("Privacy-First Design")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "All processing on-device"
                        )

                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "No data sent to external servers"
                        )

                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Camera never records video"
                        )

                        OnboardingInfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Optional anonymous analytics"
                        )
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant") {
                    onRequest()
                }
                .buttonStyle(.bordered)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Completion Step

struct CompletionStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)

            VStack(spacing: 15) {
                Text("You're All Set!")
                    .font(.system(size: 48, weight: .bold))

                Text("Ready to revolutionize your PDF workflow")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 15) {
                OnboardingInfoRow(
                    icon: "command",
                    text: "Press Cmd+T to open Timeline"
                )

                OnboardingInfoRow(
                    icon: "command",
                    text: "Press Cmd+1/2/3/4 to change UI mode"
                )

                OnboardingInfoRow(
                    icon: "command",
                    text: "Press Cmd+Shift+A for Adaptive UI"
                )
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Info Row

struct OnboardingInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - View Model

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentStep: Int = 0
    @Published var enableAdaptiveUI: Bool = true
    @Published var enableCloudSync: Bool = true
    @Published var cameraPermissionGranted: Bool = false

    // MARK: - Properties

    let totalSteps: Int = 6

    var canProceed: Bool {
        // Can always proceed, but some features require permission
        return true
    }

    // MARK: - Methods

    func goNext() {
        withAnimation {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }

    func goBack() {
        withAnimation {
            currentStep = max(currentStep - 1, 0)
        }
    }

    func completeOnboarding() {
        // Save preferences
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        UserDefaults.standard.set(enableAdaptiveUI, forKey: "adaptiveUIEnabled")
        UserDefaults.standard.set(enableCloudSync, forKey: "cloudSyncEnabled")

        // Apply settings
        if enableAdaptiveUI {
            Task {
                let coordinator = AdaptiveUICoordinator.shared
                try? await coordinator.enable()
            }
        }

        if enableCloudSync {
            Task {
                let cloudKit = CloudKitManager.shared
                try? await cloudKit.performFullSync()
            }
        }

        print("Onboarding completed")
    }

    func requestCameraPermission() async {
        // Request camera permission for gaze tracking
        #if canImport(AVFoundation)
        import AVFoundation

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionGranted = granted
        } else {
            cameraPermissionGranted = (status == .authorized)
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .frame(width: 800, height: 600)
}
