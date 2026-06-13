import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Pixel Design System

enum PixelTheme {
    static let bg      = Color(red: 0.94, green: 0.94, blue: 0.90)   // cream
    static let ink     = Color(red: 0.04, green: 0.04, blue: 0.04)   // near-black
    static let white   = Color(red: 0.98, green: 0.98, blue: 0.96)

    // Card palette — flat, bold 8-bit colors
    static let palettes: [(bg: Color, shadow: Color, text: Color)] = [
        (Color(red: 1.00, green: 0.91, blue: 0.20), Color(red: 0.55, green: 0.48, blue: 0.00), .black),   // 8-bit yellow
        (Color(red: 0.25, green: 0.82, blue: 0.55), Color(red: 0.00, green: 0.38, blue: 0.22), .black),   // 8-bit green
        (Color(red: 0.98, green: 0.35, blue: 0.35), Color(red: 0.48, green: 0.06, blue: 0.06), PixelTheme.white), // 8-bit red
        (Color(red: 0.28, green: 0.50, blue: 0.98), Color(red: 0.04, green: 0.14, blue: 0.50), PixelTheme.white), // 8-bit blue
        (Color(red: 0.72, green: 0.30, blue: 0.98), Color(red: 0.28, green: 0.04, blue: 0.48), PixelTheme.white), // 8-bit purple
    ]

    static func palette(for index: Int) -> (bg: Color, shadow: Color, text: Color) {
        palettes[abs(index) % palettes.count]
    }
}

// Hard-offset pixel shadow (no blur)
extension View {
    func pixelShadow(x: CGFloat = 4, y: CGFloat = 4, color: Color = PixelTheme.ink) -> some View {
        self.shadow(color: color, radius: 0, x: x, y: y)
    }
    func pixelBorder(width: CGFloat = 2, color: Color = PixelTheme.ink) -> some View {
        self.overlay(Rectangle().stroke(color, lineWidth: width))
    }
}

// MARK: - Main View

struct FeaturedCardsView: View {
    @EnvironmentObject private var cardStore: LoyaltyCardStore
    @EnvironmentObject private var appSettings: AppSettings
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var barcodeCard: LoyaltyCard? = nil
    @State private var isAddingCard = false
    @State private var isShowingAllCards = false
    @State private var isShowingSettings = false
    @State private var isImportingCards = false
    @State private var isExportingCards = false
    @State private var exportDocument = CardBackupDocument()
    @State private var backupMessage: BackupMessage?
    @State private var importPreview: ImportPreview?

    private var displayCards: [LoyaltyCard] { cardStore.cards }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dot-grid background
            PixelGridBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                if displayCards.isEmpty {
                    Spacer()
                    emptyState.padding(.horizontal, 20)
                    Spacer()
                } else {
                    PixelCardStack(
                        cards: displayCards,
                        currentIndex: $currentIndex,
                        dragOffset: $dragOffset,
                        isDragging: $isDragging
                    ) { card in
                        barcodeCard = card
                        cardStore.markRecentlyViewed(card)
                    }
                    .padding(.horizontal, 20)

                    if displayCards.count > 1 {
                        pixelDots.padding(.top, 18)
                    }

                    Spacer()

                    cardRows
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                }

