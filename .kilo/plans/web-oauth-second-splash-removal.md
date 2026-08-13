# Conexo Web OAuth Second-Splash Removal

## 1. Root Cause

On Flutter Web, `signInWithOAuth` causes a full page navigation. When the browser redirects back to `http://localhost:5000/`, the Flutter app restarts from `main()`. The startup sequence is:

```
main() → runApp(ConexoApp()) → home: SplashScreen()
  → SplashScreen starts 4.7s animation
  → Animation completes → _attemptStartup()
    → SupabaseClientConfig.initialize()
      → SupabaseAuth.initialize()
        → _handleInitialUri() detects auth params in URL
        → getSessionFromUrl() exchanges tokens
        → clearAuthUrlParameters() clears the URL
    → Session restored (currentUser != null)
    → AuthGate.navigateToTarget()
```

Because `SupabaseClientConfig.initialize()` is called AFTER the 4.7s animation, the animation always plays in full on Web reload — including OAuth returns.

## 2. Deterministic OAuth-Return Signal

`supabase_flutter` v2.17.1 provides a **deterministic, built-in signal**:

- After OAuth redirect, the browser URL contains auth parameters (`access_token`, `code`, etc.) in the query or fragment.
- `SupabaseAuth._handleDeeplink()` processes these parameters during `Supabase.initialize()` and then calls `clearAuthUrlParameters()` (via `window.history.replaceState`) to remove them.
- Therefore: **auth parameters are present in `Uri.base` from page load until `Supabase.initialize()` completes.**

This is not a heuristic — it's a guaranteed property of the existing Supabase Web OAuth implementation.

**Detection strategy:**
1. In `SplashScreen.initState()`, check `Uri.base` for auth callback parameters BEFORE `Supabase.initialize()` runs → store in `_urlHadAuthParams`
2. Start `SupabaseClientConfig.initialize()` early (overlaps with splash animation)
3. Listen for `SupabaseClientConfig.ready`
4. When ready, check `AuthService.currentUser != null`
5. If both `_urlHadAuthParams` AND `currentUser != null` → **deterministic OAuth return** → stop animation and navigate
6. If either is false → normal splash flow

**Auth parameters checked** (matching `SupabaseAuth._defaultIsAuthCallbackDeeplink`):
- `access_token`, `code`, `error`, `error_code`, `error_description`

## 3. Files That Would Change

| File | Change |
|------|--------|
| `lib/features/splash/splash_screen.dart` | Add early Supabase init, URL check, OAuth-return detection, and animation short-circuit |

**No other files change.** `main.dart`, `AuthService`, `AuthGate`, `LoginScreen`, `LiveLocationTracker`, `PermissionManager`, and all Android code remain untouched.

## 4. Exact Functions/Sections That Would Change

In `lib/features/splash/splash_screen.dart`:

- **`_SplashScreenState.initState()`** — Add:
  - `_urlHadAuthParams` detection from `Uri.base` (Web only)
  - Early `SupabaseClientConfig.initialize()` call if not already started
  - `SupabaseClientConfig.ready.then(...)` listener that checks for OAuth return and stops the animation

- **Add `_hasAuthParameters(Uri uri)`** — Private static method matching `SupabaseAuth._defaultIsAuthCallbackDeeplink` logic

- **Add `_triggerStartup()`** — Guarded startup trigger to prevent `_attemptStartup()` from executing twice (animation completion + OAuth detection)

## 5. Why the Change Is Safe

- **Web-only guard:** All new logic wrapped in `if (kIsWeb)`. Android, iOS, desktop unaffected.
- **No new dependencies:** Uses only existing imports (`SupabaseClientConfig`, `AuthService`, `kIsWeb`, `Uri.base`).
- **No new routes or screens:** Does not create `/auth-callback` or any callback screen.
- **Preserves routing:** `AuthGate.navigateToTarget()` remains the single source of truth.
- **Preserves splash for normal launches:** If `_urlHadAuthParams` is false (normal launch) or `currentUser` is null (failed OAuth), animation plays fully.
- **Graceful fallback:** If detection logic throws, animation plays normally.
- **No changes to OAuth flow:** `AuthService.signInWithGoogle()`, `redirectTo`, and Supabase config untouched.
- **Deterministic signal:** Relies on `supabase_flutter`'s own URL-clearing behavior, not time-based heuristics.

