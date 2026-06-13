import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cardStore: LoyaltyCardStore
    @EnvironmentObject private var brandPresetStore: BrandPresetStore

    @State private var card: LoyaltyCard
    @State private var isScanningBarcode = false
    @State private var scanErrorMessage: String?

    init(card: LoyaltyCard) {
        _card = State(initialValue: card)
    }

    private var isNewCard: Bool {
        !cardStore.cards.contains { $0.id == card.id }
    }

    private var canSave: Bool {
        !card.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !card.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // MARK: Card preview header
                HStack(spacing: 14) {
                    ZStack {
                        Rectangle().fill(editorTint).offset(x: 4, y: 4)
                        Rectangle()
                            .fill(editorTint.opacity(0.20))
                            .pixelBorder()
                            .overlay {
                                Text(card.displayInitials)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundStyle(editorTint)
                            }
                    }
                    .frame(width: 58, height: 48)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.storeName.isEmpty ? "NEW CARD" : card.storeName.uppercased())
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        Text(card.barcodeFormat.rawValue.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
                .padding(16)
                .pixelCard(shadowX: 4, shadowY: 4)

                // MARK: Brand preset picker
                if isNewCard && (!brandPresetStore.presets.isEmpty || brandPresetStore.isLoading) {
                    PixelEditorSection(title: "POPULAR BRANDS") {
                        BrandPresetPicker { preset in applyBrandPreset(preset) }
                    }
                }

                // MARK: Card details
                PixelEditorSection(title: "CARD DETAILS") {
                    // Store name
                    VStack(alignment: .leading, spacing: 6) {
                        PixelFieldLabel("STORE NAME")
                        TextField("Market Club", text: $card.storeName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(AppTheme.background)
                            .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.40))
                            .accessibilityIdentifier("storeNameField")
                    }

                    // Membership number
                    VStack(alignment: .leading, spacing: 6) {
                        PixelFieldLabel("MEMBERSHIP NUMBER")
                        HStack(spacing: 8) {
                            TextField("1234567890", text: $card.barcodeValue)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .accessibilityIdentifier("barcodeValueField")

                            Button { isScanningBarcode = true } label: {
                                ZStack {
                                    Rectangle().fill(editorTint).offset(x: 3, y: 3)
                                    Rectangle()
                                        .fill(AppTheme.ink)
                                        .pixelBorder()
                                        .overlay {
                                            Image(systemName: "barcode.viewfinder")
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundStyle(.white)
                                        }
                                }
                                .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Scan barcode")
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 6)
                        .padding(.vertical, 6)
                        .background(AppTheme.background)
                        .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.40))
                    }

                    // Barcode type
                    HStack(spacing: 12) {
                        PixelFieldLabel("BARCODE TYPE")
                        Spacer()
                        Picker("Barcode type", selection: $card.barcodeFormat) {
                            ForEach(BarcodeFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(editorTint)
                        .font(.system(.body, design: .monospaced))
                    }
                    .padding(12)
                    .background(AppTheme.background)
                    .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.40))

                    // Cover colour
                    VStack(alignment: .leading, spacing: 8) {
                        PixelFieldLabel("COVER COLOUR")
                        CardColorPicker(selection: $card.cardColor)
                    }
                }

                // MARK: Optional
                PixelEditorSection(title: "OPTIONAL") {
                    VStack(alignment: .leading, spacing: 6) {
                        PixelFieldLabel("CHECKOUT NOTE")
                        TextField("Anything helpful at checkout", text: $card.note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(AppTheme.background)
                            .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.40))
                    }
                }

                // MARK: Privacy note
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .black))
                    Text("SAVED ON THIS DEVICE ONLY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(AppTheme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceTint)
                .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.25))
            }
            .padding(16)
        }
        .background {
            Color(red: 0.94, green: 0.94, blue: 0.90).ignoresSafeArea()
            PixelGridBackground().ignoresSafeArea()
        }
        .navigationTitle(isNewCard ? "// ADD CARD" : "// EDIT CARD")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.94, green: 0.94, blue: 0.90), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isScanningBarcode) {
            NavigationStack {
                BarcodeScannerView { result in
                    card.barcodeValue = result.value
                    if let format = result.format { card.barcodeFormat = format }
                    isScanningBarcode = false
                } onUnavailable: { message in
                    scanErrorMessage = message
                    isScanningBarcode = false
                }
                .ignoresSafeArea()
                .navigationTitle("Scan Barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isScanningBarcode = false }
                    }
                }
            }
        }
        .alert("Scanner unavailable", isPresented: scannerAlertBinding) {
            Button("OK", role: .cancel) { scanErrorMessage = nil }
        } message: {
            Text(scanErrorMessage ?? "You can still enter the number manually.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    cardStore.save(card)
                    dismiss()
                }
                .disabled(!canSave)
                .fontWeight(.black)
            }
        }
        .task {
            if isNewCard { await brandPresetStore.loadPresets() }
        }
    }

    private var editorTint: Color { AppTheme.cardTint(for: card) }

    private var scannerAlertBinding: Binding<Bool> {
        Binding(get: { scanErrorMessage != nil }, set: { if !$0 { scanErrorMessage = nil } })
    }

    private func applyBrandPreset(_ preset: LoyaltyBrandPreset) {
        card.storeName = preset.name
        card.barcodeFormat = preset.barcodeFormat
        card.cardColor = preset.cardColor
        if card.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            card.note = preset.cardNote
        }
    }
}

