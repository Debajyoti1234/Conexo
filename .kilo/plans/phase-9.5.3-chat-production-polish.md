# Phase 9.5.3 — Chat Production Polish & Notification Foundation
## PLAN MODE ONLY — NO IMPLEMENTATION


## 1. Current Architecture Findings

### Timestamp Pipeline
```
Supabase TIMESTAMPTZ (UTC)
  → ChatMessage.fromJson(): DateTime.parse(json['created_at'])
    → Dart DateTime is UTC (correct parsing)
  → ConversationScreen._mapDtoToMessage(): timestamp: dto.createdAt
    → Message.timestamp = UTC DateTime (correct so far)
  → message_widgets.dart _formatClock(DateTime t):
    → t.hour, t.minute used directly WITHOUT .toLocal()
    → BUG: displays UTC time instead of device local time
```

**Root cause confirmed:** `_formatClock()` in `message_widgets.dart:311-315` uses `t.hour` and `t.minute` directly. Since `DateTime.parse()` produces a UTC DateTime, the displayed time is in UTC, not the device's local timezone. This explains the ~5.5 hour offset observed (IST is UTC+5:30).

### Three-Dot Menu
- `ConversationScreen._handleMenuAction()` currently does `debugPrint('Menu action: $actionId')` — no functional actions.
- Menu items are declarative `ChatMenuAction` objects with `id`, `label`, `icon`, `isDestructive`.
- No profile navigation, mute, block, or report logic exists.

### View Profile
- `PublicProfileScreen` and `premiumPublicProfileRoute()` exist and work for discovery/connections.
- `mapConnectionUiModelToProfile()` maps `ConnectionUiModel` → `PublicProfileViewData`.
- ConversationScreen currently has no access to the other user's profile data.
- Need to resolve the other conversation member from `conversation_members` table.

### Mute
- `ConversationPreview.isMuted` field exists in UI model but is purely cosmetic.
- No database table, no persistence, no RLS.
- `LocalChatRepository` has no mute methods.

### Block
- No block table, no block RLS, no block enforcement anywhere.
- No block impact on discovery, connections, or chat.

### Report
- No report table, no report RLS.
- No reporting flow.

### Plus Button
- `MessageComposer` plus button currently has `onTap: () {}` (empty callback).
- Represents future media attachment actions (image, voice, etc.).
- No media upload infrastructure exists.

### Push Notifications
- **No Firebase Messaging dependency** in `pubspec.yaml`.
- **No FCM configuration** in `AndroidManifest.xml` (only `POST_NOTIFICATIONS` permission exists).
- **No device token storage** — no `user_devices` or similar table.
- **No notification service** in Flutter code.
- **No Supabase Edge Functions** configured for notifications.
- **No database webhooks/triggers** for notifications.
- **No notification tables** beyond `conversation_members.last_read_at` (which is read-state, not push).

### Existing Auth Infrastructure
- `AuthService.authStateChanges` exposes `Stream<AuthState>` — available for logout cleanup.
- `AuthService.currentUser` provides the authenticated user.
- Supabase client is singleton via `SupabaseClientConfig.client`.

### Supabase Schema
Existing tables: `profiles`, `live_locations`, `connections`, `conversations`, `conversation_members`, `messages`.
No `user_devices`, `conversation_mutes`, `blocks`, `reports` tables.

---

## 2. Timestamp Root Cause + Fix

**Root cause:** `_formatClock()` in `message_widgets.dart:311-315` formats a `DateTime` without converting to local timezone. Since `DateTime.parse()` produces UTC, the displayed time is UTC.

**Current code:**
```dart
String _formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}
```

**Fix:** Convert to local timezone before extracting hour/minute:
```dart
String _formatClock(DateTime t) {
  final local = t.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}
```

**File:** `lib/features/chat/message_widgets.dart`
**Lines:** 311-315
**Migration required:** No
**Risk:** Minimal — pure display fix, database timestamps remain unchanged.

---

## 3. View Profile Design

**Flow:**
```
ConversationScreen
  → three-dot menu → "View Profile"
  → resolve other user ID from conversation_members
  → fetch profile from Supabase profiles table
  → navigate to PublicProfileScreen via premiumPublicProfileRoute()
```

