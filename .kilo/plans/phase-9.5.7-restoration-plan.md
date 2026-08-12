# Phase 9.5.7 — Phase 9.5.2 Restoration Plan

## Phase 9.5.2 Source

**Status: NOT RECOVERABLE FROM GIT HISTORY**

- No commit in the repository represents the Phase 9.5.2 Hardening state.
- The entire Supabase chat implementation exists only as **uncommitted changes** in the current working tree.
- Phase 9.5.2 changes are interleaved with post-9.5.2 changes (Phases 9.5.3–9.5.6) in the same files.
- No stash, no unreachable commit, no backup archive contains a clean Phase 9.5.2 snapshot.
- The `lib.zip` archive (committed in `74758cf`) contains only the pre-Supabase Phase 8 demo chat.

**Confidence level: ZERO** — no recoverable Phase 9.5.2 source state exists in Git.

---

## Changes After Phase 9.5.2

All post-9.5.2 changes are embedded in the current uncommitted working tree. They cannot be separated from Phase 9.5.2 changes via Git because neither was committed.

### Phase 9.5.3 (Firebase Hotfix + Production Hardening)
- Firebase removal: `firebase_core`, `firebase_messaging`, `NotificationService`, `firebase_options.dart`, Edge Function
- New migrations:
  - `20260823000000_create_conversation_mutes.sql`
  - `20260824000000_create_blocks.sql`
  - `20260825000000_create_reports.sql`
  - `20260826000000_create_user_devices.sql`
  - `20260827000000_add_last_notified_at.sql`
- `chat_repository.dart`: Added `getConversationMember`, `getProfile`, `muteConversation`, `unmuteConversation`, `isConversationMuted`, `blockUser`, `unblockUser`, `isBlocked`, `reportUser`, `getLatestMessagePreview`
- `conversation_screen.dart`: Added `_handleViewProfile`, `_handleMute`, `_handleUnmute`, `_handleBlock`, `_handleReport`
- `connections_screen.dart`: Added real-time preview updates, profile navigation wiring
- `home_connection_dashboard_cards.dart`: Added profile navigation, connection state getters

### Phase 9.5.4 (Chat UI/UX Polish)
- `chat_widgets.dart`: Search bar visual changes (`filled: false`, `isCollapsed: true` removal, padding changes)
- `conversation_widgets.dart`: Added `_CircleButton`, composer refinements
- `chat_models.dart`: Added `copyWith`, `hasUnread`, `isGroup` getters
- `message_widgets.dart`: Minor visual refinements

### Phase 9.5.5 (RLS Fix + Search Bar Refinement)
- `chat_repository.dart`: Added `status: 'pending'` to report insert
- `chat_widgets.dart`: Search bar refinement (changed back toward `filled: true`)
- Database: Attempted `conversation_members` SELECT RLS fix (unclear if applied to remote)

### Phase 9.5.6 (Root-Cause Fixes)
- New migration: `20260828000000_create_get_other_member_rpc.sql`
- `chat_repository.dart`: Changed `getConversationMember` to call RPC, added diagnostic logging (`dev.log`) to `loadMessages`, `loadUnreadCount`, `getLatestMessagePreview`
- `conversation_screen.dart`: Added `Navigator.pop(context)` after successful mute/unmute
- `chat_widgets.dart`: Search bar fix (`filled: true`, `fillColor: Colors.transparent`)

---

## Files To Restore

### Revert to Phase 8 base, then re-apply ONLY Phase 9.5.2 changes:

| File | Phase 9.5.2 Action | Post-9.5.2 additions to REMOVE |
|------|-------------------|--------------------------------|
| `lib/features/chat/chat_repository.dart` | Replace `LocalChatRepository` with `ChatRepository` (basic methods only: `getOrCreateConnectionConversation`, `loadMessages`, `sendMessage`, `updateLastReadAt`, `loadUnreadCount`) | Remove: `getConversationMember`, `getProfile`, `muteConversation`, `unmuteConversation`, `isConversationMuted`, `blockUser`, `unblockUser`, `isBlocked`, `reportUser`, `getLatestMessagePreview`, `dev.log` imports/calls |
| `lib/features/chat/conversation_screen.dart` | Accept optional `ChatRepository`, load real messages, enable composer, start/stop realtime | Remove: `_handleViewProfile`, `_handleMute`, `_handleUnmute`, `_handleBlock`, `_handleReport`, menu actions for profile/mute/block/report, error state for those actions |
| `lib/features/chat/connections_screen.dart` | Wire Connections tab to real chat via `ChatRepository` | Remove: post-9.5.2 profile navigation wiring, real-time preview updates that depend on mute/block/report state |
| `lib/features/chat/conversation_widgets.dart` | Enable `MessageComposer` send action | Remove: post-9.5.4 `_CircleButton`, post-9.5.5/9.5.6 composer refinements |
| `lib/features/chat/chat_models.dart` | Add mapping helpers if needed | Remove: post-9.5.4 `copyWith`, `hasUnread`, `isGroup` getters if they weren't in 9.5.2 |
| `lib/features/home_connection_dashboard.dart` | Update "Open Room" to use `ChatRepository` | Remove: post-9.5.2 profile navigation integration |
| `lib/features/chat/chat_widgets.dart` | **LEAVE UNCHANGED** per Phase 9.5.2 plan | Revert ALL changes (padding, `isCollapsed`, `filled`, `fillColor`, `contentPadding`, `CrossAxisAlignment.stretch`) |
| `lib/features/chat/message_widgets.dart` | **LEAVE UNCHANGED** per Phase 9.5.2 plan | Revert ALL changes |
| `lib/features/chat/chat_sections.dart` | **LEAVE UNCHANGED** per Phase 9.5.2 plan | Revert ALL changes if any |
| `lib/features/chat/demo_chat_data.dart` | **PRESERVE** per Phase 9.5.2 plan | No changes |

### Files to KEEP (created in Phase 9.5.2):
- `lib/features/chat/chat_dtos.dart` — Phase 9.5.2 DTOs
- `lib/features/chat/realtime_messages_service.dart` — Phase 9.5.2 realtime service

### Files to REMOVE (created after Phase 9.5.2):
- None — all new files were created in Phase 9.5.2 or earlier

---

## Files To Preserve

**ALL non-chat files must remain exactly as they are in the current working tree.**

### Core / App Shell
- `lib/core/supabase/supabase_client.dart`
- `lib/core/supabase/auth_service.dart`
- `lib/core/supabase/auth_gate.dart`
- `lib/core/services/location_service.dart`
- `lib/core/services/permission_manager.dart`
- `lib/main.dart`
- `lib/features/splash/splash_screen.dart`
- `lib/features/secondary_screens.dart`
- `lib/features/login_screen.dart`
- `lib/features/signup_screen.dart`
- `lib/features/phone_auth_screen.dart`
- `lib/features/auth/confirm_email_screen.dart`

### Profile (all files)
- `lib/features/profile/profile_creation_screen.dart`
- `lib/features/profile/profile_creation_sections.dart`
- `lib/features/profile/profile_creation_widgets.dart`
- `lib/features/profile/profile_management_screen.dart`
- `lib/features/profile/profile_management_sections.dart`
- `lib/features/profile/profile_navigation_mapper.dart`
- `lib/features/profile/profile_repository.dart`
- `lib/features/profile/profile_data.dart`
- `lib/features/profile/profile_strength_screen.dart`
- `lib/features/profile/profile_validation.dart`
- `lib/features/profile/public_profile_widgets.dart`
- `lib/features/profile/my_profile_screen.dart`
- `lib/features/profile/my_profile_hero.dart`
- `lib/features/profile/privacy_verification_screen.dart`
- `lib/features/profile/supabase_profile_repository.dart`
- `lib/features/profile/session_aware_profile_repository.dart`

### Connections Dashboard (Phase 9.4 — preserve, rewire later if needed)
- `lib/features/home_connection_dashboard.dart`
- `lib/features/home_connection_dashboard_cards.dart`

### Discovery (all files)
- `lib/features/home_discovery_connect.dart`
- `lib/features/home_discovery_data.dart`
- `lib/features/home_discovery_profile.dart`

