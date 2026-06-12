import XCTest
@testable import LoyaltyCardsApp

@MainActor
final class BrandPresetStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var cacheURL: URL!

    override func setUp() {
        super.setUp()
        suiteName = "BrandPresetStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        cacheURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("BrandPresetStoreTests-\(UUID().uuidString).json")
    }

    override func tearDown() {
        if let cacheURL {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        userDefaults.removePersistentDomain(forName: suiteName)
        cacheURL = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testStoreLoadsFileCachedRemotePresets() throws {
        let cachedPresets = [
            LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral),
            LoyaltyBrandPreset(name: "Boots Advantage Card", region: .unitedKingdom, category: "Pharmacy", cardColor: .blue)
        ]
        try JSONEncoder().encode(cachedPresets).write(to: cacheURL)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertEqual(store.presets.map(\.name), ["Rakuten Point", "Boots Advantage Card"])
        XCTAssertEqual(store.presets(for: .japan).map(\.name), ["Rakuten Point"])
        XCTAssertEqual(store.presets(for: .unitedKingdom).map(\.name), ["Boots Advantage Card"])
        XCTAssertEqual(store.searchAll("pharmacy").map(\.name), ["Boots Advantage Card"])
    }

    func testStoreLoadsLegacyDefaultsCache() throws {
        let cachedPresets = [
            LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral)
        ]
        userDefaults.set(try JSONEncoder().encode(cachedPresets), forKey: BrandPresetStore.cacheKey)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertEqual(store.presets.map(\.name), ["Rakuten Point"])
        XCTAssertEqual(store.presets(for: .japan).map(\.name), ["Rakuten Point"])
    }

    func testStoreRemovesCorruptFileCacheAndLoadsLegacyDefaultsCache() throws {
        try Data("not json".utf8).write(to: cacheURL)
        let cachedPresets = [
            LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral)
        ]
        userDefaults.set(try JSONEncoder().encode(cachedPresets), forKey: BrandPresetStore.cacheKey)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertEqual(store.presets.map(\.name), ["Rakuten Point"])
        XCTAssertEqual(store.presets(for: .japan).map(\.name), ["Rakuten Point"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testPreviewPresetsPopulateRegionIndex() {
        let store = BrandPresetStore.preview(
            presets: [
                LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral),
                LoyaltyBrandPreset(name: "Boots Advantage Card", region: .unitedKingdom, category: "Pharmacy", cardColor: .blue)
            ]
        )

        XCTAssertEqual(store.presets(for: .japan).map(\.name), ["Rakuten Point"])
        XCTAssertEqual(store.presets(for: .unitedKingdom).map(\.name), ["Boots Advantage Card"])
    }
}
