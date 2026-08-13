# Chat Unread-State Forensic Root-Cause Report

PLAN MODE ONLY. No source changes. Investigative findings only.

## 1. SCOPE

Audited the complete unread badge lifecycle:
- Database schema (`conversation_members`, `messages`) and RLS policies
- `ChatRepository.loadUnreadCount()` and `updateLastReadAt()`
- `ConnectionsInboxScreen._load()`, `_handleMessageEvent()`, `_openConversation()`, `_clearUnread()`
- `ConversationScreen._load()` (read-mark flow)
- `RealtimeMessagesService` (global + per-conversation channels)
- `ChatMessageEvent` DTO mapping
- `AuthService.currentUser` lookup
- `conversation_members.last_read_at` read/write contract
- Screen lifecycle, dispose/recreate, and realtime re-subscribe windows

## 2. ROOT CAUSES

### ROOT CAUSE A — Timezone-naive `last_read_at` write (`updateLastReadAt`)

**File:** `lib/features/chat/chat_repository.dart:117`

```dart
await Supabase.instance.client
    .from('conversation_members')
    .update({'last_read_at': DateTime.now().toIso8601String()})
```

`DateTime.now()` returns local time. `toIso8601String()` produces a **naive** string with no timezone offset (e.g. `2026-08-13T10:21:10.000`). The `conversation_members.last_read_at` column is `TIMESTAMPTZ`.

Postgres `TIMESTAMPTZ` interprets a naive input according to the **session timezone**. Supabase's default session timezone is **UTC**. So:

- A user in **UTC+05:30** sends `10:21:10` (local). Postgres stores `10:21:10 UTC`.
  - Actual UTC at that moment was `04:51:10`.
  - Stored `last_read_at` is **5.5 hours in the future**.
  - `loadUnreadCount` queries `created_at > future_time` → **no messages qualify** → count = 0.
  - Badge **accidentally clears** regardless of real unread state.

- A user in **UTC-05:00** sends `10:21:10` (local). Postgres stores `10:21:10 UTC`.
  - Actual UTC at that moment was `15:21:10`.
  - Stored `last_read_at` is **5 hours in the past**.
  - `loadUnreadCount` queries `created_at > past_time` → **recently-read messages still qualify** → count > 0.
  - Badge **does not clear** even though the user has read the conversation.

This produces the exact observed inconsistency across devices/accounts (timezone-dependent).

**Impact:** The server-side authoritative unread count (`loadUnreadCount`) is **wrong by the user's UTC offset** for every non-UTC user.

---

### ROOT CAUSE B — Realtime events dropped during inbox mapping initialization

**File:** `lib/features/chat/connections_screen.dart:96-103`

```dart
void _handleMessageEvent(ChatMessageEvent event) {
    ...
    final conversationId = event.message!.conversationId;
    final connectionId = _conversationToConnectionMap[conversationId];
    if (connectionId == null) return;           // <-- DROP
    if (!_connectionModels.containsKey(connectionId)) return; // <-- DROP
    ...
}
```

`_conversationToConnectionMap` and `_connectionModels` are populated **only inside `_load()`**, which is async and called in `initState()`.

`RealtimeMessagesService.instance.startGlobal()` is called **synchronously** in `initState()`, before `_load()` completes. The Supabase global realtime channel is therefore live **before** the inbox mapping exists.

Any `INSERT` event arriving in the window between `startGlobal()` and `_load()` completion is silently dropped. The unread badge never appears for that message.

The same gap reopens every time `ConnectionsInboxScreen` is recreated (e.g., tab switch, back-navigation, dispose/recreate). During that window, realtime events are lost for unread tracking.

**Impact:** Intermittent missing green unread badge, especially on fast networks or slow `_load()` (e.g., many connections).

---

### ROOT CAUSE C — Global handler increments unread without checking conversation view state

**File:** `lib/features/chat/connections_screen.dart:107-124`

```dart
final isFromOther = message.senderId != AuthService.currentUser?.id;
...
unreadCount: existing.unreadCount + (isFromOther ? 1 : 0),
```

The global `_handleMessageEvent` runs **continuously** even when the user has the conversation open. It has no concept of "user is currently viewing this thread."

When a new message arrives while the user is in the conversation:
1. The global handler increments `unreadCount` in the inbox state.
2. The user reads the message in the conversation screen.
3. On return, `_clearUnread` sets local `unreadCount = 0`.
4. If a **delayed/duplicate** realtime event for that same message arrives **after** `_clearUnread`, the handler increments again.
5. The badge reappears with no new content.

Supabase realtime can deliver events out of order or with micro-delays, especially on reconnection. The global handler's `existing.unreadCount + 1` is a pure accumulator with no de-duplication, no server-side validation, and no view-state awareness.

