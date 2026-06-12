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
            guard decodedPresets != presets else {
                userDefaults.set(Date(), forKey: Self.lastFetchKey)
                return
            }

            setPresets(decodedPresets)
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

    private func loadCachedPresets() {
        setPresets(cachedPresets())
    }

    private func cachedPresets() -> [LoyaltyBrandPreset] {
        if let data = try? Data(contentsOf: cacheURL) {
            if let decodedPresets = try? decodedPresets(from: data) {
                return decodedPresets
            }

            try? FileManager.default.removeItem(at: cacheURL)
        }

        guard let data = userDefaults.data(forKey: Self.cacheKey),
              let decodedPresets = try? decodedPresets(from: data) else {
            return []
        }

        return decodedPresets
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
