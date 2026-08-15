# Conexo Phase 10.2 — Profile Photo Bugs — Implementation Plan

## 1. Root Cause Analysis

### Issue 1 — New Photo Upload Fails

**Exact root cause:** Stale draft reference after `await` in both `_uploadAndAddPhoto` methods.

- **File:** `lib/features/profile/profile_creation_sections.dart:108`
- **File:** `lib/features/profile/profile_management_sections.dart:115`

In both files, after `await uploadProfilePhoto(...)`, the code reads `widget.draft.photos` / `draft.photos` to locate the optimistically-added photo by ID. However, `draft` / `widget.draft` is a `StatefulWidget` property that is only refreshed on the next build cycle. When the async upload completes, the parent has often not yet rebuilt, so the list does **not** contain the newly-added photo. The `map((p) => p.id == photoId ? ... : p)` therefore iterates over the **old** list and silently drops the `remoteUrl` / `uploadStatus` update.

Why Android and Web both fail: The race is between the microtask that completes the upload and the framework's rebuild of the parent widget. It is timing-dependent and platform-independent.

### Issue 2 — Replace Photo Is Intermittent

**Exact root cause:** Stale `_draft` + double-picker on Android.

- **File:** `lib/features/profile/profile_management_screen.dart:131-185`

Three compounding problems:

1. **Double-picker on Android** (`_replacePhoto` lines 137-147): The image is picked *before* the permission check. If permission is already granted, the code falls through and calls `picker.pickImage()` a **second** time, discarding the first selection. If the user cancels the second pick, the replacement silently aborts.

2. **Stale `_draft` after await** (`_uploadAndReplace` lines 174-176): After `await uploadProfilePhoto(...)`, the code reads `_draft.photos` and writes the completed replacement back to `_draft.photos[index]`. If the user edited other fields or reordered photos while the upload was in flight, `_draft` may have changed. Writing to a captured `index` can overwrite a different photo or lose the replacement entirely.

3. **No upload deduplication:** Rapid taps on the replace button spawn overlapping uploads that race to mutate `_draft`.

Why intermittent: The race window between picker completion and `_draft` mutation is small. Fast devices / slow networks produce different timing, making the failure appear random.

### Issue 3 — Profile Tab Does Not Show Persisted Photo After Relogin

**Exact root cause:** Local `assetPath` leaked into persisted Supabase row + `_HeroPhoto` display logic ignores fetched signed URLs.

Two compounding bugs:

**A. `assetPath` persisted to Supabase**
- **File:** `lib/features/profile/profile_data.dart:129`
- `ProfilePhoto.toJson()` always serializes `assetPath`, which is a device-local file path (e.g., `/data/user/0/.../cache/...` or `blob:...`).
- After a fresh login on another device, the loaded `UserProfile` carries these dead local paths.
- The edit screen (`ProfileManagementScreen`) loads the same stale `assetPath` from Supabase. Because the local file may still exist on the original device (cache not yet cleared), the photo *appears* to work on Device A. On Device B, the local path is invalid.

**B. `_HeroPhoto` ignores fetched signed URLs**
- **File:** `lib/features/profile/my_profile_hero.dart:336`
- **File:** `lib/features/profile/public_profile_widgets.dart:354-355`

Both hero widgets fetch a signed URL in `initState()` and store it in `_signedUrl`. But `build()` checks `displayUrl.startsWith('profiles/')` before rendering the network image. A signed URL is `https://...`, so the check **always fails**. The code falls through to the local-asset branches (`Image.file(widget.assetPath)` / `Image.asset(...)`).

On the original device, the stale local path may still resolve in cache → photo appears. On a fresh device, the path is dead → placeholder is shown. This is why Edit Profile (which uses `ProfilePhotoViewer` / `_RemotePhotoImage`) works correctly, while Profile/Public Profile (which uses `_HeroPhoto`) fails.

`_RemotePhotoImage` in `profile_creation_widgets.dart` is correctly implemented — it uses `_signedUrl` directly without the `startsWith` guard.

---

## 2. Exact Files to Modify