**Impact:** Badge reappears after being cleared; count can drift above the true server-side count.

---

### ROOT CAUSE D — Optimistic `_clearUnread` is overwritten by stale server data or late realtime

**File:** `lib/features/chat/connections_screen.dart:301-323`

```dart
void _clearUnread(String connectionId) {
    final idx = _connections.indexWhere((c) => c.id == connectionId);
    if (idx < 0) return;
    ...
    setState(() {
        _connections[idx] = ConversationPreview(..., unreadCount: 0, ...);
    });
}
```

`_clearUnread` is **local-only**. It does not write to the server. It can be overwritten by:

- A late realtime event (Root Cause C).
- A `_load()` triggered by `RealtimeConnectionsService.onConnectionsChanged`. `_load()` rebuilds `_connections` from server queries. If it runs after `_clearUnread` but before the user's `updateLastReadAt` has propagated, the server still returns the old count, overwriting the optimistic 0.

**Impact:** Optimistic clear is not durable until the next authoritative `_load()` reconciles.

---

### ROOT CAUSE E — `_clearUnread` uses `connectionId` but `_openConversation` passes `conversationId` to `_clearUnread` (indirectly correct but fragile)

**File:** `lib/features/chat/connections_screen.dart:273-295`

```dart
final conversationId = result.value!;
...
final realPreview = ConversationPreview(
    id: conversationId,   // <-- ConversationPreview.id = conversationId (UUID)
    ...
);
await Navigator.of(context).push(conversationRoute(realPreview, ...));
if (!mounted) return;
_clearUnread(connectionId); // <-- connectionId (e.g. "network_002")
```

`_clearUnread` searches `_connections` by `connectionId`, which is correct because `_connections` items have `id = connectionId`. However, the `ConversationPreview` passed to `ConversationScreen` carries `id = conversationId`. If any downstream code conflates the two IDs (e.g., realtime handler mapping back via `_conversationToConnectionMap`), a stale or missing mapping would prevent proper unread tracking on return.

**Impact:** Low-severity fragility; contributes to missed events if mappings diverge.

---

## 3. EXECUTION LIFECYCLE SEQUENCES

### Sequence 1 — Badge never appears (intermittent)

1. User is on Connections inbox.
2. `initState()` runs: `startGlobal()` subscribes to all message INSERTs. `_load()` starts asynchronously.
3. Remote user sends message. Supabase delivers INSERT event immediately.
4. `_handleMessageEvent` fires.
5. `_conversationToConnectionMap` is **empty** ( `_load()` still running).
6. `connectionId == null` → event is **dropped**.
7. `_load()` eventually completes, populates the map, and queries the server for unread count.
8. If the new message's `created_at` is after the user's stale `last_read_at`, the server count is correct. If `last_read_at` is timezone-corrupted (Root Cause A), the count may be 0 even though the message is truly unread.
9. **Result:** Badge appears sometimes (if event arrives after map is ready) and sometimes not (if event arrives during init).

### Sequence 2 — Badge does not clear (unreliable)

1. User opens conversation A.
2. `ConversationScreen._load()` loads messages, then calls `updateLastReadAt`.
3. `updateLastReadAt` writes naive local ISO to `TIMESTAMPTZ`. Postgres stores it as UTC.
4. If user is in negative timezone, stored `last_read_at` is **in the past**.
5. User reads all messages and navigates back.
6. `_clearUnread` optimistically sets local `unreadCount = 0`.
7. If a late realtime event for an earlier message arrives, `_handleMessageEvent` increments count back to 1 (Root Cause C).
8. If `RealtimeConnectionsService` fires `onConnectionsChanged`, `_load()` runs and queries the server. The server still reports the old `last_read_at` (or a timezone-corrupted one), returning a non-zero count.
9. `_load()` overwrites the optimistic 0 with the stale server count.
10. **Result:** Badge remains until another navigation or full reload forces a correct `_load()` after the server state has converged.

### Sequence 3 — Badge appears for own message

1. User sends message to themselves (or from another device).
2. Global realtime handler receives INSERT.
3. `isFromOther = message.senderId != AuthService.currentUser?.id` → `false` if same user, `true` if `currentUser` is null or stale.
4. If `AuthService.currentUser` is null (e.g., auth state not yet resolved after cold start), `isFromOther` is `true` for **all** messages, including own.
5. Unread count increments for own message.

**Impact:** Minor; only during auth transition windows.

---

## 4. PROBLEM CLASSIFICATION

