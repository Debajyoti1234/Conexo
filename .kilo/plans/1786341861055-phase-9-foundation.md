# Phase 9.0 — Foundation Plan

## 1. Files to Inspect (Verification Targets)

- `lib/core/supabase/supabase_client.dart`
- `lib/core/supabase/auth_service.dart`
- `lib/core/supabase/auth_gate.dart`
- `lib/features/profile/profile_repository.dart`
- `lib/features/profile/supabase_profile_repository.dart`
- `lib/features/profile/session_aware_profile_repository.dart`
- `supabase/migrations/20260809000000_create_profiles_table.sql`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `pubspec.yaml`
- `lib/features/main_shell.dart`
- `lib/main.dart`

## 2. Files That Will Probably Need Modification

- `pubspec.yaml` — add `permission_handler` dependency
- `android/app/src/main/AndroidManifest.xml` — add runtime permission declarations matching supported permission types
- `ios/Runner/Info.plist` — add iOS privacy usage description keys matching supported permission types

## 3. New File Required

- `lib/core/services/permission_manager.dart` — single centralized permission manager

## 4. Dependencies Required

- `permission_handler: ^11.3.0` (or latest stable 11.x)

No other new dependencies. `geolocator` is deferred to a later location/discovery slice.

## 5. Supabase Migration Required

**None for Phase 9.0.**

The existing `profiles` table already has `latitude` and `longitude` columns and a working RLS policy:
```sql
CREATE POLICY profiles_policy ON profiles
FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
```

Future tables should follow the same pattern. No schema changes are needed in Phase 9.0.

## 6. Permission Manager Design

### Placement
`lib/core/services/permission_manager.dart` — alongside `AuthService` in `lib/core/` as a static service class.

### Public API
```dart
abstract final class PermissionManager {
  static Future<PermissionStatus> check(PermissionType type);
  static Future<PermissionStatus> request(PermissionType type);
  static Future<bool> isGranted(PermissionType type);
  static Future<bool> isPermanentlyDenied(PermissionType type);
  static Future<void> openAppSettings();
}
```

### PermissionType Enum
```dart
enum PermissionType {
  locationWhenInUse,
  camera,
  photos,
  microphone,
  notifications,
}
```

### PermissionStatus Enum
```dart
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}
```

### Implementation Notes
- Use `permission_handler` package for all platform permission APIs.
- Do **not** request any permission on app startup.
- Each future feature will call `PermissionManager.request()` only when the user triggers the action that needs it.
- Keep the manager synchronous-looking via `Future` APIs so callers can `await` in async handlers without refactoring the existing imperative `StatefulWidget` pattern.

### Why `lib/core/services/` and not `lib/features/`?
Permissions are cross-cutting. Placing the manager in `lib/core/services/` keeps it independent of any single feature folder and avoids circular dependencies, matching the existing `AuthService` placement in `lib/core/supabase/`.

## 7. What Will Explicitly NOT Be Changed

- `lib/features/profile/profile_data.dart` — untouched
- Email authentication flow
- Google authentication flow
- Supabase authentication initialization
- Profile identity isolation from Phase 8.4 (`SessionAwareProfileRepository` behavior)
- Existing navigation (`MainShell`, `IndexedStack`, `AppRouter.slideRoute`)
- Existing UI screens and widgets
- Existing repository/state structure (`ProfileRepository`, `LocalProfileRepository`, `SupabaseProfileRepository`)
- Phone authentication (out of scope)
- Any map, GPS tracking, geospatial query, or distance-calculation code (future phases)
- Existing RLS policy
- `flutter_riverpod` remains declared but unused; no state-management migration in Phase 9.0

## 8. Validation Steps

1. **Static verification**
   - `flutter analyze` passes with no new warnings.
   - `flutter pub get` succeeds with new dependency.

2. **Permission Manager behavior**
   - Verify `check()` returns `denied` on first launch (before any request).
   - Verify `request()` maps the platform result to the correct `PermissionStatus`.
   - Verify `isPermanentlyDenied()` returns `true` after user selects "Don't ask again" (Android) or equivalent (iOS).
   - Verify `openAppSettings()` launches the OS settings page.

3. **Platform configuration verification**
   - Android: confirm `AndroidManifest.xml` contains `<uses-permission>` entries for `ACCESS_FINE_LOCATION`, `CAMERA`, `READ_MEDIA_IMAGES`, `POST_NOTIFICATIONS`, `RECORD_AUDIO`.
   - iOS: confirm `Info.plist` contains `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`.

4. **Existing auth/profile flow regression**
   - Run the app, sign in with email and Google, complete profile creation, verify `MainShell` loads and existing data persists.
   - Confirm `AuthGate.navigateToTarget()` still routes correctly.

5. **No startup permission requests**
   - Launch the app and confirm no system permission dialogs appear automatically.

## 9. Estimated Implementation Order

1. Add `permission_handler` to `pubspec.yaml` and run `flutter pub get`.
2. Add Android `<uses-permission>` declarations to `AndroidManifest.xml` (no `maxSdkVersion` unless required by feature; no phone/call permissions).
3. Add iOS privacy keys to `Info.plist` with user-facing description strings.
4. Create `lib/core/services/permission_manager.dart` with the enum, API surface, and `permission_handler` delegation.
5. Run `flutter analyze` and verify no new warnings.
6. Confirm existing auth/profile flow still works (sign in, profile creation, `MainShell`).
7. Stop. Do not integrate into any feature screen in Phase 9.0.
