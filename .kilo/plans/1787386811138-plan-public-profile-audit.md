# P1.3A — Plan → Canonical Public Profile Audit

## Scope
Audit only. No code changes. No migrations. No UI changes.

---

## 1. Canonical Public Profile Status

**FOUND** — `PublicProfileScreen` in `lib/features/profile/public_profile_screen.dart` is the single canonical public profile viewer.

**Canonical route:** `premiumPublicProfileRoute` in `lib/features/profile/public_profile_screen.dart:166`

**Current Plan → Public Profile flows already use the canonical route.** No duplicate profile screens exist.

---

## 2. Plan Flow Trace

### A. Plan Members
```
Plan → View Members → tap member → View Profile
```
- **Entry point:** `lib/features/plans/plan_members_screen.dart:130` (`_viewMember`)
- **Current route:** `premiumPublicProfileRoute`
- **Current mapper:** `mapPlanParticipantToProfile`
- **Current data source:** `PlanMembership` (from `SupabasePlanRepository.getPlanMembers`)
- **Current repository:** `SupabasePlanRepository`
- **Current UI:** `PublicProfileScreen`

### B. Plan Host
```
Plan Details → View Profile (host card)
```
- **Entry point:** `lib/features/plans/plan_details_screen.dart:140` (`_viewHostProfile`)
- **Current route:** `premiumPublicProfileRoute`
- **Current mapper:** `mapPlanParticipantToProfile`
- **Current data source:** `Experience.hostId`, `Experience.host`, `Experience.hostPortrait`
- **Current repository:** `SupabasePlanRepository.getPlanExperience`
- **Current UI:** `PublicProfileScreen`

### C. Plan Participants
```
Plan Details → participant avatar → View Profile
```
- **Entry point:** `lib/features/plans/plan_details_screen.dart:125` (`_viewParticipant`)
- **Current route:** `premiumPublicProfileRoute`
- **Current mapper:** `mapPlanParticipantToProfile`
- **Current data source:** `PlanMembership` (from `SupabasePlanRepository.getPlanMembers`)
- **Current repository:** `SupabasePlanRepository`
- **Current UI:** `PublicProfileScreen`

---

## 3. PublicProfileScreen Completeness Audit

The `PublicProfileScreen` **CAN** render the full canonical profile. It currently shows:

| Field | Rendered? | Source |
|-------|-----------|--------|
| Photos (swipeable gallery) | YES | `data.profile.photos` → `ProfileHero` PageView |
| Display name | YES | `data.displayName` |
| Verified badge | YES | `profile.verificationStatus == VerificationStatus.verified` |
| Age | YES | `data.age` (computed from `dateOfBirth` or passed directly) |
| Bio | YES | `profile.bio` → `AboutProfileSection` |
| About / aboutMe | YES | `profile.aboutMe` → `AboutProfileSection` |
| Interests | YES | `profile.interests` → `InterestsProfileSection` |
| Languages | YES | `profile.languages` → `LanguagesProfileSection` |
| Optional details | YES | `profile.location`, `education`, `college`, `company`, `hometown`, `website`, `favoriteActivities` → `OptionalDetailsSection` |
| Occupation | YES | `profile.occupation` → shown in `ProfileHero` identity block |
| Availability | YES | `profile.availabilityStatus` (field exists, not explicitly rendered in public profile sections) |
| Social links | YES | `profile.socialLinks` → `SocialLinksSection` |
| Hosted plans | YES (PLACEHOLDER) | Static `_placeholderPlans` list — NOT real backend data |

**Verdict:** The `PublicProfileScreen` is **FULL CANONICAL PROFILE** in capability. It is only as complete as the data passed to it via `PublicProfileViewData`.

---

## 4. Photo Audit — ROOT CAUSE IDENTIFIED

### Photo pipeline for Plan → Public Profile:

```
profiles.photos[]
    ↓
_fetchProfilePhotoUrls() [supabase_plan_repository.dart:704]
    ↓
ONLY primary photo extracted (line 720-723)
    ↓
getSignedPhotoUrls() batch sign
    ↓
PlanMembership.photoUrl (single signed URL)
    ↓
mapPlanParticipantToProfile() [profile_navigation_mapper.dart:200]
    ↓
Creates ONLY ONE ProfilePhoto with remoteUrl
    ↓
PublicProfileViewData.profile.photos (length = 1)
    ↓
ProfileHero PageView (renders 1 photo, no swipe)
```

### Key findings:

1. **`_fetchProfilePhotoUrls` only fetches the PRIMARY photo** (`supabase_plan_repository.dart:720-723`):
   ```dart
   final primary = photos.firstWhere(
     (p) => p is Map && p['isPrimary'] == true,
     orElse: () => photos.first,
   );
   ```
   Only one photo per user is ever returned.

2. **`mapPlanParticipantToProfile` creates exactly one `ProfilePhoto`** (`profile_navigation_mapper.dart:205-215`):
   ```dart
   final photos = <ProfilePhoto>[];
   final trimmed = photoUrl.trim();
   if (trimmed.isNotEmpty) {
     photos.add(ProfilePhoto(
       id: '${userId}_photo_0',
       assetPath: '',
       isPrimary: true,
       remoteUrl: trimmed,
       uploadStatus: PhotoUploadStatus.uploaded,
     ));
   }
   ```
   No loop. No gallery. Always a single photo.

3. **`ProfileHero` supports multi-photo swipe** (`public_profile_widgets.dart:296-305`):
   The UI CAN render multiple photos via `PageView.builder(itemCount: count)`. It is NOT limited to one photo. The limitation is purely in the data fed to it.

4. **Private photo bucket is UNCHANGED** — signed URL pipeline intact. RLS still enforced.

### All uploaded photos available: **NO**
Only the primary photo is fetched. Additional uploaded photos are never retrieved from the `profiles` table in the plan module.

---

## 5. Profile Data Completeness Comparison

