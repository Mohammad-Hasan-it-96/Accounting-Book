# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**دفتر حسابات** (Accounting Book) — an Arabic-first, offline Flutter app for tracking customer debts and credits. Supports multi-currency (local/dollar), customer groups, transaction history, data import/export, and a device activation/licensing system.

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter analyze          # Run Dart static analysis
flutter test             # Run tests
```

## Architecture

### Entry Flow
`main.dart` → `app.dart` (MultiProvider root) → `SplashScreen` → checks activation via `ActivationService` → `ActivationScreen` or `HomeScreen`

`main.dart` wraps startup in `runZonedGuarded`, initializes `CrashService`, wires `FlutterError.onError`, initializes WorkManager (`callbackDispatcher`), and re-registers the periodic auto-backup task if it was previously enabled — all before `runApp`.

### Directory Layout
```
lib/
├── app.dart                    # Root widget, MultiProvider setup
├── core/
│   ├── constants/              # DB table names, currency mappings
│   ├── helpers/                # FormatHelper, StatementHelper, CustomerHelper
│   ├── services/               # ActivationService, SettingsService, UpdateService,
│   │                           #   PinService, CrashService, PdfService, BackupSchedulerService
│   ├── theme/app_theme.dart    # Material3 light/dark themes
│   └── widgets/                # Shared widgets (UpdateDialog)
├── data/
│   ├── database/database_helper.dart   # SQLite singleton
│   ├── models/                 # Customer, Transaction, Currency
│   └── repositories/           # CustomerRepository, TransactionRepository, CurrencyRepository
├── providers/
│   ├── app_provider.dart       # Currency list state
│   └── theme_provider.dart     # Light/dark mode state
└── screens/                    # One folder per screen
```

### State Management
Provider (v6.1.5). Only two providers exist at the global level: `AppProvider` (currency list from DB) and `ThemeProvider` (theme mode). Screen-level state is managed locally with `setState`.

### Data Layer
- **SQLite** via `sqflite` — database name `daftar_hesabat.db`
- Tables: `customers`, `transactions`, `currency`, `groups`, `cus_type`
- `DatabaseHelper` is a singleton; handles DB initialization, legacy column migration, and import/export with auto-backup
- All DB access goes through repository classes — avoid calling `DatabaseHelper` directly from screens

### Key Domain Concepts
- `inFlag`: `1` = مطلوب (debit/due), `-1` = مدفوع (paid/credit) in the transactions table
- Currencies are stored in DB; the UI filters views by currency type ("محلي" vs "دولار")
- Activation is keyed on a hashed Android device ID; `ActivationService` checks/stores status in `shared_preferences` and validates against a remote API whose URL is user-configurable in Settings

### Security / App Lock
- `PinService` (singleton) stores a SHA-256 hash of the PIN in `flutter_secure_storage` (encrypted shared prefs), not `shared_preferences`. The salt prefix `daftar_pin_` is baked into the hash.
- Brute-force protection: after `maxFailedAttempts` (5) the service locks out for `lockoutDurationMinutes` (5).
- Optional biometric unlock via `local_auth`; entry/unlock UI lives in `screens/lock/lock_screen.dart`.
- Auto-lock is driven by app lifecycle in `app.dart`: on `paused` it records the time; on `resumed` it re-shows `LockScreen` if PIN is enabled and elapsed time exceeds `SettingsService.getAutoLockTimeout()` (timeout ≤ 0 disables it). The push uses the top-level `_navigatorKey`.

### Background Backup
- `BackupSchedulerService` registers a daily WorkManager periodic task (`com.daftar.auto_backup`); the enabled flag lives in `shared_preferences`.
- `callbackDispatcher` is a top-level `@pragma('vm:entry-point')` function that runs `DatabaseHelper().autoBackup()` in the background. Registering/initializing WorkManager happens in `main.dart`.

### Crash Reporting
`CrashService` is initialized first in `main.dart` and captures both Flutter framework errors (`FlutterError.onError`) and uncaught zone errors (`runZonedGuarded`). Sentry is scaffolded but commented out in `pubspec.yaml` — wire in a DSN before relying on remote crash reports.

### PDF Export
`PdfService` builds account statements via the `pdf` + `printing` packages for share/print.

### Design System (Tokens)
All visual constants are centralized under `core/theme/` — do not hardcode sizes/colors/durations/styles in screens:
- `app_dimens.dart` — `AppSpacing` (4-pt grid: xxs..xxxl), `AppRadius` (sm 8 / md 12 / lg 16, plus ready `*All` BorderRadius), `AppIconSize` (sm 16 / md 20 / lg 24 / xl 32 / xxl 48 / empty 64), `AppFontSize` (micro 10 → display 26), and `Gap` spacer widgets.
- `app_colors.dart` — `AppColors` is the single source for colors: `primary`/`primaryLight`, semantic `income`/`incomeDark`/`expense`/`expenseDark`, `cardDark`, and brand `whatsApp`/`telegram`. Reference these instead of repeating hex. (Material grey/status shades stay as `Colors.*` — already named constants.)
- `app_durations.dart` — `AppDurations` (fast/medium/slow/splashHold/snackbar/snackbarShort) for UI animation + feedback timing. Network timeouts and logic timers are NOT design tokens and stay in their layer.
- `app_text_styles.dart` — `AppTextStyles` reusable styles built on `AppFontSize` (size-only scale + `*Bold` heading variants); compose with `.copyWith(color: ...)` at the call site.
- `app_theme.dart` — Material 3 component themes (unified 48px-min buttons with md radius, `StadiumBorder` chips/badges, lg-radius dialogs, md-radius cards/inputs); pulls its colors from `AppColors`.
- Pill-shaped badges/chips use `StadiumBorder` (via `ShapeDecoration` for custom containers), not a large `borderRadius`.

### Form Inputs (Standardized)
All form fields go through shared widgets/helpers — do not hand-roll `TextFormField`/`DropdownButtonFormField`/date-picker decorations in screens:
- `core/widgets/app_form_field.dart` — `AppTextField`, `AppDropdownField<T>`, `AppDateField`. Each takes `label` + `icon`; `required: true` appends the ` *` marker and wires the required validator. They work inside a `Form` and inside dialogs. `AppTextField` auto-sets `alignLabelWithHint` for multiline.
- `core/helpers/form_validators.dart` — `FormValidators` is the single source for validation logic/messages: `required([msg])`, `requiredValue<T>([msg])`, `amount(...)`. Pass a descriptive per-field message; the trim/number logic stays centralized.
- Standard inter-field spacing is `Gap.h12` (`Gap.h8` for tighter dialogs) — not raw `SizedBox` or `AppSpacing.lg`.
- Search bars and date-range *filter* controls are not form inputs and intentionally stay outside this system.

### Confirmation Dialogs (Standardized)
All yes/no confirmation and delete dialogs go through one helper — do not hand-roll `AlertDialog` for confirmations:
- `core/widgets/app_dialog.dart` — `AppDialog.confirm(context, title:, message:, confirmLabel:, cancelLabel:, destructive:, icon:)` returns a `Future<bool>` (`true` = confirmed). Cancel is always a `TextButton`; confirm is always a `FilledButton`. `destructive: true` makes the confirm button red (`AppColors.expense`) and adds a `warning_amber_rounded` icon in the title — use it for deletes and any non-reversible action (including discard-changes prompts). Pass an `icon:` to add a leading title icon on non-destructive dialogs.
- Delete confirmation messages state that the action cannot be undone.
- Only dialogs with custom body content (PIN entry, group-name input, balance settlement, the update dialog) remain hand-built `AlertDialog`s; they still follow the same button convention (`TextButton` cancel + `FilledButton` confirm) and inherit the themed title style.

### Notifications / SnackBars (Standardized)
All transient feedback goes through one helper — do not hand-roll `SnackBar`/`ScaffoldMessenger.of(context).showSnackBar(...)` in screens:
- `core/widgets/app_snackbar.dart` — `AppSnackBar.success(context, message)`, `AppSnackBar.error(context, message)`, `AppSnackBar.warning(context, message)`, `AppSnackBar.info(context, message)`. Each shows a floating SnackBar with a consistent semantic color (`AppColors.income`/`expense`/`warning`/`primary`), a leading white icon (check / error / warning / info), white text, and `AppDurations.snackbar` duration. The helper calls `hideCurrentSnackBar()` first so messages never stack.
- Pick by intent: **success** = an action completed (saved/deleted/exported/copied); **error** = an operation failed or hit an unexpected state; **warning** = an advisory the user must heed but that isn't a failure (validation gaps, empty-export, "can't delete: has transactions"); **info** = a neutral notice that is neither success, failure, nor warning ("جارٍ تحميل البيانات…", neutral status messages).
- After an `await`, guard with `if (!mounted) return;` before calling (the helper takes a `BuildContext`). For callbacks that capture `build`'s `context`, move the async work into a State method so `context` resolves to `this.context` and the `mounted` check relates.
- `AppColors.warning` (orange) is the semantic token for advisory feedback.

### Loading Indicators (Standardized)
All spinners go through one widget — do not hand-roll `CircularProgressIndicator`/`Center(child: CircularProgressIndicator())`/`SizedBox`-wrapped spinners in screens:
- `core/widgets/app_loading.dart` — `const AppLoading()` renders a centered, full-area spinner (for a screen body waiting on data, using the default Material stroke). `const AppLoading.inline({size, strokeWidth, color})` renders a fixed-size spinner to drop into a button or list tile in place of its icon while an action runs; `size` defaults to `AppIconSize.md` (20) and `strokeWidth` to 2. Pass `AppIconSize.lg`/`AppIconSize.xl` and a `color` (e.g. `Colors.white` on colored surfaces) when a specific call site needs it.
- No animations beyond the indeterminate spinner itself — keep loading UI lightweight.
- The single `LinearProgressIndicator` (top-of-card progress bar on the home screen) is a deliberate one-off and intentionally stays outside this widget.

### Empty States (Standardized)
All "no data" / "no results" placeholders go through one widget — do not hand-roll a `Center(child: Column(...))` with a grey icon + texts in screens:
- `core/widgets/app_empty_state.dart` — `AppEmptyState(icon:, title:, description:, actionLabel:, actionIcon:, onAction:, iconSize:)`. It renders a centered column: a light-grey icon (`AppIconSize.empty` 64 by default; pass `AppIconSize.xxl` 48 for a compact panel), a `subtitle`-sized bold grey title, an optional short grey `description`, and an optional action button (shown only when both `actionLabel` and `onAction` are given — `ElevatedButton.icon` when `actionIcon` is set, else `ElevatedButton`).
- Use it for list/search empties (customers, groups, transactions, search results). For a screen with a single conditional empty (e.g. filtered vs. truly empty), branch the `icon`/`title`/`description`/action inline at the call site or in a small `_buildEmpty...()` State method rather than re-creating the layout.

### Localization
Arabic-first RTL layout. Uses `flutter_localizations` + `intl`. Comments throughout the codebase are in Arabic. `app.dart` clamps `textScaler` to 1.0–1.3 to prevent layout breakage at large system font sizes.
