# PHASE B1.1 AUDIT

> Audit-only. No Dart, migration, RLS, schema, Storage, UI, or navigation changes.
> Read-only trace of the Discovery gender algorithm + Discovery preferences.

## Gender Algorithm

| Viewer Gender | Expected | Actual | Status |
|---|---|---|---|
| Man | Women only | `{'Woman'}` (via `inFilter('gender', ['Woman'])`) | PASS |
| Woman | Men only | `{'Man'}` (via `inFilter('gender', ['Man'])`) | PASS |
| Non-binary | All 4 categories (Man, Woman, Non-binary, Prefer not to say) | `{'Man','Woman'}` only — `Non-binary` & `Prefer not to say` candidates excluded | **FAIL** |
| Prefer not to say | All 4 categories (Man, Woman, Non-binary, Prefer not to say) | `{'Man','Woman'}` only — `Non-binary` & `Prefer not to say` candidates excluded | **FAIL** |

**Critical secondary finding:** Because every branch of `eligibleTargetGenders()` only ever returns `{'Man'}` / `{'Woman'}` / `{'Man','Woman'}`, the candidate genders `'Non-binary'` and `'Prefer not to say'` are **never present in any viewer's eligible set**. Therefore profiles whose `gender = 'Non-binary'` or `'Prefer not to say'` are **completely invisible in Discovery** regardless of who is viewing. This is a more severe manifestation of the same bug.

## Exact Gender Values

Database values (`profiles.gender`, written by `profile_creation_sections.dart` options, lines 56–59):
- `'Woman'`
- `'Man'`
- `'Non-binary'`
- `'Prefer not to say'`

Application values (returned by `eligibleTargetGenders()` in `discovery_helpers.dart`):
- viewer `man` → `{'Woman'}`
- viewer `woman` → `{'Man'}`
- viewer `non-binary` → `{'Man','Woman'}`
- viewer `prefer not to say` → `{'Man','Woman'}`
- viewer `default` (null/empty/unknown) → `{'Man','Woman'}`

`inFilter('gender', eligibleGenders.toList())` passes these exact capitalized strings; they match the stored capitalized candidate values for Man/Woman but **never match 'Non-binary'/'Prefer not to say'**.

Mismatch: **YES.** `eligibleTargetGenders()` does not emit `'Non-binary'` or `'Prefer not to say'` for the non-binary / prefer-not-to-say viewer cases (and the `default` case), so those candidate categories are dropped from the Supabase query.

## Discovery Preferences

| Preference | UI | Persisted | Repository | Discovery | Status |
|---|---|---|---|---|---|
| Age Min (`discovery_min_age`) | Set in `DiscoveryPreferencesScreen` | SharedPreferences → `saveProfile` → Supabase `profiles.discovery_min_age` | Read in `fetchNearby` as `viewerMinAge` | `ageWithinDiscoveryPreference(base.age, viewerMinAge, viewerMaxAge)` | WORKING (via prefs screen) |
| Age Max (`discovery_max_age`) | Set in `DiscoveryPreferencesScreen` | Supabase `profiles.discovery_max_age` | Read as `viewerMaxAge` | applied as above | WORKING (via prefs screen) |
| Distance (`discovery_distance_km`) | Set in `DiscoveryPreferencesScreen` | Supabase `profiles.discovery_distance_km` | Read as `viewerMaxDistanceKm` | `distanceWithinDiscoveryPreference(distance, viewerMaxDistanceKm)` | WORKING (via prefs screen) |

Details:
- Age: candidate age = `DiscoveryProfile.age` = `ageFromDate(dateOfBirth)` from the candidate's `date_of_birth` (selected & parsed in `fetchNearby`). `ageWithinDiscoveryPreference` returns `true` when bounds null; rejects `< min` / `> max`; treats `min > max` as "no restriction". Unset (null) → no exclusion. Correct.
- Distance: `distanceWithinDiscoveryPreference` compares `distanceMeters <= maxDistanceKm * 1000`; null → no restriction. km↔m conversion correct. Works.
- IMPORTANT: These preferences are driven **only** by `DiscoveryPreferencesScreen`, **not** by the Discovery filter sheet. The filter-sheet Distance/Age controls are inert (see Filter Sheet).

## Filter Sheet

