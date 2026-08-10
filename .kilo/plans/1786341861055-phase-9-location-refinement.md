# Phase 9.1 — Location Refinement Plan (Inspection)

Status: INSPECTION COMPLETE. One decision requires approval before implementation (reverse-geocoding dependency). No files changed.

## 1. CURRENT LOCATION IMPLEMENTATION
- Creation: `LocationSection` (`lib/features/profile/profile_creation_sections.dart:406`) wraps `GlassTextField` bound to a `TextEditingController` and `draft.location`. Pure manual text entry.
- Management: `ManageLocationSection` (`lib/features/profile/profile_management_sections.dart:413`) — identical pattern.
- Wiring: `ProfileCreationScreen._locationController` (`profile_creation_screen.dart:43`) synced from `saved.location` (line 96); `ProfileManagementScreen._locationController` (`profile_management_screen.dart:49`) synced from `draft.location` (line 99).
- No tap-to-detect, no GPS affordance. `onChanged` only writes `draft.location` (the typed string).

## 2. CURRENT PERMISSION IMPLEMENTATION
- `PermissionManager` (`lib/core/services/permission_manager.dart`) supports `PermissionType.locationWhenInUse` → `ph.Permission.locationWhenInUse`, with `check/request/isGranted/isPermanentlyDenied/openAppSettings`.
- Location is requested at startup as part of the 5 sequential first-launch permissions in `SplashScreen`.
- No feature-level location permission request exists in either Location section.

## 3. GPS CAPTURE STATUS
- `latitude`/`longitude` (nullable `double`) exist on `UserProfileDraft` and `UserProfile`, flow through `copyWith`/`toJson`/`fromJson`/`fromDraft`/`fromProfile`, and are persisted + read by `SupabaseProfileRepository`.
- **They are never populated.** No device-location acquisition exists anywhere (no `geolocator`/`location` package, no platform channel, no `Position`). Coordinates are always `null`.

## 4. LOCATION NAME / REVERSE GEOCODING STATUS
- **No reverse geocoding exists.** No `geocoding` package; no Google/Mapbox/Nominatim usage anywhere. Location name is only what the user types.

## 5. PROFILE DATA MAPPING
- `UserProfileDraft`: `location` (String, default `''`), `latitude` (double?), `longitude` (double?).
- `UserProfile`: `location` (String), `latitude` (double?), `longitude` (double?).
- Carried by `copyWith`, `toJson`, `fromJson`, `fromDraft`, `fromProfile`. Correct and complete for storing name + coordinates separately.

## 6. SUPABASE MAPPING
- `profiles` table already has: `location TEXT NOT NULL DEFAULT ''`, `latitude DOUBLE PRECISION`, `longitude DOUBLE PRECISION` (`supabase/migrations/20260809000000_create_profiles_table.sql`).
- `saveProfile` writes all three (`supabase_profile_repository.dart:76,88,89`); `loadProfile` reads all three (`latitude`/`longitude` pass through `_snakeToCamel` default branch). **No migration needed.**

## 7. CREATION FLOW STATUS
- `LocationSection` wired at `profile_creation_screen.dart:244`. Saves via `repo.saveProfile`. lat/lng flow through draft→profile but stay null (never set).

## 8. EDIT FLOW STATUS
- `ManageLocationSection` wired at `profile_management_screen.dart:246`. Same behavior; lat/lng never set.

## 9. EXACT FILES REQUIRING CHANGE (for future implementation)

### FILE: `pubspec.yaml`
- FUNCTION/CLASS: dependencies
- CURRENT: no location/geocoding packages.
- CHANGE: add `geolocator` (GPS). Add `geocoding` ONLY if area-name resolution is approved (Decision A).
- REASON: project has no device-location API; GPS cannot be obtained without a plugin.

### FILE: `lib/core/services/location_service.dart` (NEW)
- FUNCTION/CLASS: `LocationService` (static, mirrors `PermissionManager` style)
- CURRENT: does not exist.
- CHANGE: thin wrapper: `getCurrentPosition()` → returns lat/lng via `geolocator`; optional `resolveAreaName(lat,lng)` → via `geocoding` (if approved). Uses existing `PermissionManager` for permission; no new permission system.
- REASON: keep GPS logic out of widgets; single reusable service; architecture stays simple.

