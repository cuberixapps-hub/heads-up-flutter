# Build Environments

The app supports three environments: **development**, **uat**, and **production**. Behavior (test vs production ads, sandbox vs production IAP, debug logging, debug-only UI) is driven by `EnvironmentConfig` and the `ENVIRONMENT` dart-define.

## How the active environment is chosen

- **`--dart-define=ENVIRONMENT=...`**  
  Set explicitly when running or building. Values are normalized:
  - `uat`, `staging`, `test` (case-insensitive) → **UAT**
  - `production`, `prod` → **production**
  - `development`, `dev` → **development**
- **If `ENVIRONMENT` is empty**  
  - **Release build** (`flutter build apk`, etc.) → **production**
  - **Debug/Profile** (`flutter run`) → **development**

All behavior goes through `lib/config/environment.dart`; no other file should read `fromEnvironment('ENVIRONMENT')` or `kReleaseMode` for environment.

## Environment behavior

| | development | uat | production |
|---|-------------|-----|------------|
| **useTestAds** | yes | yes | no (ProductionConfig) |
| **useSandboxIAP** | yes | yes | no (ProductionConfig) |
| **enableDebugLogging** | yes | yes | no |
| **Debug-only UI** (e.g. Simulate Premium, Version switcher) | shown | hidden | hidden |
| **Crashlytics** | off | off | on |

Production-only IDs/keys live in `lib/config/production_config.dart` (committed with placeholders). Replace placeholders with real AdMob and RevenueCat values for production builds. You can add `lib/config/production_config.dart` to `.gitignore` locally if you store real secrets there.

## Example commands

**Development (default for `flutter run`):**
```bash
flutter run
# or explicitly:
flutter run --dart-define=ENVIRONMENT=development
```

**UAT:**
```bash
flutter run --dart-define=ENVIRONMENT=uat
flutter build apk --dart-define=ENVIRONMENT=uat
flutter build ios --dart-define=ENVIRONMENT=uat
```

**Production:**
```bash
flutter build appbundle --dart-define=ENVIRONMENT=production
flutter build ipa --dart-define=ENVIRONMENT=production
```
Without `ENVIRONMENT`, a **release** build (e.g. `flutter build appbundle`) defaults to production.

To force production while still in debug/profile (e.g. for testing production config locally):
```bash
flutter run --dart-define=ENVIRONMENT=production
```

## Startup log

When `enableDebugLogging` is true (development or UAT), `EnvironmentConfig.printEnvironmentInfo()` runs at startup and prints the active environment and flags (e.g. `useTestAds`, `useSandboxIAP`, `enableDebugLogging`) to the console.
