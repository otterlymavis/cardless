import Combine
import Foundation

@MainActor
final class LoyaltyCardStore: ObservableObject {
    @Published private(set) var cards: [LoyaltyCard] = []

    private let storageKey = "minimalLoyaltyCards.cards.v1"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCards()
    }

    func save(_ card: LoyaltyCard) {
        var nextCard = card
        nextCard.updatedAt = Date()

        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = nextCard
        } else {
            cards.append(nextCard)
        }

        sortCards()
        persistCards()
    }

    func delete(_ card: LoyaltyCard) {
        cards.removeAll { $0.id == card.id }
        persistCards()
    }

    private func loadCards() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            cards = []
            return
        }

        do {
            cards = try JSONDecoder().decode([LoyaltyCard].self, from: data)
            sortCards()
        } catch {
            cards = []
        }
    }

    private func persistCards() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func sortCards() {
        cards.sort { left, right in
            left.storeName.localizedCaseInsensitiveCompare(right.storeName) == .orderedAscending
        }
    }
}
