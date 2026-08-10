# Phase 9.1 — Profile Photo + First-Launch Permission Refinement Plan

## 1. Root Cause of Issue 1 — Profile Photo Glass Cards

The current `PhotoGrid` widget is built around a **demo-asset gallery paradigm**, not a **slot-based picker paradigm**. It presents 6 bundled demo portraits as the primary selectable surface, with camera/gallery as secondary action buttons below the grid. This causes demo portraits to appear as pre-filled user profile photos during creation, and the "+" empty-slot interaction does not exist.

The `PhotosSection` and `ManagePhotosSection` both delegate to this same `PhotoGrid` with `onToggle`/`onReorder` callbacks designed for toggling demo assets on/off, not for slot-based image picking.

## 2. Root Cause of Issue 2 — First-Launch Permission Flow

There is no centralized first-launch permission orchestration. Permissions are only requested reactively when individual features are used (camera when taking a photo, photos when selecting from gallery). The app has no startup-layer permission flow, and no first-launch detection mechanism.

## 3. Exact Files to Modify

### For Issue 1 (Profile Photo Glass Cards):
1. **`lib/features/profile/profile_creation_widgets.dart`**
   - Modify `PhotoGrid` to support empty "+" slots and slot-based tapping
   - Remove the "Gallery" demo-asset grid from `PhotoGrid`
   - Add `_EmptyPhotoSlot` widget with centered "+" icon

2. **`lib/features/profile/profile_creation_sections.dart`**
   - Replace `_toggle`/`_reorder` with slot-based `_onSlotTapped(int index)`
   - Remove the separate "Take Photo" / "Choose from Gallery" action buttons below the grid
   - Keep `_pickFromCamera` and `_pickFromGallery` as the picker methods

3. **`lib/features/profile/profile_management_sections.dart`**
   - Same slot-based changes as creation sections
   - Keep existing reorder/remove controls for already-selected photos

### For Issue 2 (First-Launch Permission Flow):
4. **`lib/features/splash/splash_screen.dart`**
   - Add first-launch permission orchestration after auth check but before routing
   - Use `SharedPreferences` to track whether first-launch permissions have been requested
   - Request only Camera and Photos/Media sequentially
   - Skip already-granted permissions
   - Handle permanent denial with app-settings path

## 4. Exact Changes Per File

### `lib/features/profile/profile_creation_widgets.dart`

**Current `PhotoGrid` (lines 145-241):**
- Has selected strip + gallery grid of demo assets
- `onToggle` toggles demo assets on/off

**New `PhotoGrid`:**
- Parameters: `selected` (List<ProfilePhoto>), `onAddPhoto` (VoidCallback)
- Always renders exactly `kMaxProfilePhotos` (6) glass card slots
- Each slot is the same premium glass card style
- Empty slot: glass card with centered "+" icon
- Filled slot: glass card with selected photo image + remove button
- No demo gallery grid
- No "Gallery" label

**New helper widgets:**
- `_EmptyPhotoSlot` — glass card with "+" icon, calls `onAddPhoto` when tapped
- Update existing `_SelectedPhotoRow` to be used inline within the grid slots (or keep the strip-style for management, slot-style for creation)

### `lib/features/profile/profile_creation_sections.dart`

**Current `PhotosSection.build()` (lines 186-221):**
- Shows `PhotoGrid(gallery: profilePhotoGallery, selected: draft.photos, onToggle: _toggle, onReorder: _reorder)`
- Plus two action buttons below: "Take Photo" and "Choose from Gallery"

**New `PhotosSection.build()`:**
- Shows new `PhotoGrid(selected: draft.photos, onAddPhoto: () => _showPickerDialog(context))`
- Remove the separate action buttons row
- Add `_showPickerDialog(BuildContext context)` that shows bottom sheet with "Take Photo" / "Choose from Gallery" options
- `_pickFromCamera` and `_pickFromGallery` remain as the actual picker methods

**Remove:**
- `_toggle(String asset)` — no longer needed
- `_reorder(int oldIndex, int newIndex)` — not needed in creation (reorder happens in management)

### `lib/features/profile/profile_management_sections.dart`

**Current `ManagePhotosSection.build()` (lines 183-197):**
- Same PhotoGrid + action buttons pattern

**New `ManagePhotosSection.build()`:**
- Same slot-based `PhotoGrid`
- Keep reorder/remove controls within the grid slots for existing photos
- `_showPickerDialog` for empty slots
- Keep `_toggle` for removing photos
- Keep `_reorder` for reordering

### `lib/features/splash/splash_screen.dart`

**Current flow (lines 30-58):**
- Animation completes → check auth → route to target

