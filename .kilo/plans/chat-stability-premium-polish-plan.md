# Conexo Chat — Stability + Premium Polish Plan (Phase 9.5.2 incremental) — v2 (refined)

PLAN ONLY. No files changed, no build, no DB changes. Baseline = current verified-working Phase 9.5.2 chat. Incremental; no rollback.

> v2 refinements folded in: true realtime unread increment via the existing global listener, authoritative-count clarification, explicit no-false-blue-ticks deferral, premium long-press pin surface, keyboard small-margin clarification, per-conversation drafts, subtle Connections/Plans divider, search-bar no-regression, single-channel reuse, ordering preservation, protected-features list, DB lock, and mandatory `.\tool\build_apk.ps1` build command.

---

## 1. CURRENT STATE

### Relevant architecture
- Inbox: `connections_screen.dart` (`ConnectionsInboxScreen`) — loads accepted connections via `ConnectionsViewModel`, resolves each conversation via `ChatRepository.getOrCreateConnectionConversation`, latest preview via `getLatestMessagePreview`, unread via `loadUnreadCount`. Maintains `_connections`, `_latestMessageTimes` (connectionId→DateTime), `_conversationToConnectionMap` (conversationId→connectionId), `_connectionModels` (connectionId→model).
- Conversation: `conversation_screen.dart` (`ConversationScreen`) — loads messages, marks read, sends, realtime, optimistic append.
- Composer: `conversation_widgets.dart` (`MessageComposer`) — `StatefulWidget` with `_controller` + `_sending` flag.
- Data: `chat_repository.dart` (`ChatRepository`), DTOs `chat_dtos.dart`, UI models `chat_models.dart` / `message_models.dart`.
- Realtime: `realtime_messages_service.dart` — per-conversation channel (`start`/`stop`, server-filtered `conversation_id=eq`, `onMessageChanged`) + global channel (`startGlobal`/`stopGlobal`, unfiltered, `onGlobalMessageChanged`), two separate broadcast controllers.
- Sections: `chat_sections.dart` — `PinnedConversationsSection` (glass card) + `RecentConversationsSection` (flat list).

### Existing realtime flow
- `ConversationScreen` → `onMessageChanged` (per-conversation, server-filtered).
- `ConnectionsInboxScreen` → `onGlobalMessageChanged` (all messages, client-filtered via `_conversationToConnectionMap`). Handler currently updates `lastMessage` + `timestamp`, re-sorts by `_latestMessageTimes`, but **preserves `unreadCount` unchanged**.
- Optimistic send append de-duplicated against realtime INSERT by server `message.id`.

### Existing unread flow
- `updateLastReadAt(conversationId)` sets `conversation_members.last_read_at = now()` for current user; called in `ConversationScreen._load()` on open.
- `loadUnreadCount(conversationId)` reads current user's `last_read_at`, counts `messages` with `created_at > last_read_at AND deleted_at IS NULL`.
- Inbox sets `unreadCount` per connection during `_load()` only.

### Existing pin / keyboard / status / persistence
- `ConversationPreview.isPinned` exists; `_pinned`/`_recent` getters filter by it; real connections never set it; no pin persistence for chat.
- `ConversationScreen` `Scaffold` does not set `resizeToAvoidBottomInset` (defaults `true`); composer additionally wrapped in `AnimatedPadding(bottom: MediaQuery.viewInsets.bottom)` + `SafeArea(top:false)` + `margin:(10,8,10,10)`.
- `_mapDtoToMessage` hardcodes `MessageDeliveryStatus.read` (always blue). No per-message delivery/read column; only signal is `conversation_members.last_read_at`. Remote RLS: `conversation_members` SELECT = `auth.uid() = user_id` (own row only).
- `shared_preferences: ^2.3.2` already in `pubspec.yaml` (used by `home_connection_dashboard.dart`).

---

## 2. ISSUE-BY-ISSUE ROOT CAUSE

### ISSUE 1 — Second message cannot send
`MessageComposer._handleSend()` sets `_sending = true` and calls `widget.onSend!(text)` but **never resets `_sending`**. `onSend` is `ValueChanged<String>?` (void), so the parent `Future<void> _sendMessage` is discarded; the composer never learns completion. Both guards (`onTap: if(!_sending)`, and `_handleSend: if(text.isEmpty||_sending) return`) latch forever until the screen is recreated. Reopening recreates the composer (`_sending=false`). Affected: `conversation_widgets.dart`.

