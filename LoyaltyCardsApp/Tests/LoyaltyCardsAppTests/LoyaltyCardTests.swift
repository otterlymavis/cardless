import XCTest
@testable import LoyaltyCardsApp

final class LoyaltyCardTests: XCTestCase {
    func testDisplayInitialsUseFirstTwoWords() {
        XCTAssertEqual(LoyaltyCard(storeName: "Market Club", barcodeValue: "123").displayInitials, "MC")
        XCTAssertEqual(LoyaltyCard(storeName: "Rakuten", barcodeValue: "123").displayInitials, "R")
    }

    func testDisplayInitialsFallbackForBlankNames() {
        XCTAssertEqual(LoyaltyCard(storeName: "   ", barcodeValue: "123").displayInitials, "ID")
    }

    func testFormattedUpdatedDateIsNotEmpty() {
        let card = LoyaltyCard(
            storeName: "Market Club",
            barcodeValue: "123",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertFalse(card.formattedUpdatedDate.isEmpty)
    }
}
