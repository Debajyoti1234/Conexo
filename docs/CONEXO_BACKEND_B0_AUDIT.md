# CONEXO BACKEND B0 AUDIT

> Audit-only phase. No code, migrations, RLS, storage, or seed changes were made.
> Scope: `supabase/migrations/*` + `lib/**` + `backend/face-verification` (read-only trace).

## Overall status

The backend is **substantially real** (Supabase-backed) for Auth, Profiles, Photos (storage), Discovery, Filters (subset), Connections, Chat (1:1), and Safety/Blocking. It is **incomplete** for Notifications, User Devices, Plans (backend), and conversation *list* aggregation. There are **legacy/demo remnants** (chat demo data, a `create_migrations.py` version-collision hazard) that must not be re-run. `flutter analyze` is clean (11 info lints, 0 errors).

---

## 1. Authentication
Status: ✅ COMPLETE
Evidence: `lib/core/supabase/auth_service.dart`, `auth_gate.dart`, `signup_screen.dart`, `phone_auth_screen.dart`, `login_screen.dart`, `splash_screen.dart`.
Implemented:
- Supabase Auth via `supabase_flutter` (`SupabaseClientConfig`, `AuthService`).
- Email/password signup (`signUp`, stores `name` in `auth.users` metadata), login (`signInWithPassword`), logout (`signOut`), password reset (`resetPasswordForEmail`).
- Google sign-in implemented (`signInWithGoogle`: `GoogleSignIn` + `signInWithIdToken` on Android; OAuth on web).
- Phone OTP implemented at service layer (`signInWithPhone` + `verifyPhoneOtp`) with a `phone_auth_screen.dart` UI.
- Session persistence: handled by Supabase Auth (refresh tokens); `authStateChanges` stream exposed.
- Auth → Profile relationship: `AuthGate.navigateToTarget()` checks `ProfileStatus` and routes to `ProfileCreationScreen` or `MainShell`. Profile row is created client-side on completion (no DB trigger / `handle_new_user`).
Partial:
- Phone auth UI exists but its wiring into the main signup flow is secondary; Google sign-in is debug-traced (`_gtrace`) but functional.
Missing: No `handle_new_user` trigger — a signed-up-but-incomplete user has no `profiles` row until the creation flow runs `saveProfile()` (acceptable, but means no auto-provisioned profile).

---

## 2. Profiles
Status: ✅ COMPLETE
Evidence: `profile_data.dart` (models), `profile_repository.dart` (local base + `ProfileStatus`), `supabase_profile_repository.dart` (Supabase repo), `session_aware_profile_repository.dart`, `profile_creation_screen.dart`, `profile_management_screen.dart`, `my_profile_screen.dart`.
Implemented:
- Table: `profiles` (`20260809000000`). Columns include `photos JSONB`, `bio`, `interests TEXT[]`, `languages TEXT[]`, `gender`, `location`, `social_links JSONB`, `occupation`, `education`, `company`, `college`, `hometown`, `website`, `about_me`, `favorite_activities TEXT[]`, `verification_status` (default `'notVerified'`), `profile_visibility` (default `'public'`), `date_of_birth DATE`, `display_name`, `availability_status`, `latitude/longitude DOUBLE PRECISION`, `profile_completed BOOLEAN`, timestamps.
- Model: `UserProfile` / `UserProfileDraft` / `ProfilePhoto` (with `remoteUrl` + `uploadStatus`).
- Repository: `SupabaseProfileRepository` (upsert, select, draft in `SharedPreferences`-backed `LocalProfileRepository`). `SessionAwareProfileRepository` switches local↔Supabase by session.
- Creation: `ProfileCreationScreen` → `saveProfile()` upserts.
- Editing: `ProfileManagementScreen` → upsert (includes `profile_completed = validateDraft(draft)`).
- Visibility: `profile_visibility` enum (public/private) — canonical source = `profiles.profile_visibility`.
- Completeness: `profile_completed` + constraint `profiles_completed_requires_dob` (DOB required for completion).
- Verification status: `verification_status` (notVerified/pending/verified) — canonical source = `profiles.verification_status` (set by external face-verification backend, see §2/§3).
- Occupation: canonical = `profiles.occupation`. Age: derived from `date_of_birth` (canonical). Distance/location: `profiles.latitude/longitude` + `live_locations` (see §6). Interests/preferences: `profiles.interests`, plus `discovery_distance_km/min_age/max_age`.
- Discovery eligibility = `profile_visibility='public' AND profile_completed=true AND date_of_birth IS NOT NULL` (enforced in `DiscoveryRepository.fetchNearby`).
Canonical-field note: device-local `ProfilePhoto.assetPath` is for local gallery assets only; once uploaded `remoteUrl` (storage path) becomes canonical for remote display. `DiscoveryProfile.name` and `.displayName` are both derived from `display_name` (duplication, minor — see §14).

