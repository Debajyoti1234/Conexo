# Phase 9.4.6.1 — Discovery Zero-Results Diagnosis & Fix

## Root Cause
`discovery_repository.dart` line 50 uses `.filter('date_of_birth', 'is not', null)`. The postgrest_rest `filter` method serializes this as `date_of_birth=is not.null` (with a literal space). PostgREST cannot parse that token and returns HTTP 400. `fetchNearby()` catches the error silently via `catch (_) { return const []; }`, so the UI shows the empty state with no error indication.

## Evidence
- Verified PostgREST syntax:
  - `date_of_birth=is not.null` → 400 `"failed to parse filter (is not.null)"`
  - `date_of_birth=not.is.null` → 200, returns 19 profiles
- Verified RLS: `Authenticated users can read public profiles` policy is active and allows cross-user reads of public profiles.
- Verified data: 20 profiles in remote DB (19 visible to an authenticated user), all with `profile_visibility=public`, `profile_completed=true`, valid `date_of_birth`, and valid gender values.
- Verified `neq`, `eq`, `inFilter`, and `not.is.null` all work correctly via REST API.
- Grep confirms only one occurrence of the buggy pattern in the codebase.

## Fix
In `lib/features/profile/discovery_repository.dart`, replace:
```dart
.filter('date_of_birth', 'is not', null)
```
with:
```dart
.not('date_of_birth', 'is', null)
```

The `.not()` method generates `not.is.null`, which PostgREST accepts as `IS NOT NULL`.

## Files Modified
- `lib/features/profile/discovery_repository.dart` (1 line)

## Database Changes
None.

## RLS Changes
None.

## Verification Steps
1. `flutter analyze`
2. `flutter build apk --release`
3. Log in as Man real user → Woman real user visible
4. Log in as Woman real user → Man real user visible
5. Demo profiles visible when logged in as any user
6. All filter works
7. Nearby filter works
8. Distance ordering works
9. Gender matrix remains enforced
10. Private/incomplete profiles remain hidden
11. RLS remains secure
