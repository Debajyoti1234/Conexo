# Local Supabase Dev Workflow Improvement

## Current State
- `.vscode/launch.json` already injects `--dart-define-from-file=tool/supabase_dev.json` for debug/profile/release configs.
- `flutter run --dart-define-from-file=tool/supabase_dev.json` works.
- `tool/supabase_dev.json` is gitignored.
- `supabase_client.dart` uses `String.fromEnvironment()` (must NOT change).

## Problem
Every terminal invocation requires typing:
`flutter run --dart-define-from-file=tool/supabase_dev.json`

## Determination
Literal `flutter run` **cannot** be made to automatically consume a project-local dart-define file. Flutter CLI has no project-level config for auto-injecting dart-defines; the `--dart-define-from-file` flag must be supplied per invocation.

## Plan
Create two small wrapper scripts in `tool/`:

1. `tool/run.ps1` — wraps `flutter run --dart-define-from-file=tool/supabase_dev.json`
2. `tool/build_apk.ps1` — wraps `flutter build apk --dart-define-from-file=tool/supabase_dev.json`

Both scripts:
- Execute from repo root.
- Forward any additional arguments (`$args`) to the underlying Flutter command.
- Do NOT modify any source, config, gitignore, or architecture files.

## Usage
```powershell
.\tool\run.ps1
.\tool\build_apk.ps1
```

## Validation
- `flutter analyze` already passes.
- `flutter run` with `--dart-define-from-file=tool/supabase_dev.json` already verified working.
- Scripts are thin wrappers — risk is minimal.
- No credentials, secrets, or sensitive content are introduced beyond the existing `tool/supabase_dev.json` (already gitignored).