**Implementation:**
1. Add `ChatRepository.getConversationMember(String conversationId, String excludeUserId)` → returns the other member's `user_id`.
2. Add `ChatRepository.getProfile(String userId)` → returns profile row (RLS allows public profile reads).
3. In `ConversationScreen._handleMenuAction('view_profile')`:
   - Get current user ID
   - Call `getConversationMember(conversationId, currentUserId)` to get other user's ID
   - Call `getProfile(otherUserId)` to fetch profile
   - Map to `PublicProfileViewData` using existing `mapConnectionUiModelToProfile()` or create `mapProfileToPublicProfile()`
   - Navigate via `premiumPublicProfileRoute(data: profileData)`

**Files to modify:**
- `lib/features/chat/chat_repository.dart` — add `getConversationMember()` and `getProfile()` methods
- `lib/features/chat/conversation_screen.dart` — wire `_handleMenuAction('view_profile')`
- `lib/features/profile/profile_navigation_mapper.dart` — add `mapProfileToPublicProfile()` if needed

**Files to leave unchanged:**
- `PublicProfileScreen` — pure presentation, no changes needed
- `premiumPublicProfileRoute` — existing route, no changes needed

---

## 4. Mute Design

**Schema:**
```sql
CREATE TABLE public.conversation_mutes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  muted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);
```

**Indexes:**
```sql
CREATE INDEX idx_conversation_mutes_user_id ON public.conversation_mutes(user_id);
CREATE INDEX idx_conversation_mutes_conversation_id ON public.conversation_mutes(conversation_id);
```

**RLS:**
- SELECT: `auth.uid() = user_id` (user can read own mute state)
- INSERT: `auth.uid() = user_id` (user can mute for themselves)
- UPDATE: `auth.uid() = user_id` (user can update own mute)
- DELETE: `auth.uid() = user_id` (user can unmute)

**Behavior:**
- Muting inserts a row in `conversation_mutes`.
- Unmuting deletes the row.
- Mute does NOT stop realtime while the conversation is open.
- Mute affects push notifications (checked in notification logic).
- Mute state is queried via `EXISTS (SELECT 1 FROM conversation_mutes WHERE conversation_id = :id AND user_id = auth.uid())`.

**Migration:** `supabase/migrations/20260823000000_create_conversation_mutes.sql`

**Files to modify:**
- `lib/features/chat/chat_repository.dart` — add `muteConversation()`, `unmuteConversation()`, `isConversationMuted()`
- `lib/features/chat/conversation_screen.dart` — wire mute/unmute toggle
- `lib/features/chat/chat_models.dart` — `ConversationPreview.isMuted` already exists, no change needed
- `lib/features/chat/connections_screen.dart` — reload mute state after navigation back

**Files to create:**
- `supabase/migrations/20260823000000_create_conversation_mutes.sql`

---

## 5. Block Design

**Schema:**
```sql
CREATE TABLE public.blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);
```

**Indexes:**
```sql
CREATE INDEX idx_blocks_blocker_id ON public.blocks(blocker_id);
CREATE INDEX idx_blocks_blocked_id ON public.blocks(blocked_id);
```

**RLS:**
- SELECT: `auth.uid() = blocker_id` (user can see who they blocked)
- INSERT: `auth.uid() = blocker_id` (user can block for themselves)
- DELETE: `auth.uid() = blocker_id` (user can unblock)

**Enforcement points:**
1. **Chat:** `ConversationScreen` checks block status on load. If blocked, shows blocked state instead of messages.
2. **Realtime:** `RealtimeMessagesService` checks block status on `start()`. If blocked, does not subscribe.
3. **Messages:** `messages` INSERT policy already requires membership. Blocked users should be removed from `conversation_members` when blocked (handled in application logic or trigger).
4. **Connections:** Block does NOT automatically remove existing connections. UI hides blocked connections.
5. **Discovery:** Blocked users are excluded from discovery (handled in discovery repository).
6. **Notifications:** Blocked users cannot send notifications to the blocker.

**Migration:** `supabase/migrations/20260824000000_create_blocks.sql`

**Files to modify:**
- `lib/features/chat/chat_repository.dart` — add `blockUser()`, `unblockUser()`, `isBlocked()`, `getBlockedUsers()`
- `lib/features/chat/conversation_screen.dart` — check block on load, show blocked UI
- `lib/features/chat/connections_screen.dart` — hide blocked connections
- `lib/features/profile/discovery_repository.dart` — exclude blocked users from discovery