| Root Cause | Category | Severity |
|---|---|---|
| A — Timezone-naive `last_read_at` | Database state / client contract | **Critical** — causes wrong authoritative counts for all non-UTC users |
| B — Events dropped during init | Client state / realtime timing | **High** — causes intermittent missing badges |
| C — Blind realtime increment | Client state / realtime architecture | **High** — causes false positives after clear |
| D — Optimistic clear overwritten | Client state / lifecycle race | **Medium** — causes stale badge after return |
| E — ID mapping fragility | Client state | **Low** — contributes to B/C under edge cases |

Combined, A + B + C produce the exact reported symptoms:
- **Intermittent badge:** B (events dropped during init) + A (timezone-corrupted authoritative count).
- **Unreliable clear:** C (late realtime re-increment) + D (optimistic overwritten) + A (server count remains wrong).

---

## 5. MINIMAL FIX (CLIENT-SIDE ONLY — NO DB CHANGE REQUIRED)

### Fix A — Correct timezone in `updateLastReadAt`

**File:** `lib/features/chat/chat_repository.dart:117`

Replace:
```dart
.update({'last_read_at': DateTime.now().toIso8601String()})
```

With:
```dart
.update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
```

`DateTime.now().toUtc()` produces a properly timezone-aware ISO string (e.g. `2026-08-13T04:51:10.000Z`). Postgres `TIMESTAMPTZ` stores this correctly as UTC. `loadUnreadCount`'s `DateTime.parse()` then reads back the correct UTC instant.

**Why this is sufficient:** The existing `loadUnreadCount` already uses `DateTime.parse()` and compares `created_at > last_read_at`. Both sides become UTC-correct. No schema change, no RLS change, no migration.

### Fix B — Buffer realtime events during inbox init

**File:** `lib/features/chat/connections_screen.dart`

Add a `List<ChatMessageEvent> _pendingRealtimeEvents = [];` to the state class.

In `_handleMessageEvent`:
```dart
void _handleMessageEvent(ChatMessageEvent event) {
    if (event.type != ChatEventType.inserted) return;
    if (event.message == null) return;

    // If mappings are not ready, buffer and process after _load completes.
    if (_conversationToConnectionMap.isEmpty || _connectionModels.isEmpty) {
        _pendingRealtimeEvents.add(event);
        return;
    }
    _processMessageEvent(event);
}
```

In `_load()`, after the `setState` that sets `_loading = false`:
```dart
if (_pendingRealtimeEvents.isNotEmpty) {
    final pending = List<ChatMessageEvent>.from(_pendingRealtimeEvents);
    _pendingRealtimeEvents.clear();
    for (final evt in pending) {
        _processMessageEvent(evt);
    }
}
```

Extract the current event-processing logic into `_processMessageEvent(ChatMessageEvent event)`.

**Why this is sufficient:** Events arriving before the map is ready are not lost; they are drained immediately after `_load()` completes, when the mapping is guaranteed to exist.

### Fix C — Gate realtime unread increment on conversation view state

**File:** `lib/features/chat/connections_screen.dart`

Add a `Set<String> _viewedConversationIds = {};` to the state class.

In `_openConversation`, before pushing the route:
```dart
_viewedConversationIds.add(conversationId);
```

In `_clearUnread` (or after Navigator returns):
```dart
_viewedConversationIds.remove(connectionId);
```

In `_processMessageEvent`, increment unread **only if** the conversation is not currently viewed:
```dart
if (_viewedConversationIds.contains(connectionId)) {
    // User is actively reading this conversation; do not increment unread.
    // Still update preview + sort.
} else {
    // Increment unread.
}
```

**Why this is sufficient:** The global handler no longer increments unread for conversations the user is actively viewing. Late events for viewed conversations are ignored for unread purposes.

### Fix D — Make optimistic clear durable until server reconciles

**File:** `lib/features/chat/connections_screen.dart`

`_clearUnread` is already local-only. To prevent `_load()` from overwriting it with stale data, add a `Map<String, int> _optimisticUnreadOverrides = {};` that tracks conversations whose unread was optimistically cleared.

In `_clearUnread`:
```dart
_optimisticUnreadOverrides[connectionId] = 0;
```

In `_load()`, when building `connectionPreviews`:
```dart
final optimisticOverride = _optimisticUnreadOverrides[connectionId];
final unreadCount = optimisticOverride != null
    ? optimisticOverride
    : (unreadResult.isSuccess ? (unreadResult.value ?? 0) : 0);
```

After a successful `_load()`, clear the override for conversations whose server count matches the override:
```dart
_optimisticUnreadOverrides.removeWhere((id, val) {
    final serverCount = ...; // lookup from freshly loaded previews
    return serverCount == val;
});
```

