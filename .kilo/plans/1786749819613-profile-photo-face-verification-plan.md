# Conexo Phase 10.3F — Self-Hosted Profile-Photo Face Verification Plan

## A. Forensic Findings

### Profile Data
- **`UserProfile` / `UserProfileDraft`** (`lib/features/profile/profile_data.dart`):
  - `photos` is a `List<ProfilePhoto>` ordered list.
  - `ProfilePhoto` carries `id`, `assetPath`, `isPrimary`, `remoteUrl`, `uploadStatus`.
  - **Primary photo**: first photo in the list after `_normalizePrimary()` enforces `isPrimary = (index == 0)`.
  - `VerificationStatus` enum: `notVerified`, `pending`, `verified`. Serialized as string name in `profiles.verification_status`.
- **Primary photo normalization**:
  - `_normalizePrimary()` lives in `profile_management_sections.dart:98-103` and `profile_creation_sections.dart:91-96`.
  - Called after every remove and reorder.
  - **No verification invalidation exists anywhere.** Changing photos never resets `verificationStatus`.

### Supabase
- **Schema** (`supabase/migrations/20260809000000_create_profiles_table.sql`):
  - `profiles` table has `verification_status TEXT NOT NULL DEFAULT 'notVerified'`.
  - No `photo_verified` column exists yet.
- **Repository** (`supabase_profile_repository.dart`):
  - `saveProfile()` maps `profile.verificationStatus.name` to `verification_status`.
  - `uploadProfilePhoto()` uploads to bucket `profile-photos` at `profiles/{userId}/photos/{photoId}.{ext}`.
  - `getSignedPhotoUrl()` creates 3600s signed URLs.
- **RLS**: Owner-only write. Authenticated users can SELECT public profiles.
- **No Edge Functions exist.** No `edge-functions/` or `functions/` directory.
- **Storage bucket `profile-photos`** is assumed private. No storage RLS migrations exist in the repo.

### Verification UI
- **`PrivacyVerificationScreen`** (`privacy_verification_screen.dart`):
  - Loads `UserProfile`, displays `PrivacySection` + `VerificationSection`.
  - `_onVerifyIdentity()` opens `ComingSoonDialog`. **No real verification flow exists.**
- **`VerificationSection`** (`privacy_verification_sections.dart:85-136`):
  - Shows `VerificationStatusCard`, benefits, and a "Verify Identity" CTA when `notVerified`.
  - Info note explicitly says verification data is not collected in this version.
- **Widgets** (`privacy_verification_widgets.dart`):
  - `VerifiedBadge`, `VerificationStatusCard`, `PrimaryActionButton`, `ComingSoonDialog`, `SaveSuccessOverlay`.

### Profile Hero
- **`ProfileHero`** (`public_profile_widgets.dart:119-310`):
  - Shows `VerifiedBadge(compact: true)` when `profile.verificationStatus == VerificationStatus.verified`.
  - Identity block: `displayName, age` + optional `occupation`.
- **`ImmersiveProfileView`** (`home_discovery_profile.dart`):
  - Same badge logic in `_BadgeColumn`.

### Photo Management
- **Upload**: `_uploadAndAddPhoto()` in `profile_creation_sections.dart:100-125` and `profile_management_sections.dart:105-127`.
- **Replace**: `_replacePhoto()` / `_uploadAndReplace()` in `profile_management_sections.dart:143-202`.
- **Delete**: `_remove()` in both creation and management sections.
- **Reorder**: `_reorder()` in `profile_management_sections.dart:88-93`.
- **Cleanup**: `profile_management_screen.dart:236-254` deletes orphaned remote URLs after save.
- **Invalidation gap**: None of the above touch `verificationStatus`.

### Camera
- **`pubspec.yaml`**: `image_picker: ^1.1.2`, `permission_handler: ^11.3.0`. **No `camera` package.**
- **AndroidManifest.xml**: `CAMERA` and `READ_MEDIA_IMAGES` permissions declared.
- **Existing code**: Only `ImagePicker().pickImage()` is used. No live camera preview.

