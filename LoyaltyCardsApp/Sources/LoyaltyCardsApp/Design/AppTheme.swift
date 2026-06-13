import SwiftUI

// AppTheme is now a pixel-style alias so every view using it
// automatically inherits the 8-bit design language.
enum AppTheme {
    static let background  = PixelTheme.bg
    static let surface     = PixelTheme.white
    static let surfaceTint = Color(red: 0.90, green: 0.90, blue: 0.86)
    static let ink         = PixelTheme.ink
    static let muted       = Color(red: 0.38, green: 0.38, blue: 0.35)

    // Named card colours (kept for CardColor enum compatibility)
    static let mint  = PixelTheme.palettes[1].bg   // green
    static let coral = PixelTheme.palettes[2].bg   // red
    static let blue  = PixelTheme.palettes[3].bg   // blue
    static let plum  = PixelTheme.palettes[4].bg   // purple
    static let lemon = PixelTheme.palettes[0].bg   // yellow

    // Shadows are now hard-offset pixel shadows (radius = 0 handled via extension)
    static let softShadow = PixelTheme.ink.opacity(0.55)

    static func cardTint(for value: String) -> Color {
        let colors = [mint, coral, blue, plum, lemon]
        let total = value.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[abs(total) % colors.count]
    }

    static func cardTint(for card: LoyaltyCard) -> Color {
        if let cardColor = card.cardColor { return color(for: cardColor) }
        return cardTint(for: card.storeName)
    }

    static func color(for cardColor: CardColor) -> Color {
        switch cardColor {
        case .mint:  return mint
        case .coral: return coral
        case .blue:  return blue
        case .plum:  return plum
        case .lemon: return lemon
        }
    }
}

// MARK: - Pixel-style shape helpers used across all views

extension View {
    /// Square card block: flat fill + 2px border + hard shadow.
    func pixelCard(fill: Color = AppTheme.surface,
                   borderColor: Color = AppTheme.ink,
                   shadowColor: Color = AppTheme.ink,
                   shadowX: CGFloat = 4, shadowY: CGFloat = 4) -> some View {
        self
            .background(fill)
            .overlay(Rectangle().stroke(borderColor, lineWidth: 2))
            .compositingGroup()
            .shadow(color: shadowColor, radius: 0, x: shadowX, y: shadowY)
    }

    /// Monospaced label style.
    func pixelLabel() -> some View {
        self.font(.system(.caption, design: .monospaced).weight(.black))
            .textCase(.uppercase)
    }
}
