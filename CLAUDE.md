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

Pulse is a Flutter fitness-tracking app (Material 3, dark theme). The entire UI currently lives in a single file:

- **`lib/main.dart`** — `PulseApp` (app root) → `HomeScreen` (splash/landing) → `OnboardingScreen` (profile form)

The app communicates with a local FastAPI backend at `http://127.0.0.1:8000`. The only wired endpoint is:

- `POST /api/user/profile` — submits the user profile collected during onboarding (name, age, height, weight, sex, goal, activity level)

### Design conventions

- Background: `Colors.black`; accent: `Colors.deepPurple`; text on dark: `Colors.white` / `Colors.grey`
- All form inputs share `_buildTextField` / `_buildDropdown` helpers inside `_OnboardingScreenState`
- The backend URL is hardcoded in `_submitProfile`; extract it to a constant or config before adding more endpoints

### Targets

The project includes platform runners for Android, iOS, macOS, Windows, Linux, and Web — all are standard Flutter scaffolding. Primary development targets are likely **web** and **Windows** given the local environment.