                Color.clear.frame(height: 90)
            }

            pixelTabBar
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isAddingCard) {
            NavigationStack { CardEditorView(card: LoyaltyCard(storeName: "", barcodeValue: "")) }
        }
        .sheet(isPresented: $isShowingAllCards) {
            NavigationStack { CardListView() }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $barcodeCard) { card in LargeBarcodeView(card: card) }
        .fileImporter(isPresented: $isImportingCards, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: handleImport)
        .fileExporter(isPresented: $isExportingCards, document: exportDocument, contentType: .json, defaultFilename: "cardless-cards", onCompletion: handleExport)
        .alert(item: $backupMessage) { msg in
            Alert(title: Text(msg.title), message: Text(msg.detail), dismissButton: .default(Text("OK")))
        }
        .alert(item: $importPreview) { preview in
            Alert(title: Text("IMPORT?"), message: Text(preview.message),
                  primaryButton: .default(Text("[ IMPORT ]")) { confirmImport(preview) },
                  secondaryButton: .cancel(Text("[ CANCEL ]")))
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            // Title
            Text("// WALLET")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(PixelTheme.ink)
                .tracking(1)

            // Region pill — tapping opens Settings
            Button { isShowingSettings = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 9, weight: .black))
                    Text(appSettings.selectedRegion.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.4)
                }
                .foregroundStyle(PixelTheme.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(PixelTheme.ink)
                .pixelBorder(width: 1.5)
                .pixelShadow(x: 2, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Region: \(appSettings.selectedRegion.rawValue). Tap to change.")

            Spacer()

            Button { isShowingAllCards = true } label: {
                Text("ALL")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(PixelTheme.white)
                    .pixelBorder()
                    .pixelShadow(x: 3, y: 3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Page dots (pixel style)

    private var pixelDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<displayCards.count, id: \.self) { i in
                Rectangle()
                    .fill(i == currentIndex ? PixelTheme.ink : PixelTheme.ink.opacity(0.22))
                    .frame(width: i == currentIndex ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.15), value: currentIndex)
            }
        }
    }

    // MARK: - Card rows

    private var cardRows: some View {
        VStack(spacing: 10) {
            ForEach(Array(displayCards.prefix(3).enumerated()), id: \.element.id) { idx, card in
                PixelCardRow(card: card, colorIndex: idx) {
                    barcodeCard = card
                    cardStore.markRecentlyViewed(card)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Rectangle()
                    .fill(PixelTheme.white)
                    .pixelBorder()
                    .pixelShadow(x: 5, y: 5)

                VStack(spacing: 10) {
                    Text("░░░░░░░░░░░")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(PixelTheme.ink.opacity(0.25))
                    Text("NO CARDS")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(PixelTheme.ink)
                        .accessibilityIdentifier("emptyStateLabel")
                    Text("░░░░░░░░░░░")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(PixelTheme.ink.opacity(0.25))
                }
            }
            .frame(height: 160)

            Button { isAddingCard = true } label: {
                Text("[ + ADD FIRST CARD ]")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelTheme.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PixelTheme.ink)
                    .pixelBorder()
                    .pixelShadow(x: 4, y: 4, color: Color(red: 0.55, green: 0.48, blue: 0.00))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add first card")
            .accessibilityIdentifier("emptyAddFirstCardButton")
        }
    }

    // MARK: - Tab bar

    private var pixelTabBar: some View {
        VStack {
            Spacer()
            ZStack {
                Rectangle()
                    .fill(PixelTheme.white)
                    .overlay(alignment: .top) {
                        Rectangle().fill(PixelTheme.ink).frame(height: 2)
                    }
                    .frame(height: 80)

                HStack(spacing: 0) {
                    Spacer()
                    pixelTab("house.fill", label: "HOME")
                    Spacer()
                    pixelTab("clock", label: "LOG") { isShowingAllCards = true }
                    Spacer()

                    // Center add
                    Button { isAddingCard = true } label: {
                        ZStack {
                            Rectangle()
                                .fill(PixelTheme.ink)
                                .frame(width: 56, height: 56)
                                .pixelShadow(x: 4, y: 4)
                            Text("+")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(PixelTheme.white)
                        }
                    }
                    .offset(y: -14)
                    .accessibilityLabel("Add card")

                    Spacer()
                    pixelTab("bell", label: "BELL")
                    Spacer()
                    pixelTab("gearshape.fill", label: "SET") { isShowingSettings = true }
                    Spacer()
                }
                .frame(height: 80)
            }
            .padding(.bottom, 12)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func pixelTab(_ icon: String, label: String, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(PixelTheme.ink)
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelTheme.ink)
                    .tracking(1)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Region badge (shown in top-bar when set)
    private var regionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 10, weight: .black, design: .monospaced))
            Text(appSettings.selectedRegion.rawValue.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.5)
        }
        .foregroundStyle(PixelTheme.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PixelTheme.ink)
        .pixelBorder(width: 1.5)
    }

    // MARK: - Import / Export helpers

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let summary = try cardStore.importPreviewSummary(from: data)
            guard summary.validCards > 0 else {
                backupMessage = BackupMessage(title: "NO CARDS", detail: "No usable cards found.")
                return
            }
            importPreview = ImportPreview(data: data, summary: summary)
        } catch {
            backupMessage = BackupMessage(title: "ERROR", detail: "Invalid backup file.")
        }
    }

    private func confirmImport(_ preview: ImportPreview) {
        do {
            try cardStore.importCards(from: preview.data)
            backupMessage = BackupMessage(title: "DONE", detail: preview.completionDetail)
        } catch {
            backupMessage = BackupMessage(title: "ERROR", detail: "Import failed.")
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success: backupMessage = BackupMessage(title: "SAVED", detail: "Backup exported.")
        case .failure: backupMessage = BackupMessage(title: "ERROR", detail: "Export failed.")
        }
    }
}

// MARK: - Dot grid background

struct PixelGridBackground: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.94, green: 0.94, blue: 0.90)))
            let step: CGFloat = 20
            let dotSize: CGFloat = 2
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize))
                    ctx.fill(dot, with: .color(Color(red: 0.04, green: 0.04, blue: 0.04).opacity(0.10)))
                    y += step
                }
                x += step
            }
        }
    }
}

// MARK: - Pixel Card Stack

struct PixelCardStack: View {
    let cards: [LoyaltyCard]
    @Binding var currentIndex: Int
    @Binding var dragOffset: CGFloat
    @Binding var isDragging: Bool
    let onTap: (LoyaltyCard) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w * 0.58

