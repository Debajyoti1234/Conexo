# P1.2B.9 — Plan Group Chat Implementation Plan

## Goal
Wire the existing Plan system to the existing real Chat architecture so every Plan can have at most one group conversation, accessible only to creator + joined participants.

## Non-negotiables
- Do NOT change Connection chat behavior, RLS, or repository.
- Do NOT create a second chat system.
- Do NOT seed demo Plan chat data.
- Do NOT change Plan discovery visibility or membership semantics.
- Do NOT make storage buckets public.
- Do NOT create broad client-write RLS policies.

## Implementation Steps

### Step 1: Database Migration
**File:** `supabase/migrations/20260901000000_plan_chat_integration.sql`

1. Add partial unique index on `conversations(plan_id) WHERE plan_id IS NOT NULL`.
2. Create `get_or_create_plan_conversation(p_plan_id uuid)` SECURITY DEFINER RPC:
   - Validate auth.
   - Validate plan exists.
   - Verify caller is creator OR has `plan_members.status = 'joined'`.
   - Find or create `conversations` row with `type='plan'`, `plan_id = p_plan_id`.
   - Insert all current `plan_members.status='joined'` users into `conversation_members`.
   - Return `conversation_id`.
3. Create `sync_plan_conversation_members()` SECURITY DEFINER trigger function:
   - Fires `AFTER UPDATE OF status ON plan_members`.
   - Finds existing plan conversation; if none, returns NEW.
   - If `NEW.status = 'joined'`, insert user into `conversation_members`.
   - Else, delete user from `conversation_members`.
4. Attach trigger to `plan_members`.

Verify:
- No duplicate RPC/trigger names exist.
- Existing connection conversations have `plan_id IS NULL`.

### Step 2: ChatRepository — Add Plan Methods
**File:** `lib/features/chat/chat_repository.dart`

Add to `ChatRepository`:
- `Future<ChatResult<String>> getOrCreatePlanConversation(String planId)`
  - Calls `get_or_create_plan_conversation` RPC.
- `Future<ChatResult<List<ChatConversation>>> loadPlanConversations()`
  - Queries `conversations` where `plan_id IN (user's joined plan_ids)` and caller is a `conversation_members` member.
- `Future<ChatResult<ChatConversation?>> findConversationForPlan(String planId)`
  - Returns existing plan conversation or null.
- `Future<ChatResult<GroupMetadata?>> loadGroupMetadata(String conversationId)`
  - Projects plan title, host, and joined participants from `plan_members` + `profiles`.
  - Resolves avatars via existing signed profile-photo architecture.

Update `LocalChatRepository`:
- `findConversationForPlan` → return `null` (keep as no-op stub).
- `loadPlanConversations` → return `[]` (remove demo data usage from production path).

### Step 3: Plans Chat Inbox (Real Backend)
**File:** `lib/features/chat/connections_screen.dart`

- Replace `LocalChatRepository.loadPlanConversations()` with `ChatRepository.loadPlanConversations()`.
- Build `ConversationPreview` list from real data:
  - `id` = `conversation.id`
  - `name` = plan title
  - `avatarAsset` = plan cover or host photo
  - `lastMessage`, `timestamp`, `unreadCount` from `getLatestMessagePreview` + `loadUnreadCount`
  - `type` = `ConversationType.group`
  - `planId` = plan id
- Route plan taps through `conversationRoute(preview, chatRepository: _chatRepository)`.
- Preserve Connections tab exactly (no changes).

### Step 4: Conversation Screen — Group Realtime
**File:** `lib/features/chat/conversation_screen.dart`

- Relax the `ConversationType.private` guard in `initState()` and `_load()` so group chats also:
  - Start `RealtimeMessagesService`.
  - Load messages via `ChatRepository`.
  - Load `GroupMetadata` via `ChatRepository.loadGroupMetadata`.
  - Map sender names/avatars from `GroupMetadata.participants`.
- Private chat path must remain byte-for-byte identical.

### Step 5: Plan Details — Group Chat Button
**File:** `lib/features/plans/plan_details_screen.dart`

- Add secondary "Group Chat" action in the bottom bar when:
  - `isHost` (creator) OR
  - `plan_members.status == 'joined'` (joined participant).
- On tap:
  - Call `ChatRepository.getOrCreatePlanConversation(plan.id)`.
  - On success, build `ConversationPreview` and push `conversationRoute(preview, chatRepository: _chatRepository)`.
  - On failure, show error SnackBar.
- Do NOT show for pending/declined/removed/left.

### Step 6: Notifications
**File:** `lib/features/notifications/notification_navigation.dart`

- Replace `LocalChatRepository.findConversationForPlan` with `ChatRepository.findConversationForPlan`.
- If conversation exists → open it.
- If not, but user is creator/joined → create via `getOrCreatePlanConversation` then open.
- If user is not eligible → show clear message (not "coming soon").

### Step 7: Cleanup Dead Code
**File:** `lib/features/chat/temporary_chat_screen.dart`
- Delete after confirming zero imports/references.

### Step 8: Validation
Run:
```powershell
flutter analyze
```

Then:
```powershell
.\tool\build_apk.ps1
```

## Open Questions / Risks
- **Conversation ID scheme:** Using server-generated UUID on RPC call (not deterministic). Acceptable because RPC is idempotent and partial unique index prevents duplicates.
- **Trigger recursion:** New trigger runs `SECURITY DEFINER` with `SET search_path = public` and does not call other SECURITY DEFINER functions that query `plan_members`, so RLS recursion risk is low.
- **Realtime inbox for Plans:** `_conversationToConnectionMap` is connection-only. Plan tab realtime can be added later; not blocking this phase.

## Validation Matrix
| Test | Expected |
|------|----------|
| Creator opens Group Chat | Creates 1 conversation, can send/receive |
| Joined participant opens Group Chat | Sees same conversation, can send/receive |
| Pending user | No Group Chat button, no access |
| Declined user | No Group Chat button, no access |
| Removed user | Loses conversation_members, no access |
| Repeated opens | Exactly 1 conversations row per plan |
| Connection chat | Unchanged |
| Realtime | Messages appear without refresh |
| Unread counts | Plan tab shows unread badges |
| Notifications | Navigate to real plan chat |
