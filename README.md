# Rajhans Farmhouse Admin

Android-first Flutter admin app using Firebase Spark, Google sign-in and an operator-managed administrator allowlist. iOS follows Android validation.

## Version 0.3.1

- Date pickers grey out booked nights and reject checkout ranges crossing a booked night. An adjacent checkout/check-in on the same date remains valid.
- Past India calendar dates are blocked for new bookings and rescheduling, in both the app and Firestore rules. Historical records remain readable and cancellable.
- Separate check-in/check-out dates support 1–31 nights at 11 AM Asia/Kolkata. Dates display as `Sunday, 29-Nov-2026`.
- Smooth guest wheel selects 2–100 guests. Android recent-call selection requests permission when used; contacts and manual entry remain available.
- Rounded amounts from ₹8,000 to ₹25,000 rank popular values from the latest 200 confirmed bookings, with defaults when history is limited.
- Light/dark/system theme choices persist. Navy/violet panels, animated status badges, filters and calendar selection follow the supplied design direction.
- Calendar cells show only the selected month's dates. Multi-day stays appear across occupied days and month boundaries.
- Booking details generate a local PDF booking bill, offer preview/general sharing and open WhatsApp or WhatsApp Business with the attachment. WhatsApp may require recipient selection and always requires the user to tap Send.

The booking form starts with customer name and keeps check-in/out cards side by side on small screens, as do booking details. Check-in/out cards reuse the same stacked weekday, large day number and month tile as upcoming stays, with the year and 11 AM shown below. Save opens the new booking's details automatically. Upcoming stays use a weekday/date tile.

Advance/fully-paid choices record cumulative payment in integer paise, validated between zero and the total; remaining balance updates live. Admin corrections use the existing audit/revision checks. These are administrator-recorded amounts, not bank-verified transactions. A separate payment/refund ledger and cash-flow accounting remain later work. Cancellation preserves recorded payments and does not imply a refund.

Booking codes use the India creation date: `RF121126`, then `RF121126-02`, etc. The shared availability transaction allocates a daily sequence. Server rules validate numbering and code immutability. New Firebase document IDs are `Customer Name - RF121126`; subsequent customer edits keep that stable document ID. Existing records were renamed atomically with lock references, retaining creation dates and data. A known duplicate was cancelled at the owner's instruction. The earlier operator migration's timezone-offset lock error was corrected using UTC timestamp parsing and checked against all active bookings.

PDF files are named `Rajhans - Customer Name - RF121126.pdf`. The report tab now has occupancy/weekly-night charts, recorded payments/outstanding balance, arrival/cancellation counts, averages and booking-source breakdowns. Payment metrics count bookings in their check-in month; occupancy also includes overlapping stays from another month.

## Spark backend

Project `rajhans-farmhouse-admin`, Firestore Standard in Mumbai. No Cloud Functions or paid backend dependency. Spark quotas apply; booking confirmation requires internet.

Transactions atomically update the booking and `/availability/state`. A canonical daily-slot list protects the full stay; rules validate complete coverage, prevent overwriting occupied slots, release old slots on reschedule/cancellation, and check creation audit and revisions. Existing booking documents are preserved when the operator seeds the initial availability map. Legacy single-day clients must update after migration.

The shared map is for this single farmhouse and bounded to 10,000 slots. Archive old locks through a reviewed operator procedure before that limit. Revisit for multiple properties or substantially higher traffic.

## Development and checks

Flutter 3.47.9, Android API 36, NDK 28.2.13676358. Node 22+ and Java 21+ for rules tests.

```sh
flutter pub get
flutter analyze
flutter test
npm ci
npx -y firebase-tools@latest emulators:exec --project demo-rajhans --only firestore "npm run test:rules"
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Thirteen Flutter tests and eighteen adversarial Firestore tests cover dates, guests, amount ranking, theme storage, form/calendar rendering, overlaps/concurrency, rescheduling/cancellation, validation and access control. GitHub Actions runs checks and compiles an ARM64 test APK.

Android call-log permission is restricted by installers and Google Play policy. Some devices refuse it; contacts/manual entry are supported. Review distribution eligibility before Play submission. Bulk call history stays on-device; only the selected caller is copied to a booking.

## Distribution and remaining work

Test APKs use debug signing. GitHub runners generate different certificates; register each APK's SHA-1/SHA-256 in Firebase before Google login. Different keys may require uninstalling an older test build once. Use stable protected production signing before store distribution. Never commit credentials, signing keys or customer exports.

Native call/contact/PDF/WhatsApp behavior and performance need physical-device validation. Payment/refund ledger, full customer directory, expenses, blocked dates, notifications, exports/backup, production signing and iOS setup remain. Reports distinguish booking value, recorded payment and remaining balance. See [the roadmap](docs/ROADMAP.md).

