import SwiftUI

@main
struct LoyaltyCardsApp: App {
    @StateObject private var cardStore = LoyaltyCardStore()
    @StateObject private var brandPresetStore = BrandPresetStore()
    @StateObject private var appSettings = AppSettings()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITEST_RESET_DATA") {
            UserDefaults.standard.removeObject(forKey: LoyaltyCardStore.storageKey)
            UserDefaults.standard.removeObject(forKey: "cardless.selectedBrandPresetRegion")
            BrandPresetStore.clearCacheForTesting()
        }

        if ProcessInfo.processInfo.arguments.contains("UITEST_PREVIEW_CARDS") {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(LoyaltyCard.previewCards) {
                UserDefaults.standard.set(data, forKey: LoyaltyCardStore.storageKey)
            }
        }

        if let presetJSON = ProcessInfo.processInfo.environment["UITEST_BRAND_PRESETS"] {
            BrandPresetStore.seedCacheForTesting(Data(presetJSON.utf8))
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                FeaturedCardsView()
            }
            .environmentObject(cardStore)
            .environmentObject(brandPresetStore)
            .environmentObject(appSettings)
        }
    }
}