### ISSUE 2 — Unread badge behavior (initial + realtime + clear)
- **(2a) NULL `last_read_at` crash:** `loadUnreadCount` does `DateTime.parse(membership['last_read_at'] as String)`. RPC inserts members with `last_read_at = NULL`; never-opened conversations throw → failure → inbox shows 0 → badge never appears (Device B).
- **(2b) No live increment on incoming realtime:** `_handleMessageEvent` preserves `unreadCount` unchanged, so an incoming message while the inbox is open updates preview/order but **not** the badge.
- **(2c) No clear on read/return:** opening calls `updateLastReadAt` server-side, but the inbox never resets that conversation's `unreadCount` on return → stale badge (Device A).
- **(2d) Sender counted as unread:** count query lacks `sender_id != self`, so own messages inflate the count.
- **Backend contract:** DB schema sufficient. All fixes are client-side (query + in-memory lifecycle). No migration/RLS/RPC.

### ISSUE 3 — Long-press pin/unpin
Feature absent: no long-press handler, no toggle, connections never pinned, no persistence. `shared_preferences` available. Affected: `chat_widgets.dart` (`ConversationTile`), `connections_screen.dart`.

### ISSUE 4 — Composer too far above keyboard
Double bottom inset: `Scaffold.resizeToAvoidBottomInset` defaults `true` (lifts body) AND manual `AnimatedPadding(viewInsets.bottom)` adds keyboard height again. Affected: `conversation_screen.dart`.

### ISSUE 5 — Delivery/seen ticks
`_mapDtoToMessage` hardcodes `.read` → false blue on every own message. Backend supports only "sent" (persisted). No "delivered" (no receipts). Truthful "read" needs the recipient's `last_read_at`, which current RLS forbids the client from reading → **blue is not truthfully possible now**. Affected: `conversation_screen.dart`.

### ISSUE 6 — Connections/Plans visual separation
Enhancement: no divider between controls and list. Tab labels centering already corrected previously (must not regress). Affected: `connections_screen.dart`.

### ISSUE 7 — Per-conversation drafts
Feature absent: controller created empty each time, discarded on dispose, no keying/persistence. Affected: `conversation_widgets.dart`, `conversation_screen.dart`.

### Related audit
- Duplicate realtime subscriptions: none (separate controllers; per-conversation server-filtered). **Do not add channels.**
- Optimistic duplicate: handled via server-id de-dupe.
- Failed send lock: = Issue 1; fixed by resetting `_sending` in `finally`.
- Ordering: already correct via `_latestMessageTimes` DateTime sort; must preserve.
- Search bar: single-surface fix already in place; must not regress.

---

## 3. PROPOSED MINIMAL FIX

### Fix 1 — Second message send (`conversation_widgets.dart`)
- Change `MessageComposer.onSend` to `Future<void> Function(String)?`.
- `_handleSend`: guard, `setState(_sending=true)`, `_controller.clear()`, then `try { await widget.onSend!(text); } finally { if (mounted) setState(() => _sending = false); }`.
- Result: busy only during the real send; unlimited sequential sends; no lock on failure. No delays/polling/reloads.

### Fix 2 — Unread: authoritative initial + true realtime + clear (refinement)
- **Initial (authoritative), `chat_repository.dart` `loadUnreadCount`:**
  - Null-safe: `final raw = membership?['last_read_at'] as String?; final lastReadAt = raw != null ? DateTime.parse(raw) : DateTime.fromMillisecondsSinceEpoch(0);`
  - Exclude own: add `.neq('sender_id', user.id)` to the count query.
- **True realtime increment, `connections_screen.dart` `_handleMessageEvent`:** (reuses the EXISTING global listener — no new channel)
  - Resolve `connectionId = _conversationToConnectionMap[conversationId]`; if null or not in `_connectionModels`, ignore.
  - Determine sender: compare `event.message!.senderId` to `AuthService.currentUser?.id`.
  - Rebuild the matching `ConversationPreview` with:
    - `lastMessage` = message content, `timestamp` = `_formatInboxTimestamp(localCreatedAt)` (existing),
    - `unreadCount` = `existing.unreadCount + (isFromOtherUser ? 1 : 0)` (own messages never increment),
    - all other fields preserved.
  - Update `_latestMessageTimes[connectionId]` and re-sort (existing) → conversation moves to correct newest-first position.
  - Single `setState`. No `_load()`, no poll, no new subscription.
