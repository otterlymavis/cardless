import SwiftUI

// MARK: - AppSettings (single source of truth)

/// Persisted app-wide preferences. Read with @StateObject in the root
/// and propagated via .environmentObject().
@MainActor
final class AppSettings: ObservableObject {
    // MARK: Stored keys
    private static let regionKey   = "cardless.selectedBrandPresetRegion"
    private static let languageKey = "cardless.preferredLanguage"

    // MARK: Published values

    @Published var selectedRegion: LoyaltyBrandRegion {
        didSet { UserDefaults.standard.set(selectedRegion.rawValue, forKey: Self.regionKey) }
    }

    @Published var preferredLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(preferredLanguage.rawValue, forKey: Self.languageKey) }
    }

    // MARK: Init

    init() {
        let savedRegion = UserDefaults.standard.string(forKey: Self.regionKey)
        selectedRegion = LoyaltyBrandRegion(rawValue: savedRegion ?? "") ?? .unitedKingdom

        let savedLang = UserDefaults.standard.string(forKey: Self.languageKey)
        preferredLanguage = AppLanguage(rawValue: savedLang ?? "") ?? .system
    }
}

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable, Identifiable {
    case system      = "System Default"
    case english     = "English"
    case french      = "Français"
    case italian     = "Italiano"
    case japanese    = "日本語"
    case spanish     = "Español"
    case german      = "Deutsch"

    var id: String { rawValue }

    /// BCP-47 locale identifier used to filter brand suggestions
    var localeIdentifier: String? {
        switch self {
        case .system:   return nil
        case .english:  return "en"
        case .french:   return "fr"
        case .italian:  return "it"
        case .japanese: return "ja"
        case .spanish:  return "es"
        case .german:   return "de"
        }
    }

    /// The natural region this language maps to when auto-selecting
    var suggestedRegion: LoyaltyBrandRegion? {
        switch self {
        case .french:   return .france
        case .italian:  return .italy
        case .japanese: return .japan
        default:        return nil
        }
    }

    var flag: String {
        switch self {
        case .system:   return "🌐"
        case .english:  return "🇬🇧"
        case .french:   return "🇫🇷"
        case .italian:  return "🇮🇹"
        case .japanese: return "🇯🇵"
        case .spanish:  return "🇪🇸"
        case .german:   return "🇩🇪"
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: Region
                Section {
                    ForEach(LoyaltyBrandRegion.allCases) { region in
                        Button {
                            withAnimation { settings.selectedRegion = region }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(region.displayName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(region.brandCountDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.selectedRegion == region {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .accessibilityAddTraits(settings.selectedRegion == region ? .isSelected : [])
                        .id(region.id)
                    }
                } header: {
                    Label("Region", systemImage: "mappin.and.ellipse")
                        .textCase(nil)
                        .font(.subheadline.weight(.bold))
                } footer: {
                    Text("Brand recommendations in the card editor will prioritise this region by default.")
                }

                // MARK: Language
                Section {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            withAnimation {
                                settings.preferredLanguage = lang
                                // Auto-suggest matching region if user hasn't overridden
                                if let suggested = lang.suggestedRegion {
                                    settings.selectedRegion = suggested
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(lang.flag)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.rawValue)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if lang == .system {
                                        Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "Device language")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if settings.preferredLanguage == lang {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .accessibilityAddTraits(settings.preferredLanguage == lang ? .isSelected : [])
                        .id(lang.id)
                    }
                } header: {
                    Label("Language", systemImage: "globe")
                        .textCase(nil)
                        .font(.subheadline.weight(.bold))
                } footer: {
                    Text("Changing language will also update the suggested region for brand search.")
                }

                // MARK: About
                Section {
                    LabeledContent("Version") {
                        Text(Bundle.main.appVersionString)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Storage") {
                        Text("On-device only")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                        .textCase(nil)
                        .font(.subheadline.weight(.bold))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - LoyaltyBrandRegion display helpers

extension LoyaltyBrandRegion {
    var displayName: String {
        switch self {
        case .unitedKingdom: return "🇬🇧  United Kingdom"
        case .italy:         return "🇮🇹  Italy"
        case .france:        return "🇫🇷  France"
        case .japan:         return "🇯🇵  Japan"
        case .northAmerica:  return "🇺🇸  North America"
        }
    }

    var brandCountDescription: String {
        switch self {
        case .unitedKingdom: return "Tesco, Boots, Nectar and more"
        case .italy:         return "Esselunga, Conad, Carrefour and more"
        case .france:        return "Carrefour, Leclerc, Fnac and more"
        case .japan:         return "T-Point, Rakuten, Ponta and more"
        case .northAmerica:  return "Target, CVS, Kroger and more"
        }
    }
}

// MARK: - Bundle version helper

private extension Bundle {
    var appVersionString: String {
        let ver = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(ver) (\(build))"
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
}
