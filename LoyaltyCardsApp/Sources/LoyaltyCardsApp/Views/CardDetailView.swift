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
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        CardBadge(card: currentCard)

                        Spacer()

                        Text(currentCard.barcodeFormat.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.86), in: Capsule())
                    }

                    Text(currentCard.storeName)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                    Label("Ready for checkout", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.72))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(detailTint.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(detailTint.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: AppTheme.softShadow, radius: 16, x: 0, y: 8)

                Button {
                    isShowingLargeBarcode = true
                } label: {
                    BarcodeImageView(card: currentCard)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 210)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 30)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(detailTint.opacity(0.12), lineWidth: 1)
                        }
                        .shadow(color: AppTheme.softShadow, radius: 16, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Enlarge barcode")
                .accessibilityHint("Opens a full screen barcode for checkout")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Membership number")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                        .textCase(.uppercase)

                    HStack(alignment: .center, spacing: 12) {
                        Text(currentCard.barcodeValue)
                            .font(.title3.monospaced().weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .minimumScaleFactor(0.68)

                        Spacer(minLength: 8)

                        Button {
                            copyCardNumber()
                        } label: {
                            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.headline)
                                .frame(width: 42, height: 42)
                                .background(detailTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(didCopy ? "Copied" : "Copy membership number")
                    }
                }
                .padding(16)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: AppTheme.softShadow, radius: 14, x: 0, y: 7)

                Button {
                    toggleBrightnessBoost()
                } label: {
                    Label(
                        brightnessBeforeBoost == nil ? "Boost brightness" : "Restore brightness",
                        systemImage: brightnessBeforeBoost == nil ? "sun.max" : "sun.min"
                    )
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(AppTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Temporarily changes screen brightness for barcode scanning")

                if !currentCard.note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.muted)
                            .textCase(.uppercase)
                        Text(currentCard.note)
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: AppTheme.softShadow, radius: 14, x: 0, y: 7)
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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

                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit card")

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete card")
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                CardEditorView(card: currentCard)
            }
        }
        .fullScreenCover(isPresented: $isShowingLargeBarcode) {
            LargeBarcodeView(card: currentCard)
        }
        .confirmationDialog(
            "Delete Card?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
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
        guard let brightnessBeforeBoost else { return }

        UIScreen.main.brightness = brightnessBeforeBoost
        self.brightnessBeforeBoost = nil
    }

    private func keepScreenAwake() {
        guard idleTimerWasDisabled == nil else { return }

        idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func restoreIdleTimerIfNeeded() {
        guard let idleTimerWasDisabled else { return }

        UIApplication.shared.isIdleTimerDisabled = idleTimerWasDisabled
        self.idleTimerWasDisabled = nil
    }

    private var detailTint: Color {
        AppTheme.cardTint(for: currentCard)
    }
}

struct LargeBarcodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previousBrightness: CGFloat?
    @State private var idleTimerWasDisabled: Bool?
    @State private var didCopy = false

    let card: LoyaltyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.storeName)
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(card.barcodeFormat.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(AppTheme.ink)
                }
                .accessibilityLabel("Close")
            }

            Spacer(minLength: 0)

            BarcodeImageView(card: card)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 36)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.cardTint(for: card).opacity(0.14), lineWidth: 1)
                }

            HStack(alignment: .center, spacing: 12) {
                Text(card.barcodeValue)
                    .font(.title3.monospaced().weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.62)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Button {
                    copyCardNumber()
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.cardTint(for: card), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(didCopy ? "Copied" : "Copy membership number")
            }

            Spacer(minLength: 0)

            Label("Screen brightness is boosted until you close this view.", systemImage: "sun.max.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.surfaceTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
        .background(AppTheme.surface.ignoresSafeArea())
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            if let previousBrightness {
                UIScreen.main.brightness = previousBrightness
            }
            if let idleTimerWasDisabled {
                UIApplication.shared.isIdleTimerDisabled = idleTimerWasDisabled
            }
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

private struct CardBadge: View {
    let card: LoyaltyCard

    var body: some View {
        Text(card.displayInitials)
            .font(.headline.weight(.bold))
            .foregroundStyle(AppTheme.cardTint(for: card))
            .frame(width: 50, height: 38)
            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: LoyaltyCard.previewCards[0])
            .environmentObject(LoyaltyCardStore.preview())
    }
}