### App configuration / platform
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`
- `.gitignore`
- `pubspec.yaml`
- `pubspec.lock`
- `package.json`
- `package-lock.json`

### Non-Chat migrations (preserve)
- `supabase/migrations/20260809000000_create_profiles_table.sql`
- `supabase/migrations/20260811000000_create_live_locations_table.sql`
- `supabase/migrations/20260812000000_add_discovery_prerequisites.sql`
- `supabase/migrations/20260813000000_harden_dob_requirement.sql`
- `supabase/migrations/20260814000000_enforce_minimum_age.sql`
- `supabase/migrations/20260815000000_add_discovery_fields.sql`
- `supabase/migrations/20260817000000_create_connections_table.sql`
- `supabase/migrations/20260818000000_harden_connections_rls.sql`
- `supabase/migrations/20260819000000_fix_connections_update_rls.sql`
- `supabase/migrations/20260820000000_enable_connections_realtime.sql`

---

## Current Supabase Migrations

| # | Filename | Category | Phase 9.5.2? | Action |
|---|----------|----------|--------------|--------|
| 1 | `20260809000000_create_profiles_table.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 2 | `20260811000000_create_live_locations_table.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 3 | `20260812000000_add_discovery_prerequisites.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 4 | `20260813000000_harden_dob_requirement.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 5 | `20260814000000_enforce_minimum_age.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 6 | `20260815000000_add_discovery_fields.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 7 | `20260817000000_create_connections_table.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 8 | `20260818000000_harden_connections_rls.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 9 | `20260819000000_fix_connections_update_rls.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 10 | `20260820000000_enable_connections_realtime.sql` | NON-CHAT | Pre-9.5.2 | PRESERVE |
| 11 | `20260821000000_create_chat_foundation.sql` | CHAT | Pre-9.5.2 | PRESERVE |
| 12 | `20260822000000_create_connection_chat_rpc.sql` | CHAT | **Phase 9.5.2** | PRESERVE |
| 13 | `20260823000000_create_conversation_mutes.sql` | CHAT | Phase 9.5.3 | REMOVE |
| 14 | `20260824000000_create_blocks.sql` | CHAT | Phase 9.5.3 | REMOVE |
| 15 | `20260825000000_create_reports.sql` | CHAT | Phase 9.5.3 | REMOVE |
| 16 | `20260826000000_create_user_devices.sql` | CHAT | Phase 9.5.3 | REMOVE |
| 17 | `20260827000000_add_last_notified_at.sql` | CHAT | Phase 9.5.3 | REMOVE |
| 18 | `20260828000000_create_get_other_member_rpc.sql` | CHAT | Phase 9.5.6 | REMOVE |

---

## Phase 8 Chat Base

### What existed at Phase 8 (`7da6d88`)

| File | State |
|------|-------|
| `lib/features/chat/chat_repository.dart` | `LocalChatRepository` only — demo data, async interface |
| `lib/features/chat/chat_models.dart` | `ConversationPreview`, `ConversationType`, `ConversationStatus`, `LastMessageType` |
| `lib/features/chat/connections_screen.dart` | Demo Connections inbox with tabs, local search, skeleton loading |
| `lib/features/chat/conversation_screen.dart` | Demo chat screen, `LocalChatRepository`, decorative composer, placeholder menu (`debugPrint`) |
| `lib/features/chat/chat_widgets.dart` | Premium UI primitives — `ConversationTile`, `ChatSegmentedTabs`, `PremiumSearchBar`, `UnreadBadge`, `LoadingSkeleton`, `EmptyInbox` |
| `lib/features/chat/conversation_widgets.dart` | `ConversationAppBar`, `MessageComposer` (decorative), `ConversationIntro` |
| `lib/features/chat/message_widgets.dart` | `MessageBubble`, `SystemMessageChip`, `SharedContentCard` |
| `lib/features/chat/chat_sections.dart` | `PinnedConversationsSection`, `RecentConversationsSection` |
| `lib/features/chat/demo_chat_data.dart` | Demo conversations, messages, groups |

### What worked
- Connections inbox loaded and displayed
- Tabs switched between Connections/Plans
- Search bar filtered locally
- Connection chat opened and displayed demo messages
- Mute/Block/Report existed as menu placeholders
- View Profile navigated to profile screen (demo-based)
- Message timestamps displayed
- Empty thread state showed

### What should be preserved from Phase 8
- The entire premium UI component library
- The `ConversationPreview` model structure
- The `LocalChatRepository` interface (keep as fallback for Plans)
- The `ConversationScreen` architecture
- The `ConnectionsInboxScreen` architecture