| Filter | UI exists | Wired | Actually filters | Status |
|---|---|---|---|---|
| Distance | Yes (chips 1/3/5/10/100 km + Any) | No `onChanged` | No | INERT |
| Age | No control in sheet | n/a | No | ABSENT (only via prefs screen) |
| Gender | No control in sheet | n/a | No | ABSENT (hard-coded) |
| Verified | Yes (chip) | No `onChanged` | No | INERT |
| Availability | Yes (chip) | No `onChanged` | No | INERT |
| Interests | No segment chips in sheet | n/a | No | ABSENT (engine has keywords, no UI) |
| Sort | Yes (Closest/Best Match/Recently Joined/Most Active) | `onChanged: onSortChanged` | Yes (`_applySort`) | WORKING |

`_FilterPreferencesSheet` (`home_screen.dart`) builds `Distance`, `Availability`, `Verification` as `_PreferenceGroup` **without** `selected`/`onChanged`, so their `ChoiceChip`s render with `onSelected: null` → non-interactive. Only the `Sort` group passes `selected`/`onChanged`. `_selectFilter()` exists but is only ever invoked to reset to `'All'` (empty-state / connect-complete), so `_applyDiscoveryProfileFilter` keyword branches (Coffee/Walk/Music/Study/Nearby/Verified/Available Now/New/Shared Interests) are **unreachable**.

## Existing Filter Engine

- `eligibleTargetGenders()` — EXISTS / PARTIAL (man/woman correct; non-binary & prefer-not-to-say return only Man+Woman → violates canonical "show all 4"; also `default` case same limitation).
- `ageWithinDiscoveryPreference()` — EXISTS / WORKING (reachable via prefs screen).
- `distanceWithinDiscoveryPreference()` — EXISTS / WORKING (reachable via prefs screen).
- `_applyDiscoveryProfileFilter()` — EXISTS / PARTIAL (only `'All'` is ever passed from UI; all non-All branches UNREACHABLE).
- `_kDiscoveryFilterKeywords` — EXISTS / UNREACHABLE (Coffee/Walk/Music/Study maps defined; no UI sets those filters).
- `_applySort()` — EXISTS / WORKING (Sort is the only functional filter-sheet control).

## Real vs Demo Discovery

Real Supabase profiles: **YES.** `HomeScreen._loadProfiles()` → `DiscoveryRepository.fetchNearby()` → `Supabase.from('profiles')` → `DiscoveryProfile.fromJson` → `ImmersiveProfileView`. No mock feed in this path.

Demo data affecting runtime Discovery: **NO** (the `DiscoveryPerson`/`home_discovery_data.dart` demo model is unused by the live path; only `home_discovery_profile.dart` + `DiscoveryProfile` are imported by `home_screen.dart`).

Legacy paths found:
- `lib/features/home_discovery_data.dart` (`DiscoveryPerson`) — legacy demo model, not referenced by `home_screen.dart`.
- `lib/features/home_discovery_components.dart` — legacy, appears unreferenced.
- `LocalChatRepository` / `demo_chat_data.dart` — chat demo (not Discovery, but adjacent legacy).

## Exclusions

- Self: `neq('id', user.id)` — enforced.
- Private: `.eq('profile_visibility','public')` — enforced.
- Incomplete: `.eq('profile_completed', true)` — enforced.
- Missing DOB: `.not('date_of_birth','is',null)` — enforced.
- Blocked: `_loadBlockedProfileIds()` (both directions from `blocked_users`) → excluded via `not('id','in',consumedIds)` — enforced.
- Connected: `_loadConsumedProfileIds()` (pending/accepted from `connections`) → excluded — enforced.
- Rejected/Cancelled: not in `connections` consumed set (only pending/accepted), so rejected/cancelled connections do NOT exclude a profile from Discovery (a previously rejected user can reappear). Behavior understood; not a bug per current rules.
- Invalid coordinates: `_resolveCoordsFromBatch`/`isValidCoordinate` → candidate dropped if no valid coords — correct.

## Location

Primary coordinate source: `live_locations` (fetched per candidate via `_fetchLiveLocationsBatch`, and viewer via `_resolveViewerCoords`).

Fallback: if `live_locations` row missing/invalid, falls back to `profiles.latitude/longitude`; if those invalid → candidate dropped.

Freshness: `isLocationFresh` = `updated_at` within 60 minutes; stale `live_locations` ignored (uses profile coords or drops).

Distance calculation: `haversine(lat1,lng1,lat2,lng2)` with Earth radius 6,371,000 m — correct.

