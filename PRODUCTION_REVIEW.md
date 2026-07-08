# Production Review — دفتر حسابات (Accounting Book)

**Review type:** Final pre-publication review for Google Play
**Reviewer role:** Senior Flutter Engineer
**Date:** 2026-07-02
**Branch:** `design/unify-design-tokens`
**Scope:** Full project — release config, architecture, performance, memory, offline,
backup/restore, activation, security, SQLite, localization, dark mode, large-DB,
Android lifecycle, error handling, maintainability.

> No code was modified. This document is observations and recommendations only.
> Findings are grouped by severity. Each includes **Description**, **Impact**, and **Recommendation**,
> with `file:line` references.

---

## Executive Summary

The codebase is **well-architected and unusually clean** for a v1: a disciplined design-token
system, standardized shared widgets (dialogs/snackbars/loading/empty/error states), repository
pattern over a SQLite singleton, SQL-side balance aggregation (no N+1), lazy `ListView.builder`
lists, consistent `if (!mounted)` guards, and thoughtful `textScaler` clamping. `flutter analyze`
is clean.

However, it is **not ready to publish as-is.** There are **2 Critical** blockers (debug-signed
release, and LTR breakage on non-Arabic devices) and several **High** items around
backup/restore data-safety, crash visibility, and data-at-rest exposure that should be fixed
before a finance app reaches a global audience.

| Severity | Count | Headline items |
|----------|-------|----------------|
| 🔴 Critical | 2 | Debug-signed release (Play blocker); LTR layout on non-Arabic locale |
| 🟠 High | 6 | Import overwrite w/o rollback; inconsistent backups; `allowBackup=true`; no crash reporting; unguarded save/delete freezes form; remote API-URL override |
| 🟡 Medium | 8 | Recents exposure; wall-clock auto-lock; no pagination; missing composite index; per-keystroke work; overflow risks; no ProGuard rules; silent group-edit failures |
| 🟢 Low | 15 | PIN length edge case; lock stacking; dark-mode contrast; undisposed dialog controllers; filtered running balance; misc hardening & polish |

**Recommended release gate:** fix all Critical + High before the first production upload;
schedule Medium for the first patch; Low as backlog.

---

## 🔴 Critical

### C1 — Release build falls back to **debug signing** (Play upload blocker)
- **Description:** `android/app/build.gradle.kts:51-55` selects the release signing config only if
  `key.properties` exists, otherwise it uses the **debug** keystore. No `key.properties` and no
  `.jks`/`.keystore` exist in the repo. `android/local.properties:3` also has `flutter.buildMode=debug`.
- **Impact:** `flutter build appbundle --release` produces a **debug-signed** artifact. Google Play
  rejects debug-signed uploads. If it ever shipped, you'd be permanently locked out of updates
  without the original signing key.
- **Recommendation:** Generate an upload keystore; create `android/key.properties`
  (`storeFile`/`storePassword`/`keyAlias`/`keyPassword`), keep it and the `.jks` **out of VCS**.
  Verify with `apksigner verify --print-certs`. Make the build **fail loudly** when `key.properties`
  is missing rather than silently signing with debug. Enroll in Play App Signing.

### C2 — Non-Arabic devices render the app **LTR** (mirrored, broken layout)
- **Description:** `lib/app.dart:74` sets `supportedLocales: [Locale('ar'), Locale('en')]` but never
  sets `locale:` or a `localeResolutionCallback`. All UI strings are hardcoded Arabic. On an
  Arabic device it resolves to `ar` (RTL, correct); on any other device it resolves to `en` → the
  entire app renders **LTR** with Arabic text. Directional affordances then point the wrong way
  (e.g. `Icons.chevron_left` in `settings_screen.dart:446,467,540,548,554,639,648,675`,
  `home_screen.dart:794`; `Icons.arrow_back` in `customer_details_screen.dart:354`).
- **Impact:** On the global Play Store, **every user whose device isn't set to Arabic** gets a
  mirrored, visually-broken layout. This is highly visible and will drive 1-star reviews / rejections.
- **Recommendation:** Pin the app to Arabic: `locale: const Locale('ar')` on `MaterialApp`, and
  drop `Locale('en')` from `supportedLocales` (or wrap the app in `Directionality(textDirection: rtl)`).