## 6. Normal Launch Behavior After the Fix

**Cold launch with no session (all platforms):**
- `_urlHadAuthParams` = false (no auth params in URL)
- Animation plays for full 4.7 seconds
- No session detected → navigate to Login
- **Unchanged.**

**Authenticated reload with old session (all platforms):**
- `_urlHadAuthParams` = false (URL was cleared on previous load, or never had params)
- Animation plays for full 4.7 seconds
- Navigate to AuthGate target
- **Unchanged.**

## 7. Web OAuth Behavior After the Fix

**OAuth return (Web only):**
1. Browser redirects to `http://localhost:5000/#access_token=...`
2. `main()` runs → `SplashScreen.initState()`
3. `_urlHadAuthParams` = true (URL contains auth params)
4. `SupabaseClientConfig.initialize()` starts (overlaps with animation)
5. Animation begins playing
6. `SupabaseAuth.initialize()` processes auth callback, calls `clearAuthUrlParameters()`
7. `SupabaseClientConfig.ready` completes (~1–3s)
8. `AuthService.currentUser != null` (session restored)
9. Animation is stopped immediately
10. `_triggerStartup()` → `AuthGate.navigateToTarget()` → navigate to app
11. User sees **~1–3 seconds of splash** instead of 4.7 seconds
12. **Full 4.7-second animation does NOT replay**

## 8. Android Behavior After the Fix

**Unchanged.** The `kIsWeb` guard ensures none of the new logic executes on Android. Android continues to:
1. Show splash animation for 4.7 seconds
2. `SupabaseClientConfig.initialize()` runs after animation (same as today)
3. Navigate via `AuthGate.navigateToTarget()`

No Android files are modified.

## 9. Validation Commands

```bash
flutter analyze
.\tool\run.ps1 -d chrome --web-port 5000
```

## 10. Manual Validation Steps

### Web (Chrome)

1. Run `.\tool\run.ps1 -d chrome --web-port 5000`
2. **Normal cold launch:** Confirm full Conexo splash animation plays (~4.7s), then Login appears
3. **Email/password login:** Confirm login works and routes correctly
4. **Google OAuth:** Tap Google button → complete auth → confirm redirect to `http://localhost:5000/`
5. **OAuth return:** Confirm full 4.7-second splash animation does NOT replay. App navigates to AuthGate destination
6. **No blank screen:** Confirm no white/blank screen
7. **No console errors:** Confirm no `UnimplementedError` or OAuth errors
8. **AuthGate routing:** Confirm correct destination (profile creation or main shell)

### Android

9. Run `.\tool\run.ps1`
10. Confirm splash animation behavior unchanged
11. Confirm Google Sign-In still works
12. Confirm routing after auth unchanged

## 11. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| False positive OAuth detection | None | None | Deterministic: requires BOTH auth params in URL AND valid session. Normal authenticated reloads have neither. |
| Animation stop causes visual glitch | Low | Minor | Frozen splash frame before navigation — expected and acceptable per requirements |
| `_attemptStartup()` called twice | Very Low | None | `_triggerStartup()` guard prevents double execution regardless of trigger source |
| Early Supabase init causes side effects | None | None | `SupabaseClientConfig.initialize()` is idempotent; second call in `_initializeServicesAndNavigate()` returns early |
| Android regression | None | None | `kIsWeb` guard prevents all new code from executing on Android |

## 12. Explicit List of Files That Will NOT Be Changed

- `lib/main.dart`
- `lib/core/services/live_location_tracker.dart`
- `lib/core/services/permission_manager.dart`
- `lib/core/supabase/auth_service.dart`
- `lib/core/supabase/auth_gate.dart`
- `lib/core/supabase/supabase_client.dart`
- `lib/features/login_screen.dart`
- `lib/app/router/app_router.dart`
- Any Android (`android/`) files
- Any iOS (`ios/`) files
- Any backend, database, RLS, or migration files
- `pubspec.yaml` (no new dependencies)
