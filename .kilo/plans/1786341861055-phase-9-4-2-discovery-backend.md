# Phase 9.4.2 — People/Discovery Backend Integration

## LOCKED GENDER MATRIX

```text
Viewer                  Eligible Targets
────────────────────────────────────────
Man                     Woman
Woman                   Man
Non-binary              Man + Woman
Prefer not to say       Man + Woman
```

Only `Man` and `Woman` are eligible as discovery targets. `Non-binary` and `Prefer not to say` are NOT eligible targets for Man/Woman viewers.

## IMPLEMENTATION PLAN

### Files to Create
1. `lib/features/profile/discovery_data.dart` — `DiscoveryProfile` immutable model
2. `lib/features/profile/discovery_repository.dart` — `DiscoveryRepository` with `fetchNearby()`
3. `lib/features/profile/discovery_helpers.dart` — Haversine, gender compatibility, stale-location threshold

### Files to Modify
1. `lib/features/home_screen.dart` — Replace `peopleAroundYou` with `DiscoveryRepository.fetchNearby()`, add loading/error/empty states
2. `lib/features/home_discovery_profile.dart` — Update `ImmersiveProfileView` to consume `DiscoveryProfile`
3. `lib/features/home_discovery_data.dart` — Preserve `conversations`, `circles`, `nearbyMoments`; deprecate `peopleAroundYou` from discovery path only
4. `lib/features/profile/profile_navigation_mapper.dart` — Add `mapDiscoveryProfileToProfile()` for the new model

### Database Changes
- **None required.** Existing schema is sufficient.

### Key Logic
1. **Location:** Prefer `live_locations` if fresh (< 60 min), fallback to `profiles.latitude/longitude`, exclude if no usable coords
2. **Gender:** `eligibleTargetGenders(viewerGender)` as per locked matrix
3. **Age/DOB:** Require non-null DOB, age ≥ 18 (reuse `ageFromDate`)
4. **Privacy:** Only `profile_visibility = 'public'`
5. **Self-exclusion:** Exclude `auth.uid()`
6. **Distance:** Haversine in Dart, sort ascending
7. **Filters:** All, Nearby (≤1500m), Verified, interest keywords; Available Now/New/Shared Interests leave unchanged

### Error Handling
- No auth user → empty state
- No profile → empty state
- Network failure → existing premium error/retry state
- Empty results → existing `_DiscoveryEmptyState`
