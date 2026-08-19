# Phase 9.1B — People/Discovery: Apply Saved Discovery Preferences

## Goal
Integrate the three saved Discovery Preferences (`discovery_distance_km`, `discovery_min_age`, `discovery_max_age`) into the **existing** People/Discovery backend with the smallest possible change.

## Existing Architecture (verified)
- **Repository**: `DiscoveryRepository` in `lib/features/profile/discovery_repository.dart`
- **Query**: Direct Supabase PostgREST `from('profiles').select(...)` — not an RPC
- **Model**: `DiscoveryProfile` in `lib/features/profile/discovery_data.dart`
- **Age**: Calculated client-side via `int get age => ageFromDate(dateOfBirth)` (uses `date_of_birth` column, not stored age)
- **Distance**: Calculated client-side via `haversine()` in `discovery_helpers.dart`
- **Filters**: Server-side = visibility, completion, DOB presence, gender, consumed IDs. Client-side = distance, sort, UI filters (Nearby, Verified, etc.)
- **Pagination**: None — unbounded fetch
- **Viewer profile**: Loaded inside `fetchNearby()` at lines 20–25 for gender/interests/coords

## Integration Plan

### Single file change
**`lib/features/profile/discovery_repository.dart`** — only file modified.

### Step 1: Extend viewer profile query
Add the three preference columns to the existing viewer profile `select` (lines 22–23):

```dart
'gender, latitude, longitude, interests, display_name, availability_status, discovery_distance_km, discovery_min_age, discovery_max_age'
```

Extract them after line 29:
```dart
final viewerDistanceKm = (viewerProfile['discovery_distance_km'] as int?)?.toDouble();
final viewerMinAge = viewerProfile['discovery_min_age'] as int?;
final viewerMaxAge = viewerProfile['discovery_max_age'] as int?;
final viewerDistanceMeters = viewerDistanceKm != null ? viewerDistanceKm * 1000 : null;
```

### Step 2: Apply distance filter in candidate loop
After the existing `maxDistanceMeters` check at line 84, add:

```dart
if (viewerDistanceMeters != null && distance > viewerDistanceMeters) continue;
```

This preserves the existing `maxDistanceMeters` parameter (used by UI "Nearby" filter). When both are set, the more restrictive wins because both conditions must pass.

### Step 3: Apply age filter after profile construction
After the `DiscoveryProfile` is built (after line 113), add:

```dart
if (viewerMinAge != null && base.age < viewerMinAge) continue;
if (viewerMaxAge != null && base.age > viewerMaxAge) continue;
```

Guard for invalid range (shouldn't happen via UI, but safe):
```dart
final hasValidAgeRange = viewerMinAge == null ||
    viewerMaxAge == null ||
    viewerMinAge <= viewerMaxAge;
if (!hasValidAgeRange) {
  // skip age filtering rather than hide everyone
}
```

### NULL / Any behavior
- `discovery_distance_km = NULL` → `viewerDistanceMeters = null` → no distance filter
- `discovery_min_age = NULL` → no minimum age filter
- `discovery_max_age = NULL` → no maximum age filter
- All three NULL → existing behavior unchanged

### Why client-side
- Distance already uses haversine client-side (no PostGIS/RPC exists)
- Age is already calculated client-side from `date_of_birth`
- Introducing server-side filtering would require PostGIS, a new RPC, or querying with computed age ranges — all of which would be new infrastructure, not integration
- The task says: "unless the existing architecture makes server-side filtering impossible" — the existing architecture makes it impractical without rebuilding

### Security / RLS
- Viewer preferences are loaded using the existing `AuthService.currentUser.id` and the same `profiles` query pattern already used in `fetchNearby`
- Existing `profiles_policy` (`auth.uid() = id`) already protects the viewer's row
- No RLS changes needed
- No new tables, no new columns, no new credentials

### Refresh behavior
`HomeScreen._loadProfiles()` calls `repository.fetchNearby()` each time. When the user returns from Discovery Preferences and the People tab reloads, the new preferences are automatically picked up. No navigation or state-management changes needed.

## Validation
1. `flutter analyze` — must pass
2. `.\tool\run_prod.ps1` — manual verification:
   - Set Distance = 25km, Age = 25–35 → verify both filters apply
   - Set Distance = Any → verify distance filter removed
   - Clear age → verify no age filter
   - All NULL → verify existing behavior unchanged
3. `.\tool\build_apk.ps1` — build and report path

## Files Changed
- `lib/features/profile/discovery_repository.dart`

## Out of Scope
- No UI changes to `discovery_preferences_screen.dart` or `home_screen.dart`
- No Plans changes
- No new backend/query infrastructure
- No RLS changes
- No pagination (existing architecture has none)
