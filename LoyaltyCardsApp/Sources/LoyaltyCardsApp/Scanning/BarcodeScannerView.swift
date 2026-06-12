import SwiftUI
import AVFoundation
import VisionKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    private static let supportedSymbologies = BarcodeFormat.allCases.map(\.visionSymbology)

    let onResult: (BarcodeScanResult) -> Void
    let onUnavailable: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, onUnavailable: onUnavailable)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Self.supportedSymbologies)],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard DataScannerViewController.isSupported else {
            context.coordinator.reportUnavailable("Barcode scanning is not supported on this device.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            context.coordinator.reportUnavailable("Camera access is disabled. You can enter the number manually or allow camera access in Settings.")
            return
        case .authorized, .notDetermined:
            break
        @unknown default:
            break
        }

        guard DataScannerViewController.isAvailable else {
            context.coordinator.reportUnavailable("Camera scanning is unavailable. You can still enter the number manually.")
            return
        }

        context.coordinator.startScanningIfNeeded(uiViewController)
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
        coordinator.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onResult: (BarcodeScanResult) -> Void
        private let onUnavailable: (String) -> Void
        private var hasScannedResult = false
        private var hasReportedUnavailable = false
        private var isScanning = false

        init(
            onResult: @escaping (BarcodeScanResult) -> Void,
            onUnavailable: @escaping (String) -> Void
        ) {
            self.onResult = onResult
            self.onUnavailable = onUnavailable
        }

        func startScanningIfNeeded(_ dataScanner: DataScannerViewController) {
            guard !isScanning, !hasScannedResult, !hasReportedUnavailable else { return }

            do {
                try dataScanner.startScanning()
                isScanning = true
            } catch {
                reportUnavailable("Camera scanning could not start. You can still enter the number manually.")
            }
        }

        func stopScanning() {
            isScanning = false
        }

        func reportUnavailable(_ message: String) {
            guard !hasReportedUnavailable else { return }

            hasReportedUnavailable = true
            isScanning = false
            onUnavailable(message)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasScannedResult else { return }

            for item in addedItems {
                guard case let .barcode(barcode) = item else { continue }
                guard let value = barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !value.isEmpty else {
                    continue
                }

                hasScannedResult = true
                let format = BarcodeFormat(visionSymbology: barcode.observation.symbology)
                dataScanner.stopScanning()
                stopScanning()
                onResult(BarcodeScanResult(value: value, format: format))
                return
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            reportUnavailable("Camera scanning became unavailable. You can still enter the number manually.")
        }
    }
}