---

## 3. Profile Photos / Storage
Status: 🟡 PARTIAL
Evidence: `supabase_profile_repository.dart` (`uploadProfilePhoto`, `deleteProfilePhoto`, `getSignedPhotoUrl`, `getSignedPhotoUrls`), `home_discovery_cache.dart` (`DiscoveryPhotoCache`), `home_screen.dart` (`_prefetchBatch`), `home_discovery_profile.dart`, `my_profile_screen.dart`, `profile_creation_*`/`profile_management_*`, `20260828000000_allow_public_profile_photo_reads.sql`.
Implemented:
- Bucket: `profile-photos` (private). Upload path format **`profiles/{userId}/photos/{photoId}.jpg`** confirmed in `uploadProfilePhoto` and consumed by signed-URL readers.
- Upload flow: `profile_creation_sections.dart` / `profile_management_sections.dart` → `uploadProfilePhoto()` (normalizes → JPEG → `uploadBinary`).
- Delete flow: `deleteProfilePhoto()` (`storage.remove`).
- Signed URL generation: `createSignedUrl(path, 3600)`; `DiscoveryPhotoCache` caches signed URL + `NetworkImage` provider + `precacheImage`.
- Photo path format matches RLS policy folder layout `profiles/{id}/photos/{photoId}.jpg`.
- Storage RLS (`20260828000000`): `Authenticated can read public profile photos` — reads allowed iff `bucket_id='profile-photos'` AND the owning `profiles.id` row has `profile_visibility='public'`. So OWN photo → readable; PUBLIC other user → readable; PRIVATE other user → protected. Matches spec.
Gaps:
- The **`profile-photos` bucket is NOT created by any migration.** It is only referenced by the RLS policy + plan docs (`supabase-storage-profile-photos.md`). Bucket creation is assumed manual (dashboard). This is not version-controlled → 🟡.
- No bucket idempotent-creation migration. No object lifecycle/cleanup.
- No duplicate/orphan cleanup when a photo is removed from the profile.

---

## 4. Discovery
Status: ✅ COMPLETE (functional; no server pagination)
Evidence: `profile/discovery_repository.dart` (`fetchNearby`), `discovery_data.dart`, `discovery_helpers.dart`, `home_screen.dart` (`_loadProfiles`, `_applyDiscoveryProfileFilter`), `connections_screen.dart` (consumed-connections feed).
Implementation (real Supabase):
- Query: `profiles.select(...).neq('id', me).eq('profile_visibility','public').eq('profile_completed', true).not('date_of_birth','is',null).inFilter('gender', eligibleTargetGenders(viewerGender))`.
- Is it real users? **Yes** — `fetchNearby` reads `profiles` directly. No demo/mock data in the feed. (`DiscoveryPerson`/`home_discovery_data.dart` demo model is legacy/UI-only — see §14.)
- Exclusions:
  - Self: `neq('id', user.id)`.
  - Incomplete/missing DOB: `profile_completed=true AND date_of_birth IS NOT NULL`.
  - Private: `profile_visibility='public'`.
  - Blocked (either direction): `_loadBlockedProfileIds` (from `blocked_users`).
  - Connected (pending/accepted): `_loadConsumedProfileIds` (from `connections`).
  - Duplicate profiles: prevented by `id` primary key + `not('id','in',consumedIds)`.
