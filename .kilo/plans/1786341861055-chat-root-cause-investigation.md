# Phase 9.5.6 — Root-Cause Investigation Report

## Issue 1 — Message Load
- **Exact execution path:**
  1. `ConnectionsInboxScreen._openConversation(c)` → `c.id` is the `connections` table UUID
  2. `ChatRepository.getOrCreateConnectionConversation(connectionId)` calls RPC `get_or_create_connection_conversation`
  3. RPC returns deterministic conversation UUID via `md5(connection_id || '-conexo-connection-v1')::uuid`
  4. `ConversationScreen` is pushed with `conversation.id = conversationId` (real UUID)
  5. `ConversationScreen._load()` calls `widget.chatRepository!.loadMessages(widget.conversation.id)`
  6. `loadMessages` runs: `SELECT * FROM messages WHERE conversation_id = X AND deleted_at IS NULL ORDER BY created_at ASC`
  7. **If the query throws** (non-`AuthException`), the generic `catch (e)` returns `ChatResult.failure('Failed to load messages')`
  8. UI shows `_ErrorState` with message "Failed to load messages"

- **Exact root cause:**
  The actual Supabase error is **hidden** by `loadMessages`'s catch-all:
  ```dart
  } catch (e) {
    return ChatResult.failure('Failed to load messages');
  }
  ```
  The exact exception type/message is not logged or surfaced. From the code structure, the most likely candidates are:
  - A `PostgrestException` from the server (400/401/403/404/500)
  - A network error

  **The `conversation_members` RLS is NOT the direct cause of an error here.** The messages SELECT RLS uses an `EXISTS` subquery that reads `conversation_members` with `auth.uid() = user_id`. Since the current user CAN read their own membership row, the subquery succeeds. If the user is a member, the EXISTS is true and the message is visible. If the user is NOT a member, the query returns an empty list (200 OK), not an error.

- **Evidence from code:**
  - `lib/features/chat/chat_repository.dart:47-68` — `loadMessages` swallows the real error
  - `lib/features/chat/conversation_screen.dart:134-147` — error handling path
  - `supabase/migrations/20260821000000_create_chat_foundation.sql:143-154` — messages RLS uses EXISTS subquery

- **Evidence from migration/RLS:**
  - `conversation_members` SELECT: `auth.uid() = user_id` — allows reading own row
  - `messages` SELECT: `EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = messages.conversation_id AND user_id = auth.uid())` — should pass for members

- **Exact file + relevant code location:**
  `lib/features/chat/chat_repository.dart:47-68`

- **Minimal correction required:**
  1. **Immediate:** Log the actual exception in `loadMessages` (and other repository methods) so the real Supabase error is visible.
  2. **Investigation:** Without the actual error message, the most likely remaining causes are:
     - The `messages` table or its columns (`conversation_id`, `deleted_at`, `created_at`) do not exist in the target database (migration not applied)
     - The `conversationId` passed to `loadMessages` is not a valid UUID (would cause a 400 PostgrestException)
     - An expired/invalid session causing a 401
     - The `order` or `isFilter` parameters generating a malformed query that PostgREST rejects

---

## Issue 2 — View Profile
- **Exact execution path:**
  1. User taps three-dot menu → `PopupMenuButton` calls `onMenuSelected('view_profile')`
  2. `_handleViewProfile()` is called
  3. Calls `widget.chatRepository!.getConversationMember(widget.conversation.id, AuthService.currentUser!.id)`
  4. `getConversationMember` runs:
     ```dart
     .from('conversation_members')
     .select('user_id')
     .eq('conversation_id', conversationId)
     .neq('user_id', excludeUserId)
     .maybeSingle()
     ```
  5. `conversation_members` SELECT RLS: `auth.uid() = user_id`
  6. The current user can only see rows where `user_id = auth.uid()`
  7. `.neq('user_id', excludeUserId)` filters out the current user's row
  8. The only remaining row is the other user's row, which is blocked by RLS
  9. Result set is empty → `maybeSingle()` returns `null`
  10. `getConversationMember` returns `ChatResult.success(null)`
  11. `_handleViewProfile` checks `memberResult.value == null` → shows "Could not load profile" SnackBar and returns

- **Exact root cause:**
  `conversation_members` SELECT RLS (`auth.uid() = user_id`) prevents the current user from reading the other member's row. The query in `getConversationMember` is designed to find the OTHER user, but RLS blocks it.

- **Evidence from code:**
  - `lib/features/chat/chat_repository.dart:154-173` — `getConversationMember`
  - `lib/features/chat/conversation_screen.dart:247-260` — `_handleViewProfile`

- **Evidence from migration/RLS:**
  - `supabase/migrations/20260821000000_create_chat_foundation.sql:114-118`
    ```sql
    CREATE POLICY "Members can read membership"
      ON public.conversation_members
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
    ```
  - There is NO subsequent migration that alters this policy.

- **Exact file + relevant code location:**
  `supabase/migrations/20260821000000_create_chat_foundation.sql:114-118`

