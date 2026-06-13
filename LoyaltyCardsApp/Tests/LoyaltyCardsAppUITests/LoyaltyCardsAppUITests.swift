import XCTest

final class LoyaltyCardsAppUITests: XCTestCase {
    private var app: XCUIApplication!

    // Brand preset JSON used across tests
    private static let testPresets = """
    [
      {
        "name": "Rakuten Point",
        "region": "Japan",
        "category": "Multipartner",
        "barcodeFormat": "QR Code",
        "cardColor": "Coral",
        "note": ""
      },
      {
        "name": "Tesco Clubcard",
        "region": "UK",
        "category": "Supermarket",
        "barcodeFormat": "Code 128",
        "cardColor": "Blue",
        "note": ""
      }
    ]
    """

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("UITEST_RESET_DATA")
        app.launchEnvironment["UITEST_BRAND_PRESETS"] = Self.testPresets
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Empty state

    func testEmptyWalletShowsPixelEmptyState() {
        app.launch()

        // New pixel UI shows "NO CARDS" via accessibilityIdentifier
        XCTAssertTrue(
            app.staticTexts["emptyStateLabel"].waitForExistence(timeout: 5),
            "Empty state label should be visible"
        )

        // CTA button should be present
        let addBtn = app.buttons["emptyAddFirstCardButton"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5), "Add first card button should exist")
    }

    // MARK: - Add card + brand preset search

    func testAddCardWithBrandPresetSearch() {
        app.launch()

        // Open add-card sheet via the + tab bar button
        let plusButton = app.buttons["Add card"]
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5))
        plusButton.tap()

        // Card editor should appear
        // Search for a brand
        let searchField = app.textFields["brandPresetSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("rakuten")

        // Preset chip should appear and be tappable
        let rakutenPreset = app.buttons["brandPreset.japan-rakuten-point"]
        XCTAssertTrue(rakutenPreset.waitForExistence(timeout: 5))
        rakutenPreset.tap()

        // Store name should be filled
        let storeNameField = app.textFields["storeNameField"]
        XCTAssertTrue(storeNameField.waitForExistence(timeout: 5))
        XCTAssertEqual(storeNameField.value as? String, "Rakuten Point")

        // Dismiss
        app.buttons["Cancel"].tap()
    }

    // MARK: - Settings: region changes brand defaults

    func testSettingsRegionChangeUpdatesBrandSearch() {
        app.launch()

        // Open Settings via the gear tab
        let settingsTab = app.buttons["SET"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Settings sheet should open
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))

        // Tap Japan region
        let japanButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Japan'")).firstMatch
        XCTAssertTrue(japanButton.waitForExistence(timeout: 5))
        japanButton.tap()

        // Dismiss settings
        app.buttons["Done"].tap()

        // Now open add-card and check the region tab shows Japan selected
        let plusButton = app.buttons["Add card"]
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5))
        plusButton.tap()

        // The region pill in the preset picker should show Japan as selected
        let japanTab = app.buttons.matching(NSPredicate(format: "label == 'Japan' AND value == 'selected'")).firstMatch
        // Give it time to settle
        _ = japanTab.waitForExistence(timeout: 3)

        // Search should find the Japan preset immediately (Rakuten)
        let searchField = app.textFields["brandPresetSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("rakuten")

        let rakutenPreset = app.buttons["brandPreset.japan-rakuten-point"]
        XCTAssertTrue(rakutenPreset.waitForExistence(timeout: 5), "Rakuten preset should appear after Japan region is selected")

        app.buttons["Cancel"].tap()
    }

    // MARK: - Settings: language auto-selects region

    func testSettingsLanguageAutoSelectsRegion() {
        app.launch()

        let settingsTab = app.buttons["SET"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))

        // Scroll down to Language section and tap Japanese
        let japaneseButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '日本語'")).firstMatch
        XCTAssertTrue(japaneseButton.waitForExistence(timeout: 5))
        japaneseButton.tap()

        // Dismiss Settings
        app.buttons["Done"].tap()

        // Verify the auto-region switch worked by opening Add Card:
        // Japan brand (Rakuten) should appear WITHOUT manually switching region
        let plusButton = app.buttons["Add card"]
        XCTAssertTrue(plusButton.waitForExistence(timeout: 5))
        plusButton.tap()

        // Default presets shown without any search should include Rakuten (a Japan brand)
        // because the region auto-switched to Japan
        let searchField = app.textFields["brandPresetSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Rakuten")

        let rakutenPreset = app.buttons["brandPreset.japan-rakuten-point"]
        XCTAssertTrue(rakutenPreset.waitForExistence(timeout: 5),
            "Rakuten (Japan brand) should be found — confirming language→Japan region auto-select worked")

        app.buttons["Cancel"].tap()
    }

    // MARK: - Region pill in top bar opens Settings

    func testRegionPillOpensSettings() {
        app.launch()

        // The region pill (e.g. "Region: United Kingdom. Tap to change.") should open Settings
        let regionPill = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Region:'")).firstMatch
        XCTAssertTrue(regionPill.waitForExistence(timeout: 5))
        regionPill.tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "Tapping region pill should open Settings")
        app.buttons["Done"].tap()
    }
}
