import SwiftUI

/// Onboarding view shown to first-time users
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to 3D Scanner",
            subtitle: "Create stunning 3D models using your iPhone's LiDAR sensor",
            imageName: "cube.transparent.fill",
            imageColor: .blue,
            features: [
                OnboardingFeature(icon: "face.smiling", title: "Face Scan", description: "Capture detailed facial features"),
                OnboardingFeature(icon: "figure.stand", title: "Body Scan", description: "Full 360° body scanning"),
                OnboardingFeature(icon: "person.bust", title: "Bust Scan", description: "Head and shoulders capture")
            ]
        ),
        OnboardingPage(
            title: "Scanning Tips",
            subtitle: "Get the best results with these tips",
            imageName: "lightbulb.fill",
            imageColor: .yellow,
            features: [
                OnboardingFeature(icon: "sun.max", title: "Good Lighting", description: "Scan in well-lit environments"),
                OnboardingFeature(icon: "arrow.left.and.right", title: "Keep Distance", description: "Stay 30-50cm from the subject"),
                OnboardingFeature(icon: "figure.walk", title: "Move Slowly", description: "Walk around steadily for body scans")
            ]
        ),
        OnboardingPage(
            title: "Export & Share",
            subtitle: "Use your 3D models anywhere",
            imageName: "square.and.arrow.up.fill",
            imageColor: .green,
            features: [
                OnboardingFeature(icon: "cube", title: "STL Format", description: "Perfect for 3D printing"),
                OnboardingFeature(icon: "cube.transparent", title: "OBJ + Texture", description: "For modeling software"),
                OnboardingFeature(icon: "arkit", title: "AR Preview", description: "View in augmented reality")
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .foregroundColor(.secondary)
                .padding()
            }

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator and button
            VStack(spacing: 24) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Page
struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let imageColor: Color
    let features: [OnboardingFeature]
}

struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.imageName)
                    .font(.system(size: 50))
                    .foregroundColor(page.imageColor)
            }

            // Title & Subtitle
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Features
            VStack(spacing: 16) {
                ForEach(page.features, id: \.title) { feature in
                    FeatureRow(feature: feature)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: OnboardingFeature

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: feature.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Help Section View
struct HelpSectionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Getting Started") {
                    NavigationLink {
                        HelpDetailView(
                            title: "How to Scan a Face",
                            steps: [
                                "Position the subject 30-50cm from your device",
                                "Ensure good lighting on the face",
                                "Tap the capture button to start",
                                "Follow the on-screen guidance to capture all angles",
                                "Wait for processing to complete"
                            ]
                        )
                    } label: {
                        Label("Face Scanning", systemImage: "face.smiling")
                    }

                    NavigationLink {
                        HelpDetailView(
                            title: "How to Scan a Body",
                            steps: [
                                "Have the subject stand still in an open area",
                                "Position yourself 1.5-3m away",
                                "Tap capture and slowly walk around the subject",
                                "Follow the 360° progress indicator",
                                "Complete the full circle for best results"
                            ]
                        )
                    } label: {
                        Label("Body Scanning", systemImage: "figure.stand")
                    }

                    NavigationLink {
                        HelpDetailView(
                            title: "How to Scan a Bust",
                            steps: [
                                "Position subject 40-80cm from device",
                                "Focus on head and shoulders area",
                                "Move around to capture all angles",
                                "Good for creating portrait busts"
                            ]
                        )
                    } label: {
                        Label("Bust Scanning", systemImage: "person.bust")
                    }
                }

                Section("Tips for Best Results") {
                    HelpTipRow(icon: "sun.max", title: "Use Good Lighting", description: "Natural daylight or bright indoor lighting works best")
                    HelpTipRow(icon: "hand.raised", title: "Stay Still", description: "Keep the subject as still as possible during scanning")
                    HelpTipRow(icon: "tortoise", title: "Move Slowly", description: "Slow, steady movements capture more detail")
                    HelpTipRow(icon: "rectangle.portrait", title: "Avoid Reflective Surfaces", description: "Shiny objects and mirrors can confuse the scanner")
                    HelpTipRow(icon: "xmark.circle", title: "Avoid Glass", description: "LiDAR cannot scan through glass surfaces")
                }

                Section("Exporting") {
                    NavigationLink {
                        HelpDetailView(
                            title: "Export Formats",
                            steps: [
                                "STL: Best for 3D printing (no color/texture)",
                                "OBJ: Includes texture, ideal for 3D software",
                                "PLY: Point cloud format with vertex colors",
                                "USDZ: Apple's AR format for Quick Look"
                            ]
                        )
                    } label: {
                        Label("Export Formats", systemImage: "square.and.arrow.up")
                    }

                    NavigationLink {
                        HelpDetailView(
                            title: "Units & Scaling",
                            steps: [
                                "Default scan units are in meters",
                                "Choose mm, cm, or inches for export",
                                "STL files for 3D printing typically use mm",
                                "Scale factor is applied during export"
                            ]
                        )
                    } label: {
                        Label("Units & Scaling", systemImage: "ruler")
                    }
                }

                Section("Troubleshooting") {
                    HelpTipRow(icon: "exclamationmark.triangle", title: "LiDAR Not Available", description: "This app requires iPhone 12 Pro or later with LiDAR")
                    HelpTipRow(icon: "arrow.clockwise", title: "Scan Failed", description: "Try moving slower and ensuring good lighting")
                    HelpTipRow(icon: "memorychip", title: "Out of Memory", description: "Close other apps and try a simpler scan")
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Help Detail View
struct HelpDetailView: View {
    let title: String
    let steps: [String]

    var body: some View {
        List {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 28, height: 28)

                        Text("\(index + 1)")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Text(step)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Help Tip Row
struct HelpTipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Onboarding") {
    OnboardingView()
}

#Preview("Help") {
    HelpSectionView()
}