| File | What changes | Why | What does NOT change |
|------|-------------|-----|---------------------|
| `lib/features/profile/profile_creation_sections.dart` | Capture `widget.draft` at method entry in `_uploadAndAddPhoto`; use the captured draft for the post-upload `map` instead of reading `widget.draft` after `await`. | Eliminates stale-state race after async upload. | Picker logic, optimistic preview, permission flow, UI layout. |
| `lib/features/profile/profile_management_sections.dart` | Same stale-draft fix in `_uploadAndAddPhoto` as above. | Eliminates stale-state race for add-photo in management flow. | Picker logic, optimistic preview, reorder/remove UI. |
| `lib/features/profile/profile_management_screen.dart` | 1. Move permission check *before* first pick in `_replacePhoto`. 2. Capture `_draft` at `_uploadAndReplace` entry; locate the target photo by **ID** in the current draft after await, not by captured index. 3. Add in-flight upload cancellation / deduplication guard. | Fixes double-picker, stale-index, and concurrent-upload races. | Save logic, dirty detection, UI chrome, navigation. |
| `lib/features/profile/profile_data.dart` | 1. `ProfilePhoto.toJson()`: do **not** persist `assetPath` when `uploadStatus == uploaded` and `remoteUrl != null`. 2. `profileDraftEquals` / `_photosEqual`: include `remoteUrl` and `uploadStatus` in comparison. | 1. Prevents local file paths from leaking into Supabase. 2. Ensures drafts with completed uploads are considered dirty so Save is enabled and backend is updated. | Model shape, `fromJson`, all non-photo fields. |
| `lib/features/profile/my_profile_hero.dart` | Rewrite `_HeroPhotoState.build()` to prioritize `_signedUrl` when available; only fall back to `assetPath` when no remote URL exists or signed-URL fetch failed. | Uses the fetched signed URL instead of dead local paths. | PageView swipe logic, progress bars, identity block, animations. |
| `lib/features/profile/public_profile_widgets.dart` | Same `_HeroPhotoState.build()` rewrite as above. | Same signed-URL display fix for Public Profile. | Hero scrim, identity block, progress bars, all other widgets. |

---

## 3. State / Async Strategy

**Principle:** Capture immutable references at async boundaries; never read widget/state fields after an `await` unless the framework guarantees they are fresh.

**New-photo flow (creation & management):**
```
pickImage()
  → capture currentDraft = widget.draft (or _draft)
  → optimistic add: onChanged(currentDraft.copyWith(photos: [...currentDraft.photos, photo]))
  → await uploadProfilePhoto(...)
  → update = currentDraft.photos.map(p => p.id == photoId ? p.copyWith(...) : p)
  → onChanged(currentDraft.copyWith(photos: update))
```

The captured `currentDraft` is the **baseline** for the photo list. Other fields (bio, location) are not touched. If the parent mutates `_draft` concurrently, `onChanged` will merge the photo update into whatever the parent's current draft is (because the parent's `_onDraftChanged` simply assigns `_draft = draft`). This means concurrent non-photo edits are preserved; only the photo list is replaced with the captured baseline + uploaded photo.

**Replace flow (management):**
```
pickImage()
  → capture draftSnapshot = _draft
  → capture targetId = old.id
  → optimistic replace in draftSnapshot at index
  → onChanged(draftSnapshot.copyWith(photos: updated))
  → await uploadProfilePhoto(...)
  → find target in _draft.photos by ID (not index)
  → if found: update remoteUrl/uploadStatus
  → onChanged(_draft.copyWith(photos: ...))
  → if not found: silently discard (photo was removed while uploading)
```

Finding by ID makes the replacement robust against reorder/remove during the async window.

**Deduplication guard:**
Add a `Set<String> _inFlightUploads` to `_PhotosSectionState` / `ProfileManagementScreenState`. Before starting an upload, check if the photo ID is already in flight. If so, ignore the tap. Remove from the set on completion.

---

## 4. Upload Strategy

### New photo lifecycle
1. User picks image.
2. Optimistic `ProfilePhoto` appended to draft with `uploadStatus: uploading`.
3. `uploadProfilePhoto()` reads bytes, builds path `profiles/{userId}/photos/{photoId}.{ext}`, uploads to `profile-photos` bucket.
4. On success: photo updated to `uploadStatus: uploaded`, `remoteUrl = storagePath`.
5. On failure: photo updated to `uploadStatus: failed`.
6. User taps **Save** → `saveProfile()` persists the full `UserProfile` (including `remoteUrl`) to Supabase `profiles` table.
7. After save succeeds, orphaned remote objects (photos that were in `_original` but not in the saved draft) are deleted from Storage.

### Replacement lifecycle
1. User taps replace on slot `i`.
2. New `photoId` generated (`replace_{timestamp}`).
3. Optimistic `ProfilePhoto` inserted at index `i` with `uploadStatus: uploading`.
4. New object uploaded to Storage.
5. On success: optimistic photo updated to `uploadStatus: uploaded`, `remoteUrl = storagePath`.
6. User taps **Save** → metadata persisted.
7. After save succeeds: old Storage object (the one in `_original` but not in the new draft) is deleted.

**Safety invariant:** The old Storage object is deleted **only after** `saveProfile()` succeeds. This is already enforced in `_save()` and must remain so.

---

## 5. Persistence Strategy

After `saveProfile()`:

