import XCTest

final class WorkspaceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFieldSwatchUpdatesActiveColorAndOpensPicker() {
        let app = launch()
        let swatch = app.buttons["field-clay"]
        XCTAssertTrue(swatch.waitForExistence(timeout: 12))
        capture(app, named: "CoStudio-Overview-Light")
        press(swatch)
        let active = app.buttons["active-color"]
        let updated = NSPredicate(format: "label CONTAINS %@", "#D99878")
        expectation(for: updated, evaluatedWith: active)
        waitForExpectations(timeout: 5)

        let picker = app.buttons["open-picker"]
        XCTAssertTrue(picker.exists)
        press(picker)
        XCTAssertTrue(app.staticTexts["Color Picker"].firstMatch.waitForExistence(timeout: 8))
        capture(app, named: "CoStudio-Picker-Light")
    }

    @MainActor
    func testPaletteOpensInDarkAppearance() {
        let app = launch(appearance: "Dark")
        let button = app.buttons["new-palette"]
        XCTAssertTrue(button.waitForExistence(timeout: 12))
        capture(app, named: "CoStudio-Overview-Dark")
        press(button)
        XCTAssertTrue(app.staticTexts["Palette Generator"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Generate"].waitForExistence(timeout: 8))
        capture(app, named: "CoStudio-Palette-Dark")
    }

    @MainActor
    func testSampleImageRotationAndUndo() {
        let app = launch()
        let imageTool = app.buttons["overview-image"]
        XCTAssertTrue(imageTool.waitForExistence(timeout: 12))
        #if os(iOS)
        if !imageTool.isHittable { app.swipeUp() }
        #endif
        press(imageTool)

        let sample = app.buttons["image-sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        press(sample)

        let landscape = app.staticTexts["1152 × 768 PX"]
        XCTAssertTrue(landscape.waitForExistence(timeout: 15))
        capture(app, named: "CoStudio-Image-Light")
        let rotate = app.buttons["Rotate clockwise"]
        XCTAssertTrue(rotate.exists)
        press(rotate)

        let portrait = app.staticTexts["768 × 1152 PX"]
        XCTAssertTrue(portrait.waitForExistence(timeout: 12))
        press(app.buttons["Undo image edit"])
        XCTAssertTrue(landscape.waitForExistence(timeout: 12))
    }

    #if os(iOS)
    @MainActor
    func testOverviewOpensPickerInPortrait() {
        let app = launch(landscape: false)
        let picker = app.buttons["open-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 12))
        press(picker)
        XCTAssertTrue(app.staticTexts["Color Picker"].firstMatch.waitForExistence(timeout: 8))
    }
    #endif

    @MainActor
    private func launch(appearance: String = "Light", landscape: Bool = true) -> XCUIApplication {
        #if os(iOS)
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-appearance", appearance]
        app.launch()
        #if os(macOS)
        app.activate()
        #endif
        return app
    }

    @MainActor
    private func press(_ element: XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        #if os(macOS)
        let screenshot = app.windows.firstMatch.screenshot()
        #else
        let screenshot = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