**Files to create:**
- `supabase/migrations/20260824000000_create_blocks.sql`

**Product decision required:** Should blocking automatically remove the existing accepted connection, or just hide it? **Recommendation: Hide connection but keep it in database** so unblocking restores the relationship without re-connecting.

---

## 6. Report Design

**Schema:**
```sql
CREATE TABLE public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'fake_profile', 'other')),
  CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed'))
);
```

**Indexes:**
```sql
CREATE INDEX idx_reports_reporter_id ON public.reports(reporter_id);
CREATE INDEX idx_reports_reported_id ON public.reports(reported_id);
CREATE INDEX idx_reports_status ON public.reports(status);
```

**RLS:**
- SELECT: `auth.uid() = reporter_id` (user can see their own reports)
- INSERT: `auth.uid() = reporter_id AND reporter_id <> reported_id` (user can report others, not self)
- UPDATE: No client UPDATE policy (admin-only via service role)
- DELETE: No client DELETE policy (admin-only via service role)

**Behavior:**
- Report is submitted from chat three-dot menu.
- Reporter and reported are derived from conversation membership + auth.uid().
- Duplicate prevention: UNIQUE(reporter_id, reported_id, conversation_id) if we add conversation_id, or accept that users can re-report.
- No admin dashboard in this phase. Reports are stored for future moderation.

**Migration:** `supabase/migrations/20260825000000_create_reports.sql`

**Files to modify:**
- `lib/features/chat/chat_repository.dart` — add `reportUser()`
- `lib/features/chat/conversation_screen.dart` — wire report action

**Files to create:**
- `supabase/migrations/20260825000000_create_reports.sql`

---

## 7. Plus Button Decision

**Recommendation: Keep intentionally inactive for Phase 9.5.3.**

Rationale:
- No media upload infrastructure exists.
- Adding image/voice/file/location actions requires backend storage, permissions, and UI contracts not yet defined.
- The plus button visually signals "more options coming" without implying broken functionality.
- If tapped, it should do nothing (no error, no SnackBar).

**Future action surface (deferred):**
- Image: camera/gallery picker → Supabase Storage → message with `type: 'image'`
- Voice: recorder → Supabase Storage → message with `type: 'voice'`
- Location: map picker → message with embedded location data

**No code change required** — the current empty `onTap: () {}` is correct for this phase.

---

## 8. Push Notification Architecture Options

### Option A: Supabase Database Webhook → Supabase Edge Function → FCM

**Flow:**
1. New message INSERT into `public.messages`
2. Supabase Database Webhook triggers on INSERT
3. Webhook calls Supabase Edge Function
4. Edge Function:
   - Queries conversation_members to find recipient
   - Queries user_devices for recipient's push tokens
   - Checks conversation_mutes for mute state
   - Checks blocks for block state
   - Calls FCM HTTP v1 API to send notification
5. FCM delivers to Android device

**Security:** High — Edge Function runs server-side, never exposes FCM credentials to client. Webhook is internal Supabase infrastructure.

**Reliability:** High — Supabase webhooks are reliable for database events. Edge Functions are managed.

**Scalability:** Good — FCM handles delivery. Edge Function is lightweight.

**Complexity:** Medium — requires Supabase Edge Function deployment, FCM project setup.

**Duplicate risk:** Low — webhook fires once per INSERT. Realtime handles foreground. Need `last_notified_at` or similar to prevent duplicates if webhook fires multiple times.

**Token management:** Client registers tokens in `user_devices` table. Edge Function queries this table.

**Mute/block integration:** Easy — Edge Function queries `conversation_mutes` and `blocks` before sending.

**Android suitability:** Good — FCM is the standard Android push solution.

### Option B: Supabase Edge Function Invoked Directly from Flutter

**Flow:**
1. Flutter sends message → backend returns success
2. Flutter ALSO calls Edge Function directly to notify recipient
3. Edge Function sends FCM notification

**Security:** Lower — client invokes notification logic. Risk of abuse (spam notifications). Requires auth verification in Edge Function but client controls invocation timing.

**Reliability:** Medium — depends on client network. If client fails to call Edge Function, no notification.

**Scalability:** Poor — every client must call Edge Function. Vulnerable to network issues.

**Complexity:** Lower than Option A but security is weaker.

**Verdict:** Not recommended for production chat.

### Option C: Existing Project-Native Infrastructure