// MARK: - Brand Preset Picker

private struct BrandPresetPicker: View {
    @EnvironmentObject private var presetStore: BrandPresetStore
    @EnvironmentObject private var appSettings: AppSettings
    @State private var searchText = ""

    let applyPreset: (LoyaltyBrandPreset) -> Void

    private var selectedRegion: LoyaltyBrandRegion { appSettings.selectedRegion }

    private var displayedPresets: [LoyaltyBrandPreset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let presets = presetStore.presets(for: selectedRegion)
        guard !query.isEmpty else { return presets }
        let regionalResults = presetStore.search(query, in: presets)
        return regionalResults.isEmpty ? presetStore.searchAll(query) : regionalResults
    }

    var body: some View {
        let displayed = displayedPresets
        let region = selectedRegion

        VStack(alignment: .leading, spacing: 10) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)

                TextField("SEARCH BRANDS", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .accessibilityIdentifier("brandPresetSearchField")

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(AppTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear brand search")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.background)
            .pixelBorder(width: 1.5, color: AppTheme.ink.opacity(0.40))

            // Region tabs
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(LoyaltyBrandRegion.allCases) { r in
                        Button {
                            withAnimation { appSettings.selectedRegion = r }
                        } label: {
                            Text(r.rawValue.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(region == r ? AppTheme.surface : AppTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(region == r ? AppTheme.ink : AppTheme.background)
                                .pixelBorder(width: 1.5, color: AppTheme.ink)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(region == r ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }

            // Preset chips
            if displayed.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: presetStore.isLoading ? "clock" : "magnifyingglass")
                        .font(.system(size: 11, weight: .black))
                    Text(presetStore.isLoading ? "LOADING..." : "NO BRANDS FOUND")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(AppTheme.muted)
                .padding(11)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(displayed) { preset in
                            Button {
                                applyPreset(preset)
                                searchText = ""
                                withAnimation { appSettings.selectedRegion = preset.region }
                            } label: {
                                BrandPresetChip(preset: preset)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("brandPreset.\(preset.id)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Brand Preset Chip

private struct BrandPresetChip: View {
    let preset: LoyaltyBrandPreset
    private var tint: Color { AppTheme.color(for: preset.cardColor) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle().fill(tint).offset(x: 3, y: 3)
                Rectangle()
                    .fill(tint.opacity(0.20))
                    .pixelBorder()
                    .overlay {
                        Text(preset.name.displayInitials)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(tint)
                    }
            }
            .frame(width: 38, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(preset.category.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }
        }
        .frame(width: 120, alignment: .leading)
        .padding(10)
        .pixelCard(fill: AppTheme.background, shadowX: 3, shadowY: 3)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Fills common card details")
    }
}

// MARK: - Color picker

private struct CardColorPicker: View {
    @Binding var selection: CardColor?

    var body: some View {
        HStack(spacing: 8) {
            colorButton(color: nil, label: "Auto", systemImage: "sparkles")
            ForEach(CardColor.allCases) { cardColor in
                colorButton(color: cardColor, label: cardColor.rawValue)
            }
            Spacer(minLength: 0)
        }
    }

    private func colorButton(color: CardColor?, label: String, systemImage: String? = nil) -> some View {
        let isSelected = selection == color
        return Button {
            selection = color
        } label: {
            ZStack {
                Rectangle().fill(fillColor(for: color))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(checkmarkColor(for: color))
                }
            }
            .frame(width: 36, height: 36)
            .pixelBorder(width: isSelected ? 2 : 1.5,
                         color: isSelected ? AppTheme.ink : AppTheme.ink.opacity(0.30))
            .shadow(color: AppTheme.ink, radius: 0, x: isSelected ? 3 : 2, y: isSelected ? 3 : 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func fillColor(for color: CardColor?) -> Color {
        guard let color else { return AppTheme.surfaceTint }
        return AppTheme.color(for: color)
    }

    private func checkmarkColor(for color: CardColor?) -> Color {
        color == .lemon || color == nil ? AppTheme.ink : .white
    }
}

// MARK: - Section + label helpers

private struct PixelEditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
            content
        }
        .padding(16)
        .pixelCard(shadowX: 4, shadowY: 4)
    }
}

private struct PixelFieldLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .foregroundStyle(AppTheme.muted)
    }
}

// MARK: - Previews

#Preview("Add") {
    NavigationStack {
        CardEditorView(card: LoyaltyCard(storeName: "", barcodeValue: ""))
            .environmentObject(LoyaltyCardStore.preview(cards: []))
            .environmentObject(BrandPresetStore.preview())
    }
}

#Preview("Edit") {
    NavigationStack {
        CardEditorView(card: LoyaltyCard.previewCards[0])
            .environmentObject(LoyaltyCardStore.preview())
            .environmentObject(BrandPresetStore.preview())
    }
}