Status: WORKING (no changes made; the live-location RLS privacy concern is out of scope for this phase but noted in B0).

## Age Calculation

Canonical source: `date_of_birth` (no stored age field). Candidate age = `ageFromDate(dateOfBirth)` in `discovery_data.dart:50`, defined in `profile_validation.dart:62`.

Boundary correctness: DOB `2000-08-20`, today `2026-08-20` → `ref.year-dob.year = 26`; `hadBirthdayThisYear` = `(8>8)`||`(8==8 && 20>=20)` = true → age **26**. Correct.

Discovery display/filter consistency: `DiscoveryProfile.age` (display) and `ageWithinDiscoveryPreference(base.age, …)` (filter) both use `ageFromDate` → consistent. `connections_view_model._ageFromDate` uses identical logic for the Connections inbox (consistent across surfaces).

## Critical Findings

P0:
- `eligibleTargetGenders()` returns only Man/Woman for non-binary & prefer-not-to-say viewers (and the default case). Per canonical product rule, those viewers must see **all four** categories. Additionally, `'Non-binary'` and `'Prefer not to say'` candidate profiles are invisible to **every** viewer because no eligible set ever contains them. This is the central B1.1 bug.

P1:
- Discovery preferences (Age/Distance) are functional **only** through `DiscoveryPreferencesScreen`; the on-screen filter sheet's Distance/Age/Verification/Availability chips are inert — users cannot adjust filtering from Discovery itself.
- `_applyDiscoveryProfileFilter` keyword/segment branches (Nearby, Verified, Available Now, New, Shared Interests, Coffee/Walk/Music/Study) are unreachable — `_selectedFilter` is never set to a non-`'All'` value from the UI.

P2:
- `default` (null/empty viewer gender) resolves to Man+Woman only; decide intended default (show-all vs men+women) when fixing.
- No server-side pagination in `fetchNearby` (carries over from B0).

## Recommended B1 Implementation Order

(Recommendation only — not implemented in this audit.)

1. **B1.1a — Fix `eligibleTargetGenders()`** (the single root cause): for `non-binary` and `prefer not to say` (and `default`) return `{'Man','Woman','Non-binary','Prefer not to say'}` so all four stored candidate values are matched by `inFilter`. Confirm stored values exactly match (`'Non-binary'`, `'Prefer not to say'`) — they do. No schema/RLS change needed.
2. **B1.1b — Add UI wiring** for the filter sheet (Distance/Age/Verification/Availability/Interests/Sort) so `_applyDiscoveryProfileFilter` and the preferences actually receive UI state. (Larger UI change; separate from the pure-algorithm fix.)
3. **B1.1c — Decide default viewer-gender behavior** (show-all vs men+women) and document.

## Files Inspected

- `lib/features/profile/discovery_helpers.dart` (`eligibleTargetGenders`, `ageWithinDiscoveryPreference`, `distanceWithinDiscoveryPreference`, `haversine`, `isLocationFresh`)
- `lib/features/profile/discovery_repository.dart` (`fetchNearby`, `inFilter('gender', …)`, preference reads, exclusions, coordinate resolution)
- `lib/features/profile/discovery_data.dart` (`DiscoveryProfile`, `age`, `fromJson`)
- `lib/features/profile/profile_data.dart` (`UserProfile`/`UserProfileDraft` gender + discovery_* fields)
- `lib/features/profile/profile_creation_sections.dart` (canonical gender option strings)
- `lib/features/profile/discovery_preferences_screen.dart` (Age/Distance persistence UI)
- `lib/features/profile/profile_validation.dart` (`ageFromDate`)
- `lib/features/home_screen.dart` (`_loadProfiles`, `_FilterPreferencesSheet`, `_applyDiscoveryProfileFilter`, `_kDiscoveryFilterKeywords`, `_applySort`, `_selectFilter`)
- `lib/features/home_discovery_profile.dart` (`ImmersiveProfileView`) — live path
- `lib/features/home_discovery_data.dart`, `home_discovery_components.dart` — legacy demo (not in live path)
- `lib/features/profile/connections_view_model.dart` (`_ageFromDate`, cross-check)
- `test/features/profile/safety_repository_test.dart`, `lib/features/profile/report_problem_screen.dart` — confirm no `'Other'` gender exists (only `'Other'` report_type, unrelated)

## Changes Made

NONE

## Database Changes

NONE

## Supabase Changes

NONE

## RLS Changes

NONE

STOP AFTER THE AUDIT.