**Why this is sufficient:** The optimistic 0 persists across `_load()` calls until the server confirms it. Late realtime events still increment (Fix C), but only for non-viewed conversations.

---

## 6. FILES THAT WOULD NEED MODIFICATION

| File | Change |
|---|---|
| `lib/features/chat/chat_repository.dart` | Fix A: `DateTime.now().toUtc().toIso8601String()` in `updateLastReadAt` |
| `lib/features/chat/connections_screen.dart` | Fix B: buffer + drain pending realtime events during init; Fix C: view-state gating; Fix D: optimistic unread overrides |

No other files require changes for the unread-state fix.

---

## 7. WHAT MUST NOT BE CHANGED

- **Migrations:** No new migrations, no schema changes, no RLS changes.
- **RLS:** `conversation_members` SELECT policy (`auth.uid() = user_id`) stays as-is. `loadUnreadCount` query stays as-is except for the `.neq('sender_id', user.id)` already present.
- **RPC:** `get_or_create_connection_conversation` unchanged.
- **Realtime architecture:** Global channel + per-conversation channel structure unchanged. No new subscriptions.
- **Search UI, pin system, drafts, keyboard, message sending, ticks:** All out of scope for this forensic report.
- **`_latestMessageTimes` ordering logic:** Untouched; unread changes only mutate `unreadCount`.

---

## 8. REGRESSION RISKS

| Risk | Mitigation |
|---|---|
| `toUtc()` changes `last_read_at` semantics for existing users | Existing rows with timezone-corrupted `last_read_at` will self-correct on next `updateLastReadAt` call. No migration needed. |
| Buffered events replay in bursts after `_load()` | `_processMessageEvent` uses single `setState` per event; Flutter batches rebuilds. Visually identical to immediate processing. |
| View-state set leak if screen is disposed mid-conversation | Clear `_viewedConversationIds` in `dispose()` to prevent stale entries. |
| Optimistic override prevents `_load()` from ever reconciling | Override is cleared when server count matches, or on next `_load()` after the user returns (server-side `updateLastReadAt` has propagated). |
| `AuthService.currentUser` null during cold start | `isFromOther` falls back to `true` only if `currentUser` is null; this is existing behavior and only affects the brief auth transition window. |

---

## 9. VALIDATION PLAN (2 DEVICES / 2 ACCOUNTS)

### Device A (Account A, any timezone), Device B (Account B, any timezone)

1. **Baseline timezone check:**
   - Record each device's local UTC offset in Settings.
   - Confirm `updateLastReadAt` writes UTC-correct value by querying `conversation_members.last_read_at` via Supabase Table Editor after reading a conversation.

2. **Intermittent badge (Root Cause B):**
   - Device B sends 5 messages rapidly while Device A's inbox is loading (force slow network via DevTools bandwidth throttle).
   - Verify all 5 badges appear (no drops).

3. **Timezone-dependent clear (Root Cause A):**
   - Device A opens conversation, reads all messages, returns.
   - Verify badge clears on both positive and negative timezone offsets.
   - Cross-check server `last_read_at` is after the latest message `created_at`.

4. **Late realtime re-increment (Root Cause C):**
   - Device A opens conversation with 1 unread message.
   - Device B sends a second message while A is viewing.
   - Device A reads both, returns.
   - Verify badge stays at 0 (not re-incremented by late/delayed event).

5. **Optimistic clear durability (Root Cause D):**
   - Device A opens conversation with unread badge.
   - Rapidly trigger a connections refresh (simulate `RealtimeConnectionsService` event) while A is still in conversation.
   - A returns; verify badge is 0, not overwritten by stale `_load()`.

6. **Own-message count (existing Fix 2d):**
   - Device A sends message to itself (or from another session).
   - Verify A's own unread count does not increment.

7. **Full regression:**
   - Send 10+ messages back-to-back.
   - Open/close conversations rapidly.
   - Navigate away and back to inbox.
   - Verify ordering, previews, timestamps, pin state, drafts, keyboard, and ticks remain correct.

---

## 10. DECISION REQUIRED

The fixes above are **client-side only** and require **no database, migration, RLS, or RPC changes**. They address all four reported symptoms.

**One open design question:**

Should `_clearUnread` also call `updateLastReadAt` (in addition to the existing call in `ConversationScreen._load()`) to make the optimistic clear immediately durable on the server, or is the current flow (mark-read on open, optimistic clear on return, reconcile on next `_load()`) sufficient?

**Recommended answer:** Keep the current flow. `updateLastReadAt` already runs on conversation open. Calling it again on return adds a redundant write and does not prevent late realtime increments (Fix C is the correct guard for that). The optimistic override (Fix D) bridges the gap until the next authoritative `_load()`.

Awaiting approval to implement.