- Gender filter: **hard-coded opposite-gender** via `eligibleTargetGenders(viewerGender)` (man→woman, woman→man, non-binary/other→both). Not user-adjustable.
- Distance: `haversine` over viewer coords (live_locations, else profile coords) vs candidate coords (live_locations, else profile coords) with `isLocationFresh` (60 min) gating.
- Sorting: `DiscoverySortMode` closest / recentlyJoined / bestMatch / mostActive.
- Pagination: **NOT implemented** (single unbounded `select()`; in-memory `_applyDiscoveryProfileFilter`). OK for current scale; note as gap.
- Ordering: via `_applySort`.
- Preload/cache: `_prefetchBatch` + `DiscoveryPhotoCache` + `precacheImage` before first paint. No superfluous network calls beyond signed-URL generation per visible photo (cached).

---

## 5. Filters
Status: 🟡 PARTIAL
Evidence: `discovery_preferences_screen.dart` (prefs UI), `discovery_repository.dart` (`distanceWithinDiscoveryPreference`, `ageWithinDiscoveryPreference`, `eligibleTargetGenders`), `home_screen.dart` (`_FilterPreferencesSheet`, `_applyDiscoveryProfileFilter`, `_kDiscoveryFilterKeywords`), `profile_data.dart` (preference fields).

| Filter | UI exists? | Model exists? | Local persistence | Supabase persistence | Backend query | Affects Discovery? |
|---|---|---|---|---|---|---|
| **Distance (pref)** | Yes (prefs screen + inert sheet chips) | Yes (`discovery_distance_km`) | No (Supabase) | Yes (`profiles.discovery_distance_km`) | Yes (`distanceWithinDiscoveryPreference`) | ✅ Yes |
| **Age range (pref)** | Yes (prefs screen) | Yes (`discovery_min_age/max_age`) | No | Yes | Yes (`ageWithinDiscoveryPreference`) | ✅ Yes |
| **Gender** | No UI | n/a | n/a | n/a | Hard-coded opposite-gender via `eligibleTargetGenders` | ✅ (not user-set) |
| **Location** | No | `location`/`lat`/`lng` | No | Yes | Used for distance only, no radius-by-location UI | Partial |
| **Interests** | Segment chips defined (`Coffee/Walk/Music/Study`) | `interests` | No | Yes | Keyword filters defined in `_kDiscoveryFilterKeywords`/`_applyDiscoveryProfileFilter` | ❌ No UI to select |
| **Occupation** | No | `occupation` | No | Yes | Not filtered | ❌ |
| **Availability "Available Now"** | Sheet chip (inert) | `availability_status` | No | Yes | Defined in `_applyDiscoveryProfileFilter` (`'available_now'`) | ❌ No UI to select |
| **Verified only** | Sheet chip (inert) | `verification_status` | No | Yes | Defined in `_applyDiscoveryProfileFilter` | ❌ No UI to select |
| **New / Shared Interests / Nearby** | Defined in `_applyDiscoveryProfileFilter` | n/a | n/a | n/a | Defined | ❌ No UI to select |
| **Sort mode** | Yes (sheet) | `DiscoverySortMode` | No | No (client) | `_applySort` | ✅ Yes |

Key finding: The on-screen `_FilterPreferencesSheet` (`home_screen.dart`) renders **Distance / Availability / Verification** ChoiceChips that have **no `onChanged` handler** — only **Sort** is wired. The rich keyword/segment filters in `_applyDiscoveryProfileFilter` + `_kDiscoveryFilterKeywords` are **never reachable** (`_selectedFilter` stays `'All'`). So live filtering beyond Sort + the persisted Distance/Age preferences (set in `DiscoveryPreferencesScreen`) does **not** occur from the filter sheet.

---

