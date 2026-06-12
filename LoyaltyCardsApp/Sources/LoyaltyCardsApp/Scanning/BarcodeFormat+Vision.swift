import Vision

extension BarcodeFormat {
    var visionSymbology: VNBarcodeSymbology {
        switch self {
        case .code128:
            return .code128
        case .pdf417:
            return .pdf417
        case .qr:
            return .qr
        case .aztec:
            return .aztec
        }
    }

    init?(visionSymbology: VNBarcodeSymbology) {
        switch visionSymbology {
        case .code128:
            self = .code128
        case .pdf417:
            self = .pdf417
        case .qr:
            self = .qr
        case .aztec:
            self = .aztec
        default:
            return nil
        }
    }
}