**Finding:** None exists. No FCM, no APNs, no notification service, no device token table.

---

## 9. Recommended Push Architecture

**Option A: Supabase Database Webhook → Supabase Edge Function → FCM**

**Rationale:**
- Server-side only — no client-controlled notification logic
- Uses existing Supabase infrastructure (realtime publication, Edge Functions)
- Scales with FCM
- Clean separation: database event → notification decision → delivery
- Mute/block integration is straightforward in Edge Function

**Architecture:**
```
messages INSERT
  → Supabase Webhook
    → Supabase Edge Function: send_message_notification
      → Validate: recipient exists, not muted, not blocked
      → Query user_devices for recipient's FCM tokens
      → Call FCM HTTP v1 API
      → Return 200 to webhook
```

**Notification deduplication:**
- Edge Function checks `last_notified_at` in `conversation_members`
- Updates `last_notified_at` after sending
- Prevents duplicate notifications for same message batch

---

## 10. Device Token Design

**Table: `user_devices`**
```sql
CREATE TABLE public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  push_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NULL,
  UNIQUE(push_token)
);
```

**Indexes:**
```sql
CREATE INDEX idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_push_token ON public.user_devices(push_token);
```

**RLS:**
- SELECT: `auth.uid() = user_id` (user can see own tokens)
- INSERT: `auth.uid() = user_id` (user can register own tokens)
- UPDATE: `auth.uid() = user_id` (user can update own tokens)
- DELETE: `auth.uid() = user_id` (user can remove own tokens)

**Client behavior:**
- On app start: register/update FCM token in `user_devices`
- On token refresh: update existing token
- On logout: delete all tokens for current user (or mark with `last_seen_at = null`)
- On app close: update `last_seen_at`

**Stale token cleanup:**
- Edge Function or periodic job can delete tokens not seen in 30+ days.

**Migration:** `supabase/migrations/20260826000000_create_user_devices.sql`

---

## 11. Notification Routing

**Foreground (app open, conversation visible):**
- Realtime updates UI directly.
- No OS notification shown (avoid duplicate).
- If muted, still show in UI but no push notification when backgrounded.

**Background (app backgrounded, not closed):**
- Supabase Webhook → Edge Function → FCM → OS notification.
- Notification content: "New message from [Sender Name]" — does NOT expose message content.
- Tapping notification opens app → resolves conversation → opens ConversationScreen.

**Closed (app terminated):**
- Same as background — FCM delivers to system tray.
- Notification tap launches app → deep link to conversation.

**Mute check:**
- Edge Function queries `conversation_mutes` before sending.
- If muted, no notification sent.

**Block check:**
- Edge Function queries `blocks` before sending.
- If blocked, no notification sent.

**Duplicate prevention:**
- Edge Function checks `conversation_members.last_notified_at` (new column).
- Only sends notification for messages created after `last_notified_at`.
- Updates `last_notified_at` to latest message timestamp after sending.

**Notification tap routing:**
- FCM notification includes `conversation_id` in data payload.
- Flutter `FirebaseMessaging.onMessageOpenedApp` handler:
  - Reads `conversation_id` from payload
  - Resolves conversation via RPC if needed
  - Navigates to `ConversationScreen` with real `ChatRepository`

---

## 12. Security/RLS Design

### Device Tokens (`user_devices`)
- RLS ensures users can only manage their own tokens.
- Edge Function reads tokens server-side — never exposed to client.
- FCM server key stays in Edge Function environment variables, never in Flutter.

### Mute (`conversation_mutes`)
- RLS ensures users can only mute/unmute for themselves.
- Edge Function queries mute state — not client-provided.

### Block (`blocks`)
- RLS ensures users can only block/unblock for themselves.
- Block enforcement happens server-side (Edge Function, RLS on messages if needed).
- No client can fabricate block relationships.

### Reports (`reports`)
- RLS ensures users can only submit reports as themselves.
- `reporter_id <> reported_id` enforced in WITH CHECK.
- No client can read/modify/delete reports (admin-only via service role).
- Edge Function or Supabase Dashboard handles report review.

### Push Notifications
- FCM credentials never in Flutter.
- Notification routing uses server-verified `conversation_id`.
- Recipient identity derived from `conversation_members`, not client input.

---

## 13. Supabase Migration Plan