---

## 🟠 High

### H1 — Import overwrites the live DB **before** app-schema validation, with no atomic rollback
- **Description:** In `home_screen.dart:114-130` the flow is: `autoBackup()` → **copy imported file
  over the live DB** (`importDatabase`, `database_helper.dart:106-126`, `sourceFile.copy(targetPath)`
  at line 118) → **then** `validateTables()` at `home_screen.dart:123`. The SQLite `integrity_check`
  runs before overwrite (good), but the *app-schema* check runs after the real DB is already replaced.
  If `sourceFile.copy` throws mid-write, `_db` is null and the on-disk DB is left partially written /
  corrupt (`database_helper.dart:106-126`).
- **Impact:** Importing a file that is a valid SQLite DB but not this app's schema (or a partial copy
  on I/O error) leaves the user's real ledger destroyed. A pre-import `autoBackup` exists, but
  recovery is **manual** and undiscoverable to a typical user — effectively data loss for a finance app.
- **Recommendation:** Validate the app schema against the **source** (open read-only) *before*
  overwriting; copy to a temp path then **atomic-rename**; on any failure, **auto-restore** the
  pre-import backup and surface a clear message.

### H2 — Backups copy the **live** DB file (no checkpoint) and a background isolate opens the same DB
- **Description:** `exportDatabase`/`autoBackup` do a raw `File(sourcePath).copy(...)` while `_db` is
  open (`database_helper.dart:144-158,161-168`). If SQLite is in WAL mode the `-wal`/`-shm` sidecars
  aren't copied, so the backup can miss committed data or be inconsistent. Worse, WorkManager's
  `callbackDispatcher` (`backup_scheduler_service.dart:36-48`) runs in a **separate isolate**,
  constructs its own `DatabaseHelper` singleton, and opens its own connection to the same file —
  potentially while the UI isolate is writing.
- **Impact:** Corrupt/incomplete auto-backups and `SQLITE_BUSY`/"database is locked" errors (silently
  swallowed at `backup_scheduler_service.dart:44`). The user's safety net may be unusable exactly
  when needed. Critical-adjacent for a financial app.
- **Recommendation:** Use SQLite online backup / `VACUUM INTO 'target'`, or checkpoint (`PRAGMA
  wal_checkpoint(TRUNCATE)`) + copy the sidecars, or `closeDb()` before copying. Ensure the
  background isolate opens read-only / freshly opens-and-closes and does not race the UI writer.

### H3 — `android:allowBackup` defaults to **true** → finance DB extractable
- **Description:** `AndroidManifest.xml` (application element, line 5) does not declare
  `android:allowBackup`, so it defaults to `true`.
- **Impact:** The SQLite DB (customer names, phone numbers, debts) can be extracted via `adb backup`
  or auto-uploaded to Google cloud backup — bypassing the in-app PIN lock. Real data-at-rest leak
  for a finance app.
- **Recommendation:** Set `android:allowBackup="false"` (and/or a `dataExtractionRules` /
  `fullBackupContent` that excludes the DB).

### H4 — No crash reporting in production (stub) → zero release error visibility
- **Description:** `CrashService` is a no-op stub that only `debugPrint`s under `kDebugMode`
  (`crash_service.dart:10-18`). Sentry is commented out in `pubspec.yaml:56`. `main.dart` wires
  `FlutterError.onError` and `runZonedGuarded` to it (`main.dart:13,28`), but in release all caught
  errors are silently discarded.
- **Impact:** After launch you'll have **no telemetry** on crashes/ANRs — you can't detect or triage
  the very issues in this report if they slip through.
- **Recommendation:** Wire a real reporter (Sentry/Crashlytics) with a DSN before launch; verify a
  test crash is captured from a release build.

### H5 — Save/delete DB writes are unguarded → frozen form + silent failure
- **Description:** `add_edit_transaction_screen.dart` `_save()` sets `_saving=true` (line 148) then
  `repo.insert/update` (167-171) with **no try/catch**; same for `_deleteTransaction()` (194-196).
  `add_edit_customer_screen.dart` `_save()` insert/update (164,170) is likewise unguarded (only its
  *delete* path is wrapped). `customer_details_screen.dart` `_settleBalance()` insert (196) is also
  unguarded.