### Cross-Profile Propagation
- **Discovery** (`discovery_repository.dart`): Fetches `verification_status`, maps to `DiscoveryProfile.verificationStatus`, boosts verified profiles in `bestMatch` sort.
- **Connections** (`connections_view_model.dart:288-292`): Reads raw `verification_status` string, maps to `isVerified`.
- **Profile navigation mapper** (`profile_navigation_mapper.dart`): Passes `verificationStatus` into `UserProfile` for all view models.
- **VerifiedBadge** is rendered in `ProfileHero`, `ImmersiveProfileView`, and `ConversationPreview`.

---

## B. Recommended Architecture

**Option A — On-device Flutter inference**: Not viable for server-side authority. The client would generate embeddings and set `photo_verified = true` locally. This violates the requirement that the backend owns the final verified state.

**Option B — Supabase Edge Function**: Not viable. Supabase Edge Functions run on Deno with limited memory (128–512 MB) and short timeouts. There is no mature, production-ready Deno-native face-recognition runtime that can load ArcFace/MobileFaceNet models and perform 1:1 embedding comparison reliably within these constraints.

**Option C — Self-hosted backend (RECOMMENDED)**: A small, dedicated Python service that owns the verification authority.

### Architecture Diagram

```text
Flutter App
    │
    │ 1. Capture selfie (camera)
    │ 2. POST /verify-face { selfie, access_token }
    ▼
Self-Hosted Verification Service (Python FastAPI)
    │
    │ 3. Verify Supabase JWT
    │ 4. Download primary profile photo from Supabase Storage
    │    (service role key, never exposed to Flutter)
    │ 5. Face detection on selfie
    │    → reject if 0 faces or >1 face
    │ 6. Face detection on primary photo
    │    → reject if 0 faces or >1 face
    │ 7. Generate embeddings (ArcFace via insightface)
    │ 8. Cosine similarity
    │ 9. Threshold check (e.g., >= 0.6)
    │
    │ 10. Update Supabase: photo_verified = true/false
    │     (via Postgres or Supabase API with service role key)
    │ 11. Delete selfie from temp storage (immediate)
    │     (embeddings are in-memory only, never written to disk)
    ▼
Supabase
    │
    │ photo_verified BOOLEAN
    │ (NO selfie stored, NO embeddings stored)
    ▼
Flutter App reads photo_verified → renders VerifiedBadge
```

### Where each stage lives
- **Face detection, embedding generation, comparison**: Self-hosted backend only.
- **Verification state authority**: Supabase `profiles.photo_verified`, written by the self-hosted backend.
- **Client role**: Capture selfie, send to backend, poll/receive result, render UI.
- **Primary photo source**: Supabase Storage `profile-photos` bucket. The backend resolves the current primary photo from the `photos` JSONB array in the `profiles` row.

---

## C. Required Dependencies

### Flutter (add to `pubspec.yaml`)
- `camera: ^0.11.0` — live front-camera preview during verification capture.
- `image_picker: ^1.1.2` — already present, keep for profile photo management.
- `permission_handler: ^11.3.0` — already present.

### Self-Hosted Backend (new service, not in Flutter)
- Python 3.10+
- `fastapi` — API framework
- `insightface` — face detection + ArcFace embedding generation
- `opencv-python-headless` — image decoding/preprocessing
- `supabase` — Python client for downloading primary photo and updating verification state
- `python-jose[cryptography]` — verify Supabase JWTs
- `python-multipart` — handle image uploads
- `uvicorn` — ASGI server

### Model/Runtime
- **Model**: `insightface` bundles buffalo_l (ArcFace) automatically. No separate model download required.
- **Runtime**: CPU-only inference. ~200–500ms per image on a modern x86_64 VPS CPU.

---

## D. Supabase Changes

