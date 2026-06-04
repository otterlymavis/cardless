# Minimalist loyalty cards app brief

## Positioning

Build a tiny iOS loyalty-card wallet for people who want the convenience of StoCard/Supercards-style barcode storage without coupons, promotions, accounts, or heavy navigation.

## Primary user story

As a shopper, I want to open the app, tap a store card, and show a bright barcode in under two seconds so checkout scanning is reliable.

## Non-goals

- No coupon marketplace.
- No loyalty-program discovery feed.
- No mandatory account system.
- No card issuer integrations in the first version.
- No server requirement for the MVP.

## MVP screens

1. **Cards list:** searchable list of saved cards with store name, barcode format, and last-updated date.
2. **Add/edit card:** compact form for store name, barcode value, barcode type, and optional note.
3. **Card detail:** high-contrast barcode, large membership number, copy button, brightness hint, and edit/delete actions.

## Data model

Each card needs only:

- Stable local identifier.
- Store name.
- Barcode value.
- Barcode symbology.
- Optional note.
- Creation and update timestamps.

## Architecture

- SwiftUI for views.
- `ObservableObject` store for state updates.
- JSON encoding in `UserDefaults` for a dependency-free prototype.
- CoreImage barcode filters for local barcode generation.

## Privacy stance

The MVP should not make network requests. All card data stays on device unless the user later enables an explicit backup or sync feature.
