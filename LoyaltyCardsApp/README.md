# Minimalist iOS Loyalty Cards App

This folder contains a lightweight SwiftUI starter app for storing loyalty cards on iOS, inspired by apps such as StoCard and Supercards but scoped for a private, minimalist wallet.

## Product goals

- **Fast capture:** add a loyalty card with only a store name, barcode value, barcode format, and optional note.
- **Minimal UI:** one clean list, large barcode display, and no ads, feeds, coupons, or account sign-up.
- **Offline-first:** cards are stored locally in `UserDefaults` as JSON so the prototype has no server dependency.
- **Lightweight native stack:** SwiftUI, Foundation, CoreImage, and UIKit only.
- **Privacy-forward:** no analytics, no remote sync, and no network requests in the starter implementation.

## How to run

1. Open Xcode and create a new iOS App project named `LoyaltyCardsApp`.
2. Choose SwiftUI for the interface and Swift for the language.
3. Drag the `Sources/LoyaltyCardsApp` folder into the Xcode project.
4. Make sure the app target includes all imported files.
5. Build and run on iOS 17 or later.

## Current feature set

- Add, edit, delete, and view loyalty cards.
- Persist card data locally between launches.
- Render Code 128, PDF417, QR, and Aztec barcodes using CoreImage.
- Keep membership numbers copyable and readable when barcode scanning fails.

## Suggested next steps

- Add camera scanning with `VisionKit` or `AVFoundation` to avoid manual barcode entry.
- Add optional iCloud sync behind a setting.
- Add lock-screen widgets or App Shortcuts for favorite cards.
- Add an import/export JSON flow for backup without requiring an account.
