# Phase 10.2 — New-Photo Disappearance Fix

## Confirmed root cause

In `_uploadAndAddPhoto` (creation and management sections), `currentDraft` / `draft` is captured **before** the optimistic photo is added. After `await uploadProfilePhoto(...)`, the code maps over that stale `currentDraft.photos`, which does **not** contain the newly inserted photo. The second `onChanged(...)` therefore replaces the parent’s live draft with the old photo list, and the photo vanishes from the UI even though the Storage upload succeeded.

## Files to modify

ONLY these two files:

1. `lib/features/profile/profile_creation_sections.dart`
2. `lib/features/profile/profile_management_sections.dart`

## Exact change

In the **post-upload success path** of `_uploadAndAddPhoto`, replace the stale snapshot `currentDraft.photos` / `draft.photos` with the **current live draft** that contains the optimistically inserted photo.

### Creation sections (`profile_creation_sections.dart`)

In `_PhotosSectionState._uploadAndAddPhoto`, after the `await` in the `try` block:

```dart
// BEFORE (bug):
final updated = currentDraft.photos.map((p) { ... }).toList();
widget.onChanged(currentDraft.copyWith(photos: updated));

// AFTER (fix):
final updated = widget.draft.photos.map((p) { ... }).toList();
widget.onChanged(currentDraft.copyWith(photos: updated));
```

Do the same replacement in the `catch` block.

### Management sections (`profile_management_sections.dart`)

In `ManagePhotosSection._uploadAndAddPhoto`, after the `await` in the `try` block:

```dart
// BEFORE (bug):
final updated = draft.photos.map((p) { ... }).toList();
onChanged(draft.copyWith(photos: updated));

// AFTER (fix):
final updated = draft.photos.map((p) { ... }).toList();
onChanged(draft.copyWith(photos: updated));
```

Do the same replacement in the `catch` block.

**Note:** The management section is a `StatelessWidget`, so it accesses the live draft via the `draft` parameter (which the parent passes freshly on rebuild). Using `draft.photos` after `await` gives the current list containing the optimistic photo.

## What must NOT change

- Do NOT revert to `currentDraft.photos` / `draft.photos` from before the optimistic add.
- Do NOT touch `profile_management_screen.dart` `_uploadAndReplace` (it already uses `_draft.photos` correctly).
- Do NOT modify any other file.
- Do NOT change `ProfilePhoto.toJson()`, `_photosEqual`, signed URL logic, Storage config, RLS, auth, navigation, UI.

## Validation

1. Run `flutter analyze`.
2. Run `flutter build apk --dart-define-from-file=tool/supabase_dev.json`.
3. Confirm both succeed.