- **Clear on return, `connections_screen.dart` `_openConversation`:** `await Navigator.push(...)`; on return, optimistically rebuild that connection's `ConversationPreview` with `unreadCount: 0` + `setState` (server read already marked on open via `updateLastReadAt`). Ordering untouched (`_latestMessageTimes` unchanged).
- **Backend read logic unchanged:** `updateLastReadAt` not modified. Optimistic 0 is instant UI; the next `_load()` reconciles via the corrected authoritative `loadUnreadCount`.
- Requires importing `AuthService` (`../../core/supabase/auth_service.dart`) into `connections_screen.dart` (minimal import).

### Fix 3 — Premium long-press pin/unpin with persistence
- `chat_widgets.dart` `ConversationTile`: add optional `onLongPress`; wire `InkWell.onLongPress`.
- `connections_screen.dart`:
  - `Set<String> _pinnedConnectionIds` loaded from `SharedPreferences` (mirror dashboard style, e.g. bool keys `chat_pinned_<connectionId>` or one CSV key `chat_pinned_ids`).
  - Apply `isPinned: _pinnedConnectionIds.contains(m.connectionId)` when building previews (in both `_load` and realtime rebuilds).
  - On long-press, present a premium Conexo glass action surface (e.g. dark rounded `showModalBottomSheet` matching existing palette) with **Pin chat** or **Unpin chat**; toggle set, persist, `setState`.
  - Pinned items render in the EXISTING `PinnedConversationsSection` glass card (no redesign).
- Persists across rebuild/nav/app restart.

### Fix 4 — Keyboard inset (small intentional margin)
- `conversation_screen.dart`: set `Scaffold(resizeToAvoidBottomInset: false, ...)` so the manual `AnimatedPadding(viewInsets.bottom)` is the single lift mechanism. The composer's existing `SafeArea(top:false)` + `margin: (10,8,10,10)` provides the small intentional gap above the keyboard (not touching, not floating excessively). No composer redesign.

### Fix 5 — Truthful ticks (no false blue; blue deferred)
- `conversation_screen.dart` `_mapDtoToMessage`: stop hardcoding `.read`. Own persisted message → `MessageDeliveryStatus.sent` (gray single tick via existing `_statusGlyph`). Preserve `sending` for optimistic in-flight if already represented; received messages show no sender-status.
- **Explicitly deferred:** truthful blue read receipts require a backend capability absent today (recipient `last_read_at` is unreadable under current RLS). No RLS/RPC/migration in this phase. Documented as a future backend phase; requires separate explicit approval.

### Fix 6 — Subtle premium divider (labels stay centered)
- `connections_screen.dart`: insert a thin, low-opacity glass separator between the search/tab controls area and the `AnimatedSwitcher` content (e.g. 1px `Container` at ~6% white alpha with modest vertical spacing). No heavy container, not bright white, no redesign.
- Preserve the already-centered `Connections`/`Plans` labels (the `Center` + `MainAxisSize.min` fix in `_Segment`) — must not regress.

