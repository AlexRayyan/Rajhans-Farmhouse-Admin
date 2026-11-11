# Rajhans Farmhouse Admin

Flutter + Firebase mobile admin for one exclusive farmhouse. **Android first; iOS-ready architecture. No Expo.**

## Current Phase 1 foundation
- Material 3 dark/light/system themes, responsive navigation
- Google sign-in integration (requires Firebase/OAuth client setup)
- Admin allowlist using `admins/{uid}` and Firestore rules
- Dashboard, month calendar, booking list/details, create-booking screen
- Firebase Firestore streams and loading/empty/error states
- Callable Cloud Function with atomic nightly locks (same-day turnover is allowed)
- Flutter CI checks and unconfigured APK build

**Not production ready:** customer directory, complete payment ledger, edit/cancel flow, reports, offline support, receipts, App Check, and device-tested signing are not finished.

## Local setup

1. Install Flutter SDK, Android Studio/SDK; verify using `flutter doctor`.
2. Clone this repo; run `flutter create --platforms=android,ios --project-name rajhans_farmhouse_admin .` to generate native host projects, then `flutter pub get`.
3. Create your Firebase project, enable Google authentication, create Firestore, and register the Android package with SHA-1/SHA-256. Configure the Google OAuth web client ID. Device Google sign-in requires the native Android configuration, not just Dart constants.
4. Copy `.dart_defines.example.json` to `.dart_defines.json`, and provide **public** Firebase client config values. Never commit a service account or signing key.
5. In the Firebase CLI, choose the correct project using `firebase use --add` then deploy `firebase deploy --only firestore,functions`. Cloud Functions may require a paid Firebase billing plan.
6. After signing in, create `admins/<YOUR_UID>` with `active: true` from the Firebase Console or trusted Admin SDK. Users cannot grant themselves admin access.
7. Run `flutter run --dart-define-from-file=.dart_defines.json`.

## Booking rules
- One farmhouse, exclusive occupancy per night.
- A check-out date does not occupy that night; bookings 12→13 and 13→14 can coexist.
- A Cloud Function checks all per-night lock documents in an atomic Firestore transaction.
- Clients cannot directly write booking documents or locks.
- Monetary values are stored as integer paise.

## Release notes and limitations
- `flutter build apk --release` requires Android host files and toolchain; CI is included but may require adjustments after its first run.
- The repository does not contain native Firebase config, keys, or release signing materials.
- Current booking calendar query is an initial MVP implementation; cross-month occupancy and pagination need refinement before production.
- Cancellation and payment history are not yet implemented. Do not use the starter as a live reservations ledger.
- For iOS later: macOS/Xcode, Apple signing, and iOS Google OAuth configuration are required.

See [docs/ROADMAP.md](docs/ROADMAP.md).