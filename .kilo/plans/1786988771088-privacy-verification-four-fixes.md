# Privacy & Verification — Four Targeted Fixes (Refined, Implementation-Ready)

Surgical refinement — not a refactor. Make the smallest safe changes for the four fixes, preserve all known-good behavior and premium Conexo styling. After these land + validate, Privacy & Verification is **frozen**. Do not implement until approved.

## Scope (only these four)
1. Processing-screen **width** fix (height unchanged).
2. Photo **reorder** must NOT reverify; add/replace/remove → `notVerified`.
3. Owner-profile **verification status** beside Name/Age (tappable → Privacy & Verification).
4. Owner-profile **privacy icon** before the verification status.

---

## Key architecture facts (verified in code)

- **Verification source of truth:** Supabase `profiles.verification_status`. Written by the backend after a verify attempt AND by the app on every save via `SupabaseProfileRepository.saveProfile` payload key `verification_status` (`supabase_profile_repository.dart:92`). Loaded through `loadProfile()`. ⇒ the app's saved status must be correct or an edit overwrites the backend value.
- **Enum:** `VerificationStatus { notVerified, pending, verified }` (`profile_data.dart:41`). `pending` is handled in UI but the current 3-angle flow resolves synchronously to verified/notVerified; the header still maps it if present.
- **Photo identity:** `ProfilePhoto.id` (`profile_data.dart:101`) is stable, persisted round-trip, and already the reorder `ValueKey`. Reorder preserves ids; add/replace/remove change the id set.
- **Current reverify trigger (wrong):** a scattered "primary-photo-changed" heuristic in `ManagePhotosSection._reorder` (`profile_management_sections.dart:99-110`), `._remove` (`:87-97`), `._uploadAndAddPhoto` (`:122-155`, only when list was empty), and `ProfileManagementScreen._uploadAndReplace` (`profile_management_screen.dart:162-208`, only when `old.isPrimary`). This wrongly invalidates on reorder-that-changes-primary and wrongly keeps status on non-primary add/replace/remove.
- **Header widget is shared:** `ProfileHero` (`public_profile_widgets.dart:119`) via `HeroSection` (`public_profile_sections.dart:18`) is used by BOTH the owner (`my_profile_screen.dart:234`) and non-owners (`public_profile_screen.dart:89`). Owner-only UI must be gated by a defaulted `owner` flag so `PublicProfileScreen` stays byte-for-byte unchanged.
- **Owner navigation exists:** `MyProfileScreen._openPrivacy()` (`:100-106`) pushes `premiumPrivacyVerificationRoute` and calls `_load()` on return (auto-refresh). 3-dot menu entry (`:327-328`) must remain.
- **Processing width cause:** `_ProcessingView` (`three_angle_capture_screen.dart:380-412`) `Column` gets loose width from `AnimatedSwitcher`'s default centered `Stack`, so it collapses to its widest hard-wrapped `Text` (~70%, centered).
- **Color tokens to reuse:** `_kVerified = 0xFF47D7A5` (`public_profile_widgets.dart:25`), `_kPending = 0xFFF0C25A` (`privacy_verification_widgets.dart:18`), accent `0xFF8B5CF6`.

---

## Implementation tasks (ordered)

### Task 1 — Processing width (`three_angle_capture_screen.dart`, `_ProcessingView` only)
- Wrap the existing `Column` in `SizedBox(width: double.infinity, child: Column(...))` inside the existing `Padding(EdgeInsets.fromLTRB(24, 24, 24, 28))`.
- Keep `crossAxisAlignment: center`, both `Spacer`s, `VerifyingIndicator`, texts, typography, colors, animation, `AnimatedSwitcher`, and all other phases untouched.
- Result: content spans full available width (minus 24px sides); height unchanged.

### Task 2 — Photo-set identity helper (`profile_data.dart`)
- Add a pure, order-independent helper near `profileDraftEquals`/`_photosEqual` (~line 801/822):
  ```dart
  bool verifiedPhotoSetChanged(List<ProfilePhoto> before, List<ProfilePhoto> after) {
    final b = {for (final p in before) p.id};
    final a = {for (final p in after) p.id};
    return b.length != a.length || !b.containsAll(a);
  }
  ```
- No other behavior; used by Task 3.

