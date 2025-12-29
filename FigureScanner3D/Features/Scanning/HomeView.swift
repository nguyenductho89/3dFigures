import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                headerSection
                scanOptionsSection
                Spacer()
            }
            .padding()
            .navigationTitle("3D Scanner")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)

            Text("Create Your 3D Figure")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Scan your face or body to create a printable 3D model")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private var scanOptionsSection: some View {
        VStack(spacing: 16) {
            ScanOptionCard(
                title: "Face Scan",
                description: "Detailed facial capture",
                icon: "face.smiling",
                color: .blue,
                destination: FaceScanView()
            )

            ScanOptionCard(
                title: "Body Scan",
                description: "Full 360° body capture",
                icon: "figure.stand",
                color: .green,
                destination: BodyScanView()
            )

            ScanOptionCard(
                title: "Bust Scan",
                description: "Head and shoulders",
                icon: "person.bust",
                color: .purple,
                destination: BustScanView()
            )
        }
    }
}

// MARK: - Scan Option Card
struct ScanOptionCard<Destination: View>: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
}

#Preview {
    HomeView()
}
