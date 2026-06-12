import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CardListView: View {
    private static let maxImportFileBytes = 1_000_000

    @EnvironmentObject private var cardStore: LoyaltyCardStore
    @State private var searchText = ""
    @State private var isAddingCard = false
    @State private var isImportingCards = false
    @State private var isExportingCards = false
    @State private var exportDocument = CardBackupDocument()
    @State private var backupMessage: BackupMessage?
    @State private var importPreview: ImportPreview?
    @State private var pendingDeleteCard: LoyaltyCard?
    @State private var barcodeCard: LoyaltyCard?

    private var filteredCardSections: FilteredCardSections {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cardStore.cards.reduce(into: FilteredCardSections()) { sections, card in
            guard query.isEmpty
                || card.storeName.localizedCaseInsensitiveContains(query)
                || card.barcodeValue.localizedCaseInsensitiveContains(query)
            else { return }

            if card.isFavorite {
                sections.favoriteCards.append(card)
            } else {
                sections.regularCards.append(card)
            }
        }
    }

    var body: some View {
        let cardSections = filteredCardSections
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let recentCards = isSearching ? [] : cardStore.recentCards

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HeaderView(cardCount: cardStore.cards.count)

                    if !recentCards.isEmpty {
                        RecentCardsSection(cards: recentCards) { card in
                            barcodeCard = card
                            cardStore.markRecentlyViewed(card)
                        } copyNumber: { card in
                            copyCardNumber(card)
                        }
                    }

                    if cardSections.isEmpty {
                        EmptyCardsView(isSearching: isSearching) {
                            isAddingCard = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            if !cardSections.favoriteCards.isEmpty {
                                CardSectionHeader(title: "Favorites", count: cardSections.favoriteCards.count)

                                LazyVStack(spacing: 14) {
                                    ForEach(cardSections.favoriteCards) { card in
                                        cardLink(for: card)
                                    }
                                }
                            }

                            if !cardSections.regularCards.isEmpty {
                                if !cardSections.favoriteCards.isEmpty {
                                    CardSectionHeader(title: "Cards", count: cardSections.regularCards.count)
                                }

                                LazyVStack(spacing: 14) {
                                    ForEach(cardSections.regularCards) { card in
                                        cardLink(for: card)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Cards")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isImportingCards = true
                        } label: {
                            Label("Import Backup", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            prepareExport()
                        } label: {
                            Label("Export Backup", systemImage: "square.and.arrow.up")
                        }
                        .disabled(cardStore.cards.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Backup options")
                }

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
            .fullScreenCover(item: $barcodeCard) { card in
                LargeBarcodeView(card: card)
            }
            .fileImporter(
                isPresented: $isImportingCards,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .fileExporter(
                isPresented: $isExportingCards,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "cardless-cards",
                onCompletion: handleExport
            )
            .alert(item: $backupMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.detail),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(item: $importPreview) { preview in
                Alert(
                    title: Text("Import Backup?"),
                    message: Text(preview.message),
                    primaryButton: .default(Text("Import")) {
                        confirmImport(preview)
                    },
                    secondaryButton: .cancel()
                )
            }
            .confirmationDialog(
                "Delete Card?",
                isPresented: pendingDeleteBinding,
                titleVisibility: .visible
            ) {
                if let card = pendingDeleteCard {
                    Button("Delete \(card.storeName)", role: .destructive) {
                        cardStore.delete(card)
                        pendingDeleteCard = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteCard = nil
                }
            } message: {
                if let card = pendingDeleteCard {
                    Text("This removes \(card.storeName) from Cardless. You can restore it later only if you have a backup.")
                }
            }
        }
    }

    private func cardLink(for card: LoyaltyCard) -> some View {
        NavigationLink(value: card) {
            CardRow(card: card)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                barcodeCard = card
                cardStore.markRecentlyViewed(card)
            } label: {
                Label("Show Barcode", systemImage: "barcode")
            }

            Button {
                copyCardNumber(card)
            } label: {
                Label("Copy Number", systemImage: "doc.on.doc")
            }

            Button {
                cardStore.toggleFavorite(card)
            } label: {
                Label(
                    card.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: card.isFavorite ? "star.slash" : "star"
                )
            }

            Button(role: .destructive) {
                pendingDeleteCard = card
            } label: {
                Label("Delete card", systemImage: "trash")
            }
        }
    }

    private var pendingDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteCard != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteCard = nil
                }
            }
        )
    }

    private func prepareExport() {
        do {
            exportDocument = CardBackupDocument(data: try cardStore.exportCardsData())
            isExportingCards = true
        } catch {
            backupMessage = BackupMessage(
                title: "Export failed",
                detail: "Cardless could not prepare your backup file."
            )
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }
            defer { url.stopAccessingSecurityScopedResource() }

            if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               fileSize > Self.maxImportFileBytes {
                backupMessage = BackupMessage(
                    title: "Import failed",
                    detail: "Choose a smaller Cardless backup file."
                )
                return
            }

            let data = try Data(contentsOf: url)
            let summary = try cardStore.importPreviewSummary(from: data)
            guard summary.validCards > 0 else {
                backupMessage = BackupMessage(
                    title: "No cards found",
                    detail: "This backup does not contain any usable Cardless cards."
                )
                return
            }

            importPreview = ImportPreview(data: data, summary: summary)
        } catch {
            backupMessage = BackupMessage(
                title: "Import failed",
                detail: "Choose a valid Cardless JSON backup file."
            )
        }
    }

    private func confirmImport(_ preview: ImportPreview) {
        do {
            try cardStore.importCards(from: preview.data)
            backupMessage = BackupMessage(
                title: "Import complete",
                detail: preview.completionDetail
            )
        } catch {
            backupMessage = BackupMessage(
                title: "Import failed",
                detail: "Cardless could not import this backup."
            )
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupMessage = BackupMessage(
                title: "Export complete",
                detail: "Your Cardless backup file was saved."
            )
        case .failure:
            backupMessage = BackupMessage(
                title: "Export failed",
                detail: "Cardless could not save your backup file."
            )
        }
    }

    private func copyCardNumber(_ card: LoyaltyCard) {
        UIPasteboard.general.string = card.barcodeValue
        backupMessage = BackupMessage(
            title: "Copied",
            detail: "\(card.storeName) membership number copied."
        )
    }
}

private struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct ImportPreview: Identifiable {
    let id = UUID()
    let data: Data
    let summary: LoyaltyCardImportSummary

    var message: String {
        guard summary.validCards > 0 else {
            return "Cardless did not find any usable cards in this backup."
        }

        let detail = [
            quantity(summary.newCards, singular: "new card"),
            quantity(summary.updatedCards, singular: "card update"),
            quantity(summary.skippedCards, singular: "older duplicate")
        ]
        .filter { !$0.hasPrefix("0 ") }
        .joined(separator: ", ")

        return "Cardless found \(quantity(summary.validCards, singular: "usable card")): \(detail)."
    }

    var completionDetail: String {
        guard summary.appliedCards > 0 else {
            return "No cards were changed because the backup only contained older duplicates."
        }

        let detail = [
            quantity(summary.newCards, singular: "new card"),
            quantity(summary.updatedCards, singular: "card update")
        ]
        .filter { !$0.hasPrefix("0 ") }
        .joined(separator: ", ")

        if summary.skippedCards > 0 {
            return "Imported \(detail). Skipped \(quantity(summary.skippedCards, singular: "older duplicate"))."
        }

        return "Imported \(detail)."
    }

    private func quantity(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

private struct FilteredCardSections {
    var favoriteCards: [LoyaltyCard] = []
    var regularCards: [LoyaltyCard] = []

    var isEmpty: Bool {
        favoriteCards.isEmpty && regularCards.isEmpty
    }
}

private struct CardSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .textCase(.uppercase)

            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.ink.opacity(0.64))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.surfaceTint, in: Capsule())

            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

private struct HeaderView: View {
    let cardCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.surfaceTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white, lineWidth: 2)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cardless")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Text(cardCount == 1 ? "1 card saved" : "\(cardCount) cards saved")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("A tiny wallet for the cards you actually use.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 18, x: 0, y: 8)
    }
}

private struct RecentCardsSection: View {
    let cards: [LoyaltyCard]
    let showBarcode: (LoyaltyCard) -> Void
    let copyNumber: (LoyaltyCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(cards) { card in
                        Button {
                            showBarcode(card)
                        } label: {
                            RecentCardChip(card: card)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                copyNumber(card)
                            } label: {
                                Label("Copy Number", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct RecentCardChip: View {
    let card: LoyaltyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.displayInitials)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 34)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(card.storeName.isEmpty ? "Untitled card" : card.storeName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(card.barcodeFormat.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(width: 138, alignment: .leading)
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: AppTheme.softShadow, radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens card details")
    }

    private var tint: Color {
        AppTheme.cardTint(for: card)
    }
}

private struct EmptyCardsView: View {
    let isSearching: Bool
    let addCard: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: isSearching ? "magnifyingglass" : "barcode.viewfinder")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 76, height: 76)
                .background(AppTheme.surfaceTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(isSearching ? "No matching cards" : "No cards yet")
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                Text(isSearching ? "Try a store name or membership number." : "Add your first loyalty card and keep checkout light.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isSearching {
                Button(action: addCard) {
                    Label("Add first card", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("emptyAddFirstCardButton")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 42)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 18, x: 0, y: 8)
    }
}

private struct CardRow: View {
    let card: LoyaltyCard

    var body: some View {
        let formattedUpdatedDate = card.formattedUpdatedDate

        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.16))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
                Text(card.displayInitials)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 58, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(card.storeName.isEmpty ? "Untitled card" : card.storeName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    if card.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.lemon)
                            .accessibilityHidden(true)
                    }
                }

                HStack(spacing: 7) {
                    Text(card.barcodeFormat.rawValue)
                    Text("Updated \(formattedUpdatedDate)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint.opacity(0.72))
                .accessibilityHidden(true)
        }
        .padding(15)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: AppTheme.softShadow, radius: 14, x: 0, y: 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(updatedDate: formattedUpdatedDate))
        .accessibilityHint("Opens card details")
    }

    private var tint: Color {
        AppTheme.cardTint(for: card)
    }

    private func accessibilityLabel(updatedDate: String) -> String {
        let favoriteText = card.isFavorite ? "Favorite, " : ""
        let storeName = card.storeName.isEmpty ? "Untitled card" : card.storeName
        return "\(favoriteText)\(storeName), \(card.barcodeFormat.rawValue), updated \(updatedDate)"
    }
}

#Preview("Cards") {
    CardListView()
        .environmentObject(LoyaltyCardStore.preview())
}

#Preview("Empty") {
    CardListView()
        .environmentObject(LoyaltyCardStore.preview(cards: []))
}
