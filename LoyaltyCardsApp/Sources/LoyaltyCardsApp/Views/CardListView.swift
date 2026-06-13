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
            if card.isFavorite { sections.favoriteCards.append(card) }
            else { sections.regularCards.append(card) }
        }
    }

    var body: some View {
        let cardSections = filteredCardSections
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let recentCards = isSearching ? [] : cardStore.recentCards

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PixelHeaderView(cardCount: cardStore.cards.count)

                    if !recentCards.isEmpty {
                        PixelRecentCardsSection(cards: recentCards) { card in
                            barcodeCard = card
                            cardStore.markRecentlyViewed(card)
                        } copyNumber: { card in
                            copyCardNumber(card)
                        }
                    }

                    if cardSections.isEmpty {
                        PixelEmptyCardsView(isSearching: isSearching) {
                            isAddingCard = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            if !cardSections.favoriteCards.isEmpty {
                                PixelSectionHeader(title: "FAVORITES", count: cardSections.favoriteCards.count)
                                LazyVStack(spacing: 12) {
                                    ForEach(cardSections.favoriteCards) { card in cardLink(for: card) }
                                }
                            }
                            if !cardSections.regularCards.isEmpty {
                                if !cardSections.favoriteCards.isEmpty {
                                    PixelSectionHeader(title: "CARDS", count: cardSections.regularCards.count)
                                }
                                LazyVStack(spacing: 12) {
                                    ForEach(cardSections.regularCards) { card in cardLink(for: card) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .background {
                Color(red: 0.94, green: 0.94, blue: 0.90)
                    .ignoresSafeArea()
                PixelGridBackground().ignoresSafeArea()
            }
            .navigationTitle("// ALL CARDS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.94, green: 0.94, blue: 0.90), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { isImportingCards = true } label: {
                            Label("Import Backup", systemImage: "square.and.arrow.down")
                        }
                        Button { prepareExport() } label: {
                            Label("Export Backup", systemImage: "square.and.arrow.up")
                        }
                        .disabled(cardStore.cards.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Backup options")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAddingCard = true } label: {
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
            .fullScreenCover(item: $barcodeCard) { card in LargeBarcodeView(card: card) }
            .fileImporter(isPresented: $isImportingCards, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: handleImport)
            .fileExporter(isPresented: $isExportingCards, document: exportDocument, contentType: .json, defaultFilename: "cardless-cards", onCompletion: handleExport)
            .alert(item: $backupMessage) { message in
                Alert(title: Text(message.title), message: Text(message.detail), dismissButton: .default(Text("OK")))
            }
            .alert(item: $importPreview) { preview in
                Alert(
                    title: Text("Import Backup?"),
                    message: Text(preview.message),
                    primaryButton: .default(Text("Import")) { confirmImport(preview) },
                    secondaryButton: .cancel()
                )
            }
            .confirmationDialog("Delete Card?", isPresented: pendingDeleteBinding, titleVisibility: .visible) {
                if let card = pendingDeleteCard {
                    Button("Delete \(card.storeName)", role: .destructive) {
                        cardStore.delete(card)
                        pendingDeleteCard = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeleteCard = nil }
            } message: {
                if let card = pendingDeleteCard {
                    Text("This removes \(card.storeName) from Cardless. You can restore it later only if you have a backup.")
                }
            }
        }
    }

    private func cardLink(for card: LoyaltyCard) -> some View {
        NavigationLink(value: card) { PixelCardRow(card: card) }
            .buttonStyle(.plain)
            .contextMenu {
                Button { barcodeCard = card; cardStore.markRecentlyViewed(card) } label: {
                    Label("Show Barcode", systemImage: "barcode")
                }
                Button { copyCardNumber(card) } label: {
                    Label("Copy Number", systemImage: "doc.on.doc")
                }
                Button { cardStore.toggleFavorite(card) } label: {
                    Label(card.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: card.isFavorite ? "star.slash" : "star")
                }
                Button(role: .destructive) { pendingDeleteCard = card } label: {
                    Label("Delete card", systemImage: "trash")
                }
            }
    }

    private var pendingDeleteBinding: Binding<Bool> {
        Binding(get: { pendingDeleteCard != nil }, set: { if !$0 { pendingDeleteCard = nil } })
    }

    private func prepareExport() {
        do {
            exportDocument = CardBackupDocument(data: try cardStore.exportCardsData())
            isExportingCards = true
        } catch {
            backupMessage = BackupMessage(title: "Export failed", detail: "Cardless could not prepare your backup file.")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
            defer { url.stopAccessingSecurityScopedResource() }
            if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, fileSize > Self.maxImportFileBytes {
                backupMessage = BackupMessage(title: "Import failed", detail: "Choose a smaller Cardless backup file.")
                return
            }
            let data = try Data(contentsOf: url)
            let summary = try cardStore.importPreviewSummary(from: data)
            guard summary.validCards > 0 else {
                backupMessage = BackupMessage(title: "No cards found", detail: "This backup does not contain any usable Cardless cards.")
                return
            }
            importPreview = ImportPreview(data: data, summary: summary)
        } catch {
            backupMessage = BackupMessage(title: "Import failed", detail: "Choose a valid Cardless JSON backup file.")
        }
    }

    private func confirmImport(_ preview: ImportPreview) {
        do {
            try cardStore.importCards(from: preview.data)
            backupMessage = BackupMessage(title: "Import complete", detail: preview.completionDetail)
        } catch {
            backupMessage = BackupMessage(title: "Import failed", detail: "Cardless could not import this backup.")
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success: backupMessage = BackupMessage(title: "Export complete", detail: "Your Cardless backup file was saved.")
        case .failure: backupMessage = BackupMessage(title: "Export failed", detail: "Cardless could not save your backup file.")
        }
    }

    private func copyCardNumber(_ card: LoyaltyCard) {
        UIPasteboard.general.string = card.barcodeValue
        backupMessage = BackupMessage(title: "Copied", detail: "\(card.storeName) membership number copied.")
    }
}

// MARK: - Private types

private struct BackupMessage: Identifiable {
    let id = UUID(); let title: String; let detail: String
}

private struct ImportPreview: Identifiable {
    let id = UUID(); let data: Data; let summary: LoyaltyCardImportSummary
    var message: String {
        guard summary.validCards > 0 else { return "Cardless did not find any usable cards in this backup." }
        let detail = [quantity(summary.newCards, singular: "new card"),
                      quantity(summary.updatedCards, singular: "card update"),
                      quantity(summary.skippedCards, singular: "older duplicate")]
            .filter { !$0.hasPrefix("0 ") }.joined(separator: ", ")
        return "Cardless found \(quantity(summary.validCards, singular: "usable card")): \(detail)."
    }
    var completionDetail: String {
        guard summary.appliedCards > 0 else { return "No cards were changed because the backup only contained older duplicates." }
        let detail = [quantity(summary.newCards, singular: "new card"),
                      quantity(summary.updatedCards, singular: "card update")]
            .filter { !$0.hasPrefix("0 ") }.joined(separator: ", ")
        if summary.skippedCards > 0 { return "Imported \(detail). Skipped \(quantity(summary.skippedCards, singular: "older duplicate"))." }
        return "Imported \(detail)."
    }
    private func quantity(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }
}

private struct FilteredCardSections {
    var favoriteCards: [LoyaltyCard] = []
    var regularCards: [LoyaltyCard] = []
    var isEmpty: Bool { favoriteCards.isEmpty && regularCards.isEmpty }
}

// MARK: - Pixel sub-views

private struct PixelSectionHeader: View {
    let title: String; let count: Int
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
            ZStack {
                Rectangle().fill(AppTheme.ink).offset(x: 2, y: 2)
                Rectangle()
                    .fill(AppTheme.surface)
                    .pixelBorder(width: 1.5)
                    .overlay {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.ink)
                    }
            }
            .frame(width: 28, height: 20)
            Spacer()
        }
        .padding(.horizontal, 2)
    }
}

private struct PixelHeaderView: View {
    let cardCount: Int
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle().fill(AppTheme.ink).offset(x: 4, y: 4)
                Rectangle()
                    .fill(AppTheme.lemon)
                    .pixelBorder()
                    .overlay {
                        Text("░")
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundStyle(AppTheme.ink.opacity(0.40))
                    }
            }
            .frame(width: 52, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("CARDLESS")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                Text(cardCount == 1 ? "1 CARD" : "\(cardCount) CARDS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelCard(shadowX: 4, shadowY: 4)
    }
}

private struct PixelRecentCardsSection: View {
    let cards: [LoyaltyCard]
    let showBarcode: (LoyaltyCard) -> Void
    let copyNumber: (LoyaltyCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(cards) { card in
                        Button { showBarcode(card) } label: {
                            PixelRecentChip(card: card)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { copyNumber(card) } label: {
                                Label("Copy Number", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct PixelRecentChip: View {
    let card: LoyaltyCard
    private var pal: (bg: Color, shadow: Color, text: Color) { PixelTheme.palette(for: abs(card.storeName.hashValue)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Rectangle().fill(pal.shadow).offset(x: 3, y: 3)
                Rectangle()
                    .fill(pal.bg)
                    .pixelBorder()
                    .overlay {
                        Text(card.displayInitials)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(pal.text)
                    }
            }
            .frame(width: 44, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.storeName.isEmpty ? "UNTITLED" : card.storeName.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(card.barcodeFormat.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(width: 130, alignment: .leading)
        .padding(12)
        .pixelCard(shadowX: 3, shadowY: 3)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens card details")
    }
}

private struct PixelEmptyCardsView: View {
    let isSearching: Bool
    let addCard: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Rectangle().fill(AppTheme.ink).offset(x: 5, y: 5)
                Rectangle()
                    .fill(AppTheme.surface)
                    .pixelBorder()
                    .overlay {
                        VStack(spacing: 6) {
                            Text("░░░░░░░░░")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(AppTheme.ink.opacity(0.20))
                            Image(systemName: isSearching ? "magnifyingglass" : "barcode.viewfinder")
                                .font(.system(size: 32, weight: .black))
                                .foregroundStyle(AppTheme.ink)
                            Text(isSearching ? "NO MATCHES" : "NO CARDS")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(AppTheme.ink)
                            Text("░░░░░░░░░")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(AppTheme.ink.opacity(0.20))
                        }
                    }
            }
            .frame(height: 160)

            if !isSearching {
                Button(action: addCard) {
                    Text("[ + ADD FIRST CARD ]")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(PixelTheme.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.ink)
                        .pixelBorder()
                }
                .buttonStyle(.plain)
                .pixelShadow(x: 4, y: 4, color: Color(red: 0.55, green: 0.48, blue: 0.00))
                .accessibilityIdentifier("emptyAddFirstCardButton")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 24)
    }
}

private struct PixelCardRow: View {
    let card: LoyaltyCard
    private var pal: (bg: Color, shadow: Color, text: Color) { PixelTheme.palette(for: abs(card.storeName.hashValue)) }
    private let formattedDate: String

    init(card: LoyaltyCard) {
        self.card = card
        self.formattedDate = card.formattedUpdatedDate
    }

    var body: some View {
        HStack(spacing: 14) {
            // Initials box
            ZStack {
                Rectangle().fill(pal.shadow).offset(x: 3, y: 3)
                Rectangle()
                    .fill(pal.bg)
                    .pixelBorder()
                    .overlay {
                        Text(card.displayInitials)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(pal.text)
                    }
            }
            .frame(width: 52, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(card.storeName.isEmpty ? "UNTITLED" : card.storeName.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    if card.isFavorite {
                        Text("★")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.lemon)
                            .accessibilityHidden(true)
                    }
                }
                Text("\(card.barcodeFormat.rawValue.uppercased())  ·  \(formattedDate.uppercased())")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Text(">")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.35))
                .accessibilityHidden(true)
        }
        .padding(14)
        .pixelCard(shadowX: 4, shadowY: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.isFavorite ? "Favorite, " : "")\(card.storeName.isEmpty ? "Untitled card" : card.storeName), \(card.barcodeFormat.rawValue), updated \(formattedDate)")
        .accessibilityHint("Opens card details")
    }
}

// MARK: - Previews

#Preview("Cards") {
    CardListView()
        .environmentObject(LoyaltyCardStore.preview())
}

#Preview("Empty") {
    CardListView()
        .environmentObject(LoyaltyCardStore.preview(cards: []))
}
