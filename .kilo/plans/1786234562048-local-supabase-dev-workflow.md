# Phase 8.2 — Supabase Profile Foundation + Mandatory Profile Gate

## Current State
- `supabase_client.dart` uses `String.fromEnvironment` for credentials.
- `tool/supabase_dev.json` contains dev credentials (gitignored).
- `.vscode/launch.json` injects `--dart-define-from-file` for VS Code.
- `ProfileRepository` abstraction exists with `LocalProfileRepository` (SharedPreferences).
- `ProfileCreationScreen` uses progressive reveal, auto-saves drafts, generates timestamp ID on completion.
- `SplashScreen` only checks `AuthService.currentSession` → `MainShell` or `OnboardingScreen`.
- `LoginScreen` → `MainShell` directly on sign-in.
- `PhoneAuthScreen._verify()` → `MainShell` directly (stub).
- `ProfileScreen` (inside MainShell) has a local profile gate, but users can access other tabs without a profile.
- No `supabase/migrations/` directory exists.

## Goal
Make `ProfileCreationScreen` the mandatory post-authentication gate using Supabase for profile persistence, with `auth.uid() = profiles.id`.

## Out of Scope
- Google/Apple OAuth implementation
- Phone OTP backend
- Connections/Plans/Chat/Notifications backend
- Storage/Realtime
- New UI screens
- New dependencies
- Android/Gradle changes

## Implementation Plan

### 1. Database Migration
Create `supabase/migrations/20260809000000_create_profiles_table.sql` (no existing migrations; first migration):
- `profiles` table with `id uuid PRIMARY KEY`
- Columns: `created_at timestamptz DEFAULT now()`, `updated_at timestamptz DEFAULT now()`, `profile_completed boolean DEFAULT false`
- Map all `UserProfile` fields to Postgres types (snake_case for DB, mapped in repository)
- Enable RLS with `auth.uid() = id` for SELECT/INSERT/UPDATE
- DB-level default on `id` is a safety net only; application code explicitly sets `id = AuthService.currentUser!.id`

### 2. SupabaseProfileRepository
Add to `lib/features/profile/profile_repository.dart`:
- Implement `ProfileRepository`
- Delegate draft methods to `LocalProfileRepository` (preserve local draft behavior)
- Profile methods use `SupabaseClientConfig.client`
- `loadProfile()`: query `profiles` where `id = auth.uid()`, map snake_case → camelCase for `UserProfile.fromJson()`
- `saveProfile()`: explicitly set `id = AuthService.currentUser!.id`, validate draft with `validateDraft()`, set `profile_completed` based on validation result, upsert
- `hasProfile()`: check `profiles` where `id = auth.uid() AND profile_completed = true`
- Throw on Supabase/network errors (do NOT return false for backend errors)

### 3. Profile Creation Screen Changes
In `lib/features/profile/profile_creation_screen.dart`:
- Add optional `VoidCallback? onComplete` parameter
- In `_complete()`: use `AuthService.currentUser!.id` instead of timestamp ID
- Call `widget.onComplete?.call()` instead of `Navigator.maybePop()`
- Import `AuthService` and `profile_validation.dart`

### 4. Premium Route Update
In `lib/features/profile/profile_creation_screen.dart`:
- Update `premiumProfileCreationRoute()` to accept `VoidCallback? onComplete`
- Pass it to `ProfileCreationScreen`

### 5. AuthGate Helper
Create `lib/core/supabase/auth_gate.dart`:
- `static Future<void> navigateToTarget(BuildContext context)`
- Check `AuthService.currentSession`
- If no session → `LoginScreen`
- If session → call `SupabaseProfileRepository().checkProfileStatus()` (new method returning enum)
- Handle four states:
  - `ProfileStatus.complete` → `MainShell`
  - `ProfileStatus.incomplete` → `ProfileCreationScreen` with `onComplete` → `MainShell`
  - `ProfileStatus.missing` → `ProfileCreationScreen` with `onComplete` → `MainShell`
  - `ProfileStatus.error` → show error/retry UI; do NOT navigate to ProfileCreationScreen or MainShell
