import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

enum BarcodeImageFactory {
    private static let context = CIContext()
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 32
        cache.totalCostLimit = 4 * 1_024 * 1_024
        return cache
    }()

    static func image(for value: String, format: BarcodeFormat) -> UIImage? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        let cacheKey = "\(format.rawValue):\(trimmedValue)" as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        let data = Data(trimmedValue.utf8)
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
        guard let cgImage = Self.context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: cacheKey, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
