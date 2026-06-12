import Combine
import Foundation

struct LoyaltyCardImportSummary: Equatable {
    let newCards: Int
    let updatedCards: Int
    let skippedCards: Int

    var validCards: Int {
        newCards + updatedCards + skippedCards
    }

    var appliedCards: Int {
        newCards + updatedCards
    }
}

@MainActor
final class LoyaltyCardStore: ObservableObject {
    static let storageKey = "minimalLoyaltyCards.cards.v1"

    @Published private(set) var cards: [LoyaltyCard] = []

    private var recentCardsCache: [LoyaltyCard] = []
    private var cardIndexesByID: [UUID: Int] = [:]
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadCards()
    }

    var recentCards: [LoyaltyCard] {
        recentCardsCache
    }

    static func preview(cards: [LoyaltyCard] = LoyaltyCard.previewCards) -> LoyaltyCardStore {
        let store = LoyaltyCardStore(userDefaults: UserDefaults(suiteName: "CardlessPreview.\(UUID().uuidString)") ?? .standard)
        store.setCards(store.sortedCards(cards))
        return store
    }

    func save(_ card: LoyaltyCard) {
        var nextCards = cards
        var nextCard = card.normalizedForStorage()

        if let index = cardIndexesByID[card.id] {
            let existingCard = nextCards[index]
            nextCard.createdAt = existingCard.createdAt
            nextCard.isFavorite = existingCard.isFavorite
            nextCard.lastViewedAt = existingCard.lastViewedAt

            guard !existingCard.hasSameEditableContent(as: nextCard) else { return }

            nextCard.updatedAt = Date()
            nextCards[index] = nextCard
        } else {
            nextCard.updatedAt = Date()
            nextCards.append(nextCard)
        }

        setCards(sortedCards(nextCards))
        persistCards()
    }

    func delete(_ card: LoyaltyCard) {
        var nextCards = cards
        guard let index = cardIndexesByID[card.id] else { return }

        nextCards.remove(at: index)
        setCards(nextCards)
        persistCards()
    }

    func toggleFavorite(_ card: LoyaltyCard) {
        var nextCards = cards
        guard let index = cardIndexesByID[card.id] else { return }

        nextCards[index].isFavorite.toggle()
        nextCards[index].updatedAt = Date()
        setCards(sortedCards(nextCards))
        persistCards()
    }

    func markRecentlyViewed(_ card: LoyaltyCard) {
        var nextCards = cards
        guard let index = cardIndexesByID[card.id] else { return }
        let now = Date()
        if let lastViewedAt = nextCards[index].lastViewedAt,
           now.timeIntervalSince(lastViewedAt) < 30,
           nextCards.allSatisfy({ ($0.lastViewedAt ?? .distantPast) <= lastViewedAt }) {
            return
        }

        nextCards[index].lastViewedAt = now
        setCards(nextCards)
        persistCards()
    }

    func exportCardsData() throws -> Data {
        try encoder.encode(cards)
    }

    @discardableResult
    func importCards(from data: Data) throws -> Int {
        let importedCards = try decodedImportCards(from: data)

        var nextCards = cards
        var cardIndexesByID = cardIndexes(for: nextCards)
        var appliedCards = 0
        for importedCard in importedCards {
            if let index = cardIndexesByID[importedCard.id] {
                if importedCard.updatedAt >= nextCards[index].updatedAt {
                    nextCards[index] = importedCard
                    appliedCards += 1
                }
            } else {
                nextCards.append(importedCard)
                cardIndexesByID[importedCard.id] = nextCards.endIndex - 1
                appliedCards += 1
            }
        }

        if appliedCards > 0 {
            setCards(sortedCards(nextCards))
            persistCards()
        }

        return appliedCards
    }

    func importPreviewCount(from data: Data) throws -> Int {
        try decodedImportCards(from: data).count
    }

    func importPreviewSummary(from data: Data) throws -> LoyaltyCardImportSummary {
        try importSummary(for: decodedImportCards(from: data), existingCards: cards)
    }

    private func loadCards() {
        guard let data = userDefaults.data(forKey: Self.storageKey) else {
            setCards([])
            return
        }

        do {
            setCards(sortedCards(try decoder.decode([LoyaltyCard].self, from: data)))
        } catch {
            setCards([])
        }
    }

    private func persistCards() {
        guard let data = try? encoder.encode(cards) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }

    private func decodedImportCards(from data: Data) throws -> [LoyaltyCard] {
        var cardIndexesByID: [UUID: Int] = [:]
        return try decoder.decode([LoyaltyCard].self, from: data).reduce(into: [LoyaltyCard]()) { cards, card in
            let normalizedCard = card.normalizedForStorage()
            guard !normalizedCard.storeName.isEmpty, !normalizedCard.barcodeValue.isEmpty else { return }

            if let index = cardIndexesByID[normalizedCard.id] {
                if normalizedCard.updatedAt >= cards[index].updatedAt {
                    cards[index] = normalizedCard
                }
            } else {
                cards.append(normalizedCard)
                cardIndexesByID[normalizedCard.id] = cards.endIndex - 1
            }
        }
    }

    private func importSummary(
        for importedCards: [LoyaltyCard],
        existingCards: [LoyaltyCard]
    ) -> LoyaltyCardImportSummary {
        var comparisonCards = existingCards
        var cardIndexesByID = cardIndexes(for: comparisonCards)
        var newCards = 0
        var updatedCards = 0
        var skippedCards = 0

        for importedCard in importedCards {
            if let index = cardIndexesByID[importedCard.id] {
                if importedCard.updatedAt >= comparisonCards[index].updatedAt {
                    comparisonCards[index] = importedCard
                    updatedCards += 1
                } else {
                    skippedCards += 1
                }
            } else {
                comparisonCards.append(importedCard)
                cardIndexesByID[importedCard.id] = comparisonCards.endIndex - 1
                newCards += 1
            }
        }

        return LoyaltyCardImportSummary(
            newCards: newCards,
            updatedCards: updatedCards,
            skippedCards: skippedCards
        )
    }

    private func sortedCards(_ cards: [LoyaltyCard]) -> [LoyaltyCard] {
        cards.sorted { left, right in
            if left.isFavorite != right.isFavorite {
                return left.isFavorite && !right.isFavorite
            }

            return left.storeName.localizedCaseInsensitiveCompare(right.storeName) == .orderedAscending
        }
    }

    private func setCards(_ cards: [LoyaltyCard]) {
        recentCardsCache = sortedRecentCards(from: cards)
        cardIndexesByID = cardIndexes(for: cards)
        self.cards = cards
    }

    private func cardIndexes(for cards: [LoyaltyCard]) -> [UUID: Int] {
        cards.enumerated().reduce(into: [UUID: Int]()) { indexesByID, element in
            indexesByID[element.element.id] = element.offset
        }
    }

    private func sortedRecentCards(from cards: [LoyaltyCard]) -> [LoyaltyCard] {
        cards.reduce(into: [LoyaltyCard]()) { recentCards, card in
            guard card.lastViewedAt != nil else { return }

            let insertionIndex = recentCards.firstIndex { recentCard in
                (card.lastViewedAt ?? .distantPast) > (recentCard.lastViewedAt ?? .distantPast)
            } ?? recentCards.endIndex

            if insertionIndex < 4 {
                recentCards.insert(card, at: insertionIndex)
                if recentCards.count > 4 {
                    recentCards.removeLast()
                }
            } else if recentCards.count < 4 {
                recentCards.append(card)
            }
        }
    }
}

private extension LoyaltyCard {
    func normalizedForStorage() -> LoyaltyCard {
        var card = self
        card.storeName = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        card.barcodeValue = barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines)
        card.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return card
    }

    func hasSameEditableContent(as card: LoyaltyCard) -> Bool {
        storeName == card.storeName
            && barcodeValue == card.barcodeValue
            && barcodeFormat == card.barcodeFormat
            && note == card.note
            && cardColor == card.cardColor
    }
}
