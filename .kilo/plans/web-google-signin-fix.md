# Conexo — Web Google OAuth Redirect Fix

PLAN MODE ONLY. No source changes. Investigative findings and implementation plan.

## 1. ROOT CAUSE

`lib/core/supabase/auth_service.dart` calls `signInWithOAuth(OAuthProvider.google)` on Web **without** a `redirectTo` parameter.

When `redirectTo` is omitted, Supabase falls back to the **Site URL / default redirect URL** configured in the Supabase Dashboard. That value is currently the Android deep link:

```
com.conexo://login-callback/
```

Android handles this via the intent-filter in `AndroidManifest.xml`. Chrome on Web does not, producing:

```
Failed to launch 'com.conexo://login-callback/...'
because the scheme does not have a registered handler.
```

**Source of `com.conexo://login-callback/`:**
- `android/app/src/main/AndroidManifest.xml:42-44` — intent-filter with `android:scheme="com.conexo"` and `android:host="login-callback"`
- Supabase Dashboard Authentication → URL Configuration — Site URL and/or Allowed Redirect URLs set to `com.conexo://login-callback/`

**Confirmed:** The auth_service.dart code itself does not hardcode `com.conexo://login-callback/`. It originates from the Supabase Dashboard default.

---

## 2. FILES THAT WOULD CHANGE

| File | Change |
|---|---|
| `lib/core/supabase/auth_service.dart` | Add `redirectTo` to Web `signInWithOAuth` call |

No other source files require modification.

---

## 3. EXACT MINIMAL CHANGE

### `lib/core/supabase/auth_service.dart`

In the Web branch of `signInWithGoogle()`, change:

```dart
await _client.auth.signInWithOAuth(
  OAuthProvider.google,
);
```

To:

```dart
await _client.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'http://localhost:5000/',
);
```

**Why this works:**
- Explicit `redirectTo` overrides the Supabase Dashboard default.
- After Google authentication, Supabase redirects to `http://localhost:5000/` instead of `com.conexo://login-callback/`.
- The Flutter Web app reloads at `http://localhost:5000/`, `main()` runs, `SplashScreen` detects the restored Supabase session, and `AuthGate.navigateToTarget()` routes the user to the correct destination.
- Android flow is completely unchanged (it uses `signInWithIdToken`, not `signInWithOAuth`).

---

## 4. ANDROID vs WEB REDIRECT BEHAVIOR AFTER FIX

| Platform | Redirect Target | How |
|---|---|---|
| Android | `com.conexo://login-callback/` | Existing deep-link intent-filter in `AndroidManifest.xml`. Supabase Dashboard default remains unchanged. |
| Web | `http://localhost:5000/` | Explicit `redirectTo` parameter in `signInWithOAuth`. |

**Android is not modified.** The Android deep link, Supabase Dashboard default, and `signInWithIdToken` flow all remain untouched.

---

## 5. EXTERNAL CONFIGURATION CHANGES REQUIRED

These are **not code changes**. They are one-time dashboard/console updates.

### Supabase Dashboard
**Authentication → URL Configuration:**
- Add `http://localhost:5000/` to **Allowed Redirect URLs**

### Google Cloud Console
**APIs & Services → Credentials → OAuth 2.0 Client ID (Web):**
- Add `http://localhost:5000` to **Authorized JavaScript origins**

### Production (future)
When the production Conexo HTTPS Web domain is ready:
- Replace `http://localhost:5000/` in the `redirectTo` parameter with the production HTTPS URL
- Add the production URL to Supabase Allowed Redirect URLs
- Add the production origin to Google Cloud Authorized JavaScript origins

---

## 6. HOW WEB REDIRECT IS SELECTED

The `redirectTo` is passed explicitly in the Web branch of `signInWithGoogle()`. Supabase uses this value instead of the dashboard default. No conditional logic is needed beyond the existing `kIsWeb` check.

---

## 7. SUPABASE OAUTH SESSION RESTORATION ON WEB

After redirect back to `http://localhost:5000/`:
1. Flutter Web app reloads
2. `main()` → `SupabaseClientConfig.initialize()` runs
3. `Supabase.initialize()` restores the session from the URL hash/callback
4. `authStateChanges` fires `signedIn`
5. `SplashScreen._attemptStartup()` detects `AuthService.currentSession != null`
6. `AuthGate.navigateToTarget()` routes to the correct destination

This preserves the existing Conexo navigation behavior. No new routes, screens, or callback handlers are needed.

---

## 8. CONFIRMATION — NO OTHER CHANGES REQUIRED

- **Database:** No migrations, schema, RLS, or RPC changes.
- **Dependencies:** No `pubspec.yaml` changes.
- **Android:** Zero changes. Deep link, GoogleSignIn flow, and dashboard defaults are untouched.
- **LoginScreen UI:** No changes. Button calls `AuthService.signInWithGoogle()` as before.
- **SplashScreen / AuthGate:** No changes. Existing session-detection logic handles post-OAuth navigation.
- **`web/index.html`:** No changes.
- **`tool/run.ps1` / `tool/build_apk.ps1`:** No changes.

---

## 9. RISKS AND EDGE CASES

| Risk | Mitigation |
|---|---|
| `http://localhost:5000/` not in Supabase Allowed Redirect URLs | Supabase shows an error page. Clear user-visible message. Easy to diagnose and fix in dashboard. |
| `http://localhost:5000` not in Google Cloud Authorized origins | Google OAuth fails with origin mismatch error. Clear error shown. Fix in Google Cloud Console. |
| User denies Google consent | Supabase returns error; splash screen shows onboarding. No crash. |
| Redirect URL hardcoded for local dev | Production requires updating the `redirectTo` value. Documented in plan. |
| `signInWithOAuth` redirect suspends app | Expected behavior on Web. App reloads on return; splash handles session. |

---

## 10. VALIDATION PLAN

### Web (`.\tool\run.ps1 -d chrome --web-port 5000`)
1. `flutter analyze` → No issues found
2. App launches on `http://localhost:5000/` → splash screen loads
3. Supabase initializes
4. Tap "Sign in with Google" → browser redirects to Google OAuth
5. Complete Google authentication → browser redirects to `http://localhost:5000/`
6. App reloads → SplashScreen → session detected → `AuthGate.navigateToTarget()` → correct destination
7. **No** `com.conexo://login-callback/` redirect
8. **No** "Network error. Please try again." for normal OAuth flow

### Android (`.\tool\run.ps1`)
1. App launches → splash screen loads
2. Tap "Sign in with Google" → Google account picker (native)
3. Select account → `signInWithIdToken` → session created
4. Navigate to target
5. Existing behavior **completely unchanged**

---

## 11. IMPLEMENTATION ORDER

1. Modify `lib/core/supabase/auth_service.dart`:
   - Add `redirectTo: 'http://localhost:5000/'` to the Web `signInWithOAuth` call
2. Run `flutter analyze`
3. Validate Web with `.\tool\run.ps1 -d chrome --web-port 5000`
4. Validate Android with `.\tool\run.ps1`
5. Stop and report results