### Fix 7 — Per-conversation drafts (`SharedPreferences`)
- `conversation_widgets.dart` `MessageComposer`: add `String? initialText` and `ValueChanged<String>? onDraftChanged`. In `initState` set `_controller.text = initialText ?? ''` (programmatic set does not fire `TextField.onChanged`, so restore won't trigger a save). Add `onChanged: onDraftChanged` to the `TextField`. On successful send, clear controller and `onDraftChanged?.call('')`.
- `conversation_screen.dart`: key `chat_draft_<conversationId>`. Read the draft inside `_load()` (composer only built after `_loading=false`, so `initialText` is correct on first build). Write-through on `onDraftChanged` (non-empty → `setString`; empty → `remove`). Clear on successful send.
- Independent per conversation; survives navigation, conversation switching, and app restart; clears on send or manual empty; restore causes no spurious writes.

---

## 4. DATABASE IMPACT
- Migrations: **NO**
- RLS changes: **NO** (blue read receipts explicitly deferred; would need separate approval)
- RPC changes: **NO**
- Schema changes: **NO**

## 5. DEPENDENCY IMPACT
- `pubspec.yaml`: **NO** (`shared_preferences` already present; nothing else)

## 6. FILE CHANGE SUMMARY

| File | Change | Reason |
|---|---|---|
| `lib/features/chat/conversation_widgets.dart` | `onSend` → `Future<void> Function(String)?`, await + reset `_sending` in `finally`; add `initialText` + `onDraftChanged`, TextField `onChanged` | Issue 1, Issue 7 |
| `lib/features/chat/conversation_screen.dart` | `Scaffold(resizeToAvoidBottomInset:false)`; `_mapDtoToMessage` status → `sent`; draft load in `_load` + clear on send + pass draft params | Issue 4, Issue 5, Issue 7 |
| `lib/features/chat/chat_repository.dart` | `loadUnreadCount`: null-safe `last_read_at` + `.neq('sender_id', user.id)` | Issue 2a/2d (query-only, unavoidable) |
| `lib/features/chat/connections_screen.dart` | realtime unread increment (other-user only) in `_handleMessageEvent`; clear unread on return in `_openConversation`; pin set + SharedPreferences + apply `isPinned`; long-press premium menu; subtle divider; import `AuthService` | Issues 2b/2c, 3, 6 |
| `lib/features/chat/chat_widgets.dart` | `ConversationTile.onLongPress` param → `InkWell.onLongPress` | Issue 3 |

Not modified: `message_widgets.dart` (`_statusGlyph`/`_formatClock` correct), `realtime_messages_service.dart` (reuse existing channels), `chat_models.dart` (uses existing `isPinned`), `chat_sections.dart` (pinned/recent unchanged), `chat_dtos.dart`.

## 7. RISK ANALYSIS
- **Send/receive:** Fix 1 makes send awaitable; `finally` prevents lock on throw. Optimistic + realtime de-dupe unchanged.
- **Realtime:** no new channels/subscriptions; only `_handleMessageEvent` payload handling extended (sender check + unread increment). Single global listener preserved.
- **Unread counts:** `loadUnreadCount` null branch only affects previously-erroring never-opened conversations; `.neq` is additive; realtime increment gated to other-user; optimistic 0-on-return reconciled by authoritative `loadUnreadCount` on next `_load`.
- **Recent ordering:** `_latestMessageTimes` DateTime sort untouched; unread changes only mutate `unreadCount`.
- **Keyboard:** `resizeToAvoidBottomInset:false` scoped to `ConversationScreen` only.
- **Search:** untouched (single-surface bar preserved).
- **Pinned chats:** additive persistence; existing glass section unchanged.
- **Connections/Plans tabs:** divider is visual-only; centered labels preserved.
- **Timezone display:** untouched.
- **Existing Phase 9.5.2 behavior / RLS / migrations / RPCs / deps:** unchanged.

## 8. VALIDATION PLAN
1. `flutter analyze` → `No issues found!`
2. Manual (2 accounts / 2 devices):
   - **Issue 1:** send 5 messages back-to-back without leaving — all send.
   - **Issue 2:** B→A while A's inbox open → badge increments immediately, chat jumps to top; A opens → badge clears on return; B sends again → badge reappears immediately; A→B → A's own count never increments; never-opened conversation with incoming messages shows a badge (null-safe).
   - **Issue 3:** long-press → premium Pin sheet → pins into glass section; restart app → still pinned; long-press → Unpin → back to Recent.
   - **Issue 4:** keyboard open → composer directly above keyboard with small margin, no double gap.
   - **Issue 5:** own message = gray sent tick; never false blue.
   - **Issue 6:** subtle divider between controls and list on both tabs; labels centered.
   - **Issue 7:** A "hello" / B "how are you" persist independently across switching and restart; cleared on send / manual empty.
3. Regression sweep across all Protected Features (Section 11).

## 9. APK BUILD PLAN
- Do NOT build now (plan mode).
- After implementation, the ONLY permitted command is: `.\tool\build_apk.ps1`
- NEVER use `flutter build apk`. Do not invent or bypass the build script.

## 10. FINAL RECOMMENDATION (implementation order)
1. Second-message send (Fix 1)
2. Unread — authoritative + realtime increment + clear (Fix 2)
3. Pin persistence + premium long-press (Fix 3)
4. Keyboard inset (Fix 4)
5. Truthful ticks; blue deferred (Fix 5)
6. Per-conversation drafts (Fix 7)
7. Subtle divider (Fix 6)

## 11. PROTECTED FEATURES (must not regress)
sending/receiving; realtime delivery; optimistic append; realtime de-dupe; timezone-correct bubble timestamps; latest message preview; latest message timestamp; recent chat ordering (DateTime, newest first; pinned in pinned, unpinned in recent); search (single-surface bar); Connections/Plans tabs + centered labels; unread counts; pinned section glass UI; ConversationScreen navigation; keyboard avoidance; existing Supabase RLS; existing migrations; existing RPCs; existing dependencies.

## 12. DATABASE LOCK
No migrations, schema, RLS, RPC, or new dependencies unless explicitly approved separately (applies specifically to deferred blue read receipts).

## 13. BUILD COMMAND (mandatory)
Every APK build uses `.\tool\build_apk.ps1` only. Never `flutter build apk`.

## 14. MODE
Plan updated in plan mode. No source changes, no build performed. Awaiting explicit approval before implementation.
