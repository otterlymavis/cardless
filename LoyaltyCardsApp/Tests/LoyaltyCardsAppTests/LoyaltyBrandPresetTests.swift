import XCTest
@testable import LoyaltyCardsApp

final class LoyaltyBrandPresetTests: XCTestCase {
    func testPresetDecodingBuildsStableIDAndSearchTokens() throws {
        let json = """
        [
          {
            "name": "Rakuten Point",
            "region": "Japan",
            "category": "Multipartner",
            "barcodeFormat": "QR Code",
            "cardColor": "Coral",
            "note": ""
          }
        ]
        """

        let presets = try JSONDecoder().decode([LoyaltyBrandPreset].self, from: Data(json.utf8))

        XCTAssertEqual(presets.first?.id, "japan-rakuten-point")
        XCTAssertEqual(presets.first?.barcodeFormat, .qr)
        XCTAssertEqual(presets.first?.cardColor, .coral)
        XCTAssertTrue(LoyaltyBrandPreset.search("rakuten", in: presets).contains { $0.name == "Rakuten Point" })
    }

    func testPresetDecodingDefaultsBarcodeFormatAndNote() throws {
        let json = """
        [
          {
            "name": "Tesco Clubcard",
            "region": "UK",
            "category": "Grocery",
            "cardColor": "Blue"
          }
        ]
        """

        let presets = try JSONDecoder().decode([LoyaltyBrandPreset].self, from: Data(json.utf8))

        XCTAssertEqual(presets.first?.barcodeFormat, .code128)
        XCTAssertEqual(presets.first?.note, "")
        XCTAssertEqual(presets.first?.cardNote, "Check barcode type against your physical or app card.")
    }

    func testRegionLookupReturnsOnlyRequestedRegion() {
        let presets = samplePresets

        let italyPresets = LoyaltyBrandPreset.presets(for: .italy, in: presets)

        XCTAssertEqual(italyPresets.map(\.name), ["Carrefour"])
        XCTAssertTrue(italyPresets.allSatisfy { $0.region == .italy })
    }

    func testPresetSearchMatchesBrandCategoryAndRegion() {
        let presets = samplePresets

        XCTAssertTrue(LoyaltyBrandPreset.search("rakuten", in: presets).contains { $0.name == "Rakuten Point" })
        XCTAssertTrue(LoyaltyBrandPreset.search("pharmacy", in: presets).contains { $0.name == "Boots Advantage Card" })
        XCTAssertTrue(LoyaltyBrandPreset.search("italy", in: presets).allSatisfy { $0.region == .italy })
    }

    func testPresetSearchIgnoresPunctuation() {
        let presets = samplePresets

        XCTAssertTrue(LoyaltyBrandPreset.search("7 eleven", in: presets).contains { $0.name == "7-Eleven Japan" })
        XCTAssertTrue(LoyaltyBrandPreset.search("e leclerc", in: presets).contains { $0.name == "E.Leclerc" })
        XCTAssertTrue(LoyaltyBrandPreset.search("m s", in: presets).contains { $0.name == "M&S Sparks" })
    }

    func testPresetSearchTrimsBlankQueries() {
        XCTAssertTrue(LoyaltyBrandPreset.search("   \n", in: samplePresets).isEmpty)
    }

    private var samplePresets: [LoyaltyBrandPreset] {
        [
            LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral),
            LoyaltyBrandPreset(name: "Boots Advantage Card", region: .unitedKingdom, category: "Pharmacy", cardColor: .blue),
            LoyaltyBrandPreset(name: "Carrefour", region: .italy, category: "Grocery", cardColor: .blue),
            LoyaltyBrandPreset(name: "7-Eleven Japan", region: .japan, category: "Convenience", cardColor: .coral),
            LoyaltyBrandPreset(name: "E.Leclerc", region: .france, category: "Grocery", cardColor: .blue),
            LoyaltyBrandPreset(name: "M&S Sparks", region: .unitedKingdom, category: "Retail", cardColor: .plum)
        ]
    }
}
