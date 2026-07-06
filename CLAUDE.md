# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (pick a target)
flutter run -d chrome         # web
flutter run -d windows        # Windows desktop
flutter run                   # connected device / emulator

# Analyze / lint
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart   # single test file

# Install dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

## Architecture

Pulse is a Flutter fitness-tracking app (Material 3, dark theme) deployed to GitHub Pages (`https://prithvisudin.github.io/pulse-flutter/`, built by `.github/workflows/deploy.yml` on push to main).

- **`lib/main.dart`** — almost all UI: `PulseApp` (root) → `HomeScreen` (auth/profile gate) → `_SplashScreen` (signed out) / `OnboardingScreen` (signed in, no profile) / `_MainShell` (4 tabs: Workout, Nutrition, Coach, Profile)
- **`lib/auth_screen.dart`** — `AuthScreen`: email/password + Google + Apple sign-in via Supabase Auth
- **`lib/supabase_config.dart`** — Supabase URL + anon/publishable key

Auth is Supabase Auth (`supabase_flutter`); sessions persist in local storage and are restored on launch. The signed-in user's auth UUID is used as the profile row id (`_activeProfileId`), which keys all workout/nutrition data.

The app talks to a FastAPI backend (repo at `C:\Users\prith\pulse`, deployed on Railway at `https://web-production-2514b.up.railway.app`, `_baseUrl` in main.dart). The backend stores data in Supabase (Postgres) using the service-role key; the Flutter client only uses Supabase for auth, never direct DB access.

### Design conventions

- Background: `Color(0xFF0A0A0F)`; surfaces: `0xFF13131A`; accent gradient: `0xFF7C3AED` → `0xFF4F46E5`; muted text: `0xFF8B8B9E`
- All form inputs share `_buildTextField` / `_buildDropdown` helpers inside `_OnboardingScreenState`

### Targets

The project includes platform runners for Android, iOS, macOS, Windows, Linux, and Web — all are standard Flutter scaffolding. Primary development targets are likely **web** and **Windows** given the local environment.