### Migration
```sql
-- 20260815000000_add_photo_verified.sql
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS photo_verified BOOLEAN NOT NULL DEFAULT false;

-- Optional: track which photo version was verified
-- ALTER TABLE profiles
--   ADD COLUMN IF NOT EXISTS verified_photo_id TEXT;
```

### RLS Policy Update
```sql
-- Allow the self-hosted backend (via service role key) to update photo_verified.
-- The backend authenticates using service role key, bypassing RLS.
-- No client-facing RLS change needed.
```

### Storage
- Bucket `profile-photos` must be **private** (no anonymous read).
- The self-hosted backend uses the **service role key** to `download` the primary photo.
- **Verification selfies are NEVER uploaded to Supabase Storage.** They are received by the backend, processed in memory/temp disk, and deleted immediately.

### Edge Functions
- **None required.** All verification logic lives in the self-hosted backend.

---

## E. Flutter Changes

### Files likely to change
1. **`lib/features/profile/profile_data.dart`**
   - Add `photoVerified` field to `UserProfile` and `UserProfileDraft`.
   - Update `toJson()` / `fromJson()` / `fromProfile()` to include `photo_verified`.

2. **`lib/features/profile/supabase_profile_repository.dart`**
   - `loadProfile()`: map `photo_verified` column.
   - `saveProfile()`: include `photo_verified` in payload.

3. **`lib/features/profile/privacy_verification_screen.dart`**
   - Replace `ComingSoonDialog` with actual verification flow orchestration.
   - State: `verifying`, `errorMessage`.
   - On tap "Verify Profile Photo": navigate to a live camera capture screen.

4. **`lib/features/profile/privacy_verification_sections.dart`**
   - Update `VerificationSection` to show:
     - `notVerified`: "Verify that your profile photo belongs to you." + CTA.
     - `verified`: "Your profile photo has been matched to your live face."
   - Remove the "future feature" info note.

5. **New file: `lib/features/profile/face_verification_screen.dart`**
   - Live front-camera preview.
   - Capture button.
   - Loading state while backend processes.
   - Success/failure result handling.

6. **`lib/features/profile/public_profile_widgets.dart`**
   - `ProfileHero` already reads `verificationStatus`. After adding `photoVerified`, verify the badge logic uses the new field or continues using `verificationStatus`.
   - **Decision**: Keep `verificationStatus` as the display enum. Set it to `verified` when `photo_verified == true`. The backend or a repository method should sync these.

7. **`lib/features/profile/profile_navigation_mapper.dart`**
   - Ensure `photoVerified` / `verificationStatus` is propagated to all `PublicProfileViewData` instances.

8. **`lib/features/profile/profile_management_sections.dart`**
   - In `_normalizePrimary()` and `_remove()`, set `verificationStatus = VerificationStatus.notVerified` when the primary photo changes.

9. **`lib/features/profile/privacy_verification_widgets.dart`**
   - Update `VerificationStatusCard` and `PrimaryActionButton` text to match the desired states.

10. **`pubspec.yaml`**
    - Add `camera` dependency.

---

## F. Verification Flow

### Step-by-step

1. **User taps "Verify Profile Photo"** in `PrivacyVerificationScreen`.
2. **App requests camera permission** (already declared in `AndroidManifest.xml`).
3. **App navigates to `FaceVerificationScreen`** — shows live front-camera preview.
4. **User taps capture** — app takes a still image (`XFile`).
5. **App sends POST to self-hosted backend**:
   - Endpoint: `POST /api/v1/verify-face`
   - Headers: `Authorization: Bearer <supabase_access_token>`
   - Body: multipart form with `selfie` image.
6. **Backend validates JWT** — extracts `sub` (user ID).
7. **Backend fetches primary photo**:
   - Queries `profiles.photos` where `id = user.id`.
   - Identifies the photo where `isPrimary = true` (first in array).
   - Downloads that file from `profile-photos` bucket using service role key.
8. **Backend runs face detection** on selfie:
   - `insightface.get()` returns list of faces.
   - If `len(faces) != 1`: return `{ "match": false, "reason": "no_face" }` or `"multiple_faces"`.