## 6. Location / Distance
Status: 🟡 PARTIAL
Evidence: `profile/live_location_data.dart`, `live_location_repository.dart` (`upsert`, `fetchAll`), `core/services/live_location_tracker.dart`, `core/services/location_service.dart`, `discovery_helpers.dart` (`haversine`, `isValidCoordinate`, `isLocationFresh`), `discovery_repository.dart`.
- Coordinates storage: `live_locations(user_id PK, latitude, longitude, updated_at)` + fallback `profiles.latitude/longitude`.
- Who can read: `live_locations` SELECT = `auth.role()='authenticated'` → **any signed-in user can read ALL users' exact live coordinates** (see §13 flag).
- Exact coords exposed: **Yes** to all authenticated users (both `live_locations` and `profiles` lat/long). Privacy concern.
- Distance calculation: `haversine` (Earth radius 6,371,000 m), candidate coords prefer `live_locations` (fresh ≤60 min) else `profiles` coords.
- Distance filtering: `distanceWithinDiscoveryPreference` (km↔m) from `discovery_distance_km`.
- Location updates: `LiveLocationTracker` (`_interval = 30 min`, `high` accuracy, `Geolocator`) — periodic, not continuous.
- Stale locations: `isLocationFresh` 60-min window; stale `live_locations` ignored (falls back to profile coords; if those invalid → candidate dropped).
- Units: km / m correct (`formatDistance`).
Gaps: over-permissive live-location RLS; no continuous realtime location; no client "last seen" semantics beyond `updated_at`.

---

## 7. Connections
Status: ✅ COMPLETE
Evidence: `profile/connection_data.dart`, `connection_repository.dart`, `connections_view_model.dart`, `realtime_connections_service.dart`, `20260817000000`–`20260820000000` migrations.
- Table: `connections(id, requester_id, recipient_id, status, created_at, updated_at)`, constraints `connections_status_check`, `connections_no_self`, unique pair `idx_connections_unique_pair` (LEAST/GREATEST) for pending/accepted.
- Model: `Connection` (`ConnectionStatus`: pending/accepted/rejected/cancelled) + `ConnectionResult<T>`.
- Repository: `sendRequest`, `acceptRequest`, `rejectRequest`, `cancelRequest`, `getConnectionBetween`, `getMyConnections`, `getIncomingRequests`, `getOutgoingRequests`.
- RLS: SELECT own; INSERT as requester; UPDATE narrowly scoped (requester cancel / recipient accept-reject) with correct `WITH CHECK`; DELETE own; trigger `enforce_connection_transitions` (SECURITY DEFINER) enforces legal transitions.
- State machine (canonical): `pending_sent → accepted | rejected | cancelled` (plus `rejected`/`cancelled` terminal). No `blocked` status — blocking is a separate `blocked_users` table.
- Duplicate request handling: unique-pair index + `23505` handling in `sendRequest` ("A connection already exists") + discovery `consumed` exclusion.
- Blocking interaction: `sendRequest` calls `_isBlocked` (both directions) before inserting.
Realtime: `connections` added to `supabase_realtime` (`20260820000000`); `RealtimeConnectionsService` subscribed in `connections_screen.dart`.

---

## 8. Chat
Status: 🟡 PARTIAL
Evidence: `chat/chat_repository.dart` (`ChatRepository` + `LocalChatRepository`), `chat_models.dart`, `message_models.dart`, `chat_dtos.dart`, `realtime_messages_service.dart`, `conversation_screen.dart`, `connections_screen.dart` (`ConnectionsInboxScreen`), `20260821000000`/`20260822000000` migrations, `backend/` (none — chat has no edge function).
IMPLEMENTED (1:1 connection chat):
- Tables: `conversations(type 'connection'|'plan', plan_id)`, `conversation_members(user_id, conversation_id, last_read_at)`, `messages(sender_id, type, content, media_url, deleted_at)`.
- RPC: `get_or_create_connection_conversation(p_connection_id)` (SECURITY DEFINER, md5-deterministic id) — creates the 1:1 conversation for an accepted connection.
- `ChatRepository`: `loadMessages` (soft-delete aware), `sendMessage`, `updateLastReadAt`, `loadUnreadCount`, `getLatestMessagePreview`.
- Realtime: `RealtimeMessagesService` (per-conversation + global) subscribed from `conversation_screen.dart` and `connections_screen.dart`.
- Wiring: `connections_screen.dart` opens the conversation with the **real** `ChatRepository` (`chatRepository: _chatRepository`); inbox previews built from real RPCs. So 1:1 chat is fully functional and realtime.
PARTIAL / MISSING:
- **No conversation-list repository.** Inbox builds previews from `connections` (accepted) `getOrCreateConnectionConversation` per connection — works for 1:1. The **Plans tab** in the inbox (`_plans`) is **demo** (`LocalChatRepository.loadPlanConversations`).
- **Plan conversations (`type='plan'`) have no creation path** — no `create_plan_conversation` RPC; plan chat is absent.
- `conversation_screen.dart` **defaults** to `LocalChatRepository` (demo messages) if caller omits `chatRepository`; only the connections screen passes the real repo. `notification_navigation.dart` navigates to conversation with the **demo** repo.
- No typing indicators, no message edit/delete (soft-delete exists but no UI/delete API), no read-receipts (delivery marked "sent" only).
Classification: connection chat ✅, plan chat + demo remnants 🔴/🧹.