- **Impact:** Any write failure (locked DB, disk full, constraint) escapes to the zone handler; the
  screen never pops, `_saving` stays `true`, and the primary button is permanently disabled with a
  spinner (`onPressed: _saving ? null : _save`, transaction:367 / customer:353). The form hard-locks
  with no error and no recovery.
- **Recommendation:** Wrap writes in try/catch; on error `setState(() => _saving = false)` +
  `AppSnackBar.error(...)`, mirroring the existing delete-customer handler.

### H6 — Remote config can silently repoint the activation API base URL (PII redirect)
- **Description:** `UpdateService._applyRemoteSettings` (`update_service.dart:97-101`) persists
  `api_base_url` from the remote update JSON into prefs via `SettingsService.setApiUrl`
  (`settings_service.dart:29-32`) with **no HTTPS/host validation**. `activation_service.dart:64,106`
  then POSTs activation data — including the user's **name and phone** (`activation_service.dart:69-72`)
  — to that base URL.
- **Impact:** Whoever controls the update-config file (or can tamper prefs) can redirect activation
  PII to an arbitrary server, including an `http://` one, and forge activation (the response is an
  unsigned `is_verified` boolean — `activation_service.dart:77-79`).
- **Recommendation:** Validate `api_base_url` is `https://` and on a host allowlist before persisting;
  ideally remove the remote base-URL override entirely and ship it in the build. Have the server
  return a **signed** activation assertion verified with a bundled public key.

---

## 🟡 Medium

### M1 — Sensitive data visible in the recents/task-switcher snapshot
- **Description:** The auto-lock only pushes `LockScreen` on `resumed` (`app.dart:38-57`);
  `inactive`/`paused`/`hidden` aren't obscured and there's no `FLAG_SECURE`.
- **Impact:** Balances/customer data appear in the Android app-switcher thumbnail and are
  screenshot-able, despite the PIN lock.
- **Recommendation:** On `inactive`/`paused` show an obscuring overlay or set `FLAG_SECURE`
  (platform channel / `flutter_windowmanager`); handle `hidden` (Flutter 3.13+).

### M2 — Auto-lock timing uses wall-clock `DateTime.now()`
- **Description:** Elapsed-since-pause is computed from `DateTime.now()` (`app.dart:43-44`).
- **Impact:** Changing the device clock (or DST) can make elapsed negative/huge and **bypass the
  auto-lock**. Also confirm cold-start (killed & relaunched) enforces the PIN via the splash path.
- **Recommendation:** Use a monotonic source (`Stopwatch`/scheduler elapsed) for lock timing; verify
  cold-start locking.

### M3 — No pagination on per-customer transaction history
- **Description:** `getByCustomerAndCurrency` (`transaction_repository.dart:15-25`) loads a customer's
  **entire** history into memory (`customer_details_screen.dart:247`); no `LIMIT/OFFSET`.
- **Impact:** Memory and first-paint latency grow linearly; a customer with thousands of transactions
  janks on low-end phones. (The accounts overview is fine — it uses one aggregated row per customer.)
- **Recommendation:** Paginate with `LIMIT/OFFSET` or keyset paging on `(date_, ID)`; keep the
  SQL-side `getBalance` for the header total (already done).
- **Resolution — Mitigated (full pagination declined by design):**
  - **M4** added the composite index `idx_tx_cus_curr(cus_id, curr_id)`, so the per-customer query is
    index-backed and fast.
  - **M5** parses each transaction's date once at load and memoizes the filtered/sorted list, so the
    recurring per-rebuild jank (the concrete symptom) is gone — work is O(load), not O(frame).
  - **L5** moved the per-row running balance to an **absolute** value keyed by `tx.id`
    (`_absoluteRunning`), computed over the full ordered set and independent of the active filter —
    which was the correctness reason pagination was unsafe.
  - Full keyset pagination was **declined**: three features legitimately require the entire set anyway
    — the absolute running-balance map, `_buildStatement()`/`_exportPdf()`, and `_calculateSummary` —
    so pagination could only shrink display-object memory, which is negligible at this app's realistic
    scale (a single customer holds tens–hundreds of transactions; even a pathological 10k ≈ ~2 MB and
    a one-time ~30–50 ms parse). The added scroll-state/SQL-filter/load-more complexity on a
    balance-critical financial screen is disproportionate to that win.