9. **Backend runs face detection** on primary photo:
   - Same check. If `!= 1`: return `{ "match": false, "reason": "invalid_primary_photo" }`.
10. **Backend generates embeddings** for the single face in each image using ArcFace.
11. **Backend computes cosine similarity**.
12. **Threshold check**:
    - If `similarity >= 0.6` (configurable): `match = true`.
    - Else: `match = false`.
13. **Backend updates Supabase**:
    - `UPDATE profiles SET photo_verified = <match>, updated_at = now() WHERE id = <user_id>`.
    - Uses service role key.
14. **Backend deletes selfie temp file** (if written to disk). Embeddings are in-memory only.
15. **Backend returns** `{ "match": true/false, "threshold": 0.6 }`.
16. **Flutter receives result**:
    - Reloads profile via `loadProfile()`.
    - Shows success or failure state.
    - Badge updates automatically from persisted `verification_status`.

### UI States
- **Not Verified**: Status card + "Verify Profile Photo" CTA.
- **Verifying**: Spinner overlay, "Matching your face..." text.
- **Verified**: Status card + success copy. Badge appears in ProfileHero.
- **Failed**: Status card + failure copy. CTA reappears.

---

## G. Primary-Photo Invalidation

### Mutations that must clear verification
Any mutation that changes which photo is primary must set `verificationStatus = VerificationStatus.notVerified` and persist it.

### Exact paths
1. **`ManagePhotosSection._remove()`** (`profile_management_sections.dart:82-86`):
   - After `_normalizePrimary()`, if the removed photo was primary OR if the new primary differs from the old primary, call `onChanged(draft.copyWith(verificationStatus: VerificationStatus.notVerified))`.

2. **`ManagePhotosSection._reorder()`** (`profile_management_sections.dart:88-93`):
   - After `_normalizePrimary()`, if index 0 changed, call `onChanged(draft.copyWith(verificationStatus: VerificationStatus.notVerified))`.

3. **`_uploadAndAddPhoto()`** (`profile_management_sections.dart:105-127`):
   - If `photos.isEmpty` before add, new photo becomes primary. If previously verified, invalidate.

4. **`_uploadAndReplace()`** (`profile_management_sections.dart:162-202`):
   - If replacing the primary photo, invalidate verification.

5. **Profile creation finalization** (`profile_creation_screen.dart`):
   - Any photo added during creation makes first photo primary. Verification starts as `notVerified` — no special handling needed.

### Implementation detail
Modify `_normalizePrimary()` to return both the normalized list AND whether the primary changed, or add a helper:

```dart
bool _didPrimaryChange(List<ProfilePhoto> oldPhotos, List<ProfilePhoto> newPhotos) {
  final oldPrimary = oldPhotos.firstWhereOrNull((p) => p.isPrimary) ?? oldPhotos.firstOrNull;
  final newPrimary = newPhotos.first;
  return oldPrimary?.id != newPrimary?.id;
}
```

Then in every mutation path, if `_didPrimaryChange(...)` is true, set `verificationStatus = notVerified`.

### Recommended schema field
- **Use `photo_verified BOOLEAN` only.**
- `verified_photo_id` is **not necessary** at this stage.
- Rationale: The current architecture always makes the first photo primary. Invalidating on any primary change keeps the boolean sufficient. Adding `verified_photo_id` would require extra logic to compare IDs on every save and adds complexity without a concrete benefit for the current product requirements.

---

## H. Privacy / Data Retention

### What IS stored in Supabase
- `profiles.photo_verified` — boolean only.
- Normal profile photos in `profile-photos` bucket — unchanged.

### What is NOT stored in Supabase
- Live verification selfies.
- Verification videos.
- Face embeddings.
- Biometric templates.
- Government IDs.
- Raw face-recognition data.

