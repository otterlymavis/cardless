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
                HStack(spacing: 14) {
                    Text(card.displayInitials)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(editorTint)
                        .frame(width: 58, height: 48)
                        .background(editorTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(editorTint.opacity(0.26), lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.storeName.isEmpty ? "New loyalty card" : card.storeName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        Text(card.barcodeFormat.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()
                }
                .padding(16)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: AppTheme.softShadow, radius: 16, x: 0, y: 8)

                if isNewCard && (!brandPresetStore.presets.isEmpty || brandPresetStore.isLoading) {
                    EditorSection(title: "Popular brands") {
                        BrandPresetPicker { preset in
                            applyBrandPreset(preset)
                        }
                    }
                }

                EditorSection(title: "Card details") {
                    VStack(alignment: .leading, spacing: 8) {
                        EditorFieldLabel("Store name")
                        TextField("Market Club", text: $card.storeName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityIdentifier("storeNameField")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EditorFieldLabel("Membership number")
                        HStack(spacing: 10) {
                            TextField("1234567890", text: $card.barcodeValue)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .textFieldStyle(.plain)
                                .accessibilityIdentifier("barcodeValueField")

                            Button {
                                isScanningBarcode = true
                            } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.headline)
                                    .frame(width: 38, height: 38)
                                    .background(editorTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Scan barcode")
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 5)
                        .padding(.vertical, 5)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    HStack(spacing: 12) {
                        EditorFieldLabel("Barcode type")
                        Spacer()
                        Picker("Barcode type", selection: $card.barcodeFormat) {
                            ForEach(BarcodeFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(editorTint)
                    }
                    .padding(12)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        EditorFieldLabel("Cover color")
                        CardColorPicker(selection: $card.cardColor)
                    }
                }

                EditorSection(title: "Optional") {
                    VStack(alignment: .leading, spacing: 8) {
                        EditorFieldLabel("Checkout note")
                        TextField("Anything helpful at checkout", text: $card.note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                Label("Saved only on this device", systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(isNewCard ? "Add Card" : "Edit Card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isScanningBarcode) {
            NavigationStack {
                BarcodeScannerView { result in
                    card.barcodeValue = result.value
                    if let format = result.format {
                        card.barcodeFormat = format
                    }
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
                        Button("Cancel") {
                            isScanningBarcode = false
                        }
                    }
                }
            }
        }
        .alert("Scanner unavailable", isPresented: scannerAlertBinding) {
            Button("OK", role: .cancel) {
                scanErrorMessage = nil
            }
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
            }
        }
        .task {
            if isNewCard {
                await brandPresetStore.loadPresets()
            }
        }
    }

    private var editorTint: Color {
        AppTheme.cardTint(for: card)
    }

    private var scannerAlertBinding: Binding<Bool> {
        Binding(
            get: { scanErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    scanErrorMessage = nil
                }
            }
        )
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
        let displayedPresets = displayedPresets
        let selectedRegion = selectedRegion

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .accessibilityHidden(true)

                TextField("Search brands", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("brandPresetSearchField")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear brand search")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Region tabs — selecting here also updates AppSettings so it persists
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(LoyaltyBrandRegion.allCases) { region in
                        Button {
                            withAnimation { appSettings.selectedRegion = region }
                        } label: {
                            Text(region.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selectedRegion == region ? .white : AppTheme.ink)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    selectedRegion == region ? AppTheme.ink : AppTheme.background,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedRegion == region ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(displayedPresets) { preset in
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

            if displayedPresets.isEmpty {
                Label(presetStore.isLoading ? "Loading brands" : "No matching brands", systemImage: "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct BrandPresetChip: View {
    let preset: LoyaltyBrandPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(preset.name.displayInitials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 32)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(preset.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                Text(preset.region.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
        .frame(width: 132, alignment: .leading)
        .padding(12)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Fills common card details")
    }

    private var tint: Color {
        AppTheme.color(for: preset.cardColor)
    }
}

private struct CardColorPicker: View {
    @Binding var selection: CardColor?

    var body: some View {
        HStack(spacing: 9) {
            colorButton(color: nil, label: "Auto", systemImage: "sparkles")

            ForEach(CardColor.allCases) { cardColor in
                colorButton(color: cardColor, label: cardColor.rawValue)
            }

            Spacer(minLength: 0)
        }
    }

    private func colorButton(color: CardColor?, label: String, systemImage: String? = nil) -> some View {
        Button {
            selection = color
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fillColor(for: color))

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }

                if selection == color {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(checkmarkColor(for: color))
                }
            }
            .frame(width: 36, height: 36)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selection == color ? AppTheme.ink.opacity(0.48) : AppTheme.ink.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == color ? .isSelected : [])
    }

    private func fillColor(for color: CardColor?) -> Color {
        guard let color else { return AppTheme.surfaceTint }
        return AppTheme.color(for: color)
    }

    private func checkmarkColor(for color: CardColor?) -> Color {
        color == .lemon || color == nil ? AppTheme.ink : .white
    }
}

private struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .textCase(.uppercase)
            content
        }
        .padding(16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: AppTheme.softShadow, radius: 14, x: 0, y: 7)
    }
}

private struct EditorFieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.muted)
            .textCase(.uppercase)
    }
}

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
