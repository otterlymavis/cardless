import Foundation

enum BarcodeFormat: String, CaseIterable, Codable, Identifiable {
    case code128 = "Code 128"
    case pdf417 = "PDF417"
    case qr = "QR Code"
    case aztec = "Aztec"

    var id: String { rawValue }
}

enum CardColor: String, CaseIterable, Codable, Identifiable {
    case mint = "Mint"
    case coral = "Coral"
    case blue = "Blue"
    case plum = "Plum"
    case lemon = "Lemon"

    var id: String { rawValue }
}

struct LoyaltyCard: Identifiable, Codable, Hashable {
    var id: UUID
    var storeName: String
    var barcodeValue: String
    var barcodeFormat: BarcodeFormat
    var note: String
    var isFavorite: Bool
    var cardColor: CardColor?
    var lastViewedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        storeName: String,
        barcodeValue: String,
        barcodeFormat: BarcodeFormat = .code128,
        note: String = "",
        isFavorite: Bool = false,
        cardColor: CardColor? = nil,
        lastViewedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.storeName = storeName
        self.barcodeValue = barcodeValue
        self.barcodeFormat = barcodeFormat
        self.note = note
        self.isFavorite = isFavorite
        self.cardColor = cardColor
        self.lastViewedAt = lastViewedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        storeName = try container.decode(String.self, forKey: .storeName)
        barcodeValue = try container.decode(String.self, forKey: .barcodeValue)
        barcodeFormat = try container.decode(BarcodeFormat.self, forKey: .barcodeFormat)
        note = try container.decode(String.self, forKey: .note)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        cardColor = try container.decodeIfPresent(CardColor.self, forKey: .cardColor)
        lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

extension LoyaltyCard {
    var displayInitials: String {
        storeName.displayInitials
    }

    var formattedUpdatedDate: String {
        updatedAt.formatted(date: .abbreviated, time: .omitted)
    }
}

extension String {
    var displayInitials: String {
        let letters = split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        let value = String(letters).uppercased()
        return value.isEmpty ? "ID" : value
    }
}
