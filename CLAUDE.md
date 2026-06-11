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

### Directory Layout
```
lib/
├── app.dart                    # Root widget, MultiProvider setup
├── core/
│   ├── constants/              # DB table names, currency mappings
│   ├── helpers/                # FormatHelper, StatementHelper, CustomerHelper
│   ├── services/               # ActivationService, SettingsService, UpdateService
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

### Localization
Arabic-first RTL layout. Uses `flutter_localizations` + `intl`. Comments throughout the codebase are in Arabic.