### M4 — Missing composite index; imported legacy DBs get no indexes
- **Description:** Only single-column indexes exist (`database_helper.dart:94-103`). The hottest
  queries filter `WHERE cus_id=? AND curr_id=?` (`transaction_repository.dart:20-22,70-71`). Also,
  `_ensureLegacyCompatibility` (post-import) adds columns but never calls `_createIndexes`
  (`database_helper.dart:226-257`), so an imported DB whose `user_version`≥3 skips `_onUpgrade` and
  ends up **index-less**.
- **Impact:** Slower per-customer queries at scale; silent performance degradation after import.
- **Recommendation:** Add composite `idx_tx_cus_curr ON transactions(cus_id, curr_id)`; call
  `_createIndexes(database)` inside `_ensureLegacyCompatibility`.

### M5 — Expensive work in `build()` / on every keystroke (jank at scale)
- **Description:** `customer_details_screen.dart:332-333` re-parses dates
  (`FormatHelper.parseDate`, a `DateFormat.parseStrict` loop) for **every** transaction and re-sorts
  on every rebuild; `currency_accounts_screen.dart:275-306` filters+sorts all customers on every
  keystroke (`onChanged` at 467); `home_screen.dart:639` fires a **DB query per keystroke** with no
  debounce.
- **Impact:** Typing/filtering jank once lists grow — relevant for the small-business target hardware.
- **Recommendation:** Cache parsed `DateTime`s at load; memoize filtered/sorted lists; debounce
  search (~250-300 ms) before hitting the DB.

### M6 — `RenderFlex` overflow risk with large amounts / large text scale
- **Description:** Value `Text`s without `Flexible`/`maxLines`/ellipsis in
  `currency_accounts_screen.dart` `_SummaryBar`/`_StatItem` (606-664) and `_CustomerTile` balance
  badge (858-875); `customer_details_screen.dart` `_TransactionTile` amount (962-974).
- **Impact:** Visible overflow stripes for big numbers or `textScaler` up to 1.3 on narrow phones.
- **Recommendation:** Wrap value `Text`s in `Flexible` + `maxLines:1, overflow: ellipsis` (as already
  done in `_BalanceCard`, customer_details:782).

### M7 — No ProGuard/R8 keep rules (latent release crashes)
- **Description:** `isMinifyEnabled=false`/`isShrinkResources=false` (`build.gradle.kts:56-57`); no
  `proguard-rules.pro` exists.
- **Impact:** No shrinking/obfuscation today; and the moment R8 is enabled without keep rules it will
  likely break reflection-based plugins (`workmanager`, `local_auth`, `sqflite`, `pdf`/`printing`,
  `flutter_secure_storage`, `share_plus`, `file_picker`) — a classic release-only crash.
- **Recommendation:** Add `proguard-rules.pro` with keep rules for those plugins + `-keep class
  io.flutter.** { *; }` before ever enabling R8; verify a release build end-to-end.

### M8 — `groups_screen` mutations (and settle-balance) fail silently
- **Description:** `_addGroup`/`_renameGroup`/`_deleteGroup` (`groups_screen.dart:61-125`) do
  `db.insert/update/delete` with **no try/catch and no success/error feedback**.