- `UserProfile.toJson()` serializes `photos` as JSON.
- For uploaded photos (`uploadStatus == uploaded`, `remoteUrl != null`), `assetPath` is **not** persisted.
- For local-only assets (`uploadStatus == local`), `assetPath` is persisted because it is a bundled demo asset (`assets/...`).
- The Supabase `profiles.photos` JSONB column retains: `id`, `isPrimary`, `remoteUrl` (Storage path), `uploadStatus`.

After fresh login / another device:
- `loadProfile()` reads the row.
- `UserProfile.fromJson()` reconstructs `ProfilePhoto` objects.
- `assetPath` is `''` (empty) for uploaded photos.
- `remoteUrl` is the Storage path (`profiles/{userId}/photos/{photoId}.jpg`).
- Display widgets use `remoteUrl` → signed URL. No local cache, SharedPreferences, or in-memory draft is required.

---

## 6. Signed URL Strategy

**Generation:**
- `SupabaseProfileRepository.getSignedPhotoUrl(storagePath)` calls `createSignedUrl(path, 3600)`.
- Returns a 1-hour signed URL.

**Display flow:**
```
ProfilePhoto.remoteUrl (Storage path)
  → _HeroPhoto / _RemotePhotoImage detects `profiles/` prefix
  → calls getSignedPhotoUrl(storagePath)
  → stores result in _signedUrl
  → Image.network(_signedUrl)
```

**Rules:**
- Signed URL is **never** persisted. It is generated fresh on every widget build cycle.
- Expired URLs are not cached across sessions; each `_HeroPhoto` / `_RemotePhotoImage` instance fetches its own signed URL in `initState`.
- If `getSignedPhotoUrl` throws or returns null, the widget shows a safe gradient placeholder (`_HeroPlaceholder` / `ColoredBox`).
- `Image.network` has an `errorBuilder` that also falls back to the placeholder.

---

## 7. Android / Web Safety

- No Android native code changes (`android/**` untouched).
- No changes to `AuthService`, `auth_gate.dart`, `supabase_client.dart`, `permission_manager.dart`.
- Permission handling logic is preserved; only the order of the permission check vs. image pick is fixed in `_replacePhoto` (check first, pick once).
- Web behavior: `kIsWeb` guards remain intact. Blob URLs (`blob:...`) are still handled for local previews. The signed-URL fix works identically on Web because `Image.network` is platform-agnostic.
- `ProfilePhotoViewer` and `_RemotePhotoImage` are not modified; they already work correctly.

---

## 8. Validation Plan

### Android Tests
1. **New upload:** Create profile → pick photo → verify optimistic preview → wait for upload → verify `remoteUrl` appears in edit grid → Save → verify photo persists after app restart.
2. **Replace photo:** Edit profile → replace slot 0 → verify old photo replaced by new → Save → verify old Storage object deleted.
3. **Concurrent replace:** Rapidly tap replace on same slot twice → verify only one upload runs → verify final photo is the last successful upload.
4. **Permission flow:** Deny photos permission → verify permission dialog → grant → verify picker appears once (not twice).
5. **Save/reload:** Edit profile → Save → logout → login → verify Profile tab shows uploaded photo.
6. **Cross-device:** Upload on Device A → logout → login on Device B → verify Profile tab and Public Profile both show the photo.

### Web Tests
1. **New upload:** Same as Android #1. No permission prompts.
2. **Replace photo:** Same as Android #2.
3. **Save/reload:** Same as Android #5.
4. **Cross-device:** Same as Android #6.

### Edge Cases
1. **Upload failure:** Pick photo → simulate network failure → verify photo shows `failed` state → verify Save is disabled or save excludes failed photo.
2. **Remove during upload:** Pick photo → while uploading, remove the slot → verify upload completes but is silently discarded (no crash, no orphaned draft state).
3. **Signed URL expiry:** Wait > 1 hour → verify placeholder is shown gracefully → verify scrolling away and back refetches a fresh signed URL.
4. **Empty profile:** No photos → verify placeholder is shown everywhere.

---

## 9. Regression Protection

Files/features that MUST remain untouched:

- `android/**` — no native changes.
- `lib/core/supabase/auth_service.dart` — no auth changes.
- `lib/core/supbase/supabase_client.dart` — no client changes.
- `lib/features/profile/privacy_verification_screen.dart` — untouched.
- `lib/features/profile/profile_strength_screen.dart` — untouched.
- `lib/features/chat/**` — untouched.
- `lib/features/connections/**` — untouched.
- `lib/features/plans/**` — untouched.
- Phase 10.1 Web background changes — no modifications to background rendering logic.

---

## 10. Approval Gate

**PLAN READY — AWAITING APPROVAL**