| Field | Own Profile | Plan → Public Profile | Gap? |
|-------|------------|----------------------|------|
| Photos (all uploaded) | YES (full gallery) | NO (primary only) | **YES** |
| Display name | YES | YES (from `_fetchDisplayNames`) | NO |
| Verified badge | YES | NO (hardcoded `notVerified`) | **YES** |
| Age | YES (computed from DOB) | NO (null) | **YES** |
| Bio | YES | NO (empty) | **YES** |
| About / aboutMe | YES | NO (empty) | **YES** |
| Interests | YES | NO (empty) | **YES** |
| Languages | YES | NO (empty) | **YES** |
| Optional details | YES | NO (empty) | **YES** |
| Occupation | YES | NO (empty) | **YES** |
| Availability | YES | NO (hardcoded 'offline') | **YES** |
| Social links | YES | NO (empty) | **YES** |
| Hosted plans | NO (own profile doesn't show them) | YES (PLACEHOLDER) | Mixed |

### Where information is lost:

1. **`mapPlanParticipantToProfile`** (`profile_navigation_mapper.dart:200-236`) hardcodes almost every field to empty/defaults.
2. **`PlanMembership` model** (`plan_details_data.dart:20-56`) only carries `planId`, `userId`, `role`, `status`, `joinedAt`, `updatedAt`, `displayName`, `photoUrl`. No profile content fields.
3. **`Experience` model** (`plans_data.dart:39-118`) only carries `host`, `hostId`, `hostPortrait`. No profile content fields.
4. **`PlanHostDetails`** (`plan_details_data.dart:116-152`) is pure demo data — `isVerified` is always `false`, `rating` is always `0.0`, `plansHosted` is always `0`.

---

## 6. Hosted Plans Audit

**Source:** `PublicProfileScreen._placeholderPlans` (`public_profile_screen.dart:29-45`)

```dart
static const List<HostedPlanPlaceholder> _placeholderPlans = [
  HostedPlanPlaceholder(title: 'Weekend Hike', subtitle: 'Outdoors • Sat', icon: Icons.hiking_rounded),
  HostedPlanPlaceholder(title: 'Coffee & Chat', subtitle: 'Social • Sun', icon: Icons.coffee_rounded),
  HostedPlanPlaceholder(title: 'Live Music Night', subtitle: 'Music • Fri', icon: Icons.music_note_rounded),
];
```

**Verdict:** DEMO / PLACEHOLDER. Static const data. No repository, no backend query, no real plans.

**Own Profile tab:** Does NOT show hosted plans at all (`my_profile_screen.dart` has no `HostedPlansSection`).

---

## 7. Three-Dot Menu Architecture

**Own Profile:** Has full three-dot menu (Safety, Help, About, etc.) in `my_profile_screen.dart`.

**Public Profile:** Has `PublicProfileHeader` with:
- Back button (functional)
- `more_horiz` icon with `onTap: null` (disabled/visual only)

**Verdict:** Already architecturally clean. The non-owner profile intentionally lacks the three-dot menu. No change needed.

---

## 8. Privacy Audit

- **Plan module queries** go through `SupabasePlanRepository` which uses RLS-protected table queries.
- **`_fetchProfilePhotoUrls`** queries `profiles.photos` — protected by existing RLS policies.
- **`_fetchDisplayNames`** queries `profiles.display_name` — protected by existing RLS policies.
- **`SupabaseProfileRepository.loadProfileByUserId`** (added in P1.3) queries `profiles` with `.eq('id', userId)` — protected by the `"Authenticated users can read public profiles"` policy which requires `profile_visibility = 'public'`.
- **Private photo bucket:** UNCHANGED. Signed URL pipeline intact. RLS on `profile-photos` bucket enforces visibility.

Private profiles remain protected. No bypasses detected.

---

## 9. Root Cause Summary

The Plan → Public Profile experience is limited NOT because `PublicProfileScreen` is incomplete, but because:

1. **`mapPlanParticipantToProfile` strips all profile data** — passes only name, userId, and one photo.
2. **`_fetchProfilePhotoUrls` only fetches the primary photo** — the plans module never retrieves additional uploaded photos.
3. **`PlanMembership` and `Experience` models carry no profile content** — bio, interests, languages, etc. are never fetched into the plan module.
4. **Host verification is demo-only** — `PlanHostDetails.isVerified` is hardcoded to `false`.

The `PublicProfileScreen` is fully capable of rendering the complete profile. The data starvation happens upstream in the plan module's data fetching and mapping layers.

---

## 10. Recommended Minimal Fix

### Option A: Repository-level profile fetch (preferred)
Add a method to `SupabasePlanRepository` (or reuse `SupabaseProfileRepository`) to fetch the full `UserProfile` for a given userId when opening a public profile from Plans. Replace `mapPlanParticipantToProfile` with `mapUserProfileToPublicProfile` for Plan flows.

**Pros:** Minimal change. Reuses existing canonical mapper. Gets ALL photos, bio, interests, languages, etc.
**Cons:** One extra query per profile view (acceptable for read-only profile viewing).

### Option B: Enhance `_fetchProfilePhotoUrls` to return ALL photos
Modify `_fetchProfilePhotoUrls` to return all photos (not just primary), then enhance `mapPlanParticipantToProfile` to build a full gallery.

**Pros:** Keeps plan module self-contained.
**Cons:** Still doesn't solve the bio/interests/languages gap — those fields are simply never fetched into the plan module.

### Option C: Hybrid — fetch full UserProfile for profile views
When a Plan flow triggers a profile view, fetch the full `UserProfile` via `SupabaseProfileRepository.loadProfileByUserId`. This is the cleanest approach because it gets ALL data in one query.

**Recommendation:** Option C. The plan module already has the userId. Fetching the full profile is one query, gets everything, and reuses the canonical `mapUserProfileToPublicProfile`.

---

## 11. Files That WOULD Need Changing (for implementation, NOT in this audit)

1. `lib/features/plans/plan_details_screen.dart` — replace `mapPlanParticipantToProfile` with `mapUserProfileToPublicProfile` + `loadProfileByUserId`
2. `lib/features/plans/plan_members_screen.dart` — same replacement
3. `lib/features/plans/supabase_plan_repository.dart` — possibly add a convenience method, or rely on `SupabaseProfileRepository` directly
4. `lib/features/profile/profile_navigation_mapper.dart` — no changes needed (canonical mapper already exists)

### Files That MUST NOT Be Changed
- `lib/features/profile/public_profile_screen.dart`
- `lib/features/profile/public_profile_data.dart`
- `lib/features/profile/public_profile_widgets.dart`
- `lib/features/profile/public_profile_sections.dart`
- `lib/features/home_screen.dart`
- `lib/features/home_discovery_profile.dart`
- Any People/Discovery files

---

## 12. Migrations Required

NO — The existing `profiles` table already contains all the data. The RLS policies already protect it. No schema changes needed.

---

## 13. People/Discovery Changes Required

NO — Discovery already shows the complete profile inline via `ImmersiveProfileView`. No changes needed.

---

## 14. Final Determination

The `PublicProfileScreen` is **FULL CANONICAL PROFILE** in UI capability. The Plan → Public Profile limitation is entirely due to upstream data starvation in the plan module's mappers and data models. The fix is to fetch the full `UserProfile` (via the existing `SupabaseProfileRepository.loadProfileByUserId`) and map it with the existing `mapUserProfileToPublicProfile`, instead of using `mapPlanParticipantToProfile` which only passes a name and one photo.

==================================================
P1.3A — FINAL AUDIT REPORT
==================================================

People/Discovery:
NOT TOUCHED

Canonical Public Profile:
FOUND

Canonical screen:
PublicProfileScreen in lib/features/profile/public_profile_screen.dart

Canonical route:
premiumPublicProfileRoute in lib/features/profile/public_profile_screen.dart:166

Plan → Member → Profile:
Entry point: lib/features/plans/plan_members_screen.dart:130
Current route: premiumPublicProfileRoute
Current mapper: mapPlanParticipantToProfile
Current data source: PlanMembership (supabase_plan_repository.getPlanMembers)
Current repository: SupabasePlanRepository
Current UI: PublicProfileScreen

Plan → Host → Profile:
Entry point: lib/features/plans/plan_details_screen.dart:140
Current route: premiumPublicProfileRoute
Current mapper: mapPlanParticipantToProfile
Current data source: Experience.hostId/host/hostPortrait (supabase_plan_repository.getPlanExperience)
Current repository: SupabasePlanRepository
Current UI: PublicProfileScreen

Plan → Participant → Profile:
Entry point: lib/features/plans/plan_details_screen.dart:125
Current route: premiumPublicProfileRoute
Current mapper: mapPlanParticipantToProfile
Current data source: PlanMembership (supabase_plan_repository.getPlanMembers)
Current repository: SupabasePlanRepository
Current UI: PublicProfileScreen

Current profile data source:
PlanMembership + Experience — both carry only name, userId, and a single primary photo URL. No bio, interests, languages, or other profile content fields.

Current profile mapper:
mapPlanParticipantToProfile — strips all profile content, hardcodes everything to empty/defaults.

Current profile UI:
PublicProfileScreen — FULL CANONICAL PROFILE in capability. Limited only by the data fed into it.

All uploaded photos available:
NO — only the primary photo is fetched. _fetchProfilePhotoUrls in supabase_plan_repository.dart:704-759 only extracts the primary photo. mapPlanParticipantToProfile creates exactly one ProfilePhoto.

Photo loss point:
1. _fetchProfilePhotoUrls (line 720-723) selects only the primary photo from profiles.photos[]
2. mapPlanParticipantToProfile (line 205-215) creates a single ProfilePhoto with that one URL
3. No additional photos are ever requested or passed to PublicProfileScreen

Signed URL pipeline:
INTACT — primary photo goes through getSignedPhotoUrls batch signing. Private photos blocked by RLS.

Hosted Plans source:
DEMO / PLACEHOLDER — PublicProfileScreen._placeholderPlans is a static const list (public_profile_screen.dart:29-45). No backend query.

Missing profile fields:
- Photos: only primary (all others lost upstream)
- Bio: empty
- About/aboutMe: empty
- Interests: empty
- Languages: empty
- Optional details: empty
- Occupation: empty
- Age: null
- Verified: hardcoded notVerified
- Availability: hardcoded offline
- Social links: empty

Three-dot menu architecture:
ALREADY CLEAN — PublicProfileHeader has back + disabled more_horiz. Own Profile has full three-dot menu. No change needed.

Public profile privacy:
PRESERVED — all plan module queries use RLS. SupabaseProfileRepository.loadProfileByUserId queries profiles table directly, protected by "Authenticated users can read public profiles" policy (requires profile_visibility='public').

Private photo bucket:
UNCHANGED

Root cause:
mapPlanParticipantToProfile hardcodes all profile content fields to empty/defaults, and the plan module's _fetchProfilePhotoUrls only fetches the primary photo. The PublicProfileScreen itself is complete; the data starvation is upstream.

Recommended minimal fix:
Replace mapPlanParticipantToProfile with mapUserProfileToPublicProfile + SupabaseProfileRepository.loadProfileByUserId in Plan entry points. This fetches the full canonical UserProfile in one query and reuses the existing canonical mapper.

Files that WOULD need changing:
1. lib/features/plans/plan_details_screen.dart
2. lib/features/plans/plan_members_screen.dart
3. Possibly lib/features/plans/supabase_plan_repository.dart (for a convenience wrapper)

Files that MUST NOT be changed:
- lib/features/profile/public_profile_screen.dart
- lib/features/profile/public_profile_data.dart
- lib/features/profile/public_profile_widgets.dart
- lib/features/profile/public_profile_sections.dart
- lib/features/home_screen.dart
- lib/features/home_discovery_profile.dart
- All People/Discovery files

Migrations required:
NO

People/Discovery changes required:
NO

==================================================
AUDIT ONLY — NO CODE CHANGED
==================================================
