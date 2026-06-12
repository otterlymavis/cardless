import XCTest
@testable import LoyaltyCardsApp

@MainActor
final class LoyaltyCardStoreTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "LoyaltyCardStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveNormalizesAndPersistsCard() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)

        store.save(
            LoyaltyCard(
                storeName: "  Market Club  ",
                barcodeValue: "  1234567890  ",
                note: "  Scan at checkout  "
            )
        )

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards.first?.storeName, "Market Club")
        XCTAssertEqual(store.cards.first?.barcodeValue, "1234567890")
        XCTAssertEqual(store.cards.first?.note, "Scan at checkout")

        let reloadedStore = LoyaltyCardStore(userDefaults: userDefaults)
        XCTAssertEqual(reloadedStore.cards, store.cards)
    }

    func testLegacyCardDecodingDefaultsFavoriteToFalse() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "storeName": "Market Club",
          "barcodeValue": "123",
          "barcodeFormat": "Code 128",
          "note": "",
          "createdAt": 100,
          "updatedAt": 100
        }
        """

        let card = try JSONDecoder().decode(LoyaltyCard.self, from: Data(json.utf8))

        XCTAssertFalse(card.isFavorite)
        XCTAssertNil(card.cardColor)
        XCTAssertNil(card.lastViewedAt)
    }

    func testStoreLoadsDuplicateLegacyIDsWithoutCrashingAndTargetsLastDuplicate() throws {
        let cardID = UUID()
        let legacyCards = [
            LoyaltyCard(id: cardID, storeName: "First", barcodeValue: "1"),
            LoyaltyCard(id: cardID, storeName: "Second", barcodeValue: "2")
        ]
        userDefaults.set(try JSONEncoder().encode(legacyCards), forKey: LoyaltyCardStore.storageKey)

        let store = LoyaltyCardStore(userDefaults: userDefaults)

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.cards.map(\.storeName), ["First", "Second"])

        store.toggleFavorite(legacyCards[0])

        XCTAssertTrue(store.cards[0].isFavorite)
        XCTAssertEqual(store.cards[0].storeName, "Second")
        XCTAssertFalse(store.cards[1].isFavorite)
        XCTAssertEqual(store.cards[1].storeName, "First")
    }

    func testSaveAndReloadPreservesFavoriteState() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)

        store.save(LoyaltyCard(storeName: "Market Club", barcodeValue: "123", isFavorite: true))

        XCTAssertTrue(store.cards.first?.isFavorite == true)
        XCTAssertTrue(LoyaltyCardStore(userDefaults: userDefaults).cards.first?.isFavorite == true)
    }

    func testSaveUpdatesExistingCard() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let replacementCreatedAt = Date(timeIntervalSince1970: 300)

        store.save(
            LoyaltyCard(
                id: cardID,
                storeName: "Market Club",
                barcodeValue: "123",
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        store.save(
            LoyaltyCard(
                id: cardID,
                storeName: "Market Club Plus",
                barcodeValue: "456",
                createdAt: replacementCreatedAt,
                updatedAt: createdAt
            )
        )

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards.first?.storeName, "Market Club Plus")
        XCTAssertEqual(store.cards.first?.barcodeValue, "456")
        XCTAssertEqual(store.cards.first?.createdAt, createdAt)
        XCTAssertNotEqual(store.cards.first?.updatedAt, createdAt)
    }

    func testSavePreservesExistingFavoriteState() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()

        store.save(LoyaltyCard(id: cardID, storeName: "Market Club", barcodeValue: "123", isFavorite: true))
        store.save(LoyaltyCard(id: cardID, storeName: "Market Club Plus", barcodeValue: "456", isFavorite: false))

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].storeName, "Market Club Plus")
        XCTAssertTrue(store.cards[0].isFavorite)
    }

    func testSavePreservesExistingRecentTimestamp() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let lastViewedAt = Date(timeIntervalSince1970: 400)

        store.save(LoyaltyCard(id: cardID, storeName: "Market Club", barcodeValue: "123", lastViewedAt: lastViewedAt))
        store.save(LoyaltyCard(id: cardID, storeName: "Market Club Plus", barcodeValue: "456"))

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].lastViewedAt, lastViewedAt)
    }

    func testSaveSkipsUnchangedExistingCard() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let updatedAt = Date(timeIntervalSince1970: 500)

        store.save(
            LoyaltyCard(
                id: cardID,
                storeName: "Market Club",
                barcodeValue: "123",
                updatedAt: updatedAt
            )
        )
        let savedCard = store.cards[0]

        store.save(savedCard)

        XCTAssertEqual(store.cards[0].updatedAt, savedCard.updatedAt)
    }

    func testDeleteRemovesPersistedCard() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let card = LoyaltyCard(storeName: "Market Club", barcodeValue: "123")

        store.save(card)
        store.delete(card)

        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertTrue(LoyaltyCardStore(userDefaults: userDefaults).cards.isEmpty)
    }

    func testToggleFavoritePersistsAndUpdatesTimestamp() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let createdAt = Date(timeIntervalSince1970: 100)
        let card = LoyaltyCard(
            storeName: "Market Club",
            barcodeValue: "123",
            createdAt: createdAt,
            updatedAt: createdAt
        )

        store.save(card)
        let savedCard = store.cards[0]
        store.toggleFavorite(savedCard)

        XCTAssertTrue(store.cards[0].isFavorite)
        XCTAssertNotEqual(store.cards[0].updatedAt, savedCard.updatedAt)
        XCTAssertTrue(LoyaltyCardStore(userDefaults: userDefaults).cards[0].isFavorite)
    }

    func testMarkRecentlyViewedPersistsTimestamp() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        store.save(LoyaltyCard(storeName: "Market Club", barcodeValue: "123"))
        let savedCard = store.cards[0]

        store.markRecentlyViewed(savedCard)

        XCTAssertNotNil(store.cards[0].lastViewedAt)
        XCTAssertNotNil(LoyaltyCardStore(userDefaults: userDefaults).cards[0].lastViewedAt)
    }

    func testMarkRecentlyViewedSkipsRecentMostRecentCard() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let recentDate = Date()
        store.save(LoyaltyCard(storeName: "Market Club", barcodeValue: "123", lastViewedAt: recentDate))

        store.markRecentlyViewed(store.cards[0])

        XCTAssertEqual(store.cards[0].lastViewedAt, recentDate)
    }

    func testMarkRecentlyViewedRefreshesRecentCardWhenItIsNotMostRecent() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        store.save(LoyaltyCard(storeName: "Older", barcodeValue: "1", lastViewedAt: Date()))
        store.save(LoyaltyCard(storeName: "Newer", barcodeValue: "2", lastViewedAt: Date(timeIntervalSinceNow: 60)))
        let olderCard = store.cards.first { $0.storeName == "Older" }!
        let olderDate = olderCard.lastViewedAt

        store.markRecentlyViewed(olderCard)

        XCTAssertNotEqual(store.cards.first { $0.id == olderCard.id }?.lastViewedAt, olderDate)
    }

    func testRecentCardsSortByLastViewedAndLimitToFour() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)

        store.save(LoyaltyCard(storeName: "Never Viewed", barcodeValue: "0"))
        store.save(LoyaltyCard(storeName: "Fifth", barcodeValue: "1", lastViewedAt: Date(timeIntervalSince1970: 100)))
        store.save(LoyaltyCard(storeName: "Second", barcodeValue: "2", lastViewedAt: Date(timeIntervalSince1970: 400)))
        store.save(LoyaltyCard(storeName: "First", barcodeValue: "3", lastViewedAt: Date(timeIntervalSince1970: 500)))
        store.save(LoyaltyCard(storeName: "Fourth", barcodeValue: "4", lastViewedAt: Date(timeIntervalSince1970: 200)))
        store.save(LoyaltyCard(storeName: "Third", barcodeValue: "5", lastViewedAt: Date(timeIntervalSince1970: 300)))

        XCTAssertEqual(store.recentCards.map(\.storeName), ["First", "Second", "Third", "Fourth"])
    }

    func testExportCardsDataEncodesCurrentCards() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        store.save(LoyaltyCard(storeName: "Market Club", barcodeValue: "123", isFavorite: true, cardColor: .coral))

        let exportedCards = try JSONDecoder().decode([LoyaltyCard].self, from: store.exportCardsData())

        XCTAssertEqual(exportedCards, store.cards)
        XCTAssertEqual(exportedCards.first?.cardColor, .coral)
    }

    func testImportCardsMergesAndPersistsCards() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let importedCards = [
            LoyaltyCard(storeName: "Market Club", barcodeValue: "123"),
            LoyaltyCard(storeName: "Book House", barcodeValue: "456", isFavorite: true)
        ]
        let data = try JSONEncoder().encode(importedCards)

        let importedCount = try store.importCards(from: data)

        XCTAssertEqual(importedCount, 2)
        XCTAssertEqual(store.cards.map(\.storeName), ["Book House", "Market Club"])
        XCTAssertEqual(LoyaltyCardStore(userDefaults: userDefaults).cards, store.cards)
    }

    func testImportCardsCollapsesDuplicateIDsToNewestCard() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let importedCards = [
            LoyaltyCard(
                id: cardID,
                storeName: "Older",
                barcodeValue: "1",
                updatedAt: Date(timeIntervalSince1970: 100)
            ),
            LoyaltyCard(
                id: cardID,
                storeName: "Newest",
                barcodeValue: "2",
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        ]

        let importedCount = try store.importCards(from: JSONEncoder().encode(importedCards))

        XCTAssertEqual(importedCount, 1)
        XCTAssertEqual(store.cards.map(\.storeName), ["Newest"])
    }

    func testImportPreviewCountValidatesWithoutMutating() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        store.save(LoyaltyCard(storeName: "Existing", barcodeValue: "1"))
        let importedCards = [
            LoyaltyCard(storeName: "Market Club", barcodeValue: "123"),
            LoyaltyCard(storeName: "   ", barcodeValue: "456"),
            LoyaltyCard(storeName: "Book House", barcodeValue: "   ")
        ]

        let previewCount = try store.importPreviewCount(from: JSONEncoder().encode(importedCards))

        XCTAssertEqual(previewCount, 1)
        XCTAssertEqual(store.cards.map(\.storeName), ["Existing"])
    }

    func testImportPreviewCountCollapsesDuplicateIDs() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let importedCards = [
            LoyaltyCard(id: cardID, storeName: "Older", barcodeValue: "1", updatedAt: Date(timeIntervalSince1970: 100)),
            LoyaltyCard(id: cardID, storeName: "Newest", barcodeValue: "2", updatedAt: Date(timeIntervalSince1970: 200))
        ]

        let previewCount = try store.importPreviewCount(from: JSONEncoder().encode(importedCards))

        XCTAssertEqual(previewCount, 1)
    }

    func testImportPreviewSummaryCountsNewUpdatesAndSkippedWithoutMutating() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        store.save(LoyaltyCard(storeName: "Update Me", barcodeValue: "1"))
        store.save(LoyaltyCard(storeName: "Keep Me", barcodeValue: "2"))
        let updateCard = store.cards.first { $0.storeName == "Update Me" }!
        let keepCard = store.cards.first { $0.storeName == "Keep Me" }!

        let importedCards = [
            LoyaltyCard(storeName: "New Card", barcodeValue: "3"),
            LoyaltyCard(
                id: updateCard.id,
                storeName: "Updated Name",
                barcodeValue: "4",
                createdAt: updateCard.createdAt,
                updatedAt: Date(timeIntervalSinceNow: 60)
            ),
            LoyaltyCard(
                id: keepCard.id,
                storeName: "Older Name",
                barcodeValue: "5",
                createdAt: keepCard.createdAt,
                updatedAt: Date(timeIntervalSince1970: 100)
            ),
            LoyaltyCard(storeName: "   ", barcodeValue: "6")
        ]

        let summary = try store.importPreviewSummary(from: JSONEncoder().encode(importedCards))

        XCTAssertEqual(summary, LoyaltyCardImportSummary(newCards: 1, updatedCards: 1, skippedCards: 1))
        XCTAssertEqual(summary.validCards, 3)
        XCTAssertEqual(summary.appliedCards, 2)
        XCTAssertEqual(store.cards.map(\.storeName), ["Keep Me", "Update Me"])
    }

    func testImportCardsKeepsNewerExistingCardForDuplicateID() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let newerDate = Date(timeIntervalSinceNow: 60)
        let olderDate = Date(timeIntervalSince1970: 200)
        store.save(
            LoyaltyCard(
                id: cardID,
                storeName: "New Name",
                barcodeValue: "999",
                createdAt: newerDate,
                updatedAt: newerDate
            )
        )

        let olderImportedCard = LoyaltyCard(
            id: cardID,
            storeName: "Old Name",
            barcodeValue: "111",
            createdAt: olderDate,
            updatedAt: olderDate
        )

        let appliedCount = try store.importCards(from: JSONEncoder().encode([olderImportedCard]))

        XCTAssertEqual(appliedCount, 0)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].storeName, "New Name")
        XCTAssertEqual(store.cards[0].barcodeValue, "999")
    }

    func testImportCardsReplacesOlderExistingCardForDuplicateID() throws {
        let store = LoyaltyCardStore(userDefaults: userDefaults)
        let cardID = UUID()
        let olderDate = Date(timeIntervalSince1970: 200)
        let newerDate = Date(timeIntervalSinceNow: 60)
        store.save(
            LoyaltyCard(
                id: cardID,
                storeName: "Old Name",
                barcodeValue: "111",
                createdAt: olderDate,
                updatedAt: olderDate
            )
        )

        let newerImportedCard = LoyaltyCard(
            id: cardID,
            storeName: "New Name",
            barcodeValue: "999",
            createdAt: newerDate,
            updatedAt: newerDate
        )

        let appliedCount = try store.importCards(from: JSONEncoder().encode([newerImportedCard]))

        XCTAssertEqual(appliedCount, 1)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].storeName, "New Name")
        XCTAssertEqual(store.cards[0].barcodeValue, "999")
    }

    func testCardsSortByFavoriteThenStoreName() {
        let store = LoyaltyCardStore(userDefaults: userDefaults)

        store.save(LoyaltyCard(storeName: "Zoo Market", barcodeValue: "1"))
        store.save(LoyaltyCard(storeName: "alpha Co-op", barcodeValue: "2", isFavorite: true))
        store.save(LoyaltyCard(storeName: "Book House", barcodeValue: "3"))
        store.save(LoyaltyCard(storeName: "Corner Shop", barcodeValue: "4", isFavorite: true))

        XCTAssertEqual(store.cards.map(\.storeName), ["alpha Co-op", "Corner Shop", "Book House", "Zoo Market"])
    }
}
