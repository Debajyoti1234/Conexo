# Conexo Phase 8 — Supabase Email Authentication
## Architecture Inspection Report

**Branch:** conexo-supabase (HEAD d49e646)
**Date:** 2026-08-09
**Scope:** Inspection only — no files modified

---

### 1. Current Authentication Architecture

```
SplashScreen (lib/features/splash/splash_screen.dart)
  → OnboardingScreen (lib/features/onboarding_screen.dart)
    → LoginScreen (lib/features/login_screen.dart)
      → SignupScreen (lib/features/signup_screen.dart)
        → PhoneAuthScreen (lib/features/phone_auth_screen.dart)
          → MainShell (lib/features/main_shell.dart) ← "authenticated" destination
```

**Key finding:** Authentication is currently **entirely UI-only**. No backend, no service, no provider, no state management exists.

- **LoginScreen** (`lib/features/login_screen.dart:29-36`): `_continueToConexo()` validates the form and pushes `MainShell` directly via `Navigator.pushAndRemoveUntil`. There is no auth call.
- **SignupScreen** (`lib/features/signup_screen.dart:32-48`): `_submit()` validates the form and navigates to `PhoneAuthScreen`. On success, `PhoneAuthScreen._verify()` (`lib/features/phone_auth_screen.dart:33-38`) pushes `MainShell`. There is no auth call.
- **Logout** (`lib/features/profile/my_profile_screen.dart:114`): `_logout()` shows a "coming soon" SnackBar. No logout logic exists.
- **Forgot password** (`lib/features/login_screen.dart:83`): `onForgot: () {}` — empty callback. No forgot-password UI exists.
- **Validators** are pure functions in `login_screen.dart:130-144` and `signup_screen.dart:155-167`. They are UI-only and must not change.
- **No Riverpod providers exist** for authentication. The `pubspec.yaml` includes `flutter_riverpod: ^2.6.1` but it is unused in the auth flow.

---

### 2. Current Supabase Architecture

```
main.dart
  → SupabaseClientConfig.initialize()  (lib/core/supabase/supabase_client.dart:14-27)
    → Supabase.initialize(url, publishableKey)
  → runApp(const ConexoApp())
    → MaterialApp(home: const SplashScreen())
```

**Key files:**

- **`lib/main.dart:10`** — Calls `SupabaseClientConfig.initialize()` before `runApp()`.
- **`lib/core/supabase/supabase_client.dart`** — Abstraction layer:
  - `url` and `publishableKey` loaded from `--dart-define` (`String.fromEnvironment`)
  - `client` getter exposes `Supabase.instance.client`
  - Throws `StateError` if credentials are missing
- **No auth service, no auth provider, no session listener, no deep-link handler in Dart code.**

---

### 3. Proposed Implementation — Files That Need to Change

| File | Why | Responsibility | What stays unchanged |
|------|-----|---------------|---------------------|
| `lib/features/login_screen.dart` | Wire sign-in to Supabase | Call `SupabaseClientConfig.client.auth.signInWithPassword()` on submit, show loading/error/success, navigate to `MainShell` on success | Validators, UI layout, colors, navigation structure |
| `lib/features/signup_screen.dart` | Wire sign-up to Supabase | Call `SupabaseClientConfig.client.auth.signUp()` on submit, show loading state, navigate to a confirmation screen or show confirmation message | Validators, UI layout, interest chips, navigation to `PhoneAuthScreen` (keep as secondary option) |
| `lib/features/phone_auth_screen.dart` | Keep as secondary path, no changes needed for email auth | No changes — remains as alternative phone auth placeholder | Entire file unchanged |
| `lib/core/supabase/supabase_client.dart` | May add auth helper methods | Could add convenience methods like `currentUser`, `currentSession` getters | Initialization logic unchanged |
| `lib/features/splash/splash_screen.dart` | Session restoration | Check `SupabaseClientConfig.client.auth.currentSession` before navigating to onboarding — if session exists, skip to `MainShell` | Splash animation unchanged |
| `lib/features/profile/my_profile_screen.dart` | Wire logout | Replace `_placeholder('Logout')` with `SupabaseClientConfig.client.auth.signOut()` + navigate to `LoginScreen` | Profile UI unchanged |
| **NEW** `lib/core/supabase/auth_service.dart` | Centralize auth logic | Encapsulate sign-in, sign-up, sign-out, password reset, session check | N/A — new file |
| **NEW** `lib/features/auth/confirm_email_screen.dart` | Email confirmation handling | Show "check your email" UI after sign-up, handle deep-link callback `com.conexo://login-callback/` | N/A — new file |