**New flow:**
- Animation completes → check auth → if authenticated, check first-launch permissions → route to target
- First-launch check: read `SharedPreferences` key `conexo_permissions_requested_v1`
- If not requested: sequentially request Camera, then Photos/Media
- Skip already-granted permissions
- If denied, continue to next permission
- If permanently denied, show brief explanation then continue
- After all requests (or skip), set `conexo_permissions_requested_v1 = true`
- Then proceed to `AuthGate.navigateToTarget()`

## 5. Permission Sequence and Orchestration Point

**Orchestration point:** `SplashScreen` (after animation completes, before `AuthGate.navigateToTarget()`)

**Sequence:**
1. Check `SharedPreferences` for `conexo_permissions_requested_v1`
2. If already requested → skip all, proceed to routing
3. If first launch:
   - Check Camera permission status
   - If not granted → request Camera
   - If permanently denied → show "Open Settings" dialog
   - Check Photos/Media permission status
   - If not granted → request Photos/Media
   - If permanently denied → show "Open Settings" dialog
   - Set `conexo_permissions_requested_v1 = true`
4. Proceed to `AuthGate.navigateToTarget()`

**Only these permissions are requested on first launch:**
- Camera (has implemented feature: profile photo capture)
- Photos/Media (has implemented feature: gallery selection via image_picker)

**NOT requested on first launch:**
- Location (no location feature implemented)
- Notifications (no notification feature implemented)
- Microphone (no audio feature implemented)

## 6. Android API 34 Permission Considerations

| Permission | Declared in AndroidManifest | Runtime Required | API 34 Behavior | Feature Dependency | Request on First Launch |
|---|---|---|---|---|---|
| `CAMERA` | Yes | Yes | Unchanged | Profile photo capture | YES |
| `READ_MEDIA_IMAGES` | Yes | Yes | Android 13+ (API 33) | Gallery selection via image_picker | YES |
| `ACCESS_FINE_LOCATION` | Yes | Yes | Unchanged | None yet | NO |
| `POST_NOTIFICATIONS` | Yes | Yes | Android 13+ (API 33) | None yet | NO |
| `RECORD_AUDIO` | Yes | Yes | Unchanged | None yet | NO |

**Photos/Media note:** On Android 13+ (API 33+), `image_picker` uses `READ_MEDIA_IMAGES` for gallery access. On older versions it falls back to `READ_EXTERNAL_STORAGE`. The existing `Permission.photos` in `permission_handler` handles this mapping automatically. No additional dependency is needed.

## 7. What Must Remain Untouched

- `lib/core/supabase/auth_service.dart`
- `lib/core/supabase/auth_gate.dart`
- `lib/core/supabase/supabase_client.dart`
- `lib/features/profile/profile_data.dart`
- `lib/features/profile/profile_repository.dart`
- `lib/features/profile/supabase_profile_repository.dart`
- `lib/features/profile/session_aware_profile_repository.dart`
- `lib/features/profile/my_profile_screen.dart`
- `lib/features/profile/profile_strength_screen.dart`
- `lib/features/profile/privacy_verification_screen.dart`
- All navigation/routing files
- Supabase schema/migrations
- RLS policies
- Profile backend CRUD logic

## 8. Validation Steps

1. `flutter analyze` — must pass with no new issues
2. **`.\tool\build_apk.ps1`** — APK must build successfully
3. **Fresh install runtime test:**
   - Install APK on fresh device/emulator
   - Launch app → verify Camera permission dialog appears first
   - Grant/deny → verify Photos/Media dialog appears next
   - Verify no Location/Notifications/Microphone dialogs appear
   - Verify app routes to correct screen after permissions
4. **Second launch:**
   - Close and reopen app
   - Verify no permission dialogs appear
5. **Profile creation photo flow:**
   - Open profile creation
   - Verify 6 glass card slots with "+" icons (no demo portraits)
   - Tap empty slot → verify camera/gallery choice
   - Take photo / select from gallery → verify image appears in slot
   - Verify no separate "Take Photo" / "Choose from Gallery" cards below grid
6. **Profile management photo flow:**
   - Edit profile with existing photos
   - Verify photos display in slots
   - Tap empty slot → verify camera/gallery choice
   - Verify reorder/remove still works

## 9. Permissions That Should NOT Yet Be Requested

| Permission | Reason |
|---|---|
| Location | No location/GPS feature implemented in Conexo yet |
| Notifications | No notification feature implemented yet |
| Microphone | No audio/voice feature implemented yet |

These permissions remain declared in `AndroidManifest.xml` for future feature phases. Requesting them now would confuse users and provide no functional benefit.