### Temporary processing (self-hosted backend)
| Data | Where | How long | Deletion |
|------|-------|----------|----------|
| Selfie image | Backend temp disk (or memory) | During single request (~1-2s) | Deleted immediately after processing |
| Face embeddings | Backend memory only | During single request | Never written to disk; garbage-collected after request |

### Can temporary data reach Supabase Storage?
- **No.** The self-hosted backend must NOT upload selfies to Supabase Storage.
- The backend only writes the boolean `photo_verified` to the `profiles` table.
- Primary profile photos remain in the existing `profile-photos` bucket (private, signed URLs).

---

## I. Security

### Preventions
1. **No service role key in Flutter**: The Flutter app never holds or sends the Supabase service role key. Only the self-hosted backend holds it as an environment variable.
2. **No face embeddings to client**: Embeddings are generated and compared entirely in the backend. The client receives only `{ match: boolean }`.
3. **No client-side trust**: The client cannot set `photo_verified = true` directly. The backend writes this value after authenticating the user via Supabase JWT.
4. **Backend auth**: Every `/verify-face` request must include a valid Supabase access token. The backend verifies the JWT signature and `sub` claim.
5. **Temp data cleanup**: Selfies are deleted from backend temp storage immediately after inference. Embeddings never touch disk.
6. **Primary photo freshness**: Verification always uses the CURRENT primary photo fetched from Supabase at request time. No cached primary photo is trusted.
7. **Rate limiting**: The backend should rate-limit verification attempts per user to prevent abuse (e.g., 5 attempts per hour).

### Backend-to-Supabase auth
- Backend uses Supabase service role key for:
  - Downloading primary photos from Storage.
  - Updating `profiles.photo_verified`.
- The service role key is stored as an environment variable on the backend host. It never appears in the Flutter bundle or network requests from the app.

---

## J. Risks / Limitations

### Face matching without liveness
- **Risk**: A printed photo, screen replay, or deepfake could pass 1:1 matching.
- **Mitigation**: Conexo must clearly label this as "photo match" verification, NOT liveness detection or KYC. The UI copy should state: "Your live photo was matched to your profile photo."
- **Scope**: We are NOT implementing anti-spoof or liveness detection in Phase 10.3F. That is a future enhancement requiring different models (e.g., texture analysis, 3D depth, blink detection).

### ML runtime limitations
- `insightface` on CPU is ~200–500ms per image. Total request time ~1–3s. Acceptable for a "Verify" button flow.
- Requires a VPS with at least 2 CPU cores and 2 GB RAM. A $5–10/month VPS is sufficient.
- Cold start: If using serverless Python (Railway/Fly.io), cold starts add ~2–5s. Use always-on instances for production.

### Android performance
- Camera capture is standard `camera` package + `ImagePicker` alternative. No heavy ML runs on the device.
- The Flutter app only uploads a JPEG (~100–500KB) to the backend. Low bandwidth and CPU impact.

### False positives / false negatives
- ArcFace on `insightface` with cosine similarity threshold 0.6 is a reasonable default for 1:1 face verification.
- Threshold should be tuned on a small validation set before production.
- Lighting, angle, and occlusion will affect accuracy. Users may need to retake the selfie.

### Privacy implications
- Even though selfies are ephemeral, sending a live face photo to a server is a privacy step.
- The UI must disclose this clearly: "A temporary selfie is processed to verify your photo. It is not stored."
- Consider adding a privacy policy update.

### Infrastructure risk
- The self-hosted backend is a new point of failure. If it goes down, verification breaks.
- Mitigation: Health checks, monitoring, and a graceful fallback (show "Verification temporarily unavailable").

---

## K. Implementation Phases

### 10.3F.1 — Backend verification service setup
- Create Python FastAPI service.
- Add `insightface`, `opencv-python-headless`, `supabase`, `python-jose`.
- Implement `/health` and `/api/v1/verify-face` endpoints.
- Add JWT verification middleware.
- Configure environment variables: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `VERIFICATION_THRESHOLD`.
- Deploy to a test VPS (Railway/Fly.io/DigitalOcean).

