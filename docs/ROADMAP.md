# Rajhans Farmhouse roadmap

## Confirmed

- Flutter/Dart; Android first, iOS after Android validation.
- Firebase Spark only: Google authentication, Firestore Standard in Mumbai.
- No Cloud Functions or paid backend service in this plan.
- One exclusive 24-hour slot: 11 AM check-in, 11 AM checkout the following day in Asia/Kolkata.
- Adjacent bookings meet at checkout; any future cleaning buffer requires an explicit rule change.
- Integer paise; booking value is distinct from payments received.

## Foundation

Native Android configuration, Google auth/admin gate, month calendar and dashboard, atomic create/edit/cancel operations, slot locking and server-enforced rules. Core rules have thirteen emulator tests. Flutter startup/date/money tests are included.

## Remaining Android MVP

1. Test Google login, access control and booking flows on a physical device.
2. Finish the supplied visual design, customer directory, search/filter and persistent settings.
3. Add an append-only payment/refund ledger with atomic balance validation, receipts and trustworthy collected/outstanding totals. Current bookings have zero collected payments.
4. Add blocked-date operations, exports and recovery/backup policy.
5. Profile startup, calendar scrolling, memory and network usage; measure release download size, configure production signing and validate APK/AAB.

## Operations and iOS

Expenses and monthly/yearly reports follow the core ledger. On Spark, reminders can be local-device notifications or user-initiated WhatsApp/SMS handoffs; automatic server scheduling is outside this plan. iOS needs native Firebase registration/configuration, macOS/Xcode, Apple signing and device testing.

## Validation limits

Passing emulator and unit tests does not replace real-device or release validation. No no-lag, binary-size or production-readiness claim is made without measurements. No billing upgrade has been performed.