### FILE: `lib/features/profile/profile_creation_sections.dart`
- FUNCTION/CLASS: `LocationSection`
- CURRENT: manual-only `GlassTextField`.
- CHANGE: add a "use current location" affordance (suffix GPS icon — Decision B). On tap: `PermissionManager.check/request(locationWhenInUse)` → if granted, `LocationService.getCurrentPosition()` → set `draft.latitude/longitude`; if geocoding approved, resolve area name → set `controller.text` + `draft.location`; keep field editable. Handle denied (allow manual entry) and permanentlyDenied (Settings path via `PermissionManager.openAppSettings`).
- REASON: satisfies GPS capture + editable name without redesigning the field.

### FILE: `lib/features/profile/profile_management_sections.dart`
- FUNCTION/CLASS: `ManageLocationSection`
- CURRENT: manual-only `GlassTextField`.
- CHANGE: identical detect behavior as creation.
- REASON: same behavior required in edit flow.

### FILE: `lib/features/profile/profile_creation_widgets.dart`
- FUNCTION/CLASS: `GlassTextField`
- CURRENT: supports only a prefix `icon`.
- CHANGE: add optional `suffix`/`onSuffixTap` (non-breaking, additive) to host the GPS button while preserving visual language.
- REASON: needed to trigger detection without a separate card; keeps UI consistent.

### FILES: `profile_creation_screen.dart` / `profile_management_screen.dart`
- CURRENT: own `_locationController`, sync from draft/saved, pass to sections.
- CHANGE: likely NONE — sections set `controller.text` and emit `onChanged(draft.copyWith(location:, latitude:, longitude:))` using the passed controller. Verify lat/lng survive save (they already do).
- REASON: minimal footprint; screens remain single owner of controllers.

### Platform config
- Android: `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` already declared. No change.
- iOS: `NSLocationWhenInUseUsageDescription` already present in `ios/Runner/Info.plist`. No change.

## 10. NEW DEPENDENCIES REQUIRED
- `geolocator` — REQUIRED for GPS coordinates (A: coordinate acquisition). No API key.
- `geocoding` — OPTIONAL, NEEDS APPROVAL for area-name resolution (B: name resolution). Uses OS-native geocoder (Android `Geocoder`, iOS `CLGeocoder`); no API key, but network-dependent and can return empty on some devices/emulators.
- No Google Maps / Mapbox / paid geocoding APIs proposed.

## 11. MIGRATION REQUIRED
- No. Schema already has `location`, `latitude`, `longitude`.

## 12. MINIMAL IMPLEMENTATION PLAN
1. Add `geolocator` to `pubspec.yaml`; `flutter pub get`.
2. (If Decision A approves reverse geocoding) add `geocoding`.
3. Create `lib/core/services/location_service.dart` (GPS acquisition; optional name resolution) using `PermissionManager`.
4. Extend `GlassTextField` with optional suffix/onSuffixTap (additive).
5. Update `LocationSection` and `ManageLocationSection` to add detect flow: permission → GPS → set lat/lng → (optional) resolve name → set controller.text + draft.location; editable; graceful denial + Settings path.
6. Confirm `saveProfile`/`loadProfile` persist lat/lng (already do). No repository change expected.

## 13. VALIDATION PLAN
- `flutter analyze` → no new issues.
- `.\tool\run.ps1` on device: create profile → tap detect → grant location → coordinates captured; name populated (if geocoding approved) and editable; save.
- Restart app → reload profile → verify `location`, `latitude`, `longitude` persisted in Supabase.
- Deny path: detect → deny → manual entry still works; no crash. Permanently denied → Settings path shown.
- Edit flow: same via `ManageLocationSection`; verify single row updated (no duplicate), lat/lng updated.
- `.\tool\build_apk.ps1` → build succeeds.

## 14. RISKS / BLOCKERS
- Reverse geocoding reliability: OS geocoder can return empty/misnamed areas or need network; must fall back to coordinates-only + manual name.
- If Decision A is "coordinates only," the visible name stays manual while lat/lng are captured — meets the "do not fake coordinates" rule but not auto-naming.
- `geolocator` requires location services enabled at OS level; handle "services disabled" distinctly from "permission denied."
- Startup already requests location; feature-level re-request must still work when previously denied (Android allows re-prompt until "don't ask again").
- Do not let detection block save; coordinates are optional at the model level (nullable).

## DECISION REQUIRED (before implementation)
- Decision A — Area-name resolution: (Recommended) add `geocoding` (OS-native, no API key) to auto-fill the editable area name from GPS; OR capture GPS coordinates only and leave the name fully manual. GPS coordinate capture via `geolocator` is required either way.
