import SwiftUI
import UIKit

struct CardDetailView: View {
    @EnvironmentObject private var cardStore: LoyaltyCardStore
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var didCopy = false
    @State private var isConfirmingDelete = false
    @State private var brightnessBeforeBoost: CGFloat?
    @State private var isShowingLargeBarcode = false
    @State private var idleTimerWasDisabled: Bool?

    let card: LoyaltyCard

    private var currentCard: LoyaltyCard {
        cardStore.cards.first { $0.id == card.id } ?? card
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // MARK: Card hero
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        // Initials badge
                        ZStack {
                            Rectangle().fill(detailTint).offset(x: 3, y: 3)
                            Rectangle()
                                .fill(AppTheme.surface)
                                .pixelBorder()
                                .overlay {
                                    Text(currentCard.displayInitials)
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundStyle(detailTint)
                                }
                        }
                        .frame(width: 50, height: 40)
                        .accessibilityHidden(true)

                        Spacer()

                        Text(currentCard.barcodeFormat.rawValue.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.surface)
                            .pixelBorder(width: 1.5)
                    }

                    Text(currentCard.storeName.uppercased())
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color(red: 0.20, green: 0.76, blue: 0.40))
                            .frame(width: 8, height: 8)
                        Text("READY")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .pixelCard(fill: detailTint.opacity(0.15), shadowX: 5, shadowY: 5)

                // MARK: Barcode
                Button {
                    isShowingLargeBarcode = true
                } label: {
                    BarcodeImageView(card: currentCard)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                        .pixelCard(shadowX: 4, shadowY: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Enlarge barcode")
                .accessibilityHint("Opens a full screen barcode for checkout")

                // MARK: Membership number
                VStack(alignment: .leading, spacing: 10) {
                    Text("MEMBERSHIP NO.")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.muted)

                    HStack(alignment: .center, spacing: 12) {
                        Text(currentCard.barcodeValue)
                            .font(.system(.title3, design: .monospaced).weight(.black))
                            .foregroundStyle(AppTheme.ink)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .minimumScaleFactor(0.68)

                        Spacer(minLength: 8)

                        Button { copyCardNumber() } label: {
                            ZStack {
                                Rectangle().fill(detailTint).offset(x: 3, y: 3)
                                Rectangle()
                                    .fill(AppTheme.ink)
                                    .pixelBorder()
                                    .overlay {
                                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(didCopy ? "Copied" : "Copy membership number")
                    }
                }
                .padding(16)
                .pixelCard(shadowX: 4, shadowY: 4)

                // MARK: Brightness boost
                Button { toggleBrightnessBoost() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: brightnessBeforeBoost == nil ? "sun.max" : "sun.min")
                            .font(.system(size: 13, weight: .black))
                        Text((brightnessBeforeBoost == nil ? "BOOST BRIGHTNESS" : "RESTORE BRIGHTNESS").uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.surfaceTint)
                    .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Temporarily changes screen brightness for barcode scanning")

                // MARK: Note
                if !currentCard.note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.muted)
                        Text(currentCard.note)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .pixelCard(shadowX: 4, shadowY: 4)
                }
            }
            .padding(16)
        }
        .background {
            Color(red: 0.94, green: 0.94, blue: 0.90).ignoresSafeArea()
            PixelGridBackground().ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.94, green: 0.94, blue: 0.90), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            cardStore.markRecentlyViewed(currentCard)
            keepScreenAwake()
        }
        .onDisappear {
            restoreBrightnessIfNeeded()
            restoreIdleTimerIfNeeded()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    cardStore.toggleFavorite(currentCard)
                } label: {
                    Image(systemName: currentCard.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(currentCard.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                Button { isEditing = true } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit card")

                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete card")
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack { CardEditorView(card: currentCard) }
        }
        .fullScreenCover(isPresented: $isShowingLargeBarcode) {
            LargeBarcodeView(card: currentCard)
        }
        .confirmationDialog("Delete Card?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete \(currentCard.storeName)", role: .destructive) {
                cardStore.delete(currentCard)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(currentCard.storeName) from Cardless. You can restore it later only if you have a backup.")
        }
    }

    private func copyCardNumber() {
        UIPasteboard.general.string = currentCard.barcodeValue
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            didCopy = false
        }
    }

    private func toggleBrightnessBoost() {
        if brightnessBeforeBoost == nil {
            brightnessBeforeBoost = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        } else {
            restoreBrightnessIfNeeded()
        }
    }

    private func restoreBrightnessIfNeeded() {
        guard let b = brightnessBeforeBoost else { return }
        UIScreen.main.brightness = b
        brightnessBeforeBoost = nil
    }

    private func keepScreenAwake() {
        guard idleTimerWasDisabled == nil else { return }
        idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func restoreIdleTimerIfNeeded() {
        guard let v = idleTimerWasDisabled else { return }
        UIApplication.shared.isIdleTimerDisabled = v
        idleTimerWasDisabled = nil
    }

    private var detailTint: Color { AppTheme.cardTint(for: currentCard) }
}

// MARK: - Large Barcode View

struct LargeBarcodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previousBrightness: CGFloat?
    @State private var idleTimerWasDisabled: Bool?
    @State private var didCopy = false

    let card: LoyaltyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.storeName.uppercased())
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(card.barcodeFormat.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Button { dismiss() } label: {
                    ZStack {
                        Rectangle().fill(AppTheme.ink).offset(x: 3, y: 3)
                        Rectangle()
                            .fill(AppTheme.surface)
                            .pixelBorder()
                            .overlay {
                                Text("X")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundStyle(AppTheme.ink)
                            }
                    }
                    .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }

            Spacer(minLength: 0)

            // Barcode panel
            BarcodeImageView(card: card)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 36)
                .pixelCard(shadowX: 5, shadowY: 5)

            // Number + copy
            HStack(alignment: .center, spacing: 12) {
                Text(card.barcodeValue)
                    .font(.system(.title3, design: .monospaced).weight(.black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.62)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Button { copyCardNumber() } label: {
                    ZStack {
                        Rectangle().fill(AppTheme.cardTint(for: card)).offset(x: 3, y: 3)
                        Rectangle()
                            .fill(AppTheme.ink)
                            .pixelBorder()
                            .overlay {
                                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                    }
                    .frame(width: 44, height: 44)
                }
                .accessibilityLabel(didCopy ? "Copied" : "Copy membership number")
            }

            Spacer(minLength: 0)

            // Brightness note
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .black))
                Text("BRIGHTNESS BOOSTED")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceTint)
            .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.30))
        }
        .padding(18)
        .background {
            Color(red: 0.94, green: 0.94, blue: 0.90).ignoresSafeArea()
            PixelGridBackground().ignoresSafeArea()
        }
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            if let b = previousBrightness { UIScreen.main.brightness = b }
            if let v = idleTimerWasDisabled { UIApplication.shared.isIdleTimerDisabled = v }
        }
    }

    private func copyCardNumber() {
        UIPasteboard.general.string = card.barcodeValue
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            didCopy = false
        }
    }
}

// MARK: - Barcode image helper

private struct BarcodeImageView: View {
    let card: LoyaltyCard

    var body: some View {
        if let image = BarcodeImageFactory.image(for: card.barcodeValue, format: card.barcodeFormat) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Barcode for \(card.storeName)")
        } else {
            ContentUnavailableView(
                "Barcode unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Check the card number and barcode type.")
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CardDetailView(card: LoyaltyCard.previewCards[0])
            .environmentObject(LoyaltyCardStore.preview())
    }
}