### 10.3F.2 — Flutter camera capture screen
- Add `camera` to `pubspec.yaml`.
- Create `FaceVerificationScreen` with live front-camera preview.
- Request `PermissionType.camera`.
- Capture still image to `XFile`.
- Show loading state.

### 10.3F.3 — Flutter → backend integration
- Add API client method `verifyFace(XFile selfie)` in a new `VerificationRepository` or service class.
- Send multipart POST with Supabase access token.
- Handle success / failure / error responses.
- Update `PrivacyVerificationScreen` to call this flow.

### 10.3F.4 — Supabase schema migration
- Add `photo_verified BOOLEAN NOT NULL DEFAULT false` to `profiles`.
- Update `supabase_profile_repository.dart` to read/write `photo_verified`.
- Update `UserProfile` / `UserProfileDraft` models.

### 10.3F.5 — Primary-photo invalidation
- Add `_didPrimaryChange()` helper in `profile_management_sections.dart`.
- Invalidate `verificationStatus` in `_remove()`, `_reorder()`, `_uploadAndAddPhoto()`, `_uploadAndReplace()`.
- Ensure profile creation also starts with `notVerified`.

### 10.3F.6 — Verification UI updates
- Update `VerificationSection` copy for notVerified / verified / verifying / failed states.
- Replace "future feature" info note with accurate privacy copy.
- Update `PrivacyVerificationScreen` state management.

### 10.3F.7 — ProfileHero badge wiring
- Verify `ProfileHero` renders `VerifiedBadge` when `photo_verified == true` (via `verificationStatus`).
- Verify `ImmersiveProfileView` does the same.
- Verify `ConversationPreview` in chat uses the correct flag.

### 10.3F.8 — Cross-profile propagation
- Ensure `profile_navigation_mapper.dart` passes `verificationStatus` / `photoVerified` for all sources.
- Verify Discovery sort still boosts verified profiles.
- Verify Connections view reads the new field.

### 10.3F.9 — Security and privacy validation
- Confirm no service role key in Flutter.
- Confirm self-hosted backend never uploads selfies to Supabase Storage.
- Confirm temp files are deleted.
- Add rate limiting to backend.
- Add request timeout handling in Flutter.

### 10.3F.10 — Final testing
- Test flow: unverified → verify → verified → change primary photo → unverified.
- Test failure paths: no face, multiple faces, low similarity, backend down.
- Test cross-profile: verify on one device, view from another device in Discovery/Chat.
- Test primary photo invalidation via remove, reorder, replace.

---

## L. Final Recommendation

1. **Is genuine self-hosted 1:1 face matching feasible with the current Conexo architecture?**
   - **Yes**, but it requires adding a small self-hosted backend service alongside Supabase. The existing Flutter + Supabase architecture is compatible; it just needs a new compute layer for face recognition.

2. **Recommended model/runtime:**
   - **Backend**: Python FastAPI.
   - **Model**: `insightface` (ArcFace / buffalo_l).
   - **Inference**: CPU-only on a small VPS.

3. **Where it should execute:**
   - **Self-hosted backend only.** Not in Flutter, not in Supabase Edge Functions.

4. **Should Supabase store only `photo_verified`?**
   - **Yes.** The `profiles.photo_verified` boolean is the only persistent verification state in Supabase.

5. **Is `verified_photo_id` necessary?**
   - **No, not at this stage.** The current architecture always makes the first photo primary, and we will invalidate verification on any primary change. A boolean is sufficient.

6. **Should liveness be included now or deferred?**
   - **Deferred.** Conexo should clearly label this as "profile photo match," not liveness or KYC. Anti-spoof / liveness detection is a future phase requiring different models and UX.

7. **Any blocker that must be resolved before implementation?**
   - **No hard blockers.** The main work is provisioning the self-hosted backend and the new Flutter camera screen. The Supabase migration is a single column addition. All other pieces are additive changes to existing code.
