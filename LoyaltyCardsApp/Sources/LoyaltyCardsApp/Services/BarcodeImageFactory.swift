import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum BarcodeImageFactory {
    static func image(for value: String, format: BarcodeFormat) -> UIImage? {
        let context = CIContext()
        let data = Data(value.utf8)
        let filter: CIFilter

        switch format {
        case .code128:
            let code128 = CIFilter.code128BarcodeGenerator()
            code128.message = data
            code128.quietSpace = 16
            filter = code128
        case .pdf417:
            let pdf417 = CIFilter.pdf417BarcodeGenerator()
            pdf417.message = data
            filter = pdf417
        case .qr:
            let qr = CIFilter.qrCodeGenerator()
            qr.message = data
            qr.correctionLevel = "M"
            filter = qr
        case .aztec:
            let aztec = CIFilter.aztecCodeGenerator()
            aztec.message = data
            filter = aztec
        }

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
