import XCTest
@testable import LoyaltyCardsApp

final class BarcodeImageFactoryTests: XCTestCase {
    func testSupportedFormatsRenderImages() {
        for format in BarcodeFormat.allCases {
            let image = BarcodeImageFactory.image(for: value(for: format), format: format)

            XCTAssertNotNil(image, "\(format.rawValue) should render an image")
            XCTAssertGreaterThan(image?.size.width ?? 0, 0)
            XCTAssertGreaterThan(image?.size.height ?? 0, 0)
        }
    }

    func testBarcodeRenderingTrimsInput() {
        let trimmedImage = BarcodeImageFactory.image(for: "1234567890", format: .code128)
        let paddedImage = BarcodeImageFactory.image(for: "  1234567890  \n", format: .code128)

        XCTAssertEqual(trimmedImage?.size, paddedImage?.size)
    }

    func testBarcodeRenderingReusesCachedImages() {
        let firstImage = BarcodeImageFactory.image(for: "9876543210", format: .code128)
        let secondImage = BarcodeImageFactory.image(for: "  9876543210\n", format: .code128)

        XCTAssertTrue(firstImage === secondImage)
    }

    func testBlankBarcodeValueDoesNotRenderImage() {
        for format in BarcodeFormat.allCases {
            XCTAssertNil(BarcodeImageFactory.image(for: "   \n", format: format))
        }
    }

    private func value(for format: BarcodeFormat) -> String {
        switch format {
        case .code128:
            return "1234567890"
        case .pdf417:
            return "PDF417-1234567890"
        case .qr:
            return "QR-1234567890"
        case .aztec:
            return "AZTEC-1234567890"
        }
    }
}
