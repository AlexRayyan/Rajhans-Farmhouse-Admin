# Rajhans Farmhouse Admin

Android-first Flutter app for one exclusive farmhouse. Shared Dart code is intended for iOS later.

## Backend: Firebase Spark

Project: `rajhans-farmhouse-admin`. Firestore Standard: `(default)`, Mumbai (`asia-south1`). Google sign-in and an operator-managed `admins/{uid}` allowlist restrict access.

This version uses **Firestore client transactions and server-enforced Security Rules**, with no Cloud Functions, Cloud Storage or paid backend dependency. Spark quotas still apply. Availability confirmation requires an internet connection.

Each booking occupies exactly **11 AM to 11 AM the next day, Asia/Kolkata**. Timestamps are stored in UTC; one canonical availability document identifies each 24-hour slot. Creation and rescheduling atomically reserve the slot. Cancellation retains the booking and releases its slot in the same transaction. Rules reject orphan locks, double bookings, forged audit data, invalid amounts and client privilege changes.

Money is stored as integer paise. This foundation stores zero collected payments; the append-only payment/refund ledger is a later milestone. Do not use this build as a payment ledger.

## Implemented foundation

- Native Android host, application ID `com.rajhansfarmhouse.admin`, Firebase client configuration and Google sign-in integration.
- Administrator gate, dashboard booking count/value, month calendar, create/edit/cancel bookings and booking details/list.
- Dark/light/system appearances; weekend tint/border; fixed 24-hour booking date picker.
- Separate repository for Firestore operations, transaction-based slot protection, immutable creation audit fields and revision checks in rules.
- Three Flutter tests and thirteen adversarial Firestore emulator tests, including simultaneous competing reservations.
- GitHub Actions for static analysis, tests, security rules and Android compilation.

## Development

Use Flutter **3.47.9**, an Android SDK supporting API 36, NDK 28.2.13676358, and a compatible JDK. The Firestore emulator requires Java 21+. Install Node 22+ for rule tests.

```sh
flutter pub get
flutter analyze
flutter test
npm ci
npx -y firebase-tools@latest emulators:exec --project demo-rajhans --only firestore "npm run test:rules"
flutter run
```

The Android `google-services.json` is public Firebase client configuration, not an administrative credential. Never commit OAuth refresh tokens, service accounts, customer exports or signing keys. Debug certificates for this development machine are registered. A CI-generated APK uses a different certificate and is a compilation check, not a configured Google-login distribution build.

For additional development machines, register their debug SHA-1/SHA-256 and fetch current native configuration through the Firebase CLI. Only a trusted project operator may create or revoke `admins/{uid}` entries; signed-in users cannot grant themselves access.

Deploy approved rules and auth configuration with:

```sh
npx -y firebase-tools@latest deploy --project rajhans-farmhouse-admin --only firestore,auth
```

## Release status

This is an in-progress foundation. Payment history/receipts, customer directory, complete search/filter, blocked dates, reports/expenses, persistent settings and notifications remain. Physical-device login/booking checks and profiling are still required. Release builds currently use debug signing for testing; store distribution requires a dedicated signing key and its registered Firebase certificate. iOS native setup, Apple signing and device testing are deferred.

See [the roadmap](docs/ROADMAP.md).

