# Conexo Phase 10.3 — Profile UX Consolidation Plan

## Phase 10.3E — Premium Location Autocomplete & Nearby Suggestions

### 0. Forensic findings

**LocationService** (`lib/core/services/location_service.dart`):
- `detectCurrentLocation()` exists — GPS + reverse geocoding
- Does NOT have forward geocoding/search
- Uses `geocoding` package (already a dependency)

**LocationDetectField** (`lib/features/profile/profile_creation_widgets.dart`):
- Wraps `GlassTextField` with GPS suffix icon
- Callbacks: `onLocationNameChanged` (text), `onLocationDetected` (GPS result)
- No autocomplete/suggestions

**Profile Creation** (`lib/features/profile/profile_creation_sections.dart`):
- Uses `LocationDetectField` with both callbacks
- Updates draft: location, latitude, longitude

**Edit Profile** (`lib/features/profile/profile_management_sections.dart`):
- Uses `LocationDetectField` with same callbacks
- Same draft update pattern

**UserProfile** (`lib/features/profile/profile_data.dart`):
- Fields: `location` (String), `latitude` (double?), `longitude` (double?)

**Supabase** (`lib/features/profile/supabase_profile_repository.dart`):
- `saveProfile()` persists `location`, `latitude`, `longitude`
- `loadProfile()` retrieves them
- JSONB photo ordering untouched

**pubspec.yaml**:
- `geocoding: ^5.0.0` — available for forward geocoding
- `geolocator: ^14.0.3` — available for GPS

**Conclusion**: Location text + lat/lng are already backend-backed. Forward geocoding is the only missing piece.

---

### 1. Add forward geocoding to LocationService

**File:** `lib/core/services/location_service.dart`

Add:
```dart
static Future<List<Placemark>> searchLocations(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];
  try {
    return await Geocoding().locationFromAddress(trimmed);
  } catch (_) {
    return [];
  }
}
```

---

### 2. Enhance LocationDetectField with autocomplete

**File:** `lib/features/profile/profile_creation_widgets.dart`

Add to `_LocationDetectFieldState`:
- `_suggestions` list
- `_searching` bool
- `_debounce` timer
- Focus node for keyboard handling

**Behavior**:
- Debounce text input by 300ms
- Call `LocationService.searchLocations(query)`
- Show suggestions in a `GlassCard` dropdown below field
- On tap: fill text, update lat/lng via reverse geocode of selected placemark
- On empty/collapse: hide suggestions
- Max 4-5 visible suggestions

**Display name formatting**:
- Prefer `locality + administrativeArea`
- Fallbacks: subLocality, subAdministrativeArea, administrativeArea
- De-duplicate

---

### 3. Premium suggestion UI

Use existing glass design language:
- `GlassCard` container
- Subtle border
- Soft blur
- Existing typography
- Max 4-5 items
- 200-300ms appearance animation
- Small loading indicator while searching

---

### 4. Preserve existing behavior

- GPS detection unchanged
- Reverse geocoding unchanged
- Permission flow unchanged
- `onLocationNameChanged` still called on text input
- `onLocationDetected` still called on GPS success
- Profile Creation and Edit Profile use same enhanced field

---

### 5. Files to modify

| File | Change |
|------|--------|
| `lib/core/services/location_service.dart` | Add `searchLocations()` forward geocoding |
| `lib/features/profile/profile_creation_widgets.dart` | Add autocomplete to `LocationDetectField` |
| `lib/features/profile/profile_creation_sections.dart` | No changes (already uses `LocationDetectField`) |
| `lib/features/profile/profile_management_sections.dart` | No changes (already uses `LocationDetectField`) |

---

### 6. Out of scope

- Supabase schema/migrations
- Profile strength
- Verification
- Privacy
- Discovery preferences
- Photo system
- Chat/connections/plans
- Navigation

---

### 7. Validation

1. `flutter analyze` → `No issues found!`
2. `.\tool\build_apk.ps1` → success

### Manual verification

| Test | Expected |
|------|----------|
| GPS detection | Works as before |
| Manual typing | Shows suggestions after 300ms |
| Suggestion tap | Updates text + lat/lng |
| Permission denied | Manual entry still works |
| Empty field | No suggestions |
| Search failure | No crash, no suggestions |
| Edit Profile | Existing location loads, suggestions work |
| Backend | location + lat + lng persisted and reloaded |

---

### 8. Completion report

1. Files changed
2. Existing location backend fields discovered
3. Supabase migration required: YES/NO
4. Permission behavior
5. GPS/reverse-geocoding behavior
6. Manual autocomplete behavior
7. Suggestion UI implementation
8. Latitude/longitude persistence
9. Profile Creation integration
10. Edit Profile integration
11. `flutter analyze` result
12. APK build result
13. Any remaining limitation