---

## 9. Plans
Status: 🔴 MISSING (backend)
Evidence: `plans/plan_repository.dart` (`LocalPlanRepository` only), `create_plan_data.dart`, `plans_data.dart`, `my_plans_data.dart`, `plan_details_data.dart`, `plan_join_controller.dart`, plan screens.
- **No Supabase tables** for plans (no migration creates `plans`, `plan_members`, `plan_invitations`).
- Repository is `LocalPlanRepository` → `SharedPreferences` only. No `SupabasePlanRepository`.
- UI is rich (create / my plans / details / join) but persists locally.
- Membership / invitations / plan chat / plan locations / lifecycle: UI-only, local.
- No backend dependency wired; entirely decoupled from the otherwise Supabase-backed app.

---

## 10. Notifications
Status: 🔴 MISSING
Evidence: `notifications/notification_models.dart`, `demo_notification_data.dart`, `notification_navigation.dart`, `activity_center_screen.dart`.
- Entirely **demo**: `AppNotification` is a "demo notification"; `demo_notification_data.dart` is static; `notification_navigation.dart` uses `LocalChatRepository` (demo) to open chats.
- No notification table, no FCM/push token registration, no push handling, no notification preferences, no realtime notifications.
- The "Activity Center" renders demo data only.
(See §11 — `user_devices` premise is not reflected in deployed schema.)

---

## 11. User Devices
Status: 🔴 MISSING
Evidence: `supabase/migrations/*` (no user_devices), `create_migrations.py` (generator only), `backend/face-verification` (no FCM), `lib/**` (no FCM/token code).
- **No `user_devices` table exists in `supabase/migrations`.** It appears only inside `create_migrations.py` (as a *generator template*) at version `20260826000000` and in planning docs (`.kilo/plans/phase-9.5.3-*.md`, `phase-9.5.7-restoration-plan.md` which lists it as **REMOVE**). It was **not deployed**.
- No `firebase_messaging` / FCM dependency in `pubspec` (Google sign-in present, but no FCM).
- No push-token registration anywhere in `lib`.
Conclusion: the "we already have user_devices" premise is **not reflected in the live schema**. Do NOT assume it exists. Flagged as P0 for the notifications phase.

---

## 12. Realtime
Status: 🟡 PARTIAL
| Area | Realtime required? | Enabled in migration? | Used in client? | Working? |
|---|---|---|---|---|
| connections | Yes | ✅ (`20260820000000`) | ✅ (`RealtimeConnectionsService` in `connections_screen`) | ✅ |
| messages | Yes | ✅ (`20260821000000`) | ✅ (`RealtimeMessagesService` per-conv + global) | ✅ |
| conversation_members / conversations | Yes | ✅ | partial (membership read via query, not subscribed) | ✅ |
| profiles | No (not needed) | — | — | n/a |
| live_locations | No subscription | — | no realtime; polled via `LiveLocationTracker` | n/a |
| blocked_users | Optional | — | no subscription (re-fetched on load) | n/a |
| safety_reports | No | — | no | n/a |
| plans | Yes (plan chat) | ❌ not enabled (no plan tables) | ❌ | ❌ |
Conclusion: realtime works where implemented (connections + chat). Plan realtime is impossible until plan tables/conversations exist.

---

## 13. RLS / Security
Status: 🟡 PARTIAL (two privacy flags)
Matrix (RESOURCE | SELECT | INSERT | UPDATE | DELETE | WHO):

