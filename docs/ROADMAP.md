# Rajhans Farmhouse Admin — Roadmap

## Confirmed decisions
- Flutter / Dart. No Expo.
- Android first, shared iOS-ready Flutter code.
- Firebase Auth with Google sign-in; admin allowlist.
- Firestore storage; callable Cloud Functions for protected writes.
- One farmhouse booking at a time; night occupancy [check-in, check-out).
- Same-day turnover is allowed.
- Dark / light / system themes.

## Phase 1: core MVP
1. Foundation, login, themes, calendar and initial booking flow (in this PR).
2. Native Android/iOS Firebase configuration with owner's Firebase project.
3. Finish full bookings (edit/cancel and locked-night release), customers and payment ledger.
4. Add secure receipts, dashboard totals, clear offline/errors, and security/emulator tests.
5. Android release signing, device profiling and release APK/AAB.

## Phase 2
Expenses, reports, notifications, export, audit trails.

## Release blockers
The current scaffolding is **not production-ready**. In particular Google OAuth, Firestore/Functions deployment, all CRUD and payment operations, App Check, integration testing, and Android/iOS signing are not complete. CI must be verified before claiming a successful build. Never place credentials, guest information, or signing materials in GitHub.