| Migration | Purpose |
|-----------|---------|
| `20260823000000_create_conversation_mutes.sql` | Mute table + RLS + indexes |
| `20260824000000_create_blocks.sql` | Block table + RLS + indexes |
| `20260825000000_create_reports.sql` | Report table + RLS + indexes |
| `20260826000000_create_user_devices.sql` | Device token table + RLS + indexes |
| `20260827000000_add_last_notified_at.sql` | Add `last_notified_at` to `conversation_members` for notification deduplication |

**No modifications to existing migrations.**
**No modifications to existing RLS policies.**
**No modifications to existing RPC.**

---

## 14. Exact Files to Create

| File | Purpose |
|------|---------|
| `supabase/migrations/20260823000000_create_conversation_mutes.sql` | Mute table, RLS, indexes |
| `supabase/migrations/20260824000000_create_blocks.sql` | Block table, RLS, indexes |
| `supabase/migrations/20260825000000_create_reports.sql` | Report table, RLS, indexes |
| `supabase/migrations/20260826000000_create_user_devices.sql` | Device token table, RLS, indexes |
| `supabase/migrations/20260827000000_add_last_notified_at.sql` | Add `last_notified_at` column to `conversation_members` |
| `lib/features/chat/chat_repository.dart` (extend) | Add mute, block, report, profile methods |
| `lib/features/chat/conversation_screen.dart` (extend) | Wire menu actions, block UI |
| `lib/features/chat/message_widgets.dart` (extend) | Timestamp timezone fix |
| `lib/features/profile/profile_navigation_mapper.dart` (extend) | Add `mapProfileToPublicProfile()` if needed |

---

## 15. Exact Files to Modify

| File | Changes |
|------|---------|
| `lib/features/chat/message_widgets.dart` | Fix `_formatClock()` to use `.toLocal()` |
| `lib/features/chat/conversation_screen.dart` | Wire View Profile, Mute, Block, Report menu actions; add block-state UI |
| `lib/features/chat/chat_repository.dart` | Add `getConversationMember()`, `getProfile()`, `muteConversation()`, `unmuteConversation()`, `isConversationMuted()`, `blockUser()`, `unblockUser()`, `isBlocked()`, `reportUser()`, `registerDeviceToken()`, `unregisterDeviceToken()` |
| `lib/features/chat/connections_screen.dart` | Hide blocked connections from list; reload mute state |
| `lib/features/profile/profile_navigation_mapper.dart` | Add `mapProfileToPublicProfile(UserProfile)` or reuse existing mapper |
| `lib/features/profile/discovery_repository.dart` | Exclude blocked users from discovery results |

---

## 16. Exact Files to Leave Unchanged

| File | Reason |
|------|--------|
| `lib/features/chat/chat_models.dart` | UI models — `isMuted` already exists, no structural change |
| `lib/features/chat/chat_widgets.dart` | Pure UI primitives |
| `lib/features/chat/chat_sections.dart` | Layout only |
| `lib/features/chat/message_widgets.dart` | Only `_formatClock()` fix — no redesign |
| `lib/features/chat/demo_chat_data.dart` | Demo data preserved |
| `lib/features/chat/conversation_widgets.dart` | Plus button remains inactive |
| `lib/features/chat/realtime_messages_service.dart` | Working realtime — no change |
| `lib/features/chat/chat_dtos.dart` | Backend DTOs — no change |
| `lib/features/profile/connection_repository.dart` | Connection CRUD locked |
| `lib/features/profile/connections_view_model.dart` | Connection state locked |
| `lib/features/profile/connection_data.dart` | Connection DTOs locked |
| `lib/features/profile/realtime_connections_service.dart` | Connection realtime locked |
| `lib/core/supabase/auth_service.dart` | Auth logic locked |
| `lib/core/supabase/supabase_client.dart` | Client config locked |
| All existing migrations | Locked |
| `pubspec.yaml` | Will need `firebase_messaging` added in implementation phase (not planning) |

---

## 17. Implementation Sequence

1. **Timestamp fix** — `message_widgets.dart` — single-line change, no migration
2. **Mute migration** — `20260823000000_create_conversation_mutes.sql`
3. **Block migration** — `20260824000000_create_blocks.sql`
4. **Report migration** — `20260825000000_create_reports.sql`
5. **Device token migration** — `20260826000000_create_user_devices.sql`
6. **last_notified_at migration** — `20260827000000_add_last_notified_at.sql`
7. **ChatRepository extensions** — mute, block, report, profile, device token methods
8. **ConversationScreen menu wiring** — View Profile, Mute, Block, Report
9. **ConnectionsInboxScreen block filtering** — hide blocked connections
10. **Discovery block exclusion** — exclude blocked users from discovery
11. **Push notification infrastructure** — FCM setup, Edge Function, Flutter notification service
12. **flutter analyze** — verify no new issues
13. **Two-device testing** — full matrix

