import SwiftUI

struct SettingsView: View {
    @AppStorage("scanQuality") private var scanQuality = ScanQualitySetting.high
    @AppStorage("autoProcess") private var autoProcess = true
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    var body: some View {
        NavigationStack {
            List {
                // Scan Settings
                Section("Scan Settings") {
                    Picker("Scan Quality", selection: $scanQuality) {
                        ForEach(ScanQualitySetting.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }

                    Toggle("Auto Process After Scan", isOn: $autoProcess)

                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }

                // Export Settings
                Section("Export Settings") {
                    NavigationLink("Default Export Format") {
                        ExportFormatSettingsView()
                    }

                    NavigationLink("Default Scale") {
                        ScaleSettingsView()
                    }
                }

                // Storage
                Section("Storage") {
                    HStack {
                        Text("Used Storage")
                        Spacer()
                        Text("125 MB")
                            .foregroundColor(.secondary)
                    }

                    Button("Clear Cache", role: .destructive) {
                        // Clear cache action
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink("Tutorial") {
                        TutorialView()
                    }

                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }

                    Link("Rate App", destination: URL(string: "https://apps.apple.com")!)

                    Link("Contact Support", destination: URL(string: "mailto:support@example.com")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Settings Enums
enum ScanQualitySetting: String, CaseIterable {
    case low, medium, high, ultra

    var displayName: String {
        switch self {
        case .low: return "Low (Fast)"
        case .medium: return "Medium"
        case .high: return "High (Recommended)"
        case .ultra: return "Ultra (Slow)"
        }
    }
}

// MARK: - Sub Views
struct ExportFormatSettingsView: View {
    @AppStorage("defaultExportFormat") private var defaultFormat = "STL"

    var body: some View {
        List {
            ForEach(["STL", "OBJ", "GLTF", "USDZ", "PLY"], id: \.self) { format in
                Button(action: { defaultFormat = format }) {
                    HStack {
                        Text(format)
                        Spacer()
                        if defaultFormat == format {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Export Format")
    }
}

struct ScaleSettingsView: View {
    @AppStorage("defaultScale") private var defaultScale = 1.0

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Scale")
                    Slider(value: $defaultScale, in: 0.1...5.0, step: 0.1)
                    Text(String(format: "%.1fx", defaultScale))
                        .frame(width: 50)
                }
            }

            Section("Presets") {
                ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { scale in
                    Button(action: { defaultScale = scale }) {
                        HStack {
                            Text("\(String(format: "%.1f", scale))x")
                            Spacer()
                            if defaultScale == scale {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("Default Scale")
    }
}

struct TutorialView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TutorialStep(number: 1, title: "Choose Scan Type", description: "Select Face, Body, or Bust scan from the home screen.")
                TutorialStep(number: 2, title: "Position Subject", description: "Follow the on-screen guides to position correctly.")
                TutorialStep(number: 3, title: "Start Scanning", description: "Tap the capture button and follow movement instructions.")
                TutorialStep(number: 4, title: "Review & Export", description: "Preview your 3D model and export for printing.")
            }
            .padding()
        }
        .navigationTitle("Tutorial")
    }
}

struct TutorialStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
            Privacy Policy

            Last updated: December 2024

            Your privacy is important to us. This app processes all 3D scanning data locally on your device.

            Data Collection:
            - All scans are stored locally on your device
            - No personal data is transmitted to external servers
            - Camera and LiDAR data is used only for scanning

            Data Storage:
            - Scan data is stored in the app's private container
            - You can delete any scan at any time

            Contact us at support@example.com for questions.
            """)
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

#Preview {
    SettingsView()
}