- Use `pushAndRemoveUntil` with `(route) => false`

### 6. ProfileRepository Interface Update
In `lib/features/profile/profile_repository.dart`:
- Add `Future<ProfileStatus> checkProfileStatus()` to abstract class
- Implement in `LocalProfileRepository` (returns `ProfileStatus.error` or local equivalent)
- Implement in `SupabaseProfileRepository` (queries DB, returns missing/incomplete/complete/error)

### 7. SplashScreen Update
In `lib/features/splash/splash_screen.dart`:
- Replace inline navigation with `await AuthGate.navigateToTarget(context)` after animation
- Keep existing animation unchanged

### 8. LoginScreen Update
In `lib/features/login_screen.dart`:
- Replace `Navigator.pushAndRemoveUntil(MainShell())` with `await AuthGate.navigateToTarget(context)`

### 9. PhoneAuthScreen Update
In `lib/features/phone_auth_screen.dart`:
- Replace `Navigator.pushAndRemoveUntil(MainShell())` with `await AuthGate.navigateToTarget(context)`

### 10. Validation
- `flutter analyze` passes
- Test all auth flows route through gate
- Test profile completion navigates to MainShell
- Test incomplete profile stays on ProfileCreationScreen
- Test sign out → sign in re-evaluates gate
- Verify RLS prevents cross-user access
- Test network failure does NOT grant MainShell access
- Test network failure surfaces error/retry state (not silently treated as missing)

## Key Design Decisions

### ID Strategy
`profiles.id` is explicitly set to `AuthService.currentUser!.id` in application code. Database `DEFAULT auth.uid()` is a safety net only, not the primary mechanism.

### Profile Completion Logic
`saveProfile()` uses existing `validateDraft()` from `profile_validation.dart` to determine `profile_completed`. The database flag reflects actual completion status, not a hardcoded true.

### Error Handling
`checkProfileStatus()` returns `ProfileStatus.error` on Supabase/network failure. `AuthGate` treats this distinctly from `missing`/`incomplete`/`complete`. On error, show an error/retry UI and do NOT navigate to `ProfileCreationScreen` or `MainShell`. The user must retry or sign out.

### Draft vs Profile Persistence
- Drafts stay local (SharedPreferences via `LocalProfileRepository`)
- Profiles go to Supabase
- `SupabaseProfileRepository` delegates drafts to `LocalProfileRepository`

### Navigation Centralization
- `AuthGate.navigateToTarget()` is the single decision point
- Called from `SplashScreen`, `LoginScreen`, `PhoneAuthScreen`
- Not scattered across feature screens (Plans, People, etc.)

### onComplete Callback
- Added to `ProfileCreationScreen` to handle post-completion navigation
- Default: `Navigator.maybePop()` (preserves existing ProfileScreen flow)
- From gate: navigates to `MainShell`

## Files Modified/Created

### Created
- `supabase/migrations/20260809000000_create_profiles_table.sql`
- `lib/core/supabase/auth_gate.dart`

### Modified
- `lib/features/profile/profile_repository.dart` — add `ProfileStatus` enum, `checkProfileStatus()`, `SupabaseProfileRepository`
- `lib/features/profile/profile_creation_screen.dart` — use `auth.uid()`, add `onComplete`, import validation
- `lib/features/splash/splash_screen.dart` — use `AuthGate`
- `lib/features/login_screen.dart` — use `AuthGate`
- `lib/features/phone_auth_screen.dart` — use `AuthGate`

## Risks
- `SupabaseProfileRepository` instantiated before `Supabase.initialize()` — mitigated by init order in `main()`
- Network failure during profile check — shows error/retry UI; does NOT grant MainShell access
- Race condition in `SplashScreen` profile check — handled by awaiting `AuthGate`

## Open Questions
None. Ready to implement.
