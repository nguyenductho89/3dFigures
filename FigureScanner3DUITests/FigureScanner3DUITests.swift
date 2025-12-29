import XCTest

final class FigureScanner3DUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testHomeViewLoads() throws {
        let app = XCUIApplication()
        app.launch()

        // Check that the main tab view loads
        XCTAssertTrue(app.tabBars.buttons["Scan"].exists)
        XCTAssertTrue(app.tabBars.buttons["Gallery"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    @MainActor
    func testNavigationToFaceScan() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap on Face Scan option
        if app.buttons["Face Scan"].exists {
            app.buttons["Face Scan"].tap()
            // Verify we navigated to face scan view
            XCTAssertTrue(app.buttons["xmark"].waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
