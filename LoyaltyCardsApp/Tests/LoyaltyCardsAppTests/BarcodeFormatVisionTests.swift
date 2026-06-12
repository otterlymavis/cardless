import Vision
import XCTest
@testable import LoyaltyCardsApp

final class BarcodeFormatVisionTests: XCTestCase {
    func testBarcodeFormatsMapToVisionSymbologies() {
        XCTAssertEqual(BarcodeFormat.code128.visionSymbology, .code128)
        XCTAssertEqual(BarcodeFormat.pdf417.visionSymbology, .pdf417)
        XCTAssertEqual(BarcodeFormat.qr.visionSymbology, .qr)
        XCTAssertEqual(BarcodeFormat.aztec.visionSymbology, .aztec)
    }

    func testVisionSymbologiesMapToBarcodeFormats() {
        XCTAssertEqual(BarcodeFormat(visionSymbology: .code128), .code128)
        XCTAssertEqual(BarcodeFormat(visionSymbology: .pdf417), .pdf417)
        XCTAssertEqual(BarcodeFormat(visionSymbology: .qr), .qr)
        XCTAssertEqual(BarcodeFormat(visionSymbology: .aztec), .aztec)
    }

    func testUnsupportedVisionSymbologyReturnsNil() {
        XCTAssertNil(BarcodeFormat(visionSymbology: .ean13))
    }
}