---

## Rebuild Boundary

### REMOVE (post-Phase 9.5.2 chat code)
All changes in the following categories must be removed from chat files:

1. **Menu actions** — `_handleViewProfile`, `_handleMute`, `_handleUnmute`, `_handleBlock`, `_handleReport`
2. **Database methods** — `getConversationMember`, `getProfile`, `muteConversation`, `unmuteConversation`, `isConversationMuted`, `blockUser`, `unblockUser`, `isBlocked`, `reportUser`, `getLatestMessagePreview`
3. **Realtime event handlers** — `_handleRealtimeEvent`, `_startRealtime`, `_realtimeSubscription`
4. **Diagnostic logging** — `import 'dart:developer' as dev`, all `dev.log` calls
5. **Search bar changes** — revert to Phase 8 `PremiumSearchBar` (padding `vertical: 4`, `isCollapsed: true`, no `filled`/`fillColor`/`contentPadding`)
6. **Chat widgets changes** — revert `ChatSegmentedTabs` `CrossAxisAlignment.stretch`, any other post-9.5.2 modifications
7. **Conversation widgets changes** — revert `_CircleButton`, composer changes beyond Phase 9.5.2
8. **Message widgets changes** — revert to Phase 8 state
9. **Home dashboard cards changes** — revert to Phase 8 state
10. **Migrations** — remove files 13–18 listed above

### KEEP (Phase 9.5.2 chat code)
1. `ChatRepository` class with basic methods:
   - `getOrCreateConnectionConversation`
   - `loadMessages`
   - `sendMessage`
   - `updateLastReadAt`
   - `loadUnreadCount`
2. `RealtimeMessagesService` singleton
3. `ChatDto` classes (`ChatConversation`, `ChatMessage`, `ChatMessageEvent`, `ChatEventType`)
4. `ConnectionsInboxScreen` real chat wiring
5. `ConversationScreen` real chat integration (without menu actions)
6. `MessageComposer` send action
7. Migration `20260822000000_create_connection_chat_rpc.sql`

### PRESERVE (all non-chat)
- Everything outside `lib/features/chat/` remains untouched
- All non-chat migrations remain applied
- All Phase 9 profile, discovery, location, auth code remains

---

## Rebuild Order

