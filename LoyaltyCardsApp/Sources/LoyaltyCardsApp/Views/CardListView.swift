import SwiftUI

struct CardListView: View {
    @EnvironmentObject private var cardStore: LoyaltyCardStore
    @State private var searchText = ""
    @State private var isAddingCard = false

    private var filteredCards: [LoyaltyCard] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return cardStore.cards
        }

        return cardStore.cards.filter { card in
            card.storeName.localizedCaseInsensitiveContains(searchText)
                || card.barcodeValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredCards.isEmpty {
                    ContentUnavailableView(
                        "No cards yet",
                        systemImage: "barcode.viewfinder",
                        description: Text("Add your first loyalty card to keep checkout fast and uncluttered.")
                    )
                } else {
                    List {
                        ForEach(filteredCards) { card in
                            NavigationLink(value: card) {
                                CardRow(card: card)
                            }
                        }
                        .onDelete(perform: deleteCards)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cards")
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingCard = true
                    } label: {
                        Label("Add card", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: LoyaltyCard.self) { card in
                CardDetailView(card: card)
            }
            .sheet(isPresented: $isAddingCard) {
                NavigationStack {
                    CardEditorView(card: LoyaltyCard(storeName: "", barcodeValue: ""))
                }
            }
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        offsets.map { filteredCards[$0] }.forEach(cardStore.delete)
    }
}

private struct CardRow: View {
    let card: LoyaltyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.storeName)
                .font(.headline)
            Text(card.barcodeFormat.rawValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
