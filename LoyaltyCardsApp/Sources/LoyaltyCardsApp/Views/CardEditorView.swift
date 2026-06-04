import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cardStore: LoyaltyCardStore

    @State private var card: LoyaltyCard

    init(card: LoyaltyCard) {
        _card = State(initialValue: card)
    }

    private var canSave: Bool {
        !card.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !card.barcodeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Card") {
                TextField("Store name", text: $card.storeName)
                    .textInputAutocapitalization(.words)
                TextField("Barcode value", text: $card.barcodeValue)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Barcode type", selection: $card.barcodeFormat) {
                    ForEach(BarcodeFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
            }

            Section("Optional") {
                TextField("Note", text: $card.note, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle(card.storeName.isEmpty ? "Add Card" : "Edit Card")
        .navigationBarTitleDisplayMode(.inline)
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
    }
}
