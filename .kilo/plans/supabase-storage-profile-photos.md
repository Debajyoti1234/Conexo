# Conexo Phase 10.2 — Supabase Storage Profile Photo Persistence

## 1. Current Profile Photo Architecture

**Model (`profile_data.dart`):**
- `ProfilePhoto` has: `id`, `assetPath`, `isPrimary`, `remoteUrl` (String?, placeholder), `uploadStatus` (PhotoUploadStatus: local/uploading/uploaded/failed)
- `remoteUrl` and `uploadStatus` exist but are **never populated or persisted** by any repository
- Photos are stored as `List<ProfilePhoto>` in both `UserProfileDraft` and `UserProfile`
- Serialized as JSON in the `profiles.photos` column

**Repository (`supabase_profile_repository.dart`):**
- `saveProfile()` writes `photos` JSON to the `profiles` table
- `loadProfile()` reads from the `profiles` table
- **No Storage upload/download/delete code exists anywhere in the codebase**

**Draft persistence (`LocalProfileRepository`):**
- Drafts stored in `SharedPreferences` as JSON
- Photos in drafts use local `assetPath` only

**Key finding:** The schema is **already sufficient** — `remoteUrl` and `uploadStatus` fields exist but are unused. No migration needed.

---

## 2. Current Database Schema Relevant to Photos

The `profiles` table stores photos as a JSON array in a `photos` column. Each photo object includes:
```json
{
  "id": "camera_123456",
  "assetPath": "/data/user/0/com.conexo.app/cache/...",
  "isPrimary": true,
  "remoteUrl": null,
  "uploadStatus": "local"
}
```

The schema already supports remote URLs and upload status. No changes needed.

---

## 3. Existing Supabase Storage

**Current state:**
- No Storage bucket exists in the project
- No Storage code exists in the codebase
- No upload/delete helpers exist

**Required setup (MUST be completed before implementation):**
- Create a `profile-photos` bucket in Supabase Storage
- Configure RLS policies for authenticated-user CRUD on their own prefix
- **Do NOT make the bucket public**

---

## 4. RLS / Storage Policies

**Cannot verify without Supabase dashboard access.** Must be configured before Flutter implementation.

Required capabilities for authenticated users:
- INSERT their own profile photos
- UPDATE/overwrite their own photos
- DELETE their own photos
- SELECT/read their own stored files

**STOP implementation if bucket/policies are not ready.** Do not attempt to bypass them from Flutter.

---

## 5. Web XFile Handling

- `image_picker` on Web returns `XFile` with `path` as a `blob:` URL
- `XFile.readAsBytes()` returns `Uint8List` — works on both Android and Web
- **Do NOT use `XFile.path` with `dart:io.File` on Web**
- Upload bytes directly via `Supabase.instance.client.storage.from('profile-photos').upload(path, bytes)`

---

## 6. Android XFile Handling

- `XFile.path` returns a real file path
- `XFile.readAsBytes()` also works
- Safest approach: use `readAsBytes()` for both platforms (unified)

---

## 7. Recommended Storage Path Strategy

```
profiles/{userId}/photos/{photoId}.{extension}
```

Where:
- `{userId}` = `AuthService.currentUser.id` — ensures user isolation
- `{photoId}` = existing `ProfilePhoto.id` (e.g., `camera_${millisecondsSinceEpoch}`) — no filename collisions
- `{extension}` = from original filename (jpg, png, etc.)

**Properties:**
- Deterministic ownership (userId in path)
- Easy deletion (known path)
- Easy replacement (overwrite same path)
- No personal info in filenames
- Works on Android and Web

**Important:** `ProfilePhoto.remoteUrl` stores the **Storage object path**, not a literal URL.
Example: `profiles/{userId}/photos/{photoId}.jpg`

---

## 8. Recommended Path Strategy

Store the **Storage object path** in `ProfilePhoto.remoteUrl`. Never store a literal URL (public or signed) because:
- Signed URLs expire
- Public URLs would require a public bucket

Example: `profiles/{userId}/photos/{photoId}.jpg`

**Important:** `ProfilePhoto.remoteUrl` stores ONLY the Storage object path, not a URL.

---

## 8a. Signed URL Generation

Because the `profile-photos` bucket must remain **private** with no anonymous access, the UI must generate **authenticated signed URLs** when displaying remote photos:

```dart
Future<String?> getSignedPhotoUrl(String storagePath) async {
  try {
    return await Supabase.instance.client
      .storage
      .from('profile-photos')
      .createSignedUrl(storagePath, 3600);
  } catch (e) {
    debugPrint('Failed to generate signed URL for $storagePath: $e');
    return null;
  }
}
```