| Resource | SELECT | INSERT | UPDATE | DELETE | WHO |
|---|---|---|---|---|---|
| `profiles` | owner (`auth.uid()=id`) **+** authenticated-public (`profile_visibility='public'`) | owner | owner | — | owner / authed-public-read |
| `live_locations` | **all authenticated** | owner | owner | — | **over-permissive** |
| `connections` | own (requester/recipient) | requester | narrow (cancel/accept/reject) | requester | own |
| `conversations` | members only | — (no policy) | — | — | members |
| `conversation_members` | own | own | own | own | own |
| `messages` | members | members (sender) | sender | soft-delete only (no DELETE policy) | members/sender |
| `safety_reports` | reporter | any authed (reporter≠reported) | — | — | reporter |
| `blocked_users` | blocker | blocker (≠self) | — | blocker | blocker |
| `safety_report_summary` (view) | **none** (revoked anon+authed; granted service_role) | — | — | — | service_role only |
| `storage.objects` (profile-photos) | authed **if** owner **or** public-profile | owner (upload) | — | owner | authed/`public` logic |
| `storage.objects` (report-screenshots) | (default bucket policy) | owner (SafetyRepository) | — | — | authed |

Flags:
- ⚠️ **`live_locations` SELECT = `auth.role()='authenticated'`** exposes **every user's exact real-time coordinates to every signed-in user**. Overly permissive (P1). Discovery only needs the viewer's own location + candidate distances; consider scoping reads.
- ⚠️ **`profiles` public-read exposes the whole row** (incl. exact `latitude/longitude`, `date_of_birth`, `bio`, `photos`) to any authenticated user for public profiles. Acceptable for Discovery but exact coords are exposed; consider a privacy review.
- ✅ `conversations` has no INSERT/UPDATE/DELETE policy (immutable from client; created only via SECURITY DEFINER RPC) — correct.
- ✅ `safety_report_summary` correctly revoked from app roles (admin-only via `service_role`).
- No contradictory policies found. No duplicate-named policies on the same table (policies use distinct names; `profiles` has both `profiles_policy` (FOR ALL owner) and `Authenticated users can read public profiles` (SELECT) — complementary, not contradictory).

---

## 14. Duplication / Architecture
Status: 🧹 DUPLICATED / LEGACY
Items found (read-only report; not removed):
1. **`create_migrations.py` — version-collision hazard (P0).** This generator, if executed, would write migrations at `20260823000000`/`20260824000000`/`20260825000000`/`20260826000000`/`20260827000000`, which **collide with the already-deployed** `add_discovery_preferences`/`create_safety_tables`/`create_safety_report_summary` (and the freed `20260826000000`). It would **overwrite real migrations** and create *divergent* tables (`blocks`, `reports`, `conversation_mutes`, `user_devices`) that **do not match** the deployed schema (`blocked_users`, `safety_reports`). **Do not run this script.** It is legacy from an earlier schema design.
2. **Chat demo remnants.** `LocalChatRepository` + `demo_chat_data.dart` + `chat_models.dart` (`demoMessageThreads`, `demoConversations`) are still referenced by `conversation_screen.dart` (default repo), `notification_navigation.dart`, and the Plans inbox tab in `connections_screen.dart`. Legacy/duplicate data path alongside the real `ChatRepository`.
3. **`DiscoveryPerson` / `home_discovery_data.dart` / `home_discovery_components.dart`** — legacy demo discovery *UI* model. Only `home_discovery_profile.dart` (which uses the real `DiscoveryProfile`) is imported by `home_screen.dart`; `home_discovery_components.dart` appears unused (dead/legacy).
4. **`scripts/seed-demo-users.js`** — seeds demo users (legacy test data), not part of app runtime.
5. **`DiscoveryProfile.name` duplicates `displayName`** — both derived from `display_name` (minor model duplication). `DiscoveryProfile.fromJson` also reads `name`/`full_name` that the `profiles` table does not have (falls back to `display_name`).
6. No old Firebase backend present (only doc-comments mention "future Firebase"). No second discovery query (single `DiscoveryRepository`). `SessionAwareProfileRepository`/`SupabaseProfileRepository`/`LocalProfileRepository` are a clean layered design, not duplicates.

