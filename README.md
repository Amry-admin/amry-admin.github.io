# CycleSync

Private period and cycle tracker. Flutter (Android + web/PWA) with Supabase.

> CycleSync's dates and insights are estimates, not medical advice. It cannot
> diagnose a condition, confirm ovulation, or prevent pregnancy.

## Status

| Phase | What | State |
| --- | --- | --- |
| 1 | Foundation: theme, navigation, Supabase connection check, CI | Done |
| 2 | Sign-up, login, onboarding, disclaimer | Not started |
| 3 | Period + daily logging, calendar, cycle calculations | Not started |
| 4 | History, insights, CSV export | Not started |
| 5 | Reminders, account deletion, privacy tests | Not started |
| 6 | PWA polish, signed APK, sharing | Not started |

## Live app

Web: https://ebrahim-omar0729.github.io/cyclesync/ (deployed by GitHub Actions)

APK: open the latest successful **Build Android APK** run under the **Actions**
tab and download the `cyclesync-release-apk` artifact.

## Run it on your computer (VS Code terminal)

Prerequisites: Flutter stable, Android Studio (for the Android SDK), Git.

```bash
git clone https://github.com/Ebrahim-omar0729/cyclesync.git
cd cyclesync
flutter pub get

# Web (Chrome), port 3000 matches the Supabase redirect URL
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY

# Android phone or emulator
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY

# Checks (CI runs the same)
flutter analyze
flutter test
```

Without the two `--dart-define` values the app shows a "not configured"
screen instead of starting. It also refuses to start if given a Supabase
**secret** or **service_role** key.

## Configuration and secrets

- GitHub → Settings → Secrets and variables → Actions holds
  `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the publishable/anon key).
- Never put the Supabase secret/service_role key, database password,
  or signing keystore in this repository.
- The public key is safe in the app only because Row Level Security is on
  for every table (see `supabase/migrations/`).

## Project layout

```text
lib/
  main.dart                 config check + Supabase init
  app.dart                  MaterialApp, theme, router
  core/config/              build-time config validation
  core/constants/           fixed text (disclaimer)
  core/theme/               light/dark theme
  core/widgets/             app shell (nav), shared widgets
  core/providers.dart       Riverpod providers
  data/services/            Supabase-facing services
  features/<feature>/       screens per feature
  routing/                  go_router setup
supabase/migrations/        SQL, applied in order
test/unit, test/widget      tests
.github/workflows/          CI: APK build, web build + deploy
```

## Database changes

Each change is a new file in `supabase/migrations/` named
`YYYYMMDDHHMMSS_description.sql`. Run it in the Supabase SQL Editor (dev
project first), then commit it. Never edit an applied migration.

## Adding packages

Use `flutter pub add <package>` so versions match the installed Flutter,
then commit both `pubspec.yaml` and `pubspec.lock`.