1. **Create safety checkpoint** — backup current working tree before any changes
2. **Revert all chat files to Phase 8 base** — use `git checkout 7da6d88 -- <file>` for each chat file
3. **Remove post-9.5.2 chat files** — `chat_dtos.dart`, `realtime_messages_service.dart` (these were Phase 9.5.2 creations, but we'll recreate them cleanly)
4. **Remove post-9.5.2 migrations** — delete files 13–18 from `supabase/migrations/`
5. **Re-implement Phase 9.5.2 `ChatRepository`** — clean implementation with only the basic methods
6. **Re-implement `ChatDto` classes** — clean DTO layer
7. **Re-implement `RealtimeMessagesService`** — clean singleton
8. **Wire `ConnectionsInboxScreen`** — real chat routing
9. **Wire `ConversationScreen`** — real data loading, realtime, composer (without menu actions)
10. **Wire `home_connection_dashboard.dart`** — "Open Room" navigation
11. **Validate** — `flutter analyze`, APK build

---

## Safety Checkpoint

**Before any restoration work:**

Create a temporary branch from current HEAD to preserve all uncommitted changes:

```bash
git checkout -b backup/phase-9.5.6-broken-chat
git add -A
git commit -m "chore: backup Phase 9.5.6 broken chat state before Phase 9.5.2 restoration"
git checkout conexo-supabase
```

This preserves the entire working tree in a disposable branch. No data is lost.

Alternatively, create a patch file:

```bash
git diff HEAD > backup-phase-9.5.6.patch
```

Or archive the entire project directory to a safe location outside the repo.

---

## Exact Restoration Procedure

### Step 1: Safety Checkpoint
Create backup branch or patch as described above.

### Step 2: Revert chat files to Phase 8 base
```bash
git checkout 7da6d88 -- \
  lib/features/chat/chat_repository.dart \
  lib/features/chat/chat_models.dart \
  lib/features/chat/chat_widgets.dart \
  lib/features/chat/chat_sections.dart \
  lib/features/chat/connections_screen.dart \
  lib/features/chat/conversation_screen.dart \
  lib/features/chat/conversation_widgets.dart \
  lib/features/chat/message_widgets.dart \
  lib/features/chat/demo_chat_data.dart
```

### Step 3: Remove post-9.5.2 new chat files
```bash
git rm --cached \
  lib/features/chat/chat_dtos.dart \
  lib/features/chat/realtime_messages_service.dart
rm lib/features/chat/chat_dtos.dart \
   lib/features/chat/realtime_messages_service.dart
```

### Step 4: Remove post-9.5.2 migrations
```bash
git rm --cached \
  supabase/migrations/20260823000000_create_conversation_mutes.sql \
  supabase/migrations/20260824000000_create_blocks.sql \
  supabase/migrations/20260825000000_create_reports.sql \
  supabase/migrations/20260826000000_create_user_devices.sql \
  supabase/migrations/20260827000000_add_last_notified_at.sql \
  supabase/migrations/20260828000000_create_get_other_member_rpc.sql
rm supabase/migrations/20260823000000_create_conversation_mutes.sql \
   supabase/migrations/20260824000000_create_blocks.sql \
   supabase/migrations/20260825000000_create_reports.sql \
   supabase/migrations/20260826000000_create_user_devices.sql \
   supabase/migrations/20260827000000_add_last_notified_at.sql \
   supabase/migrations/20260828000000_create_get_other_member_rpc.sql
```

### Step 5: Revert `home_connection_dashboard.dart` and `home_connection_dashboard_cards.dart` to Phase 8
```bash
git checkout 7da6d88 -- \
  lib/features/home_connection_dashboard.dart \
  lib/features/home_connection_dashboard_cards.dart
```

### Step 6: Verify non-chat files are untouched
Run `git diff 7da6d88 --name-status` and confirm only chat-related files and post-9.5.2 migrations are reverted.

### Step 7: Re-implement Phase 9.5.2 cleanly
Follow the Phase 9.5.2 plan exactly:
- Create `chat_repository.dart` with `ChatRepository` (basic methods only)
- Create `chat_dtos.dart` with DTOs
- Create `realtime_messages_service.dart` with singleton
- Modify `connections_screen.dart` for real chat routing
- Modify `conversation_screen.dart` for real data + realtime
- Modify `conversation_widgets.dart` for active composer
- Modify `home_connection_dashboard.dart` for "Open Room"
- Create migration `20260822000000_create_connection_chat_rpc.sql`

### Step 8: Validate
- `flutter analyze` — 0 errors
- Build APK using `.\tool\build_apk.ps1`
- Manual verification of connection chat flow

---

## Risks

1. **No recoverable Phase 9.5.2 commit exists.** All restoration must be done by reconstructing from the Phase 8 base + Phase 9.5.2 plan. The exact Phase 9.5.2 implementation details may have deviated from the plan.

2. **Working tree contains 2,994 uncommitted insertions across 25 files.** A careless operation could destroy non-chat Phase 9 work. The safety checkpoint is mandatory.

3. **`home_connection_dashboard.dart` and `home_connection_dashboard_cards.dart` are cross-feature.** They import chat modules but belong to the Connections feature. Reverting them to Phase 8 would lose the Supabase connection integration. They must be reverted and then re-wired as part of Phase 9.5.2.

4. **Remote Supabase database state is unknown.** The 18 migrations may or may not be applied. Restoration of source code does not automatically restore the database schema.

5. **Phase 9.5.2 plan says `chat_widgets.dart` should be unchanged, but the current working tree has changes.** These changes (search bar, tabs) were introduced post-9.5.2 and must be reverted.

6. **The `LocalChatRepository` class was removed in Phase 9.5.2** per the plan. It must be re-added as a fallback for Plans tab.

---

## Final Verdict

**RESTORATION REQUIRES RECONSTRUCTION**

No recoverable Phase 9.5.2 Git state exists. The restoration must be performed by:
1. Reverting all chat files to Phase 8 base
2. Removing post-9.5.2 migrations
3. Re-implementing Phase 9.5.2 cleanly from the plan

This is a reconstruction, not a rollback.
