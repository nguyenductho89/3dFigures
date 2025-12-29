import XCTest
@testable import FigureScanner3D

final class FigureScanner3DTests: XCTestCase {

    override func setUpWithError() throws {
        // Setup code
    }

    override func tearDownWithError() throws {
        // Teardown code
    }

    func testScanTypeIcon() throws {
        XCTAssertEqual(ScanType.face.icon, "face.smiling")
        XCTAssertEqual(ScanType.body.icon, "figure.stand")
        XCTAssertEqual(ScanType.bust.icon, "person.bust")
    }

    func testScan3DDateFormatted() throws {
        let scan = Scan3D(
            name: "Test Scan",
            type: .face,
            createdAt: Date()
        )
        XCTAssertFalse(scan.dateFormatted.isEmpty)
    }

    func testScanQualitySettings() throws {
        XCTAssertEqual(ScanQualitySetting.allCases.count, 4)
        XCTAssertEqual(ScanQualitySetting.high.displayName, "High (Recommended)")
    }
}