---

## 18. Two-Device Test Matrix

| Test | Device A | Device B | Expected Result |
|------|----------|----------|-----------------|
| 1. Both online in chat | Open conversation | Open same conversation | Both see messages in realtime |
| 2. A sends → B receives | Send "Hello" | — | B sees "Hello" via realtime |
| 3. B sends → A receives | — | Send "Hi" | A sees "Hi" via realtime |
| 4. Rapid messages | Send 5 messages quickly | — | All 5 appear in order, no duplicates |
| 5. A backgrounded → B sends | Background app | Send "Test" | A receives push notification |
| 6. A fully closes → B sends | Close app | Send "Test" | A receives push notification |
| 7. A reopens notification | Tap notification | — | App opens to correct conversation |
| 8. A mutes B → B sends | Mute conversation | Send "Muted" | A receives no push notification. Message appears when A opens conversation. |
| 9. A unmutes B → B sends | Unmute | Send "Unmuted" | A receives push notification |
| 10. A blocks B | Block B | — | A sees blocked UI. B's messages stop. |
| 11. B attempts after block | — | Send message | Message fails RLS or is not delivered. B sees error or no conversation. |
| 12. A reports B | Report B with reason | — | Report persisted. A sees confirmation. |
| 13. A opens View Profile | Tap View Profile | — | Public profile opens. Back returns to chat. |
| 14. A logs out | Logout | — | Realtime channels cleaned up. No stale subscriptions. |
| 15. A logs in again | Login | — | Fresh realtime channel works. |
| 16. Multiple devices | Login on phone + tablet | — | Both devices receive notifications. Token management works. |
| 17. Token refresh | FCM token refreshes | — | New token registered in user_devices. Old token removed. |
| 18. Network interruption | Disconnect network | Send message | Message queued/sent on reconnect. Realtime recovers. |
| 19. Conversation switching | Open A → B | — | A's channel cleaned up. B's channel active. |
| 20. Timestamp across timezones | Device in IST (UTC+5:30) | Device in PST (UTC-8) | Both see correct LOCAL time for same message |

---

## 19. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **FCM token refresh race** | Medium | Medium | Client re-registers token on every app start. Old tokens cleaned up via `UNIQUE(push_token)` and stale-token cleanup job. |
| **Webhook delivery failure** | Low | Medium | Supabase webhooks retry automatically. Edge Function should be idempotent. |
| **Block/ mute state desync** | Low | Low | RLS enforces server-side. Client state reloads from Supabase on navigation. |
| **Report spam** | Medium | Low | `UNIQUE(reporter_id, reported_id)` prevents duplicate reports for same pair. Admin review in future phase. |
| **Edge Function cold start** | Low | Low | Supabase Edge Functions have fast cold starts for chat notification volume. |
| **Notification tap routing failure** | Low | Medium | Include `conversation_id` in FCM data payload. Flutter handler validates and navigates. |
| **Timestamp edge cases** | Low | Low | `.toLocal()` handles DST and timezone offsets correctly in Dart. |

---

## 20. Explicit Scope Boundary

### IN SCOPE for Phase 9.5.3
- Timestamp display fix (`.toLocal()`)
- View Profile menu action
- Mute foundation (table + RLS + basic UI toggle)
- Block foundation (table + RLS + UI enforcement)
- Report foundation (table + RLS + submission UI)
- Push notification architecture and implementation
- Device token management
- Notification routing (foreground/background/closed)
- Security/RLS for all new tables
- Two-device production testing

### OUT OF SCOPE for Phase 9.5.3
- Image messages
- Voice messages
- Calls
- Typing indicators
- Read receipts UI
- Message editing
- Message forwarding
- Admin dashboard for reports/blocks
- Full moderation system
- Redesign of chat UI or composer
- Plans chat backend
- Replacing working realtime architecture
- Dependency upgrades unless explicitly justified

---

## Phase 9.5.3 Plan Complete
## No implementation performed
## STOP
