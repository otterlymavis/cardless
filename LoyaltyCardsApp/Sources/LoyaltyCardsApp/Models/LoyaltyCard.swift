import Foundation

enum BarcodeFormat: String, CaseIterable, Codable, Identifiable {
    case code128 = "Code 128"
    case pdf417 = "PDF417"
    case qr = "QR Code"
    case aztec = "Aztec"

    var id: String { rawValue }
}

struct LoyaltyCard: Identifiable, Codable, Hashable {
    var id: UUID
    var storeName: String
    var barcodeValue: String
    var barcodeFormat: BarcodeFormat
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        storeName: String,
        barcodeValue: String,
        barcodeFormat: BarcodeFormat = .code128,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.storeName = storeName
        self.barcodeValue = barcodeValue
        self.barcodeFormat = barcodeFormat
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