**Display flow:**
1. Read `ProfilePhoto.remoteUrl` (Storage object path)
2. Call `createSignedUrl(path, expiry)` to get a temporary signed URL
3. Pass signed URL to `Image.network()`
4. If signed URL generation fails, show a placeholder image

**Why signed URLs:** Respects private bucket + RLS policies. No public/anonymous access required.

---

## 9. Exact Files That Would Need Modification

| File | Change | Why |
|------|--------|-----|
| `lib/features/profile/supabase_profile_repository.dart` | Add `uploadProfilePhoto()` and `deleteProfilePhoto()` methods | Handles Storage upload/delete + returns Storage object path |
| `lib/features/profile/profile_creation_sections.dart` | After `ImagePicker().pickImage()`, trigger upload; update `ProfilePhoto.remoteUrl` and `uploadStatus` | Connects creation flow to Storage |
| `lib/features/profile/profile_management_sections.dart` | Same as above for edit/replace/delete | Connects management flow to Storage |
| `lib/features/profile/profile_creation_widgets.dart` | Update `ProfilePhotoViewer` to convert Storage path → signed URL → `Image.network()` | Display remote photos via signed URL |
| `lib/features/profile/profile_management_widgets.dart` | Same signed URL display handling | Display remote photos via signed URL |
| `lib/features/profile/my_profile_hero.dart` | Same signed URL display handling | Display remote photos via signed URL |
| `lib/features/profile/public_profile_widgets.dart` | Same signed URL display handling | Display remote photos via signed URL |

---

## 10. Exact Files That Must Remain Unchanged

- `android/` — all Android files
- `lib/core/services/permission_manager.dart`
- `lib/core/services/live_location_tracker.dart`
- `lib/core/supabase/auth_service.dart`
- `lib/core/supabase/auth_gate.dart`
- `lib/core/supabase/supabase_client.dart`
- `lib/features/splash/splash_screen.dart`
- `lib/features/login_screen.dart`
- `lib/main.dart`
- `lib/features/chat/**` — Phase 9.5.2 frozen
- `lib/features/connections/**`
- `lib/features/plans/**`
- `lib/app/theme/app_widgets.dart`
- `tool/run.ps1`
- `tool/build_apk.ps1`
- `tool/supabase_dev.json`
- `tool/supabase_vercel.json`
- `vercel.json`
- `pubspec.yaml`
- All Supabase migrations/RLS/RPC files
- Phase 10.1 Web background files

---

## 11. Android/Web Upload Strategy

**Unified byte-based upload (both platforms):**

```dart
Future<String?> uploadProfilePhoto(String photoId, XFile xfile) async {
  final user = AuthService.currentUser;
  if (user == null) return null;

  final bytes = await xfile.readAsBytes();
  final ext = xfile.name.split('.').last;
  final path = 'profiles/${user.id}/photos/$photoId.$ext';

  await Supabase.instance.client
    .storage
    .from('profile-photos')
    .upload(path, bytes);

  return path; // Storage object path — store in ProfilePhoto.remoteUrl
}
```

**Why bytes:** Works identically on Android (file → bytes) and Web (blob → bytes). No platform-specific code needed.

**Display:** When the UI needs to show a remote photo, convert the stored Storage path to a signed URL using `createSignedUrl()` (see Section 8a). Never store the signed URL in the database.

---

## 12. Supabase Dashboard Prerequisites

**MUST be completed BEFORE any Flutter implementation.**

### Required Storage Configuration

1. **Create Storage bucket:** `profile-photos`
   - **PRIVATE** — do NOT enable public/anonymous access
   - No public URL access allowed

2. **Configure RLS policies** for the `profile-photos` bucket:
   - Authenticated users can INSERT objects to their own prefix: `profiles/{auth.uid()}/photos/*`
   - Authenticated users can UPDATE/overwrite their own objects
   - Authenticated users can DELETE their own objects
   - Authenticated users can SELECT/read their own objects
   - No cross-user access
   - No anonymous access

3. **Verify policies** before implementation:
   - Confirm authenticated users can access only their own `profiles/{userId}/` prefix
   - Confirm no public/anonymous access is possible

**If bucket/policies are not configured, STOP implementation and report exactly what must be created/configured in Supabase.** Do not attempt to bypass Storage restrictions from Flutter.

---

## 13. Failure/Recovery Strategy

### Replacement (safe order — CORRECTED)
1. Upload new object to Storage
2. Save new Storage path to profile metadata
3. Confirm profile metadata save succeeded
4. Delete old Storage object