**Files that will NOT be modified:**
- `auth_components.dart` — UI components unchanged
- `app_router.dart` — routing unchanged
- `main_shell.dart` — authenticated shell unchanged
- `onboarding_screen.dart` — unchanged
- `secondary_screens.dart` — unchanged
- `pubspec.yaml` — no new dependencies
- AndroidManifest.xml — deep-link config already exists
- All profile, chat, plans, notification files — no changes

---

### 4. Proposed Auth Flow

**SIGN UP:**
```
User fills SignupScreen form
  → validators pass
  → AuthService.signUp(email, password, name)
    → Supabase.auth.signUp()
    → Supabase sends confirmation email to user
  → Show confirmation screen ("Check your email")
  → User clicks link in email (com.conexo://login-callback/)
  → Deep-link handler receives callback
  → Supabase verifies token
  → Session is established
  → Navigate to MainShell
```

**SIGN IN:**
```
User fills LoginScreen form
  → validators pass
  → AuthService.signIn(email, password)
    → Supabase.auth.signInWithPassword()
    → Supabase returns session
  → Session persisted by Supabase client
  → Navigate to MainShell (pushAndRemoveUntil)
```

**SIGN OUT:**
```
User taps Logout in ProfileScreen
  → AuthService.signOut()
    → Supabase.auth.signOut()
    → Session cleared
  → Navigate to LoginScreen (pushAndRemoveUntil)
```

---

### 5. Session Strategy

Use **Supabase's built-in session persistence** — do not create duplicate auth state.

1. **Initialization:** `Supabase.initialize()` in `main.dart` runs before `runApp()`. The Supabase Flutter client automatically persists the session to local storage (SharedPreferences under the hood via `supabase_flutter`).

2. **Session restoration:** On app launch, after `Supabase.initialize()`, check `SupabaseClientConfig.client.auth.currentSession`. If a valid session exists, skip `SplashScreen → OnboardingScreen → LoginScreen` and navigate directly to `MainShell`.

3. **Auth state changes:** Listen to `SupabaseClientConfig.client.auth.onAuthStateChanged` stream. This stream emits `AuthChangeEvent` (signedIn, signedOut, tokenRefreshed, etc.). Use this to reactively update navigation — if the session becomes invalid, route to `LoginScreen`.

4. **No duplicate state:** The existing app has no auth state. We will not introduce Riverpod providers for auth state. Instead, the `SplashScreen` will perform a one-time session check, and the auth state stream will handle runtime changes. This keeps the architecture minimal and aligned with the existing codebase patterns (no Riverpod in auth).

---

### 6. Error Mapping

Supabase auth errors will be mapped to the existing UI without changing validators:

| Supabase error | Mapping |
|---------------|---------|
| `Invalid login credentials` | Show SnackBar: "Invalid email or password" |
| `Email not confirmed` | Show SnackBar: "Please confirm your email first" |
| `User already registered` | Show SnackBar: "An account with this email already exists" |
| `Password too weak` | Show SnackBar: "Password must be at least 8 characters" (validator already enforces this, but Supabase may have additional rules) |
| `Network error` | Show SnackBar: "Network error. Please try again." |
| `Too many requests` | Show SnackBar: "Too many attempts. Please wait and try again." |

**Loading states:** The existing `PrimaryButton` widget (`auth_components.dart:517-575`) does not have a loading state. We will either:
- Option A: Wrap the button with a local `_isLoading` state in the screen's `State` class (minimal change)
- Option B: Show a modal progress indicator during auth calls

**Error display:** Use `ScaffoldMessenger.showSnackBar()` — consistent with the existing `_placeholder()` pattern in `my_profile_screen.dart:116-123`.

**Validators are NOT changed** — they run before the Supabase call. Supabase errors that relate to format (email validity, password length) are caught by validators first.

---

### 7. Deep-Link Strategy

**Scheme:** `com.conexo://login-callback/` (already configured in AndroidManifest.xml:28-38)

1. **Supabase dashboard config** — Already set:
   - Site URL: `com.conexo://login-callback/`
   - Allowed Redirect URL: `com.conexo://login-callback/`