            ZStack(alignment: .leading) {
                ForEach(visibleOffsets.reversed(), id: \.self) { offset in
                    let idx = safeIndex(currentIndex + offset)
                    PixelCard(card: cards[idx], colorIndex: idx)
                        .frame(width: w, height: h)
                        .offset(x: xOffset(for: offset), y: yOffset(for: offset))
                        .zIndex(Double(3 - offset))
                        .opacity(offset == 0 ? 1.0 : 0.72 - Double(offset - 1) * 0.18)
                        .animation(.easeOut(duration: 0.20), value: currentIndex)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.78), value: dragOffset)
                        .onTapGesture { if offset == 0 { onTap(cards[idx]) } }
                }
            }
            .frame(height: h + 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { v in isDragging = true; dragOffset = v.translation.width }
                    .onEnded { v in
                        isDragging = false
                        withAnimation(.easeOut(duration: 0.20)) {
                            if v.translation.width < -50, cards.count > 1 { currentIndex = safeIndex(currentIndex + 1) }
                            else if v.translation.width > 50, cards.count > 1 { currentIndex = safeIndex(currentIndex - 1) }
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: 240)
    }

    private var visibleOffsets: [Int] { Array(0..<min(3, cards.count)) }
    private func safeIndex(_ i: Int) -> Int { ((i % cards.count) + cards.count) % cards.count }
    private func xOffset(for offset: Int) -> CGFloat { offset == 0 ? dragOffset * 0.5 : -CGFloat(offset) * 16 }
    private func yOffset(for offset: Int) -> CGFloat { -CGFloat(offset) * 8 }
}

// MARK: - Single Pixel Card

struct PixelCard: View {
    let card: LoyaltyCard
    let colorIndex: Int

    private var pal: (bg: Color, shadow: Color, text: Color) { PixelTheme.palette(for: colorIndex) }

    var body: some View {
        ZStack(alignment: .leading) {
            // Hard pixel shadow layer
            Rectangle()
                .fill(pal.shadow)
                .offset(x: 6, y: 6)

            // Card face
            Rectangle()
                .fill(pal.bg)
                .overlay(alignment: .topTrailing) {
                    // Pixel art corner decoration
                    pixelCornerArt
                }
                .overlay(alignment: .bottomLeading) {
                    Text(card.storeName.isEmpty ? "???" : card.storeName.uppercased())
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(pal.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(18)
                }
                .pixelBorder(width: 2.5)
        }
    }

    private var pixelCornerArt: some View {
        // Simple pixel grid pattern in top-right
        VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { col in
                        let filled = pixelPattern(row: row, col: col)
                        Rectangle()
                            .fill(pal.text.opacity(filled ? 0.18 : 0.05))
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(16)
    }

    private func pixelPattern(row: Int, col: Int) -> Bool {
        let patterns: [[Bool]] = [
            [true,  false, true,  false],
            [false, true,  false, true ],
            [true,  false, true,  false],
            [false, true,  false, true ],
        ]
        return patterns[row][col]
    }
}

// MARK: - Pixel Card Row

private struct PixelCardRow: View {
    let card: LoyaltyCard
    let colorIndex: Int
    let action: () -> Void

    private var pal: (bg: Color, shadow: Color, text: Color) { PixelTheme.palette(for: colorIndex) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Initials box
                ZStack {
                    Rectangle().fill(pal.shadow).offset(x: 3, y: 3)
                    Rectangle()
                        .fill(pal.bg)
                        .pixelBorder(width: 2)
                        .overlay {
                            Text(card.displayInitials)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(pal.text)
                        }
                }
                .frame(width: 44, height: 44)

                Text(card.storeName.isEmpty ? "???" : card.storeName.uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelTheme.ink)
                    .lineLimit(1)

                Spacer()

                if card.isFavorite {
                    Text("★")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.00, green: 0.72, blue: 0.00))
                }

                Text(">")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(PixelTheme.ink.opacity(0.40))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background {
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(PixelTheme.ink.opacity(0.70)).offset(x: 4, y: 4)
                    Rectangle().fill(PixelTheme.white).pixelBorder(width: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting private types

private struct BackupMessage: Identifiable {
    let id = UUID(); let title: String; let detail: String
}

private struct ImportPreview: Identifiable {
    let id = UUID(); let data: Data; let summary: LoyaltyCardImportSummary
    var message: String { "\(summary.validCards) CARD\(summary.validCards == 1 ? "" : "S") FOUND." }
    var completionDetail: String { "IMPORTED \(summary.appliedCards) CARD\(summary.appliedCards == 1 ? "" : "S")." }
}

// MARK: - Previews

#Preview("Pixel — With cards") {
    NavigationStack {
        FeaturedCardsView()
            .environmentObject(LoyaltyCardStore.preview())
    }
}

#Preview("Pixel — Empty") {
    NavigationStack {
        FeaturedCardsView()
            .environmentObject(LoyaltyCardStore.preview(cards: []))
    }
}
