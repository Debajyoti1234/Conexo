# Conexo Web Location Permission Compatibility Fix

## 1. Root Cause

`permission_handler` v11.3.0 does not implement Web platform interfaces for the following permission types: `locationWhenInUse`, `camera`, `photos`, `microphone`, `notifications`. Calling `.status` or `.request()` on any of these `ph.Permission` objects on Web throws `UnimplementedError`.

**Call chain 1 (primary reported crash):**
`main.dart:44` → `LiveLocationTracker.start()` → `_checkPermission()` → `PermissionManager.check(PermissionType.locationWhenInUse)` → `permission_handler` → **UnimplementedError**

**Call chain 2 (also crashes on Web after OAuth):**
`SplashScreen:96` → `_ensureFirstLaunchPermissions()` → iterates all 5 permissions → `PermissionManager.check()` for each → **UnimplementedError** on the first unsupported call.

## 2. Files That Need Modification

| File | Reason |
|------|--------|
| `lib/core/services/permission_manager.dart` | Single gateway for all permission checks/requests. Adding Web guards here prevents ALL unsupported Web permission crashes. |

**No other files need modification.** `LiveLocationTracker` and `SplashScreen` continue to call `PermissionManager` exactly as they do today.

## 3. Functions That Need Modification

In `lib/core/services/permission_manager.dart`:

- `PermissionManager.check()` — add `kIsWeb` guard
- `PermissionManager.request()` — add `kIsWeb` guard  
- `PermissionManager.isGranted()` — add `kIsWeb` guard
- `PermissionManager.isPermanentlyDenied()` — add `kIsWeb` guard

## 4. Minimal Platform-Conditional Strategy

Add `import 'package:flutter/foundation.dart';` to `permission_manager.dart`.

Create a private helper:

```dart
static bool get _isWeb => kIsWeb;

static bool _unsupportedOnWeb(PermissionType type) {
  return type != PermissionType.locationWhenInUse
      && type != PermissionType.camera
      && type != PermissionType.photos
      && type != PermissionType.microphone
      && type != PermissionType.notifications
      ? false
      : _isWeb;
}

static PermissionStatus _webSafeStatus(PermissionType type) {
  switch (type) {
    case PermissionType.locationWhenInUse:
      return PermissionStatus.granted;
    case PermissionType.camera:
    case PermissionType.photos:
    case PermissionType.microphone:
    case PermissionType.notifications:
      return PermissionStatus.denied;
  }
}
```

Guard the four public methods:

```dart
static Future<PermissionStatus> check(PermissionType type) async {
  if (_unsupportedOnWeb(type)) return _webSafeStatus(type);
  final status = await _toPermission(type).status;
  return _mapStatus(status);
}

static Future<PermissionStatus> request(PermissionType type) async {
  if (_unsupportedOnWeb(type)) return _webSafeStatus(type);
  final status = await _toPermission(type).request();
  return _mapStatus(status);
}

static Future<bool> isGranted(PermissionType type) async {
  if (_unsupportedOnWeb(type)) return _webSafeStatus(type) == PermissionStatus.granted;
  return await _toPermission(type).isGranted;
}

static Future<bool> isPermanentlyDenied(PermissionType type) async {
  if (_unsupportedOnWeb(type)) return false;
  return await _toPermission(type).isPermanentlyDenied;
}
```

**Web behavior rationale:**
- `locationWhenInUse` → `granted`: `geolocator` ^14.0.3 already handles browser geolocation natively. Returning `granted` lets `LiveLocationTracker` proceed to `Geolocator.getCurrentPosition()`, which triggers the browser's native permission prompt at the point of actual use.
- `camera`, `photos`, `microphone`, `notifications` → `denied`: These are not supported by `permission_handler` on Web. Their respective Flutter plugins (`image_picker`, etc.) have independent Web implementations that invoke browser prompts when the feature is actually used. Returning `denied` prevents startup crash while keeping the app functional.

## 5. Android Behavior Preservation

`kIsWeb` is `false` on Android. All existing `permission_handler` calls execute identically to today. No changes to permission flow, UI, or behavior on Android.

## 6. PermissionManager vs LiveLocationTracker

**PermissionManager is the correct place.**

- It is the single gateway for ALL permission operations in the app.
- Fixing it here protects both `LiveLocationTracker` and `SplashScreen._ensureFirstLaunchPermissions()` plus any future callers.
- Fixing only `LiveLocationTracker` would leave the SplashScreen crash intact.
- Fixing in `SplashScreen` would not protect `LiveLocationTracker`.
- No new location architecture is needed; `geolocator` Web support is already in use for the actual position fetch.

## 7. Additional Unsupported Web Permission Calls

**Yes.** All five permissions iterated in `SplashScreen._ensureFirstLaunchPermissions()` are unsupported on Web via `permission_handler`:

| Permission | permission_handler Web support |
|------------|-------------------------------|
| `locationWhenInUse` | ❌ Not implemented |
| `camera` | ❌ Not implemented |
| `photos` | ❌ Not implemented |
| `microphone` | ❌ Not implemented |
| `notifications` | ❌ Not implemented |

The fix in `PermissionManager` handles all five uniformly.

## 8. Exact Validation Commands

```bash
flutter analyze
.\tool\run.ps1 -d chrome --web-port 5000
```

### Web Validation Steps (manual)

1. App starts → **Splash appears** (no blank screen, no UnimplementedError).
2. No session → **Login appears**.
3. **Google OAuth works**.
4. Google redirects back to **localhost:5000**.
5. **Splash appears** again.
6. **No `UnimplementedError`** in browser DevTools console.
7. App **does NOT become blank**.
8. `AuthGate.navigateToTarget()` reaches the correct destination (home/profile).