- **Minimal correction required:**
  Change the SELECT policy to allow members to read all members of conversations they belong to:
  ```sql
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

---

## Issue 3 — Mute
- **Exact execution path:**
  1. User taps "Mute" in menu → `_handleMute()` is called
  2. Calls `widget.chatRepository!.muteConversation(widget.conversation.id)`
  3. `muteConversation` runs:
     ```dart
     .from('conversation_mutes')
     .upsert({
       'conversation_id': conversationId,
       'user_id': user.id,
     }, onConflict: 'conversation_id, user_id');
     ```
  4. `conversation_mutes` INSERT policy: `auth.uid() = user_id` — passes because `user.id == auth.uid()`
  5. The upsert succeeds → `ChatResult.success(null)`
  6. `_handleMute` sets `setState(() { _isMuted = true; })`
  7. **However:** the `PopupMenuButton` is already open and was built with the old `_isMuted` value. The user sees no immediate change in the open menu.
  8. When the user closes and reopens the menu, it now shows "Unmute".

- **Exact root cause:**
  The mute database operation **succeeds**. The perceived "no-op" is a **UI state synchronization issue**:
  - `_isMuted` is a local state variable in `_ConversationScreenState`
  - The open `PopupMenuButton` does not rebuild when `_isMuted` changes
  - The conversation list (`ConnectionsInboxScreen`) shows the muted indicator based on `isMuted` in `ConversationPreview`, which is only refreshed during `_load()`. After muting from the chat screen, the list does not refresh until the next `_load()`.

- **Evidence from code:**
  - `lib/features/chat/conversation_screen.dart:315-329` — `_handleMute` sets `_isMuted = true`
  - `lib/features/chat/conversation_screen.dart:567-569` — `_buildMenuActions` uses `_isMuted` but menu is already open
  - `supabase/migrations/20260823000000_create_conversation_mutes.sql:23-27` — INSERT RLS passes

- **Minimal correction required:**
  1. After `_handleMute`/`_handleUnmute` succeeds, close the menu or trigger a rebuild that refreshes the menu actions.
  2. Optionally, emit a stream/event from `RealtimeMessagesService` or use a state management solution to sync mute state between the conversation screen and the inbox list.

---

## Issue 4 — Block
- **Exact execution path:**
  1. User taps "Block" → confirmation dialog appears
  2. User confirms → `_handleBlock()` continues
  3. Calls `widget.chatRepository!.getConversationMember(widget.conversation.id, AuthService.currentUser!.id)`
  4. **Same RLS failure as Issue 2:** `getConversationMember` returns `ChatResult.success(null)`
  5. `_handleBlock` checks `otherId.isFailure || otherId.value == null` → **returns silently**
  6. The confirmation dialog has already closed (from the user's tap), but NO SnackBar or navigation occurs

- **Exact root cause:**
  `getConversationMember` returns null due to `conversation_members` SELECT RLS (`auth.uid() = user_id`). The block operation never executes because the code guards on `otherId.value == null`.

- **Evidence from code:**
  - `lib/features/chat/conversation_screen.dart:347-394` — `_handleBlock`
  - `lib/features/chat/chat_repository.dart:154-173` — `getConversationMember`
  - `supabase/migrations/20260821000000_create_chat_foundation.sql:114-118` — SELECT RLS blocks cross-member reads

- **Minimal correction required:**
  Fix `conversation_members` SELECT RLS (same as Issue 2).

---

## Issue 5 — Report
- **Exact execution path:**
  1. User taps "Report" → reason picker dialog appears
  2. User selects a reason → dialog closes (`Navigator.pop(context, v)`)
  3. Details dialog appears → user submits or skips → dialog closes
  4. Calls `widget.chatRepository!.reportUser(reportedId: otherId.value!, ...)`
  5. **But first:** `otherId = await widget.chatRepository!.getConversationMember(...)`
  6. **Same RLS failure:** `getConversationMember` returns `ChatResult.success(null)`
  7. `_handleReport` checks `otherId.isFailure || otherId.value == null` → **returns silently**
  8. User sees no "Report submitted" SnackBar

- **Exact root cause:**
  `getConversationMember` returns null due to `conversation_members` SELECT RLS. The report insert never executes.

- **Evidence from code:**
  - `lib/features/chat/conversation_screen.dart:396-481` — `_handleReport`
  - `lib/features/chat/chat_repository.dart:310-335` — `reportUser`
  - `lib/features/chat/chat_repository.dart:154-173` — `getConversationMember`
  - `supabase/migrations/20260821000000_create_chat_foundation.sql:114-118` — SELECT RLS

- **RLS verification for `reports` table:**
  - `supabase/migrations/20260825000000_create_reports.sql:27-31`
    ```sql
    CREATE POLICY "Users can insert reports"
      ON public.reports
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = reporter_id AND reporter_id <> reported_id);
    ```
  - This policy is **compatible** with `reportUser` (which sets `reporter_id: user.id`). The insert would succeed if `getConversationMember` returned the other user's ID.

- **Minimal correction required:**
  Fix `conversation_members` SELECT RLS (same as Issue 2).

---

## Issue 6 — Search Bar
- **Exact execution path (widget tree inspection):**
  ```
  Container (outer glass field)
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .10)),
    )
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0)
    child: Row
      Icon (search)
      SizedBox(width: 11)
      Expanded
        TextField (inner field)
          decoration: InputDecoration(
            border: InputBorder.none,
            filled: false,          ← THIS IS THE PROBLEM
            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 0),
          )
      ValueListenableBuilder (clear button)
  ```

- **Exact root cause:**
  The `TextField` has `filled: false` and `border: InputBorder.none`. With `filled: false`, the `TextField` does **not** create a Material background layer. The `InputDecorator` reserves internal padding space but paints no background. As a result, the hint text and cursor appear to float inside the outer `Container` without the TextField visually filling the parent. This creates the perception of a "nested field" — the outer Container looks like one field, and the TextField's content area looks like a second, smaller field inside it.

- **Evidence from code:**
  - `lib/features/chat/chat_widgets.dart:261-313` — `PremiumSearchBar.build`
  - Line 286: `filled: false`
  - The outer `Container` has `minHeight: 54` and rounded corners, creating a visible boundary
  - The inner `TextField` has `contentPadding: EdgeInsets.symmetric(vertical: 14)` which constrains the text area vertically within the parent

- **Minimal correction required:**
  Change the `TextField` decoration from:
  ```dart
  decoration: InputDecoration(
    border: InputBorder.none,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
    ...
  ),
  ```
  to:
  ```dart
  decoration: InputDecoration(
    border: InputBorder.none,
    filled: true,
    fillColor: Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
    ...
  ),
  ```
  `filled: true` with `fillColor: Colors.transparent` makes the `TextField` create a Material layer that fills the parent `Container`, eliminating the visual nesting while keeping the background transparent.

---

## Cross-cutting root cause

Issues 2, 4, and 5 share one underlying problem: **`conversation_members` SELECT RLS (`auth.uid() = user_id`) is too restrictive.** It only allows a user to read their own membership row. All three features (`getConversationMember` → View Profile, Block, Report) need to read the OTHER user's membership row, which is blocked.

Issue 1 (Message Load) has a **separate, undetermined root cause** — the actual Supabase error is hidden by the generic catch in `loadMessages`. The RLS chain for messages should allow the query to succeed (or return empty), not throw an error.

Issue 3 (Mute) is a **UI state propagation issue**, not a database/RLS issue.

Issue 6 (Search Bar) is a **widget styling issue**, unrelated to the database.

---

## Required changes

### Database policies

| Table | Policy | Current | Required |
|-------|--------|---------|----------|
| `conversation_members` | SELECT | `auth.uid() = user_id` | Allow members to read all members of conversations they belong to |

**File:** `supabase/migrations/20260821000000_create_chat_foundation.sql:114-118`

**Required SQL:**
```sql
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