### Task 3 — Single authoritative verify decision at save (`profile_management_screen.dart`, `_save()`)
- In `_save()` before building the profile:
  ```
  changed = verifiedPhotoSetChanged(_original.photos, _draft.photos)
  status  = changed ? VerificationStatus.notVerified : _original.verificationStatus
  savedDraft = _draft.copyWith(verificationStatus: status)
  profile = UserProfile.fromDraft(savedDraft, id: _profileId)
  ```
- After successful save set `_original = _draft = savedDraft` (keeps local baseline consistent for subsequent edits).
- Baseline is `_original` (the loaded persisted profile, matching Supabase’s current `verification_status`).

### Task 4 — Photo handlers only mutate photos (remove status resets)
- Remove the `verificationStatus` reset logic from (they should ONLY change `photos`):
  - `ManagePhotosSection._reorder` (`profile_management_sections.dart`)
  - `ManagePhotosSection._remove`
  - `ManagePhotosSection._uploadAndAddPhoto`
  - `ProfileManagementScreen._uploadAndReplace` (`profile_management_screen.dart`)
- `_save()` (Task 3) is the sole decision point. Reorder still persists (order/`isPrimary` differences keep it "dirty" via `_photosEqual`).

### Task 5 — Owner header: verification badge beside Name/Age (`public_profile_widgets.dart`)
- Add optional params to `ProfileHero`: `bool owner = false`, `VoidCallback? onOpenPrivacyVerification`.
- Owner path: replace the current "verified badge above name" block with a single-line cluster:
  `Row( Flexible(Text(titleLine, maxLines:1, ellipsis)) , privacyBadge , verificationBadge )`.
- Verification badge (reuse the translucent-pill visual language of the existing `VerifiedBadge`, NOT a Material button/card):
  - `verified` → `Icons.verified_rounded`, label "Verified", color `_kVerified`.
  - `pending`  → `Icons.hourglass_top_rounded`, label "Pending", color `_kPending`.
  - `notVerified` → `Icons.shield_outlined`, label "Verify", color accent `0xFF8B5CF6`.
- Wrap the badge in a tap target → `onOpenPrivacyVerification`. Add `Semantics`/tooltip.
- Non-owner path: unchanged (existing `VerifiedBadge` above name, only when verified, not tappable, no privacy icon).

### Task 6 — Owner header: privacy icon before verification (`public_profile_widgets.dart`)
- Compact privacy badge rendered BEFORE the verification badge (order: `Name, Age → Privacy → Verification`):
  - `profile.profileVisibility == public` → `Icons.public_rounded`, tooltip/Semantics "Public".
  - `private` → `Icons.lock_rounded`, tooltip/Semantics "Private".
- Same pill visual weight as the verification badge; tap → `onOpenPrivacyVerification` (shortcut only; no privacy persistence/logic change).

### Task 7 — Forward owner params + wire navigation
- `public_profile_sections.dart`: add `owner`/`onOpenPrivacyVerification` to `HeroSection` and forward to `ProfileHero` (defaults preserve non-owner behavior).
- `my_profile_screen.dart`: pass `owner: true` and `onOpenPrivacyVerification: _openPrivacy` to `HeroSection`. Existing `_openPrivacy` → `_load()` on return refreshes the badge. Leave the 3-dot menu entry intact.

---

## Verification state matrix (result of Tasks 2–4)
```
same photo IDs, reordered → set unchanged → keep original status (e.g. Verified stays Verified)
photo added               → set changed   → notVerified
photo removed             → set changed   → notVerified
photo replaced            → set changed   → notVerified
```
Note (approved product decision): the backend matches the selfie to the primary photo, yet reorder (even if the primary changes) intentionally keeps verification — all of the owner's own photos belong to the same verified person.

## Owner header structure
```
Public  + Verified   →  Name, Age   [🌐 public]  [✓ Verified]
Private + Verify     →  Name, Age   [🔒 lock]    [🛡 Verify]
Public  + Pending    →  Name, Age   [🌐 public]  [⏳ Pending]
Private + Pending    →  Name, Age   [🔒 lock]    [⏳ Pending]
```
- Long names: `Flexible` + `TextOverflow.ellipsis` on the title; badges stay compact.
- Tap Privacy or Verification → Privacy & Verification (`_openPrivacy`).

## Processing structure (unchanged except full width)
```
┌──────────────────────────────────────────────┐
│                   (Spacer)                    │
│                indicator ◉                    │
│                  All set!                     │
│         We're reviewing your photos.          │
│         This may take a few seconds…          │
│                   (Spacer)                    │
└──────────────────────────────────────────────┘
```