- **Impact:** Failed group edits are swallowed by the zone handler; the user sees nothing (list just
  doesn't change).
- **Recommendation:** Wrap mutations; show `AppSnackBar.error` on failure (and success confirmation).

---

## 🟢 Low

### L1 — PIN length inconsistency + a 5-digit dead-end
- **Description:** `_configurePinLock` uses `maxLength:4` (`settings_screen.dart:198,206`) but
  `_changePinDialog` uses `maxLength:6` (258,267) with a label still saying "(4 أرقام)". The lock
  screen only auto-submits at length **4 or 6** (`lock_screen.dart:83`) and has no submit button.
- **Impact:** A user who sets a 5-digit PIN can never unlock.
- **Recommendation:** Standardize PIN length; fix labels; constrain to 4/6 or add an explicit confirm.

### L2 — Auto-lock can stack multiple `LockScreen`s
- **Description:** `app.dart:50` pushes a `LockScreen` on each qualifying resume with no check that
  one is already on top.
- **Impact:** Rapid background/foreground cycles stack multiple lock routes.
- **Recommendation:** Track a "lock shown" flag or check the current route before pushing.

### L3 — Dark mode: light-only accent banners + low-contrast secondary text
- **Description:** `Colors.orange.shade50` warning blocks stay bright in dark mode
  (`currency_accounts_screen.dart:398`, `settings_screen.dart:497`, `activation_screen.dart:241-254`);
  pervasive `Colors.grey.shade600/700` secondary text (~3.9:1 on `#272727`) is below WCAG AA
  (`app_error_state.dart:82`, `app_empty_state.dart:56`, `home_screen.dart:566-595`, customer_details).
- **Impact:** Dim/mismatched text and banners in dark mode (readable but sub-AA).
- **Recommendation:** Use `colorScheme.onSurfaceVariant`/`onSurface` for secondary text; derive banner
  colors from brightness or use `errorContainer`/`tertiaryContainer` roles.

### L4 — Dialog `TextEditingController`s not disposed in Settings PIN dialogs
- **Description:** `_configurePinLock` (`settings_screen.dart:183-184`) and `_changePinDialog`
  (242-244) create controllers that are never disposed (unlike groups/customer_details dialogs).
- **Impact:** Small controller leak each time a PIN dialog opens.
- **Recommendation:** Dispose in a `try/finally` after `showDialog` returns.

### L5 — Per-tile running balance uses the **filtered** subset
- **Description:** `customer_details_screen.dart:536-545` computes "الرصيد بعدها" from
  `visibleTransactions` while the header shows the full `_balance`.
- **Impact:** With a date/type filter active, per-row running balances don't reconcile with the header.
- **Recommendation:** Compute running balances from the full ordered set, or label them as filtered.

### L6 — PIN hash is unsalted/uniterated
- **Description:** `pin_service.dart:90-91` — single SHA-256 over a constant prefix `'daftar_pin_'`;
  4/6-digit space.
- **Impact:** If secure storage is ever compromised, the whole PIN space is brute-forced instantly.
  (The `flutter_secure_storage` + `encryptedSharedPreferences` layer is the real protection.)
- **Recommendation:** Optional for a screen lock — add a per-install random salt + a slow KDF
  (PBKDF2/scrypt/argon2) if offline-brute-force resistance is desired.

### L7 — Lockout counter resets to 0 after each lockout (throttle, not hard cap)
- **Description:** `pin_service.dart:76-82` resets attempts to 0 on lockout.
- **Impact:** Attacker gets 5 tries per 5 min indefinitely (rate-limited, not capped). Kill-app does
  **not** bypass lockout (wall-clock `locked_until` persists — verified correct).
- **Recommendation:** Consider escalating lockout duration; don't reset the counter until a successful
  unlock.

### L8 — Leading-wildcard `LIKE` search (full scan)
- **Description:** `customer_repository.dart:39-41` uses `LIKE '%q%'`, which can't use `idx_cus_name`.
- **Impact:** Full table scan per search; noticeable only at thousands of customers.
- **Recommendation:** Prefix search (`q%`) to use the index, or add FTS; combine with M5 debounce.

### L9 — `UrlHelper` has no scheme allowlist / unguarded `Uri.parse`
- **Description:** `url_helper.dart:16-17` launches whatever scheme it's given.
- **Impact:** None today (all callers pass hardcoded HTTPS/`wa.me`/`mailto`). Latent if a future caller
  passes untrusted input. `LaunchMode.externalApplication` is the safe choice.
- **Recommendation:** Allowlist `uri.scheme` (`https`/`mailto`/`tel`/`whatsapp`/`tg`) and wrap
  `Uri.parse` in try/catch.

### L10 — Auto-backups stored in app-scoped storage (lost on uninstall)
- **Description:** `getExternalStorageDirectory() ?? getApplicationDocumentsDirectory()`
  (`database_helper.dart:149-150,173-174`) → `/Android/data/<pkg>/files`, deleted on uninstall and
  not user-visible.
- **Impact:** Auto-backups vanish with the app; only manual `Share` export survives.
- **Recommendation:** Document this, or write auto-backups to a user-visible/SAF location.

### L11 — No certificate pinning
- **Description:** `http` calls use a default client (`activation_service.dart:65,107`,
  `update_service.dart:65`). Timeouts *are* set (15s/10s) — good.
- **Impact:** Defense-in-depth gap; low for this app (HTTPS, no secrets), but relevant given H6's PII.
- **Recommendation:** Optional — pin certs and ship a `network_security_config.xml` forbidding cleartext.

### L12 — Blocking startup awaits; periodic task re-registered every launch
- **Description:** `main.dart:20-24` awaits WorkManager init + `BackupSchedulerService.enable()`
  (which `registerPeriodicTask` with `replace`) **before** `runApp` on every cold start.
- **Impact:** Extra first-frame latency and redundant re-registration.
- **Recommendation:** Defer non-critical init after `runApp`; skip re-registering if already scheduled.

### L13 — Legacy `flutter_icons:` key; verify icon assets
- **Description:** `pubspec.yaml:91` uses the deprecated `flutter_icons:` key (vs
  `flutter_launcher_icons:` for `^0.14.3`). Confirm `assets/icon/app_icon.png` + `app_icon_fg.png`
  exist and icons were regenerated.
- **Impact:** Wrong/stale adaptive icon in the store listing if not regenerated.
- **Recommendation:** Migrate the key and re-run `dart run flutter_launcher_icons`.

### L14 — Minor manifest/build polish
- **Description:** Hardcoded app label `دفتر حسابات` instead of `@string/app_name`
  (`AndroidManifest.xml:6`); `minSdk`/`targetSdk`/`compileSdk` inherit Flutter defaults (not pinned,
  `build.gradle.kts:18,43-44`); `INTERNET` declared for an app marketed as "offline" (legitimately
  needed by `http`/`url_launcher`/`printing` — just confirm the store copy matches).
- **Impact:** Cosmetic / reproducibility; potential store-listing mismatch on the "offline" claim.
- **Recommendation:** Use a localized string resource; pin SDK versions explicitly; align store copy.

### L15 — Double-submit gaps on FABs
- **Description:** Add-group FAB (`groups_screen.dart:247`) and add-transaction FAB
  (`customer_details_screen.dart:583`) aren't debounced; a fast double-tap can open two dialogs/editors.
  (The add/edit **forms** are already protected via `_saving`.)
- **Impact:** Two stacked dialogs/editors; low impact.
- **Recommendation:** Guard with a simple in-flight flag.

---

## Verified Correct (no action needed)

These were checked and are implemented well:

- **Architecture:** repository pattern; screens don't touch `DatabaseHelper` directly; two global
  providers only; clean design-token system; `flutter analyze` clean.
- **SQLite:** balances via SQL aggregates (no N+1); customer overview is one `GROUP BY` query;
  `PRAGMA foreign_keys=ON` on every open; migrations are idempotent/non-destructive
  (`_addColumnIfMissing`, `IF NOT EXISTS`); integrity check before overwrite.
- **Memory/UI:** all long lists use `ListView.builder`/`.separated`; controllers disposed in every
  `StatefulWidget` screen; consistent `if (!mounted)` guards after awaits.
- **Security done right:** PIN in `flutter_secure_storage` (`encryptedSharedPreferences`); lockout
  survives app-kill (persisted wall-clock `locked_until`); all network timeouts set; **no** cleartext
  endpoints, hardcoded secrets/keys/tokens, or sensitive logging outside `kDebugMode`; biometric flow
  uses `biometricOnly` + capability checks; activation correctly **fails closed** when offline & not
  yet activated.
- **Lifecycle:** `WidgetsBindingObserver` added/removed correctly; `runZonedGuarded` +
  `FlutterError.onError` wired; `ensureInitialized` inside the same zone as `runApp`.
- **Localization:** `textScaler` clamped to 1.3 (upper-bound only, deliberately) — avoids the
  `_ClampedTextScaler` assertion; consistent `intl` number/date formatting.

---

## Suggested Release Plan

1. **Block release until fixed:** C1, C2, H1, H2, H3, H4, H5, H6.
2. **First patch:** M1–M8.
3. **Backlog:** L1–L15.
4. **Also:** `flutter test` currently fails to launch in the dev environment with a WebSocket 503 at
   the harness-bootstrap stage (not a code failure) — resolve so tests run in CI before shipping.

*End of report. No files were modified.*
