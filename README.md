# Cardless

Cardless is a minimalist iOS loyalty-card wallet. It is built for one job: open the app, tap a saved store card, and show a bright barcode at checkout without accounts, coupons, feeds, or sync dependencies.

## App

The SwiftUI app lives in [`LoyaltyCardsApp`](LoyaltyCardsApp/README.md).

Core MVP features:

- Searchable list of locally saved loyalty cards.
- Add, edit, delete, and favorite card details.
- Built-in brand presets, with optional remote additions cached on device.
- Recent cards for fast checkout access.
- Custom card colors.
- Offline camera barcode scanning for faster card entry.
- High-contrast barcode detail screen and full-screen checkout barcode mode.
- Temporary brightness boost and screen-awake behavior while showing cards.
- Copyable membership number fallback.
- Local JSON import/export for account-free backup.
- Local JSON persistence in `UserDefaults`.
- CoreImage barcode rendering for Code 128, PDF417, QR Code, and Aztec.

## Run

```bash
cd LoyaltyCardsApp
xcodegen generate
open LoyaltyCardsApp.xcodeproj
```

Then build and run from Xcode on iOS 17 or later.

## Test

```bash
cd LoyaltyCardsApp
xcodebuild test -project LoyaltyCardsApp.xcodeproj -scheme LoyaltyCardsApp -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Scope

Cardless intentionally excludes accounts, coupons, feeds, issuer integrations, payment features, ads, analytics, card-data network sync, and unrelated workflows.