---

## Files

**Must change**
- `lib/features/profile/verification/three_angle_capture_screen.dart` (Task 1)
- `lib/features/profile/profile_data.dart` (Task 2)
- `lib/features/profile/profile_management_screen.dart` (Tasks 3, 4)
- `lib/features/profile/profile_management_sections.dart` (Task 4)
- `lib/features/profile/public_profile_widgets.dart` (Tasks 5, 6)
- `lib/features/profile/public_profile_sections.dart` (Task 7)
- `lib/features/profile/my_profile_screen.dart` (Task 7)
- `test/features/profile/**` (new/updated tests)

**Must NOT change** (out of scope)
- `lib/features/profile/profile_creation_sections.dart` (creation profiles are always `notVerified`; its resets are harmless — leave as-is).
- Backend (`backend/face-verification/**`), Railway, Vercel, `/api/v1/verify-face`, `/api/v1/verify-face-multi`, matching algorithm, threshold `0.40`, InsightFace.
- Face-verification transport (`face_verification_client.dart`), iOS/web + Android multipart, image normalization.
- Supabase auth, Google auth, email/password auth.
- Supabase photo storage/upload, signed URLs, `verification_status` schema, `saveProfile` columns.
- 3-angle capture, guidance UI, success/failure UI, verification status UI (except the processing-width fix).
- Existing privacy settings logic/persistence, existing navigation, 3-dot menu, `PublicProfileScreen`.
- Discovery, Plans, People, Connections, Rooms, Android Gradle/Kotlin, OAuth config.

---

## Regression rules
- Owner UI gated by `owner` (default false) ⇒ `PublicProfileScreen` and every other `HeroSection`/`ProfileHero` consumer render exactly as today.
- Only the edit/save path decides verification; `saveProfile` payload/columns unchanged ⇒ backend `verification_status` preserved on reorder-only, correctly cleared on real content changes.
- No backend/API/threshold/model/transport/storage/auth code touched.
- Task 1 edits only `_ProcessingView`; other phases and `AnimatedSwitcher` untouched ⇒ height/animation preserved.
- Navigation reuses `_openPrivacy` + `_load`; 3-dot entry intact.

---

## Tests required (`test/features/profile/`)

**Unit — `verifiedPhotoSetChanged`**
- same ids reordered → `false`
- id added → `true`
- id removed → `true`
- id replaced → `true`

**Widget — owner header** (`ProfileHero`/`HeroSection` with `owner: true`)
- Renders correct badge per status: Public+Verified, Private+Verified, Public+Pending, Private+Pending, Public+Verify, Private+Verify.
- Order is exactly `Name, Age → Privacy → Verification`.
- Tapping Privacy badge and tapping Verification badge each invoke the Privacy & Verification callback.
- Non-owner (`owner: false`) rendering unchanged (no privacy icon, no Verify/Pending affordance, not tappable).

**Keep passing:** `test/features/profile/verification/verification_flow_test.dart`, `test/features/profile/selfie_verification_test.dart`, `test/widget_test.dart`.

---

## Validation

Commands (per project rules; never `flutter run`/`flutter build`):
```powershell
flutter analyze
flutter test
.\tool\build_apk.ps1
```

Manual checklist:
1. Processing screen fills available width; height unchanged.
2. Reorder photos while Verified → stays **Verified**.
3. Add a photo → **Verify** (notVerified).
4. Remove a photo → **Verify**.
5. Replace a photo → **Verify**.
6. Pending status → renders **Pending**.
7. Owner header order exactly `Name, Age → Privacy → Verification`.
8. Public → globe icon.
9. Private → lock icon.
10. Verification badge → opens Privacy & Verification.
11. Privacy badge → opens Privacy & Verification.
12. Existing 3-dot → Privacy & Verification still works.
13. `PublicProfileScreen` unchanged.
14. Existing verification flow still works.
15. Google Auth untouched.
16. Railway/Vercel verification transport untouched.

---

## Resolved decisions (previously open)
- Privacy icon tap → opens Privacy & Verification (confirmed by refinement).
- "Verify" icon → `Icons.shield_outlined` (🛡), matching existing verification language (confirmed).
- Long-name handling → `Flexible` + ellipsis on the title, badges beside name (chosen approach).
- Badge style → reuse the translucent-pill language of existing `VerifiedBadge`/`VerificationBadge`; no generic Material button/card.
