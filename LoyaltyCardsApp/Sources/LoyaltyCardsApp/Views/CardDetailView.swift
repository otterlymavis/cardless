import SwiftUI

struct CardDetailView: View {
    @EnvironmentObject private var cardStore: LoyaltyCardStore
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    let card: LoyaltyCard

    private var currentCard: LoyaltyCard {
        cardStore.cards.first { $0.id == card.id } ?? card
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(currentCard.storeName)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(currentCard.barcodeFormat.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                BarcodeImageView(card: currentCard)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                VStack(spacing: 10) {
                    Text(currentCard.barcodeValue)
                        .font(.title3.monospaced())
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)
                    Text("Tip: turn brightness up if a scanner struggles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !currentCard.note.isEmpty {
                    Text(currentCard.note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                Button(role: .destructive) {
                    cardStore.delete(currentCard)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                CardEditorView(card: currentCard)
            }
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
