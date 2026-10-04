# EatSoon — Food Expiry Tracker

Never let good food go to waste. EatSoon tracks what's in your fridge and
tells you what to eat first, with a reminder before it expires.

- Bundle ID: `com.boxill.eatsoon`
- Platform: iOS only, 15.0+
- No accounts, no backend. Everything is stored on-device.

## What it does

- **Food list** — name, category (dairy, meat, produce, bakery, frozen,
  other), expiry date. Stored as JSON in SharedPreferences.
- **"Eat first" hero card** — the single most urgent item with a one-tap
  "Used up" action.
- **Urgency-sorted list** — expired first, then fewest days left.
  Color coding: red = expired or ≤ 2 days left, amber = 3–5 days,
  green = 6+ days.
- **Add / edit sheet** — name validation, category chips, date picker
  (defaults to +7 days). "Used up" removes an item with an Undo snackbar.
  Swipe-to-delete on rows, also with Undo.
- **Onboarding** — 3 pages (problem → how it works → reminders), then
  the paywall, then the app. Shown once.
- **Paywall (EatSoon Pro)** — custom UI wired to RevenueCat
  (entitlement `pro`, offering `default`): Monthly $2.99 (3-day trial) /
  Yearly $19.99 (7-day trial, "Best value"). Restore purchases, close
  button falls back to the free tier.

## Free vs Pro

| | Free | Pro |
|---|---|---|
| Tracked items | up to 5 | unlimited |
| Reminder timing | fixed 2 days before, 9am | adjustable 1 / 2 / 3 days (Settings) |

## Notifications

- Local notifications only (`flutter_local_notifications` + `timezone`);
  no push server, no APNs certificate needed.
- Each item gets one notification at **9:00am local time**,
  `leadDays` before its expiry: *"Eat soon: Milk — Expires in 2 days —
  use it up!"*
- Scheduling is pure date math in `lib/logic/expiry_logic.dart`
  (`reminderDateFor`); the service layer only talks to the OS plugin.
  Past moments are never scheduled. Deleting an item cancels its
  notification; changing the lead time reschedules everything.
- Permission is requested contextually on onboarding page 3
  ("Enable reminders"), not on cold launch.

## Tests

41 tests, all passing (`flutter test`):

- `test/expiry_logic_test.dart` — day-difference math, urgency
  classification boundaries (expired / 0–2 / 3–5 / 6+), label strings,
  sort order + alphabetical tiebreak, reminder scheduling (lead times
  1/2/3, past moments → null, month boundaries, exact-now → null),
  notification id stability.
- `test/food_item_test.dart` — JSON round-trip, unknown-category
  fallback, name validation (empty / too long / ok).
- `test/state_test.dart` — free-tier 5-item cap, Pro unlimited,
  remove + undo, update persistence, lead-time persistence.
- `test/widget_test.dart` — onboarding 3-page flow + Skip, paywall
  renders both plans / yearly marked best value / purchase completes /
  close dismisses, home empty state, add-item flow, hero urgency labels,
  used-up + undo, empty-name rejection.

`flutter analyze`: zero issues.

## Manual QA checklist for TestFlight

1. Fresh install → onboarding pages swipe, Skip works, "Get started"
   lands on the paywall.
2. Paywall: both plans load with StoreKit prices, yearly pre-selected,
   purchase with a sandbox account → Pro, close → free tier.
3. Add 6 items on free → 6th triggers the paywall; upgrade → add
   unlimited.
4. Add an item expiring in 3 days → notification arrives at 9:00am
   two days before (set the device clock forward to verify).
5. Settings → change lead time to 1 day (Pro) → notification
   reschedules to 1 day before.
6. Delete an item → no notification fires for it afterwards.
7. Deny notification permission → app still works, no crashes.
8. Background the app overnight → badge/counts correct next launch,
   expired items show "Expired N days ago" in red.
9. Restore purchases on a second device with the same Apple ID.

## Stubbed / needs the release pipeline

- `AppConfig.termsUrl` / `privacyUrl` are placeholders
  (`example.com`) — replace with real hosted pages before submission.
- RevenueCat products (`com.boxill.eatsoon.pro.monthly` /
  `.pro.yearly`) must exist in App Store Connect and be linked in the
  RevenueCat dashboard; the app reads prices/trials from the offering.
- App icon (all sizes), launch screen, and onboarding art are in the
  repo. App Store screenshots still to be captured from the simulator.
