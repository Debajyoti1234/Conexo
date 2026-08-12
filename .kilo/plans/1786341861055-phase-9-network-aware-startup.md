# Phase 9.3 — Network-Aware Startup: Implementation Plan

Status: READY FOR IMPLEMENTATION. No unresolved decisions.

---

## 1. ROOT CAUSE

`main()` in `lib/main.dart` awaits `SupabaseClientConfig.initialize()` and `GoogleSignIn.instance.initialize()` **before** calling `runApp()`. If the device has no network, `Supabase.initialize()` hangs or fails during this await. The Flutter first frame never renders, producing a blank screen instead of the splash animation.

The existing `SplashScreen` has an error state (`_showError`) but it is only reached **after** the 4.7s animation completes — which never happens if `runApp()` itself is blocked.

---

## 2. FILES TO MODIFY

| File | Change |
|------|--------|
| `lib/main.dart` | Remove `await SupabaseClientConfig.initialize()` and `await GoogleSignIn.instance.initialize()` from `main()`. Call `runApp()` immediately. |
| `lib/features/splash/splash_screen.dart` | Add network check after animation completes; show premium "No Network" state when offline; initialize Supabase/Google only after network is confirmed; wire retry to re-run the same flow. |

No new files, no new dependencies, no package additions.

---

## 3. MAIN.DART CHANGE

Remove the two `await` calls from `main()`. The app must render its first frame unconditionally:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConexoApp());
}
```

`SupabaseClientConfig.initialize()` and `GoogleSignIn.instance.initialize()` move to the splash screen's post-animation callback, after the network check passes.

---

## 4. SPLASH SCREEN CHANGES

### 4a. Network check method

Private method on `_SplashScreenState`, using `dart:io` `InternetAddress.lookup` with a 3-second timeout:

```dart
Future<bool> _hasNetwork() async {
  try {
    final result = await InternetAddress.lookup('supabase.com').timeout(
      const Duration(seconds: 3),
    );
    return result.isNotEmpty;
  } on UnsupportedError {
    // dart:io unavailable (web) — proceed without check
    return true;
  } on Exception {
    return false;
  }
}
```

### 4b. Post-animation flow

After the animation's `addStatusListener` fires with `completed`, insert the network check **before** any Supabase/auth work:

```dart
// 1. Network check first
final hasNetwork = await _hasNetwork();
if (!hasNetwork) {
  setState(() {
    _showError = true;
    _errorMessage = 'No network connection';
  });
  return;
}

// 2. Initialize Supabase + Google (moved from main())
await SupabaseClientConfig.initialize();
await GoogleSignIn.instance.initialize(
  serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
);

// 3. Existing auth flow continues unchanged
final hasSession = AuthService.currentSession != null;
// ... rest of existing logic
```

### 4c. Retry button

The existing `_retry()` method restarts the animation. When it completes again, the flow re-checks network and either proceeds or shows the No Network state. No changes needed to `_retry()` itself.

### 4d. No Network state UI

Premium overlay matching the existing splash dark aesthetic. Added to the existing `_showError` branch in `build()`:

```dart
if (_showError) {
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF090B14), Colors.black],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Subtle glow behind icon
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: Color(0xFFB7A5FF),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _errorMessage ?? 'Something went wrong',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Connect to the internet to continue.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _RetryButton(onPressed: _retry),
            ],
          ),
        ),
      ),
    ),
  );
}
```

### 4e. Retry button widget

Private widget matching the Conexo glass-button language:

```dart
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF587BE2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Try Again',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. LIVE LOCATION TRACKER SAFETY (no changes needed)

`LiveLocationTracker._getPosition()` already returns `null` on any exception. `_tick()` already returns early if `position == null` or `AuthService.currentUser == null`. Network failures during periodic location writes are silently swallowed. No changes required.

---

## 6. WHAT IS NOT CHANGED

| Item | Status |
|------|--------|
| Splash animation (4.7s, ambient background, logo, title, tagline) | Untouched |
| Auth flow (`_ensureFirstLaunchPermissions`, `AuthGate.navigateToTarget`) | Untouched |
| Navigation rules | Untouched |
| Profile creation / management | Untouched |
| Live location tracker | Untouched |
| Supabase client config | Untouched (initialization moved, not modified) |
| Existing error state for `AuthGate` returning null | Untouched |

---

## 7. VALIDATION

| Test | Expected Result |
|------|-----------------|
| Internet ON → launch | Splash animation → auth flow → normal app |
| Internet OFF before launch | Splash renders → animation plays → No Network state appears |
| Tap Retry while offline | No Network state remains, no blank screen |
| Turn internet ON → tap Retry | Network check passes → Supabase init → auth flow |
| Disconnect while app running | No crash, no blank screen (tracker silently fails) |
| Live location network failure | Silent fail, no UI impact |
| `flutter analyze` | No issues |
| `.\tool\build_apk.ps1` | Success |

---

## 8. IMPLEMENTATION ORDER

1. Modify `lib/main.dart` — remove blocking awaits
2. Modify `lib/features/splash/splash_screen.dart` — add `_hasNetwork()`, insert network check in post-animation flow, add No Network state UI, add `_RetryButton`
3. `flutter analyze`
4. `.\tool\build_apk.ps1`