**Never delete the old photo before the new metadata has been successfully persisted.**

### Deletion (safe order — CORRECTED)
1. Remove photo from local state immediately
2. Update profile metadata (remove photo from JSON)
3. Confirm metadata update succeeds
4. Delete Storage object in background

**Do not permanently remove the Storage object until the profile metadata update succeeds.** If metadata update fails, preserve the old object and restore/retain existing UI state.

### Upload failure
- Upload fails → existing photo remains intact; do NOT update `remoteUrl`; set `uploadStatus = failed`

### Best-effort cleanup
- If Storage upload succeeds but subsequent profile save fails: implement best-effort cleanup of the orphaned Storage object. Do not leave known orphan objects intentionally as the normal path.

---

## 14. Validation Plan

### Android
```bash
.\tool\run.ps1
```
- Add photo → verify upload → verify display
- Multiple photos → verify ordering
- Replace photo → verify old replaced, new shown
- Delete photo → verify removed from UI + Storage
- Close/reopen app → verify photos reload from Supabase
- Confirm UI unchanged

### Web Localhost
```bash
.\tool\run.ps1 -d chrome --web-port 5000
```
- Add photo from gallery → verify upload → verify display
- Camera picker → verify upload → verify display
- Multiple photos → verify ordering
- Replace → verify old replaced
- Delete → verify removed
- Refresh browser → verify photos persist
- Log out/in → verify photos reload
- Verify no `Image.file`/`File(blob:)` errors

### Supabase
- Verify Storage objects exist in `profile-photos` bucket
- Verify paths match `profiles/{userId}/photos/{photoId}.{ext}`
- Verify no cross-user access
- Verify `createSignedUrl()` works for authenticated users
- Verify signed URLs are NOT stored in database
- Verify deleted/replaced objects are cleaned up

---

## 15. Risks / Open Decisions

| Risk | Mitigation |
|------|-----------|
| No existing Storage bucket | **STOP** — must create `profile-photos` bucket + RLS policies before Flutter implementation |
| RLS policies not yet configured | **STOP** — must configure before production |
| Large image uploads | No size limits currently enforced; may need client-side compression later |
| Network failures during upload | Failure strategy above handles gracefully |
| Orphaned Storage objects | Best-effort cleanup implemented; not blocking |
| Signed URL generation failure | Display placeholder image; do not crash |

---

## 16. Supabase Dashboard Prerequisites (MUST complete before implementation)

Before any Flutter code changes:

1. **Create Storage bucket:** `profile-photos`
   - **PRIVATE** — do NOT enable public/anonymous access
   - No public URL access allowed

2. **Configure RLS policies** for the `profile-photos` bucket:
   - Authenticated users can INSERT/UPDATE/DELETE/SELECT on `profiles/{userId}/`
   - No cross-user access
   - No anonymous access

3. **Verify policies** before implementation:
   - Confirm authenticated users can access only their own `profiles/{userId}/` prefix
   - Confirm bucket is NOT public
   - Confirm `createSignedUrl()` works for authenticated users

**If bucket/policies are not ready, STOP implementation and report exactly what must be created/configured in Supabase.** Do not attempt to bypass Storage restrictions from Flutter.

---

## 17. Implementation File List (for approval)

| File | Change |
|------|--------|
| `lib/features/profile/supabase_profile_repository.dart` | Add `uploadProfilePhoto()`, `deleteProfilePhoto()` |
| `lib/features/profile/profile_creation_sections.dart` | Trigger upload after picker |
| `lib/features/profile/profile_management_sections.dart` | Trigger upload/replace/delete |
| `lib/features/profile/profile_creation_widgets.dart` | Remote URL display |
| `lib/features/profile/profile_management_widgets.dart` | Remote URL display |
| `lib/features/profile/my_profile_hero.dart` | Remote URL display |
| `lib/features/profile/public_profile_widgets.dart` | Remote signed URL display |

---

## 18. Implementation Helper (new file or existing utility)

Add a small reusable signed-URL helper used by all display widgets:

```dart
Future<String?> getSignedPhotoUrl(String storagePath) async {
  try {
    return await Supabase.instance.client
      .storage
      .from('profile-photos')
      .createSignedUrl(storagePath, 3600);
  } catch (e) {
    debugPrint('Failed to generate signed URL for $storagePath: $e');
    return null;
  }
}
```

---

## 19. Approval Gate

**PLAN READY — AWAITING EXPLICIT IMPLEMENTATION APPROVAL**

No code has been modified. No migrations have been created. No RLS policies have been changed.

**Prerequisite:** Supabase `profile-photos` bucket + RLS policies must be configured before implementation begins.
