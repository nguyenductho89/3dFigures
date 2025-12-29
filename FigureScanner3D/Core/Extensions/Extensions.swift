import Foundation
import SwiftUI
import simd

// MARK: - Color Extensions
extension Color {
    static let scanBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let scanGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let scanPurple = Color(red: 0.6, green: 0.3, blue: 0.9)

    static let backgroundPrimary = Color(.systemBackground)
    static let backgroundSecondary = Color(.secondarySystemBackground)
    static let backgroundTertiary = Color(.tertiarySystemBackground)
}

// MARK: - Date Extensions
extension Date {
    // MARK: Cached Formatters (for performance)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let mediumDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    // MARK: Formatted String Properties
    var timeAgoString: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDateString: String {
        Self.shortDateFormatter.string(from: self)
    }

    var mediumDateTimeString: String {
        Self.mediumDateTimeFormatter.string(from: self)
    }

    var iso8601String: String {
        Self.iso8601Formatter.string(from: self)
    }
}

// MARK: - SIMD3 Extensions
extension SIMD3 where Scalar == Float {
    var length: Float {
        sqrt(x * x + y * y + z * z)
    }

    var normalized: SIMD3<Float> {
        let len = length
        guard len > 0 else { return self }
        return self / len
    }

    static func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + (b - a) * t
    }
}

// MARK: - simd_float4x4 Extensions
extension simd_float4x4 {
    var position: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }

    var forward: SIMD3<Float> {
        SIMD3<Float>(-columns.2.x, -columns.2.y, -columns.2.z).normalized
    }

    var up: SIMD3<Float> {
        SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z).normalized
    }

    var right: SIMD3<Float> {
        SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z).normalized
    }

    static func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
        return matrix
    }

    static func scale(_ s: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.0.x = s.x
        matrix.columns.1.y = s.y
        matrix.columns.2.z = s.z
        return matrix
    }
}

// MARK: - Float Extensions
extension Float {
    var degreesToRadians: Float {
        self * .pi / 180
    }

    var radiansToDegrees: Float {
        self * 180 / .pi
    }

    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Int Extensions
extension Int {
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var formattedWithSeparator: String {
        Self.decimalFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Int64 Extensions
extension Int64 {
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

// MARK: - Data Extensions
extension Data {
    var hexString: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - URL Extensions
extension URL {
    var fileSize: Int64? {
        guard let resources = try? resourceValues(forKeys: [.fileSizeKey]),
              let size = resources.fileSize else {
            return nil
        }
        return Int64(size)
    }

    var creationDate: Date? {
        try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    var modificationDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

// MARK: - View Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
}

// MARK: - RoundedCorner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - CGImage Extensions
extension CGImage {
    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - Array Extensions
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == SIMD3<Float> {
    var centroid: SIMD3<Float> {
        guard !isEmpty else { return .zero }
        let sum = reduce(SIMD3<Float>.zero, +)
        return sum / Float(count)
    }

    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let first = first else {
            return (.zero, .zero)
        }

        var minPoint = first
        var maxPoint = first

        for point in self {
            minPoint = simd.min(minPoint, point)
            maxPoint = simd.max(maxPoint, point)
        }

        return (minPoint, maxPoint)
    }
}
