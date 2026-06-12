import Foundation

extension LoyaltyCard {
    static let previewCards: [LoyaltyCard] = [
        LoyaltyCard(
            storeName: "Market Club",
            barcodeValue: "123456789012",
            barcodeFormat: .code128,
            note: "Use at self-checkout if prompted.",
            isFavorite: true,
            cardColor: .mint,
            lastViewedAt: Date(timeIntervalSince1970: 1_800_030_000),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        LoyaltyCard(
            storeName: "Book House",
            barcodeValue: "BOOK-998877",
            barcodeFormat: .qr,
            cardColor: .plum,
            lastViewedAt: Date(timeIntervalSince1970: 1_800_020_000),
            createdAt: Date(timeIntervalSince1970: 1_799_900_000),
            updatedAt: Date(timeIntervalSince1970: 1_799_900_000)
        ),
        LoyaltyCard(
            storeName: "Corner Pharmacy",
            barcodeValue: "PHARMACY-445566",
            barcodeFormat: .pdf417,
            isFavorite: true,
            cardColor: .blue,
            createdAt: Date(timeIntervalSince1970: 1_799_800_000),
            updatedAt: Date(timeIntervalSince1970: 1_799_800_000)
        )
    ]
}
