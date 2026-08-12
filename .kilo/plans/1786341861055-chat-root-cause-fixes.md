# Phase 9.5.6 — Root-Cause Fix Plan

## Goal
Fix 6 reported failures in the chat feature with minimal, production-safe changes:
1. Message load error
2. View profile no-op
3. Mute no-op
4. Block no-op
5. Report no-op
6. Search bar nested visual

## Root Causes Found

### CRITICAL: `conversation_members` SELECT RLS blocks cross-member reads
**File:** `supabase/migrations/20260821000000_create_chat_foundation.sql:118`

Current policy:
```sql
CREATE POLICY "Members can read membership"
  ON public.conversation_members
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
```

This only allows a user to see **their own** membership row.  
But `ChatRepository.getConversationMember` queries for the **other** user:
```dart
.select('user_id')
.eq('conversation_id', conversationId)
.neq('user_id', excludeUserId)
```

Because the current user cannot read other members' rows, this query **always returns null**.  
All features that depend on `getConversationMember` silently fail:
- View Profile (`conversation_screen.dart:249`)
- Block (`conversation_screen.dart:373`)
- Report (`conversation_screen.dart:398`)

### Message load error
`loadMessages` uses `.isFilter('deleted_at', null)` which is valid in postgrest 2.9.1.  
The messages SELECT RLS requires `EXISTS (SELECT 1 FROM conversation_members ...)` — this should pass because the RPC inserts both users.  
If the user sees a persistent error, the most likely cause is the conversation_id mismatch or a network/auth issue. The RLS fix above ensures the user can read conversation_members, which is a prerequisite for the messages RLS check.

### Mute no-op
`muteConversation` does an `upsert` into `conversation_mutes`. The INSERT RLS is `auth.uid() = user_id` which should pass. The operation itself likely succeeds, but if the UI doesn't reflect it, it may be because `_isMuted` is only set during `_load()`. This is a UI state issue, not a database issue.

### Search bar nested visual
`PremiumSearchBar` has `filled: false` on the inner `TextField`. Without a filled background, the text and cursor can appear to float inside the outer Container, creating a "nested" visual. Changing to `filled: true` with `fillColor: Colors.transparent` gives the TextField a proper Material layer.

## Plan

### Step 1: Fix `conversation_members` SELECT RLS
Create migration `supabase/migrations/20260828000000_fix_conversation_members_select_rls.sql`:
```sql
-- Allow members to read all members of conversations they belong to
DROP POLICY IF EXISTS "Members can read membership" ON public.conversation_members;

CREATE POLICY "Members can read membership"
  ON public.conversation_members
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversation_members.conversation_id
        AND cm.user_id = auth.uid()
    )
  );
```

### Step 2: Fix search bar visual
In `lib/features/chat/chat_widgets.dart`, change the `TextField` decoration from:
```dart
filled: false,
```
to:
```dart
filled: true,
fillColor: Colors.transparent,
```

### Step 3: Verify mute UI state
Ensure `_handleMute` and `_handleUnmute` update `_isMuted` immediately (they already do). If the mute state appears to not persist across screen reloads, verify `isConversationMuted` is called during `_load()` (it is, at line 164).

### Step 4: Validate message load
After the RLS fix, verify that `loadMessages` succeeds by checking:
1. `widget.conversation.id` is the actual conversation UUID (not the connectionId)
2. The user is a member of the conversation (RLS check)
3. The messages table has rows for that conversation

If the error persists, add error logging to capture the exact Supabase error message.

## Files to Change
1. `supabase/migrations/20260828000000_fix_conversation_members_select_rls.sql` — new migration
2. `lib/features/chat/chat_widgets.dart` — search bar `filled` fix

## Validation
1. Run `supabase db reset` or apply the migration to the dev database
2. Open a conversation and verify messages load
3. Tap "View profile" — should navigate to profile screen
4. Tap "Block" — should show "Blocked" SnackBar
5. Tap "Report" — should show "Report submitted" SnackBar
6. Observe search bar — should no longer have nested visual

## Risks
- The RLS change allows users to read other members' rows in conversations they belong to. This is the intended behavior for a chat app (users need to know who they're talking to).
- The `conversation_members` table now exposes `user_id` to all members of a conversation. This is acceptable because `user_id` is already referenced in the `messages` table and is needed for UI display.
