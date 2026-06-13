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

        XCTAssertGreaterThanOrEqual(store.presets.count, 40)
        XCTAssertTrue(store.presets(for: .japan).contains { $0.name == "Rakuten Point" })
        XCTAssertTrue(store.presets(for: .unitedKingdom).contains { $0.name == "Boots Advantage Card" })
        XCTAssertTrue(store.searchAll("pharmacy").contains { $0.name == "Boots Advantage Card" })
        XCTAssertTrue(store.searchAll("tesco").contains { $0.name == "Tesco Clubcard" })
    }

    func testStoreLoadsLegacyDefaultsCache() throws {
        let cachedPresets = [
            LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral)
        ]
        userDefaults.set(try JSONEncoder().encode(cachedPresets), forKey: BrandPresetStore.cacheKey)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertGreaterThanOrEqual(store.presets.count, 40)
        XCTAssertTrue(store.presets(for: .japan).contains { $0.name == "Rakuten Point" })
        XCTAssertTrue(store.searchAll("tesco").contains { $0.name == "Tesco Clubcard" })
    }

    func testStoreRemovesCorruptFileCacheAndLoadsLegacyDefaultsCache() throws {
        try Data("not json".utf8).write(to: cacheURL)
        let cachedPresets = [
            LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral)
        ]
        userDefaults.set(try JSONEncoder().encode(cachedPresets), forKey: BrandPresetStore.cacheKey)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertGreaterThanOrEqual(store.presets.count, 40)
        XCTAssertTrue(store.presets(for: .japan).contains { $0.name == "Rakuten Point" })
        XCTAssertTrue(store.searchAll("tesco").contains { $0.name == "Tesco Clubcard" })
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testCachedPresetsOverrideBuiltInPresetsWithMatchingID() throws {
        let cachedPresets = [
            LoyaltyBrandPreset(name: "Tesco Clubcard", region: .unitedKingdom, category: "Grocery Remote", cardColor: .plum)
        ]
        try JSONEncoder().encode(cachedPresets).write(to: cacheURL)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)
        let tescoPreset = try XCTUnwrap(store.searchAll("tesco").first { $0.name == "Tesco Clubcard" })

        XCTAssertEqual(tescoPreset.category, "Grocery Remote")
        XCTAssertEqual(tescoPreset.cardColor, .plum)
        XCTAssertEqual(store.searchAll("tesco").filter { $0.name == "Tesco Clubcard" }.count, 1)
    }

    func testStoreFallsBackToBuiltInPresetsWhenFileCacheIsEmpty() throws {
        try JSONEncoder().encode([LoyaltyBrandPreset]()).write(to: cacheURL)

        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertGreaterThanOrEqual(store.presets.count, 40)
        XCTAssertTrue(store.searchAll("tesco").contains { $0.name == "Tesco Clubcard" })
    }

    func testStoreFallsBackToBuiltInPresetsWhenCacheIsEmpty() {
        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        XCTAssertGreaterThanOrEqual(store.presets.count, 40)
        XCTAssertTrue(store.searchAll("tesco").contains { $0.name == "Tesco Clubcard" })
        XCTAssertTrue(store.searchAll("rakuten").contains { $0.name == "Rakuten Point" })
        XCTAssertTrue(store.searchAll("sephora").count >= 2)
    }

    func testSearchWithPreferredRegionIncludesAllMatchesWithRegionalResultsFirst() {
        let store = BrandPresetStore(userDefaults: userDefaults, presetURL: nil, cacheURL: cacheURL)

        let results = store.search("sephora", preferredRegion: .italy)

        XCTAssertEqual(results.first?.name, "Sephora Beauty Pass Italy")
        XCTAssertTrue(results.contains { $0.name == "Sephora France" })
        XCTAssertTrue(results.contains { $0.name == "Sephora Beauty Insider" })
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