---

## 15. FINAL CLASSIFICATION
1. Authentication — ✅ COMPLETE
2. Profiles — ✅ COMPLETE
3. Profile Photos — 🟡 PARTIAL (bucket not in migrations)
4. Discovery — ✅ COMPLETE (no server pagination)
5. Filters — 🟡 PARTIAL (Distance/Age wired; filter-sheet chips inert; keyword/segment filters unreachable)
6. Location — 🟡 PARTIAL (over-permissive live-location RLS)
7. Connections — ✅ COMPLETE
8. Chat — 🟡 PARTIAL (1:1 realtime complete; plan chat + demo remnants)
9. Plans — 🔴 MISSING (backend)
10. Notifications — 🔴 MISSING
11. User Devices — 🔴 MISSING (no deployed table)
12. Realtime — 🟡 PARTIAL (connections+chat only)
13. RLS/Security — 🟡 PARTIAL (2 privacy flags)
14. Duplication/Legacy — 🧹 DUPLICATED / LEGACY
15. Data consistency — 🟡 PARTIAL (see notes)

Data-consistency notes:
- `SafetyRepository.getBlockedUsers` uses a `blocked_profiles!inner(display_name, photos)` relationship. `blocked_users.blocked_user_id` references `auth.users`, **not** `profiles`, so PostgREST cannot auto-derive a `blocked_profiles` relationship — this query is **likely BROKEN** (⚠️) and would fail at runtime. Verify/fix before relying on the Blocked list.
- Plans persist locally while everything else is Supabase → inconsistent multi-device state.
- Distance units correct; DOB/age/visibility enforced by constraints/triggers.

---

