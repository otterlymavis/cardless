# Cardless iOS App

This folder contains Cardless, a lightweight SwiftUI loyalty-card wallet for iOS. It is inspired by the old simple Stocard-style flow, but scoped as a private, local-first utility.

## Product goals

- **Fast capture:** add a loyalty card manually or with on-device barcode scanning.
- **Minimal UI:** cute wallet list, recent cards, large barcode display, and no ads, feeds, coupons, or account sign-up.
- **Offline-first:** cards are stored locally in `UserDefaults` as JSON; brand presets include an offline baseline and optional remote additions.
- **Lightweight native stack:** SwiftUI, Foundation, CoreImage, and UIKit only.
- **Privacy-forward:** no analytics or remote sync; optional remote brand presets are fetched only from your configured JSON URL and cached locally.

## How to run

1. Install XcodeGen if needed: `brew install xcodegen`.
2. From this folder, run `xcodegen generate`.
3. Open `LoyaltyCardsApp.xcodeproj` in Xcode.
4. Build and run on iOS 17 or later.

## Current feature set

- Add, edit, delete, and view loyalty cards.
- Start new cards from built-in brand presets, plus optional remote additions cached on device.
- Mark frequent cards as favorites and keep them pinned to the top.
- Show recently used cards as direct checkout shortcuts.
- Customize card cover colors.
- Scan card barcodes on device with VisionKit from the add/edit flow.
- Persist card data locally between launches.
- Import and export local JSON backups without an account.
- Render Code 128, PDF417, QR, and Aztec barcodes using CoreImage.
- Show a full-screen checkout barcode with brightness boost and screen-awake behavior.
- Keep membership numbers copyable and readable when barcode scanning fails.

## Test

```bash
xcodegen generate
xcodebuild test -project LoyaltyCardsApp.xcodeproj -scheme LoyaltyCardsApp -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Remote Brand Presets

Cardless ships with a small built-in brand catalog so search works offline on a fresh install. To add or override presets, host a JSON file like `../docs/brand-presets.example.json`, then set `CardlessBrandPresetURL` in `Sources/LoyaltyCardsApp/Info.plist` or `project.yml` to that HTTPS URL. The app merges successful downloads with the built-in catalog, caches them in the app Caches directory, and skips refreshes for 24 hours.

## Manual acceptance checklist

- Add a card manually and save it.
- Add a card with camera scanning on a physical device.
- Favorite and unfavorite cards from the list and detail screen.
- Open a recent card and confirm it goes straight to full-screen barcode mode.
- Use full-screen barcode mode, close it, and confirm brightness restores.
- Copy a membership number from detail, list context menu, recent context menu, and full-screen mode.
- Export a backup, delete/import cards, and confirm data returns.
- Relaunch the app and confirm cards, favorites, colors, and recents persist.

## Suggested next steps

- Add optional iCloud sync behind a setting.
- Add lock-screen widgets or App Shortcuts for favorite cards.
- Add stronger import review for large backup files.
