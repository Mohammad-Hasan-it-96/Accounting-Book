# Release Checklist — دفتر حسابات (Accounting Book)

Complete every item before publishing a release. Check the box only after the
step passes on the exact build you intend to ship. Record the version/build
number and the date at the top of each run.

- **Version:** `_______`  (pubspec `version:` — bump before building)
- **Build number:** `_______`
- **Date:** `_______`
- **Tester:** `_______`

---

## 1. Static Checks & Build

### Release Signing (one-time setup)
Full walkthrough: [`docs/RELEASE_SIGNING.md`](docs/RELEASE_SIGNING.md). Do this
once; the release build **refuses to sign** until it's in place (resolves C1).
- [ ] Upload keystore generated **outside** the repo (`keytool -genkeypair … -storetype PKCS12`).
- [ ] `android/key.properties` created with `keyAlias` / `keyPassword` /
      `storeFile` (forward-slash path) / `storePassword`.
- [ ] `git status` shows **neither** the keystore nor `key.properties` (both gitignored).
- [ ] Keystore file **and** its passwords backed up in ≥2 secure places (losing
      them = can't update the listing).
- [ ] Negative test: temporarily removing `key.properties` makes a *release*
      build fail with the "التوقيع للإصدار غير مُهيّأ" error (then restore it).

### Flutter Analyze
- [ ] `flutter pub get` completes with no errors.
- [ ] `flutter analyze` reports **no errors** (warnings reviewed and accepted).
- [ ] No leftover `print`/debug logging in shipping code paths.

### Flutter Test
- [ ] `flutter test` — all tests pass.
- [ ] New/changed behavior since last release has test coverage (or is noted).

### APK Build
Build the shipping artifact **with the Sentry DSN** so remote crash reporting is
active (omit the flag only for a deliberately no-telemetry build):
```
flutter build appbundle --release --dart-define=SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project>
# or, for a direct APK:
flutter build apk --release --dart-define=SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project>
```
- [ ] `flutter build apk --release` succeeds.
- [ ] (If shipping to Play) `flutter build appbundle --release` succeeds.
- [ ] APK/AAB is signed with the **release** keystore (not debug) — verify via
      `keytool -printcert -jarfile <artifact>`.
- [ ] `version`/`versionCode` in the built artifact match this checklist header.
- [ ] APK installs on a clean device without errors.
- [ ] App launches past `SplashScreen` without a crash.

### Crash Reporting (Sentry)
- [ ] Build passed `--dart-define=SENTRY_DSN=…` (the DSN is **not** committed;
      supply it at build time / from a CI secret). See `CrashService`.
- [ ] DSN copied from Sentry → Project Settings → Client Keys, pointing at the
      correct project/environment.
- [ ] Smoke-test: trigger a test error on the built app and confirm it appears in
      the Sentry dashboard (then confirm normal runs report **no** noise).
- [ ] With **no** DSN, the app still runs and logs locally to `crash_log.txt`
      (no remote send) — i.e. the DSN is truly optional.

---

## 2. Core Data Safety

### Database Backup
- [ ] Manual export produces a backup file at the expected location.
- [ ] Exported file opens / is non-empty and contains recent data.
- [ ] Auto-backup on import/export runs (see `DatabaseHelper`).
- [ ] Background daily backup (`BackupSchedulerService` / WorkManager task
      `com.daftar.auto_backup`) is registered when enabled in Settings.
- [ ] Toggling auto-backup off unregisters the periodic task.

### Database Restore
- [ ] Importing a previously exported backup restores customers, transactions,
      currencies, and groups intact.
- [ ] Restore over an existing DB behaves as designed (no silent data loss;
      pre-import auto-backup is created).
- [ ] Balances and `inFlag` (1 = مطلوب / -1 = مدفوع) are correct after restore.
- [ ] Multi-currency data (محلي / دولار) survives the round-trip.
- [ ] Restoring a backup from the **previous app version** works (schema
      migration / legacy column handling).

---

## 3. Licensing & Distribution

### Activation
- [ ] Fresh install shows `ActivationScreen` when not activated.
- [ ] Activation against the configured remote API succeeds and stores status
      in `shared_preferences`.
- [ ] Activated state persists across app restarts (no re-activation prompt).
- [ ] Device-ID hashing behaves correctly on real hardware.
- [ ] Graceful handling when the activation API is unreachable / offline.
- [ ] Custom activation API URL from Settings is respected.

### Updates
- [ ] `UpdateService` correctly detects when a newer version is available.
- [ ] `UpdateDialog` appears with correct version info and download link.
- [ ] No false "update available" when already on latest.
- [ ] Update flow degrades gracefully when the update endpoint is unreachable.

---

## 4. Features & Output

### PDF Export
- [ ] Account statement PDF generates via `PdfService` (share + print).
- [ ] Arabic text renders correctly (shaping, no tofu/boxes).
- [ ] RTL layout and column alignment are correct in the PDF.
- [ ] Numbers, dates, and currency totals match the on-screen statement.
- [ ] Share and print both work on a real device.

---

## 5. UI / Presentation

### Dark Mode
- [ ] All screens render correctly in dark mode (no unreadable text).
- [ ] Semantic colors (income/expense, cards) use `AppColors` tokens, not
      hardcoded hex.
- [ ] Toggling theme at runtime updates the whole app.
- [ ] Dialogs, snackbars, empty/error states are legible in both themes.

### RTL
- [ ] All screens lay out right-to-left correctly.
- [ ] Icons/chevrons with direction point the correct way.
- [ ] Text alignment and input fields behave in RTL.
- [ ] `textScaler` cap (1.3) holds — no layout breakage at large system font.
- [ ] Date picker opens without the `_ClampedTextScaler` assertion crash.

---

## 6. Device / OS Matrix

Test the release APK on each API level. Record device/emulator used.

| OS | API | Device | Launch | Backup/Restore | PDF | Activation | Notes |
|----|-----|--------|:------:|:--------------:|:---:|:----------:|-------|
| Android 10 | 29 | | [ ] | [ ] | [ ] | [ ] | |
| Android 11 | 30 | | [ ] | [ ] | [ ] | [ ] | |
| Android 12 | 31/32 | | [ ] | [ ] | [ ] | [ ] | |
| Android 13 | 33 | | [ ] | [ ] | [ ] | [ ] | |
| Android 14 | 34 | | [ ] | [ ] | [ ] | [ ] | |
| Android 15 | 35 | | [ ] | [ ] | [ ] | [ ] | |

Per-OS attention points:
- [ ] **Android 10** — scoped storage: backup export/import file access works.
- [ ] **Android 11** — storage permission model; WorkManager background backup.
- [ ] **Android 12** — splash screen API, exact-alarm/background restrictions.
- [ ] **Android 13** — runtime notification permission (if any notifications).
- [ ] **Android 14** — foreground service / background work restrictions.
- [ ] **Android 15** — edge-to-edge enforcement; no clipped/overlapping UI.

---

## 7. Install Scenarios

### Large Database Test
- [ ] App remains responsive with a large dataset (many customers +
      thousands of transactions).
- [ ] Home screen and customer lists scroll smoothly.
- [ ] Statement generation and PDF export complete in reasonable time.
- [ ] Backup/restore of a large DB completes without OOM or ANR.
- [ ] Search/filter performance is acceptable.

### Fresh Install Test
- [ ] Clean install on a device that never had the app.
- [ ] First launch → Splash → Activation → Home flow works.
- [ ] Empty states render correctly (no customers/transactions yet).
- [ ] Creating first customer, currency, and transaction works.
- [ ] App lock / PIN setup (if enabled) works from scratch.

### Upgrade Test
- [ ] Install **previous** released version, add data, then install this build
      over it (no uninstall).
- [ ] Existing data (customers, transactions, currencies, groups) is preserved.
- [ ] DB schema migration / legacy column handling runs without data loss.
- [ ] Settings (activation, PIN, auto-backup flag, API URLs) are retained.
- [ ] No forced re-activation after upgrade.

---

## 8. Play Store Submission

### Build & Signing
- [ ] Shipping an **App Bundle** (`flutter build appbundle --release`), not APK.
- [ ] `versionCode` is higher than the currently published release.
- [ ] Signed by Play App Signing (upload key matches the enrolled key).
- [ ] `applicationId` matches the existing Play listing.
- [ ] ProGuard/R8 shrinking (if enabled) doesn't break WorkManager, sqflite,
      or the PDF/printing packages — verified on the release build.

### Store Listing
- [ ] App title, short description, and full description (Arabic) up to date.
- [ ] Screenshots current (phone + tablet if declared), RTL/Arabic UI shown.
- [ ] Feature graphic and app icon match the shipped build.
- [ ] What's-new / release notes filled in for this version (Arabic).
- [ ] Default language and additional locales correct.

### Policy & Compliance
- [ ] Data safety form matches actual behavior — declare device-ID collection
      (activation), any network calls (activation/update API), and local data.
- [ ] Privacy policy URL is live and accurate.
- [ ] Permissions justified (storage for backup/restore, internet, biometric,
      notifications if used); no unused permissions in the manifest.
- [ ] `targetSdkVersion` meets Play's current minimum requirement.
- [ ] Content rating questionnaire completed.
- [ ] App category and contact details correct.

### Release Rollout
- [ ] Upload to **internal testing** track first; smoke-test the installed build.
- [ ] Staged/percentage rollout configured (start small, e.g. 10–20%).
- [ ] Correct track selected (production vs. testing) before submitting.
- [ ] Pre-launch report reviewed (no new crashes on Google's test devices).
- [ ] Sentry dashboard watched during rollout for new crash groups (if a DSN was
      shipped); triage before widening the staged rollout.
- [ ] Rollback / halt-rollout plan noted in case of post-release crashes.

---

## 9. iOS App Store Submission

> Only applicable if an iOS build is shipped. Note: background auto-backup
> relies on WorkManager (Android-only) — verify the backup story on iOS
> (foreground/manual export) before declaring iOS support.

### Build & Signing
- [ ] `flutter build ipa --release` succeeds.
- [ ] Signed with a valid **Distribution** certificate and App Store
      provisioning profile.
- [ ] `CFBundleShortVersionString` and `CFBundleVersion` (build) bumped above
      the last submitted build.
- [ ] Bundle identifier matches the App Store Connect record.
- [ ] Deployment target meets the current App Store minimum.
- [ ] Builds against the latest required Xcode / iOS SDK.

### Device Testing (iOS)
- [ ] Launches past `SplashScreen` on a real iPhone (not just simulator).
- [ ] RTL / Arabic layout renders correctly.
- [ ] Backup **export** and **import** work with the iOS Files/share sheet.
- [ ] PDF export share + print work via the iOS share sheet.
- [ ] Activation and update flows work.
- [ ] Biometric unlock (Face ID / Touch ID) works; `NSFaceIDUsageDescription`
      is present in `Info.plist`.
- [ ] Dark mode renders correctly.
- [ ] Tested on latest iOS and one prior major version.

### Store Listing (App Store Connect)
- [ ] App name, subtitle, and description (Arabic) up to date.
- [ ] Screenshots for each required device size, showing RTL/Arabic UI.
- [ ] Keywords, support URL, and marketing URL set.
- [ ] What's-new / release notes filled in for this version (Arabic).
- [ ] Primary language and category correct.

### Policy & Compliance
- [ ] App Privacy ("nutrition label") matches actual behavior — declare
      device-ID collection (activation) and network calls (activation/update).
- [ ] Privacy policy URL is live and accurate.
- [ ] Encryption / export compliance (`ITSAppUsesNonExemptEncryption`) declared.
- [ ] Usage-description strings present for any accessed capability
      (Face ID, files, etc.); no unused entitlements.
- [ ] Age rating questionnaire completed.
- [ ] Demo/activation instructions provided in App Review notes so the
      reviewer can get past the activation gate.

### Release Rollout
- [ ] Uploaded to **TestFlight** first; smoke-test the installed build.
- [ ] Correct build selected for App Store review.
- [ ] Phased release enabled (7-day automatic rollout).
- [ ] "Release manually / automatically after approval" set as intended.
- [ ] Rollback plan noted (remove from sale / expedited fix) for post-release
      crashes.

---

## 10. Sign-off

- [ ] Release notes / changelog updated.
- [ ] Git tag created for this version.
- [ ] All above sections complete; no open blockers.

**Approved by:** `_______`  **Date:** `_______`
