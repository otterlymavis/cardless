import SwiftUI

// MARK: - AppSettings (single source of truth)

/// Persisted app-wide preferences. Read with @StateObject in the root
/// and propagated via .environmentObject().
@MainActor
final class AppSettings: ObservableObject {
    private static let regionKey   = "cardless.selectedBrandPresetRegion"
    private static let languageKey = "cardless.preferredLanguage"

    @Published var selectedRegion: LoyaltyBrandRegion {
        didSet { UserDefaults.standard.set(selectedRegion.rawValue, forKey: Self.regionKey) }
    }

    @Published var preferredLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(preferredLanguage.rawValue, forKey: Self.languageKey) }
    }

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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // MARK: Region section
                    PixelSettingsSection(title: "// REGION") {
                        VStack(spacing: 0) {
                            ForEach(LoyaltyBrandRegion.allCases) { region in
                                Button {
                                    withAnimation { settings.selectedRegion = region }
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(region.displayName)
                                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                                .foregroundStyle(AppTheme.ink)
                                            Text(region.brandCountDescription.uppercased())
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        if settings.selectedRegion == region {
                                            Text("✓")
                                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                                .foregroundStyle(AppTheme.ink)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(settings.selectedRegion == region
                                                ? AppTheme.lemon.opacity(0.30)
                                                : AppTheme.surface)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(settings.selectedRegion == region ? .isSelected : [])
                                .id(region.id)

                                if region != LoyaltyBrandRegion.allCases.last {
                                    Rectangle()
                                        .fill(AppTheme.ink.opacity(0.12))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.50))
                        .shadow(color: AppTheme.ink, radius: 0, x: 4, y: 4)
                    }

                    // MARK: Language section
                    PixelSettingsSection(title: "// LANGUAGE") {
                        VStack(spacing: 0) {
                            ForEach(AppLanguage.allCases) { lang in
                                Button {
                                    withAnimation {
                                        settings.preferredLanguage = lang
                                        if let suggested = lang.suggestedRegion {
                                            settings.selectedRegion = suggested
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(lang.flag)
                                            .font(.system(size: 18))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(lang.rawValue)
                                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                                .foregroundStyle(AppTheme.ink)
                                            if lang == .system {
                                                Text((Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "Device language").uppercased())
                                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                        }
                                        Spacer()
                                        if settings.preferredLanguage == lang {
                                            Text("✓")
                                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                                .foregroundStyle(AppTheme.ink)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(settings.preferredLanguage == lang
                                                ? AppTheme.lemon.opacity(0.30)
                                                : AppTheme.surface)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(settings.preferredLanguage == lang ? .isSelected : [])
                                .id(lang.id)

                                if lang != AppLanguage.allCases.last {
                                    Rectangle()
                                        .fill(AppTheme.ink.opacity(0.12))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.50))
                        .shadow(color: AppTheme.ink, radius: 0, x: 4, y: 4)
                    }

                    // MARK: About section
                    PixelSettingsSection(title: "// ABOUT") {
                        VStack(spacing: 0) {
                            PixelInfoRow(label: "VERSION", value: Bundle.main.appVersionString)
                            Rectangle().fill(AppTheme.ink.opacity(0.12)).frame(height: 1)
                            PixelInfoRow(label: "STORAGE", value: "ON-DEVICE ONLY")
                            Rectangle().fill(AppTheme.ink.opacity(0.12)).frame(height: 1)
                            PixelInfoRow(label: "MADE WITH", value: "SwiftUI ♥")
                        }
                        .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.50))
                        .shadow(color: AppTheme.ink, radius: 0, x: 4, y: 4)
                    }
                }
                .padding(16)
            }
            .background {
                Color(red: 0.94, green: 0.94, blue: 0.90)
                    .ignoresSafeArea()
                PixelGridBackground().ignoresSafeArea()
            }
            .accessibilityIdentifier("settingsView")
            .navigationTitle("// SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.94, green: 0.94, blue: 0.90), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                }
            }
        }
    }
}

// MARK: - Pixel sub-views

private struct PixelSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
            content
        }
    }
}

private struct PixelInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
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
