import Foundation

@MainActor
final class BrandPresetStore: ObservableObject {
    static let cacheKey = "cardless.brandPresets.cache.v1"
    static let lastFetchKey = "cardless.brandPresets.lastFetch.v1"
    nonisolated private static let configurationURLKey = "CardlessBrandPresetURL"
    nonisolated private static let maxPresetBytes = 1_000_000
    nonisolated private static let refreshInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var presets: [LoyaltyBrandPreset] = []
    @Published private(set) var isLoading = false

    private var presetsByRegion: [LoyaltyBrandRegion: [LoyaltyBrandPreset]] = [:]
    private let userDefaults: UserDefaults
    private let presetURL: URL?
    private let cacheURL: URL
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        presetURL: URL? = nil,
        cacheURL: URL = BrandPresetStore.defaultCacheURL
    ) {
        self.userDefaults = userDefaults
        self.presetURL = presetURL ?? Self.configuredPresetURL
        self.cacheURL = cacheURL
        loadCachedPresets()
    }

    static func preview(presets: [LoyaltyBrandPreset] = []) -> BrandPresetStore {
        let store = BrandPresetStore(
            userDefaults: UserDefaults(suiteName: "CardlessBrandPresetPreview.\(UUID().uuidString)") ?? .standard,
            presetURL: nil,
            cacheURL: FileManager.default.temporaryDirectory.appendingPathComponent("brand-presets-preview-\(UUID().uuidString).json")
        )
        store.setPresets(presets)
        return store
    }

    func loadPresets() async {
        guard !isLoading, let presetURL else { return }
        guard shouldRefreshPresets else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let request = URLRequest(
                url: presetURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 8
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard ((response as? HTTPURLResponse)?.statusCode).map({ (200..<300).contains($0) }) ?? true,
                  data.count <= Self.maxPresetBytes else {
                return
            }

            let decodedPresets = try decodedPresets(from: data)
            guard !decodedPresets.isEmpty else { return }
            let mergedPresets = Self.mergedPresets(with: decodedPresets)
            guard mergedPresets != presets else {
                userDefaults.set(Date(), forKey: Self.lastFetchKey)
                return
            }

            setPresets(mergedPresets)
            persistCache(data)
            userDefaults.set(Date(), forKey: Self.lastFetchKey)
        } catch {
            loadCachedPresets()
        }
    }

    func presets(for region: LoyaltyBrandRegion) -> [LoyaltyBrandPreset] {
        presetsByRegion[region] ?? []
    }

    func search(_ query: String, in presets: [LoyaltyBrandPreset]) -> [LoyaltyBrandPreset] {
        LoyaltyBrandPreset.search(query, in: presets)
    }

    func searchAll(_ query: String) -> [LoyaltyBrandPreset] {
        LoyaltyBrandPreset.search(query, in: presets)
    }

    func search(_ query: String, preferredRegion: LoyaltyBrandRegion) -> [LoyaltyBrandPreset] {
        let allResults = searchAll(query)
        let regionalResults = allResults.filter { $0.region == preferredRegion }
        let otherResults = allResults.filter { $0.region != preferredRegion }

        return regionalResults + otherResults
    }

    private func loadCachedPresets() {
        setPresets(cachedPresets())
    }

    private func cachedPresets() -> [LoyaltyBrandPreset] {
        if let data = try? Data(contentsOf: cacheURL) {
            if let decodedPresets = try? decodedPresets(from: data) {
                return Self.mergedPresets(with: decodedPresets)
            }

            try? FileManager.default.removeItem(at: cacheURL)
        }

        guard let data = userDefaults.data(forKey: Self.cacheKey),
              let decodedPresets = try? decodedPresets(from: data) else {
            return Self.defaultPresets
        }

        return Self.mergedPresets(with: decodedPresets)
    }

    private func persistCache(_ data: Data) {
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: cacheURL, options: .atomic)
            userDefaults.removeObject(forKey: Self.cacheKey)
        } catch {
            userDefaults.set(data, forKey: Self.cacheKey)
        }
    }

    private func setPresets(_ presets: [LoyaltyBrandPreset]) {
        self.presets = presets
        presetsByRegion = Dictionary(grouping: presets, by: \.region)
    }

    private func decodedPresets(from data: Data) throws -> [LoyaltyBrandPreset] {
        try decoder.decode([LoyaltyBrandPreset].self, from: data).reduce(into: [LoyaltyBrandPreset]()) { presets, preset in
            guard !preset.name.isEmpty, !preset.category.isEmpty else { return }

            presets.append(preset)
        }
    }

    private static func mergedPresets(with remotePresets: [LoyaltyBrandPreset]) -> [LoyaltyBrandPreset] {
        guard !remotePresets.isEmpty else { return defaultPresets }

        var mergedPresets = defaultPresets
        var indexesByID = Dictionary(uniqueKeysWithValues: defaultPresets.enumerated().map { ($0.element.id, $0.offset) })

        for preset in remotePresets {
            if let index = indexesByID[preset.id] {
                mergedPresets[index] = preset
            } else {
                indexesByID[preset.id] = mergedPresets.count
                mergedPresets.append(preset)
            }
        }

        return mergedPresets
    }

    private var shouldRefreshPresets: Bool {
        guard !presets.isEmpty,
              let lastFetch = userDefaults.object(forKey: Self.lastFetchKey) as? Date else {
            return true
        }

        return Date().timeIntervalSince(lastFetch) >= Self.refreshInterval
    }

    nonisolated private static var configuredPresetURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: configurationURLKey) as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return URL(string: value)
    }

    nonisolated private static var defaultCacheURL: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("brand-presets.json")
    }

    static let defaultPresets: [LoyaltyBrandPreset] = [
        LoyaltyBrandPreset(name: "Boots Advantage Card", region: .unitedKingdom, category: "Pharmacy", cardColor: .blue),
        LoyaltyBrandPreset(name: "Co-op Membership", region: .unitedKingdom, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "IKEA Family UK", region: .unitedKingdom, category: "Home", barcodeFormat: .qr, cardColor: .lemon),
        LoyaltyBrandPreset(name: "M&S Sparks", region: .unitedKingdom, category: "Retail", cardColor: .plum),
        LoyaltyBrandPreset(name: "Morrisons More", region: .unitedKingdom, category: "Grocery", cardColor: .mint),
        LoyaltyBrandPreset(name: "My John Lewis", region: .unitedKingdom, category: "Department Store", barcodeFormat: .qr, cardColor: .blue),
        LoyaltyBrandPreset(name: "Nectar", region: .unitedKingdom, category: "Multipartner", barcodeFormat: .qr, cardColor: .plum),
        LoyaltyBrandPreset(name: "Superdrug Health & Beautycard", region: .unitedKingdom, category: "Pharmacy", cardColor: .coral),
        LoyaltyBrandPreset(name: "Tesco Clubcard", region: .unitedKingdom, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Waitrose MyWaitrose", region: .unitedKingdom, category: "Grocery", barcodeFormat: .qr, cardColor: .mint),

        LoyaltyBrandPreset(name: "Bennet Club", region: .italy, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Carrefour Payback", region: .italy, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Conad Carta Insieme", region: .italy, category: "Grocery", cardColor: .coral),
        LoyaltyBrandPreset(name: "Coop Carta Socio", region: .italy, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Esselunga Fidaty", region: .italy, category: "Grocery", cardColor: .lemon),
        LoyaltyBrandPreset(name: "Feltrinelli Carta Piu", region: .italy, category: "Books", barcodeFormat: .qr, cardColor: .plum),
        LoyaltyBrandPreset(name: "IKEA Family Italy", region: .italy, category: "Home", barcodeFormat: .qr, cardColor: .lemon),
        LoyaltyBrandPreset(name: "Pam Panorama Per Te", region: .italy, category: "Grocery", cardColor: .mint),
        LoyaltyBrandPreset(name: "Sephora Beauty Pass Italy", region: .italy, category: "Beauty", barcodeFormat: .qr, cardColor: .plum),
        LoyaltyBrandPreset(name: "Tigota Club", region: .italy, category: "Beauty", cardColor: .coral),

        LoyaltyBrandPreset(name: "Auchan Waaoh", region: .france, category: "Grocery", cardColor: .coral),
        LoyaltyBrandPreset(name: "Carrefour France", region: .france, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Casino Max", region: .france, category: "Grocery", barcodeFormat: .qr, cardColor: .mint),
        LoyaltyBrandPreset(name: "E.Leclerc", region: .france, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Fnac", region: .france, category: "Books & Tech", barcodeFormat: .qr, cardColor: .lemon),
        LoyaltyBrandPreset(name: "Intermarche", region: .france, category: "Grocery", cardColor: .coral),
        LoyaltyBrandPreset(name: "Monoprix", region: .france, category: "Grocery", barcodeFormat: .qr, cardColor: .plum),
        LoyaltyBrandPreset(name: "Sephora France", region: .france, category: "Beauty", barcodeFormat: .qr, cardColor: .plum),

        LoyaltyBrandPreset(name: "7-Eleven Japan", region: .japan, category: "Convenience", barcodeFormat: .qr, cardColor: .coral),
        LoyaltyBrandPreset(name: "AEON Point", region: .japan, category: "Grocery", barcodeFormat: .qr, cardColor: .mint),
        LoyaltyBrandPreset(name: "d Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .lemon),
        LoyaltyBrandPreset(name: "FamilyMart FamiPay", region: .japan, category: "Convenience", barcodeFormat: .qr, cardColor: .mint),
        LoyaltyBrandPreset(name: "Lawson Ponta", region: .japan, category: "Convenience", barcodeFormat: .qr, cardColor: .blue),
        LoyaltyBrandPreset(name: "Matsukiyo Cocokara", region: .japan, category: "Pharmacy", barcodeFormat: .qr, cardColor: .lemon),
        LoyaltyBrandPreset(name: "Rakuten Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .coral),
        LoyaltyBrandPreset(name: "T Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .blue),
        LoyaltyBrandPreset(name: "WAON Point", region: .japan, category: "Multipartner", barcodeFormat: .qr, cardColor: .mint),

        LoyaltyBrandPreset(name: "Best Buy Rewards", region: .northAmerica, category: "Electronics", barcodeFormat: .qr, cardColor: .blue),
        LoyaltyBrandPreset(name: "CVS ExtraCare", region: .northAmerica, category: "Pharmacy", cardColor: .coral),
        LoyaltyBrandPreset(name: "Kroger Plus", region: .northAmerica, category: "Grocery", cardColor: .blue),
        LoyaltyBrandPreset(name: "Petco Vital Care", region: .northAmerica, category: "Pet Supplies", barcodeFormat: .qr, cardColor: .mint),
        LoyaltyBrandPreset(name: "REI Co-op", region: .northAmerica, category: "Outdoor", barcodeFormat: .qr, cardColor: .mint),
        LoyaltyBrandPreset(name: "Sephora Beauty Insider", region: .northAmerica, category: "Beauty", barcodeFormat: .qr, cardColor: .plum),
        LoyaltyBrandPreset(name: "Starbucks Rewards", region: .northAmerica, category: "Coffee", barcodeFormat: .qr, cardColor: .mint),
        LoyaltyBrandPreset(name: "Target Circle", region: .northAmerica, category: "Retail", barcodeFormat: .qr, cardColor: .coral),
        LoyaltyBrandPreset(name: "Walgreens myWalgreens", region: .northAmerica, category: "Pharmacy", cardColor: .blue)
    ]

    #if DEBUG
    static func seedCacheForTesting(_ data: Data) {
        let cacheURL = defaultCacheURL
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: cacheURL, options: .atomic)
            UserDefaults.standard.removeObject(forKey: cacheKey)
        } catch {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    static func clearCacheForTesting() {
        try? FileManager.default.removeItem(at: defaultCacheURL)
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: lastFetchKey)
    }
    #endif
}
