# Rajhans Farmhouse roadmap

## Confirmed choices

Flutter; Android first, iOS later. Firebase Spark only, Google authentication, Firestore Standard in Mumbai. One property; 1–31 nights, 11 AM check-in/out Asia/Kolkata. Adjacent bookings meet at checkout. Amounts stored in integer paise, separate from payments received.

## Implemented through 0.2.0

Login/admin gate; booking dashboard; current-month calendar; multi-day create/edit/cancel with atomic overlap protection; 2–100 guest wheel; readable dates and past-date guards; history-ranked amounts; Android recent calls/contacts; persistent themes; animated status/details and list filters; PDF booking bill with preview/sharing/WhatsApp handoff. Nine Flutter and fifteen rules tests; Android CI.

## Next Android milestones

1. Physical-device checks for calls, contacts, theme restart, multi-day bookings and PDF/WhatsApp. Profile startup, scrolling, memory and network use.
2. Append-only payment/refund ledger with validated balances. Only then label documents as payment receipts or report collected revenue.
3. Full customer directory, blocked dates, expenses, financial reports, exports and recovery/backup policy.
4. Stable protected signing key, Firebase certificate, distribution/architecture choices, store permission review and APK/AAB validation.

## iOS and operations

Native Firebase registration, macOS/Xcode, Apple signing and device testing follow Android acceptance. Android device bridge needs iOS equivalents for settings, contacts and PDF sharing. iOS does not expose call history to third-party apps; use contacts/manual entry.

On Spark, reminders can use local notifications or user-initiated messaging. Automatic server scheduling requires a different plan. No billing upgrade performed.

Automated checks do not establish device performance, automatic WhatsApp delivery or production readiness.
