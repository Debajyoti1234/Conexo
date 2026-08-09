# Conexo — Fix "Supabase configuration is missing" White Screen

**Branch:** conexo-supabase
**Type:** Local dev configuration fix (no Dart/source changes)
**Decision:** VS Code `launch.json` only (per user)

---

## Root Cause (confirmed)

- `lib/core/supabase/supabase_client.dart:4-10` reads credentials via **compile-time** constants:
  `String.fromEnvironment('SUPABASE_URL')` and `String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')`.
- These are only populated at build time via `--dart-define` / `--dart-define-from-file`.
- `lib/main.dart:15` calls `await SupabaseClientConfig.initialize()` **before** `runApp()`. With empty
  defines, `initialize()` throws `StateError` at `supabase_client.dart:16` → no UI renders → white screen.
- The intended local config **already exists** and is correct:
  - `tool/supabase_dev.json` — flat JSON with exact keys `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`.
  - Already gitignored at `.gitignore:47` (`/tool/supabase_dev.json`) → credentials are not committed.
- The missing piece: **nothing supplies that file to the build.** Flutter 3.44.8 / Dart 3.12.2 support
  `--dart-define-from-file`, and the JSON format matches exactly. No Dart change is needed.

## Architecture / Constraints Honored

- Existing Supabase architecture preserved (compile-time `String.fromEnvironment` + dart-define).
- No credentials hardcoded in Dart; none committed to Git.
- No changes to auth UI, validators, routing, Gradle, AGP, Kotlin, Android config, or dependencies.
- No new packages.

## Exact Change (implementation-capable agent)

Create **`.vscode/launch.json`** (new file; `.vscode/` is not gitignored, and this file contains only a
path reference — no secrets — so it is safe to commit):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "conexo (debug)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define-from-file=tool/supabase_dev.json"]
    },
    {
      "name": "conexo (profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile",
      "program": "lib/main.dart",
      "args": ["--dart-define-from-file=tool/supabase_dev.json"]
    },
    {
      "name": "conexo (release)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "release",
      "program": "lib/main.dart",
      "args": ["--dart-define-from-file=tool/supabase_dev.json"]
    }
  ]
}
```

- The Dart-Code extension runs from the project root, so `tool/supabase_dev.json` resolves correctly.
- After this, VS Code **Run/Debug** (F5) launches with credentials injected — no secret typing.

## CLI note (informational; launch.json cannot build an APK)

Because the user chose launch.json only (no wrapper scripts), CLI invocations must append the flag:

- Run:   `flutter run --dart-define-from-file=tool/supabase_dev.json`
- Build: `flutter build apk --dart-define-from-file=tool/supabase_dev.json`

This is inherent to the compile-time architecture. (If bare `flutter run` / `flutter build apk` should
also work without the flag, revisit and add `tool/` wrapper scripts — explicitly out of scope now.)

## Production / CI (keep secure)

- Do not commit `tool/supabase_dev.json` (already gitignored).
- In CI/production, provide the same defines from CI secrets, e.g.
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
  or a CI-generated define-file. Nothing is hardcoded, so this already works.

## Files

- **Create:** `.vscode/launch.json`
- **Untouched:** `lib/core/supabase/supabase_client.dart`, `lib/main.dart`, all auth UI/validators/routing,
  `pubspec.yaml`, `.gitignore` (already correct), `tool/supabase_dev.json` (already present & ignored),
  Android/Gradle/Kotlin config.

## Validation

1. `flutter analyze` → expect "No issues found!" (no code changed).
2. `flutter clean`
3. `flutter pub get`
4. Launch via VS Code **conexo (debug)** config (F5) on the Android device.
   - Equivalent CLI check: `flutter run --dart-define-from-file=tool/supabase_dev.json`.
5. Expected: `SupabaseClientConfig.initialize()` succeeds; app renders the existing Conexo splash → UI
   instead of a white screen. No `StateError` thrown.

## Handoff

This requires creating a non-plan file (`.vscode/launch.json`) and running `flutter clean` /
`flutter pub get` / `flutter run` (mutating/long-running). Switch to an implementation-capable agent to
apply the change and run validation.
