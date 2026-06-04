import SwiftUI

@main
struct LoyaltyCardsApp: App {
    @StateObject private var cardStore = LoyaltyCardStore()

    var body: some Scene {
        WindowGroup {
            CardListView()
                .environmentObject(cardStore)
        }
    }
}
