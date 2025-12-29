import SwiftUI

struct BustScanView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "person.bust")
                    .font(.system(size: 80))
                    .foregroundColor(.purple)

                Text("Bust Scan")
                    .font(.title)
                    .foregroundColor(.white)

                Text("Coming in version 1.5")
                    .foregroundColor(.secondary)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding()
        }
    }
}

#Preview {
    BustScanView()
}