### UI files

| File | Change |
|------|--------|
| `lib/features/chat/chat_widgets.dart` | `PremiumSearchBar`: change `filled: false` to `filled: true` and add `fillColor: Colors.transparent` |

---

## NOT required

- **Do not modify** `messages` RLS — the EXISTS subquery is correct for the intended behavior
- **Do not modify** `conversation_mutes`, `blocks`, or `reports` RLS — their policies are compatible with the repository queries (once `getConversationMember` works)
- **Do not modify** `profiles` RLS — the existing public-read policy (`Authenticated users can read public profiles`) already allows reading other users' public profiles
- **Do not modify** the `get_or_create_connection_conversation` RPC
- **Do not modify** `connections` RLS

---

## Validation plan

After applying the `conversation_members` RLS fix and the search bar fix:

1. **Message Load:** Add error logging to `loadMessages` to capture the actual Supabase exception. Without this, the exact failure mode cannot be confirmed. Verify the query succeeds by checking:
   - `widget.conversation.id` is a valid conversation UUID (not the connectionId)
   - The user is a member of the conversation (membership row exists)
   - The `messages` table exists in the target database with the expected schema

2. **View Profile:**
   - Open a connection chat
   - Tap three-dot menu → "View profile"
   - Expected: navigates to `PublicProfileScreen` with the other user's profile data
   - If it fails, the SnackBar should now show the actual `getProfile` error (not "Could not load profile")

3. **Block:**
   - Open a connection chat
   - Tap three-dot menu → "Block" → confirm
   - Expected: "Blocked" SnackBar appears
   - Verify in Supabase dashboard that a row is inserted into `blocks`

4. **Report:**
   - Open a connection chat
   - Tap three-dot menu → "Report" → select reason → submit
   - Expected: "Report submitted" SnackBar appears
   - Verify in Supabase dashboard that a row is inserted into `reports`

5. **Mute:**
   - Open a connection chat
   - Tap three-dot menu → "Mute"
   - Expected: menu closes; reopening menu shows "Unmute"
   - Verify in conversation list that muted indicator appears (may require pull-to-refresh)

6. **Search Bar:**
   - Open Connections inbox
   - Observe `PremiumSearchBar`
   - Expected: single unified glass field, no nested inner field appearance
   - The `TextField` should visually fill the outer `Container`
