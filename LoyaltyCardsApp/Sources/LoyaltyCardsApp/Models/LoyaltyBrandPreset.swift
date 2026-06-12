import Foundation

enum LoyaltyBrandRegion: String, CaseIterable, Codable, Identifiable {
    case unitedKingdom = "UK"
    case italy = "Italy"
    case france = "France"
    case japan = "Japan"
    case northAmerica = "North America"

    var id: String { rawValue }
}

struct LoyaltyBrandPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let region: LoyaltyBrandRegion
    let category: String
    let barcodeFormat: BarcodeFormat
    let cardColor: CardColor
    let note: String
    let searchTokens: String
    let compactSearchTokens: String

    init(
        name: String,
        region: LoyaltyBrandRegion,
        category: String,
        barcodeFormat: BarcodeFormat = .code128,
        cardColor: CardColor,
        note: String = ""
    ) {
        self.id = Self.id(for: name, region: region)
        self.name = name
        self.region = region
        self.category = category
        self.barcodeFormat = barcodeFormat
        self.cardColor = cardColor
        self.note = note

        let tokens = [name, category, region.rawValue]
            .map(\.searchNormalized)
            .joined(separator: " ")
        self.searchTokens = tokens
        self.compactSearchTokens = tokens.searchCompacted
    }

    var cardNote: String {
        note.isEmpty ? "Check barcode type against your physical or app card." : note
    }

    static func presets(for region: LoyaltyBrandRegion, in presets: [LoyaltyBrandPreset]) -> [LoyaltyBrandPreset] {
        presets.filter { $0.region == region }
    }

    static func search(_ query: String, in presets: [LoyaltyBrandPreset]) -> [LoyaltyBrandPreset] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        let foldedQuery = normalizedQuery.searchNormalized
        let compactQuery = foldedQuery.searchCompacted

        return presets.filter { preset in
            preset.searchTokens.contains(foldedQuery)
                || preset.compactSearchTokens.contains(compactQuery)
        }
    }

    private static func id(for name: String, region: LoyaltyBrandRegion) -> String {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: ".", with: "")

        return "\(region.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))-\(slug)"
    }
}

extension LoyaltyBrandPreset: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case region
        case category
        case barcodeFormat
        case cardColor
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            region: try container.decode(LoyaltyBrandRegion.self, forKey: .region),
            category: try container.decode(String.self, forKey: .category),
            barcodeFormat: try container.decodeIfPresent(BarcodeFormat.self, forKey: .barcodeFormat) ?? .code128,
            cardColor: try container.decode(CardColor.self, forKey: .cardColor),
            note: try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(region, forKey: .region)
        try container.encode(category, forKey: .category)
        try container.encode(barcodeFormat, forKey: .barcodeFormat)
        try container.encode(cardColor, forKey: .cardColor)
        try container.encode(note, forKey: .note)
    }
}

private extension String {
    var searchNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var searchCompacted: String {
        filter { !$0.isWhitespace }
    }
}