2. **App-side handling:**
   - Add a `SupabaseAuthListener` widget (or use `onAuthStateChanged` stream) at the app root level that listens for auth state changes.
   - When `AuthChangeEvent.signedIn` fires after email confirmation via deep link, navigate to `MainShell`.
   - The `supabase_flutter` package handles the deep-link parsing automatically via its internal `AuthWebView` / `AuthDeepLink` mechanism.

3. **No additional deep-link code needed** in AndroidManifest — the existing intent-filter handles it.

---

### 8. Dependencies

**ZERO new dependencies required.**

- `supabase_flutter: ^2.17.1` — Already in `pubspec.yaml:32`. Contains all needed auth APIs (`signInWithPassword`, `signUp`, `signOut`, `onAuthStateChanged`, etc.).
- `flutter_riverpod: ^2.6.1` — Already in `pubspec.yaml:28` but unused for auth. We will NOT introduce Riverpod for auth state — the existing pattern is stateful widgets + Supabase's built-in stream.
- No other packages needed.

---

### 9. Risks

1. **No auth state management exists.** The app currently assumes any navigation to `MainShell` means "authenticated." We must ensure that session checks happen before navigation, not after. Risk: a user could manually navigate to `MainShell` without a valid session.

2. **SplashScreen → OnboardingScreen → LoginScreen is hardcoded.** If we add session restoration to `SplashScreen`, we need to ensure the animation completes gracefully and doesn't flash the onboarding screen before redirecting.

3. **PhoneAuthScreen is a placeholder.** It currently navigates directly to `MainShell` without any real verification. This should remain as-is for Phase 8 (email auth only) but could confuse users if both signup paths are visible.

4. **Supabase auth state stream vs widget lifecycle.** The `onAuthStateChanged` stream must be listened to at a lifecycle-aware point. Listening in `SplashScreen` or a new root-level widget is appropriate. If the listener is in a screen that gets disposed, auth state changes will be missed.

5. **Email confirmation flow depends on external email client.** If the user doesn't have an email app configured, the confirmation flow breaks. We should provide a "Resend email" option.

6. **No error boundary.** The existing app has no error handling for auth failures beyond SnackBars. A `try/catch` around every Supabase call is mandatory.

---

### 10. Exact Change Plan

**Phase 8a — Auth Service (new file)**
1. Create `lib/core/supabase/auth_service.dart` with:
   - `Future<AuthResponse> signIn(String email, String password)`
   - `Future<AuthResponse> signUp(String email, String password, String name)`
   - `Future<void> signOut()`
   - `Future<void> resetPassword(String email)`
   - `Stream<AuthState> get authStateChanges` (wraps `client.auth.onAuthStateChanged`)
   - `User? get currentUser`
   - `Session? get currentSession`
   - Centralized error mapping (Supabase error → user-friendly message)

**Phase 8b — LoginScreen wiring**
2. In `lib/features/login_screen.dart`:
   - Add `_isLoading` state
   - Add `_errorMessage` state
   - On "Continue to Conexo" press: call `AuthService.signIn()`, show loading on button, on success navigate to `MainShell`, on error show SnackBar
   - Wire `onForgot` to navigate to a password reset flow (or show email SnackBar if UI not built yet)

**Phase 8c — SignupScreen wiring**
3. In `lib/features/signup_screen.dart`:
   - Add `_isLoading` state
   - On "Create my account" press: call `AuthService.signUp()`, show loading, on success navigate to confirmation screen
   - Create `lib/features/auth/confirm_email_screen.dart` — shows "Check your email" with resend option

**Phase 8d — SplashScreen session restoration**
4. In `lib/features/splash/splash_screen.dart`:
   - After animation completes, check `AuthService.currentSession`
   - If session exists → navigate to `MainShell`
   - If no session → navigate to `OnboardingScreen` (existing behavior)

**Phase 8e — Logout wiring**
5. In `lib/features/profile/my_profile_screen.dart:114`:
   - Replace `_placeholder('Logout')` with `await AuthService.signOut()` + navigate to `LoginScreen`

**Phase 8f — Auth state listener**
6. Add a top-level `AuthStateListener` widget (or use `SplashScreen` + `MaterialApp.router` pattern) that listens to `AuthService.authStateChanges` and redirects to `LoginScreen` when `signedOut` event fires.

**Validation:**
- Run `flutter analyze` — must pass
- Run `flutter run` — app launches, can sign up, receive email, confirm, sign in, see `MainShell`
- Run `flutter run` — app launches with existing session → skips to `MainShell`
- Logout → returns to `LoginScreen`
