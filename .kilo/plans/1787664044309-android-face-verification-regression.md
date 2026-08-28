# Android Face Verification Regression — Investigation & Fix Plan

## 1. Commit(s) Found Related to Face Verification

| Commit | Message |
|--------|---------|
| `3edfec8` | chore: connect face verification to railway production |
| `c3546a1` | chore: add face verification fixes |
| `1fdf54a` | feat: stabilize profile image and face verification |
| `5a964be` | feat: add premium multi-angle face verification |
| `ffc03a0` | fix: restore web face verification multipart transport |
| `b920d1e` | feat: privacy and verification complete |

## 2. Last Known-Good Implementation

**Commit:** `b920d1e` — `feat: privacy and verification complete`

This commit represents the completed Privacy & Verification module where Face Verification was fully implemented and working on Android.

## 3. Files That Changed Between `b920d1e` and HEAD (Face Verification Relevant)

- `lib/features/profile/verification/three_angle_capture_screen.dart` — Complete rewrite (new verification flow UI)
- `lib/features/profile/face_verification_client.dart` — Image normalization added
- `lib/features/profile/privacy_verification_screen.dart` — Permission debug logging added
- `lib/features/profile/selfie_capture_screen.dart` — Image normalization added
- `android/app/src/main/AndroidManifest.xml` — Added `android:showWhenLocked`, `android:turnScreenOn`
- `android/app/build.gradle.kts` — Added Firebase/google-services, coreLibraryDesugaring, `minSdk = 23`
- `android/build.gradle.kts` — Added Firebase classpath
- `pubspec.yaml` — Added Firebase/push notification packages

## 4. Exact Android-Specific Difference Causing Regression

### Root Cause
The current `lib/features/profile/verification/three_angle_capture_screen.dart` has an **Android-specific permission gate** in `_onVerifyTapped()` that blocks the Railway request before it ever fires:

```dart
Future<void> _onVerifyTapped() async {
  if (_processing) return;
  setState(() => _processing = true);
  
  if (Platform.isAndroid) {
    final granted = await _requestCameraPermission();  // <-- BLOCKS HERE
    if (!granted) {
      _onPermissionDenied();
      return;  // <-- EXITS BEFORE RAILWAY REQUEST
    }
  }
  
  // Railway request never reached on Android if permission denied
  _beginVerification();
}
```

The `_requestCameraPermission()` method:
```dart
Future<bool> _requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isPermanentlyDenied) {
    _showPermissionPermanentDialog();
    return false;
  }
  return status.isGranted;
}
```

### Why This Is the Regression
- At commit `b920d1e`, the flow used `ImagePicker().pickImage(source: ImageSource.camera, ...)` **directly** without any pre-check for Android camera permission.
- `ImagePicker` internally handles Android runtime permission prompts.
- The new `ThreeAngleCaptureScreen._onVerifyTapped()` adds an explicit `Platform.isAndroid` permission gate that **requires** `Permission.camera` to be granted **before** the Railway request is ever initiated.
- On Android 13+ (`targetSdk >= 33`), `android.permission.CAMERA` is a dangerous runtime permission. If the user has denied it, or if the permission state is not yet granted, `_requestCameraPermission()` returns `false` and `_onPermissionDenied()` pops the screen — **Railway is never called**.

### Why Web/iOS Remain Unaffected
- **Web:** No camera runtime permission model; `Platform.isAndroid` check is skipped.
- **iOS:** Uses `Info.plist` camera description; `ImagePicker` handles iOS permission internally. The Android-specific gate is not executed.
- **Android only:** The `if (Platform.isAndroid)` gate is the sole blocker.

## 5. Proposed Minimal Fix

### Option A (Recommended — Smallest, matches old behavior)
Remove the Android-specific permission gate in `_onVerifyTapped()` and let `ImagePicker().pickImage()` handle camera permission internally, as it did at `b920d1e`.

**Change:** In `lib/features/profile/verification/three_angle_capture_screen.dart`, remove the `if (Platform.isAndroid)` block from `_onVerifyTapped()`.

### Option B (If permission UX is desired)
Move the permission request **before** `ThreeAngleCaptureScreen` is shown, or handle `Permission.camera.request()` denial by still proceeding to `ImagePicker` (which will show its own permission UI).

### Verification Plan
1. Add temporary debug logging to `_onVerifyTapped()` to confirm execution stops at `_requestCameraPermission()` on Android.
2. Apply Option A fix.
3. Run `flutter analyze`.
4. Build APK with `.\tool\build_apk.ps1` (do not run `flutter run` or `flutter build`).
5. Verify on Android device/emulator that tapping "Verify Now" now reaches Railway.

## 6. Open Questions / Risks

- **Risk:** Removing the permission gate means Android users who have permanently denied camera permission will see ImagePicker's error instead of the custom dialog. This matches the old behavior at `b920d1e`.
- **Risk:** The `minSdk = 23` change in `android/app/build.gradle.kts` is already in place and matches Android 6.0+ runtime permission model.
- **Validation:** No existing unit tests cover this flow (`test/widget_test.dart` is the only test). Manual Android verification required.
