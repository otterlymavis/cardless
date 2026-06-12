import Foundation

struct BarcodeScanResult: Equatable {
    let value: String
    let format: BarcodeFormat?
}
