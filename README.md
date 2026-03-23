# Stylex

Stylex is a Flutter-based digital wardrobe app that helps users organize clothing pieces, generate outfit suggestions, and save looks for later. It combines closet management, weather-aware recommendations, and outfit building into a single mobile-first experience.

## Features

- User authentication powered by Supabase
- Digital closet for uploading and managing clothing items
- Local image-based clothing analysis for category and color detection
- Weather snapshot on the home screen with temperature and condition icon
- Outfit of the day suggestions based on available closet items
- Manual outfit builder for mixing and matching pieces
- Saved looks with rename and detail view support
- Settings screen for app preferences and account actions

## Built With

- [Flutter](https://flutter.dev/) for the cross-platform app
- [Dart](https://dart.dev/) for application logic
- [Supabase](https://supabase.com/) for authentication and backend data
- `geolocator` for location-aware weather support
- `image_picker` and `image` for clothing image capture and analysis
- `shared_preferences` for lightweight local persistence

## Project Structure

```text
lib/
  app/
    config/       # App configuration such as Supabase setup
    models/       # Data models used across the app
    screens/      # UI screens including home, closet, outfits, and settings
    services/     # Business logic, weather, closet, and image analysis
    view_models/  # Screen state and orchestration
    widgets/      # Shared UI widgets
```

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- A Supabase project

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

Open `lib/app/config/supabase_config.dart` and set your project credentials:

```dart
static const String url = 'YOUR_SUPABASE_URL';
static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 3. Run the app

```bash
flutter run
```

## Running Locally on This Workspace

This repository may live in a Windows path with spaces, which can interfere with some Flutter tooling. If that happens, use the helper scripts included in the project.

### Option 1: Start the helper shell

```powershell
.\tools\stylex-shell.cmd
```

Then run:

```powershell
flutter clean
flutter pub get
flutter run
```

### Option 2: Use the Flutter wrapper directly

```powershell
.\tools\flutter.cmd --version
.\tools\flutter.cmd clean
.\tools\flutter.cmd pub get
.\tools\flutter.cmd run
```

## Available Screens

- Home
- Closet
- Add Closet Item
- Outfit Maker
- Settings
- Style Preferences
- Authentication and boot flow

## Notes

- Weather and outfit suggestions are cached during the active app session to avoid unnecessary refreshes when switching tabs.
- Outfit suggestions use the closet inventory and rotate through different valid combinations when available.
- The repository includes platform folders for Android, iOS, macOS, Windows, Linux, and web because this is a Flutter project.

## Status

Stylex is currently structured as an app prototype / student project with core wardrobe, outfit, and settings flows already in place.
