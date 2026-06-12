import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.965, green: 0.98, blue: 0.988)
    static let surface = Color.white
    static let surfaceTint = Color(red: 0.992, green: 0.948, blue: 0.958)
    static let ink = Color(red: 0.12, green: 0.125, blue: 0.15)
    static let muted = Color(red: 0.42, green: 0.455, blue: 0.5)
    static let mint = Color(red: 0.25, green: 0.68, blue: 0.58)
    static let coral = Color(red: 0.96, green: 0.45, blue: 0.39)
    static let blue = Color(red: 0.34, green: 0.55, blue: 0.88)
    static let plum = Color(red: 0.63, green: 0.47, blue: 0.82)
    static let lemon = Color(red: 0.96, green: 0.76, blue: 0.33)

    static let softShadow = Color(red: 0.42, green: 0.47, blue: 0.55).opacity(0.14)

    static func cardTint(for value: String) -> Color {
        let colors = [mint, coral, blue, plum, lemon]
        let total = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[abs(total) % colors.count]
    }

    static func cardTint(for card: LoyaltyCard) -> Color {
        if let cardColor = card.cardColor {
            return color(for: cardColor)
        }

        return cardTint(for: card.storeName)
    }

    static func color(for cardColor: CardColor) -> Color {
        switch cardColor {
        case .mint:
            return mint
        case .coral:
            return coral
        case .blue:
            return blue
        case .plum:
            return plum
        case .lemon:
            return lemon
        }
    }
}