## Migration audit
- Total migrations (deployed): **16** (`supabase/migrations/*.sql`).
- Files: 09000000, 11000000, 12000000, 13000000, 14000000, 15000000, 17000000, 18000000, 19000000, 20000000, 21000000, 22000000, 23000000, 24000000, 25000000, 28000000.
- Duplicate versions: **None** among deployed files (all distinct, monotonic with gaps).
- Version collisions: **None in `supabase/migrations`.** The previously-flagged `20260826000000` (user_devices) is **absent** from the folder (was removed). ⚠️ However, `create_migrations.py` still carries `20260823000000`–`20260827000000` templates that **would collide** if run → latent hazard only.
- Suspicious/obsolete: `create_migrations.py` (see §14 #1). No obsolete migration files in the folder.

---

## Backend dependency map (actual code)
```
Auth
  └─> Profiles (creation after signup; AuthGate routes on ProfileStatus)
        └─> Discovery (reads profiles; eligibility = public + completed + DOB)
              ├─> live_locations / profiles coords (distance)
              ├─> profile preferences (discovery_distance_km / min_age / max_age)
              └─> excluded sets (connections consumed, blocked_users)
                    └─> Connections (Connect button -> ConnectionRepository)
                          └─> accepted connection -> Chat RPC get_or_create_connection_conversation
                                └─> messages + RealtimeMessagesService
Safety (blocked_users / safety_reports)
  ├─> Discovery exclusion
  ├─> Connections send-block check
  └─> Chat block UI (conversation_screen)
Realtime
  ├─> connections (enabled + used)
  └─> messages (enabled + used)
Notifications  ── (BLOCKED: depends on User Devices + FCM, both MISSING)
Plans         ── (LOCAL ONLY: no Supabase dependency; plan chat impossible until backend)
```

---

## Priority issues
P0 — blocking
- `create_migrations.py` is a version-collision hazard that would overwrite real migrations; **quarantine / clearly mark as legacy**. (No fix needed now; just do not run.)
- `user_devices` does **not** exist in deployed schema despite the phase brief; any B-notifications work must treat it as net-new (or confirm with infra). 

P1 — important
- `live_locations` SELECT is open to all authenticated users (exact real-time coords exposed). Review/reduce scope.
- `profiles` public-read returns full row incl. exact coords/DOB to all authed users — privacy review.
- Filter UI is non-functional: `_FilterPreferencesSheet` Distance/Availability/Verification chips have no handlers; keyword/segment filters unreachable. Wire to existing backend logic.
- `profile-photos` bucket has no migration (create idempotently or document as manual).
- Chat demo remnants (`LocalChatRepository`/`demo_chat_data`) still power conversation default + Plans inbox tab + notification navigation — replace with real backend or clearly fence.

P2 — later
- Verify/fix `SafetyRepository.getBlockedUsers` `blocked_profiles!inner(...)` relationship (likely broken).
- Add server-side Discovery pagination.
- Make gender/availability/verified/interests filters user-selectable (engine already partly present).
- Chat: message delete/read-receipts/typing; plan conversation RPC + realtime.

---

## Recommended next subphase
- **B1.0 — Migration hygiene (P0):** quarantine `create_migrations.py`; add a guard/README that deployed versions are authoritative. Confirm `user_devices` status with infra.
- **B1.1 — Storage bucket (P1):** idempotent `insert into storage.buckets` migration for `profile-photos` (private, authenticated reads only); the RLS policy already exists.
- **B1.2 — Discovery filter correctness (P1):** wire the Filter sheet chips (Distance/Availability/Verification) and expose the existing keyword/segment + availability/verified filters so `_applyDiscoveryProfileFilter` is actually reachable.
- **B1.3 — Location privacy (P1):** scope `live_locations` SELECT (e.g., function/limited exposure) instead of `auth.role()='authenticated'`.
- **B1.4 — Chat cleanup (P1):** ensure `conversation_screen` always uses the real `ChatRepository`; remove/migrate demo chat paths in Plans inbox + notifications.
- **B2 — Notifications + User Devices (P0 for feature):** create `user_devices` + FCM registration + push handling (net-new).
- **B3 — Plans backend:** `plans`/`plan_members`/`plan_invitations` tables + `SupabasePlanRepository` + plan-conversation RPC + realtime.
- **B4 — Blocked-list fix (P2):** correct `getBlockedUsers` relationship/query.

---

## Files inspected (key)
Migrations: `supabase/migrations/20260809000000` … `20260828000000` (16 files).
Core: `core/supabase/supabase_client.dart`, `auth_service.dart`, `auth_gate.dart`.
Profile: `profile_data.dart`, `profile_repository.dart`, `supabase_profile_repository.dart`, `session_aware_profile_repository.dart`, `discovery_repository.dart`, `discovery_data.dart`, `discovery_helpers.dart`, `discovery_preferences_screen.dart`, `connection_data.dart`, `connection_repository.dart`, `connections_view_model.dart`, `realtime_connections_service.dart`, `live_location_repository.dart`, `live_location_data.dart`, `safety_repository.dart`, `face_verification_client.dart`, `public_profile_data.dart`.
Discovery/Home: `home_screen.dart`, `home_discovery_profile.dart`, `home_discovery_cache.dart`, `home_discovery_data.dart` (legacy), `home_discovery_components.dart` (legacy).
Chat: `chat_repository.dart`, `chat_models.dart`, `message_models.dart`, `chat_dtos.dart`, `realtime_messages_service.dart`, `conversation_screen.dart`, `connections_screen.dart`.
Plans: `plan_repository.dart` (+ `create_/my_plans_/plan_details_data.dart`).
Notifications: `notification_models.dart`, `demo_notification_data.dart`, `notification_navigation.dart`.
Services: `core/services/live_location_tracker.dart`, `location_service.dart`, `image_normalizer.dart`.
Legacy/Gen: `create_migrations.py`, `scripts/seed-demo-users.js`, `backend/face-verification/*` (verification backend).
Supabase fn: `supabase/functions/notify-safety-report/index.ts`.

---

## Validation
`flutter analyze`: **11 issues found — all `info`-level** (deprecated_member_use, use_null_aware_elements, avoid_print, use_build_context_synchronously). **0 errors, 0 warnings.** No `flutter run` / `flutter build` executed.

Source changes made: **NONE**
Database changes: **NONE**
Supabase changes: **NONE**
Migrations created/modified: **NONE**
RLS modified: **NONE**
Storage modified: **NONE**

STOP — B0 complete. Do not start B1.
