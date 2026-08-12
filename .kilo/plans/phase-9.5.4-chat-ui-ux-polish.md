# Phase 9.5.4 — Chat UI/UX + Conversation State Polish
## PLAN MODE ONLY — NO IMPLEMENTATION

## 1. Current State Summary

### What works
- Supabase Auth, Realtime chat, message deduplication, timestamp `.toLocal()` fix, mute/block/report DB tables + RLS, View Profile navigation skeleton, connection list UI.

### What is broken or incomplete
| # | Issue | Root Cause |
|---|-------|-----------|
| 1 | Connection chat preview shows wrong timestamp (e.g. "Just now" for Person B/C) | `_load()` uses `connection.updatedAt` instead of latest message `created_at` |
| 2 | Keyboard gap above composer | `MessageComposer` wraps itself in `SafeArea(top: false)` which adds bottom padding; `AnimatedPadding` in `ConversationScreen` also adds bottom padding — double padding creates gap |
| 3 | Connection/Plan tab labels appear too high | `_Segment` inside `Row` uses default `CrossAxisAlignment.center`; `Expanded` doesn't force full-height stretch |
| 4 | Search bar looks like nested controls | Outer `Container` has its own padding + `TextField` has default `InputDecorator` padding, creating a "field within a field" visual |
| 5 | View Profile silently fails on error | `_handleViewProfile` returns early without SnackBar if `getConversationMember` or `getProfile` fails |
| 6 | Mute/Unmute menu doesn't update immediately | `_handleMute`/`_handleUnmute` call `setState(() {})` but never update `_isMuted`, so `_buildMenuActions` still reads the stale initial value |
| 7 | Muted indicator never appears in connection list | `_load()` builds `ConversationPreview` with `isMuted: false` (default); never queries `conversation_mutes` |
| 8 | Block confirmation unclear | SnackBar says "User blocked" instead of clear "Blocked" |
| 9 | Report flow unclear | SnackBar shows "Report submitted" but no visible test confirmation path |

---

## 2. Fix Plan

### Fix 1 — Connection Chat Preview Timestamp

**Problem:** `connections_screen.dart:_load()` builds `ConversationPreview` with:
```dart
timestamp: _relativeTime(m.updatedAt),  // uses connection.updatedAt
lastMessage: 'Connected',              // hardcoded
```

**Required behavior:**
- Source of truth: `public.messages.created_at` for latest non-deleted message per conversation
- Empty conversation → show "No messages yet" instead of fabricated relative time
- Convert UTC → local before formatting

**Plan:**
1. Add `ChatRepository.getLatestMessagePreview(String conversationId)` → returns `(String? lastMessage, DateTime? createdAt)` or a dedicated DTO.
   - Query: `SELECT content, created_at FROM messages WHERE conversation_id = :id AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1`
   - Returns `null` for empty conversations.
2. In `ConnectionsInboxScreen._load()`:
   - After getting `connectionModels`, for each model, call `getOrCreateConnectionConversation(connectionId)` to obtain the `conversationId`.
   - Call `getLatestMessagePreview(conversationId)` for each.
   - Build `ConversationPreview` with actual `lastMessage` and formatted `timestamp`.
   - For empty conversations: `lastMessage: 'No messages yet'`, `timestamp: ''`.
3. Update `_relativeTime` to accept `DateTime?` and return `''` for null.
4. Ensure `_relativeTime` converts to local: `final local = dateTime.toLocal();` before computing diff.

**Files:**
- `lib/features/chat/chat_repository.dart` — add `getLatestMessagePreview`
- `lib/features/chat/connections_screen.dart` — update `_load()` to use real message timestamps

**Do NOT:** change database schema. Use existing `messages` table.

---

### Fix 2 — Chat Input / Keyboard Position

**Problem:** `MessageComposer` in `conversation_widgets.dart:242` wraps its content in `SafeArea(top: false)`. `SafeArea` adds bottom padding for system UI (gesture nav bar). Meanwhile `ConversationScreen` uses `AnimatedPadding(bottom: MediaQuery.of(context).viewInsets.bottom)` to offset for keyboard. The two paddings stack, creating a visible gap.

**Plan:**
1. Remove `SafeArea(top: false)` wrapper from `MessageComposer`. The outer `Scaffold` already manages safe-area insets for the body.
2. Keep `AnimatedPadding` in `ConversationScreen` — it correctly tracks keyboard inset.
3. Verify `Scaffold` default `resizeToAvoidBottomInset: true` (already default, no change needed).

**Files:**
- `lib/features/chat/conversation_widgets.dart` — remove `SafeArea(top: false)` from `MessageComposer`

**Before:**
```dart
return SafeArea(
  top: false,
  child: Container(
    margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    ...
  ),
);
```

**After:**
```dart
return Container(
  margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
  ...
);
```

---

### Fix 3 — Connection / Plan Glass Tab Vertical Alignment

**Problem:** `ChatSegmentedTabs` uses a `Row` with default `CrossAxisAlignment.center`. `_Segment` is wrapped in `Expanded`, but `Expanded` in a `Row` only forces cross-axis (vertical) expansion when the `Row`'s `crossAxisAlignment` is `stretch`. With `center`, each `_Segment` only takes the height of its content, leaving the highlight behind.

**Plan:**
1. Add `crossAxisAlignment: CrossAxisAlignment.stretch` to the outer `Row` in `ChatSegmentedTabs` (line ~432 in `chat_widgets.dart`).
2. Ensure `_Segment`'s inner `Row` uses `MainAxisSize.min` (it already does implicitly via children) so text isn't stretched.

**Files:**
- `lib/features/chat/chat_widgets.dart` — add `crossAxisAlignment: CrossAxisAlignment.stretch` to `Row` inside `ChatSegmentedTabs`

**Change:**
```dart
// In ChatSegmentedTabs build:
Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,  // ADD THIS
  children: [
    _Segment(...),
    _Segment(...),
  ],
),
```

---

### Fix 4 — Search Bar Premium Polish

**Problem:** `PremiumSearchBar` has:
- Outer `Container` with `padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)` (4px top/bottom)
- Inner `TextField` with default `InputDecorator` padding (~12px top/bottom)
- Combined effect: text appears to sit in a nested inner rectangle

**Plan:**
1. Remove vertical padding from outer `Container` — keep only horizontal padding (`EdgeInsets.symmetric(horizontal: 16, vertical: 0)` or split into `EdgeInsets.fromLTRB(16, 14, 16, 14)`).
2. Remove `isCollapsed: true` from `InputDecoration` — it's unnecessary and can interfere with content padding.
3. Set `contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0)` on `InputDecoration` to center text vertically in the 54px container.
4. Keep outer `Container`'s glass decoration as the single visual surface.

**Files:**
- `lib/features/chat/chat_widgets.dart` — `PremiumSearchBar` build method

**Before:**
```dart
Container(
  constraints: const BoxConstraints(minHeight: 54),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  decoration: ...,
  child: Row(
    children: [
      Icon(...),
      SizedBox(width: 11),
      Expanded(
        child: TextField(
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            ...
          ),
        ),
      ),
    ],
  ),
)
```

**After:**
```dart
Container(
  constraints: const BoxConstraints(minHeight: 54),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  decoration: ...,
  child: Row(
    children: [
      Icon(...),
      SizedBox(width: 11),
      Expanded(
        child: TextField(
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
            ...
          ),
        ),
      ),
    ],
  ),
)
```

---

### Fix 5 — View Profile Error Handling

**Problem:** `_handleViewProfile` silently returns on failure:
```dart
if (result.isFailure || result.value == null) return;  // silent
if (profileResult.isFailure || profileResult.value == null) return;  // silent
```

**Plan:**
1. Replace silent returns with `ScaffoldMessenger.of(context).showSnackBar(...)` showing non-destructive error message.
2. Keep existing navigation logic unchanged.

**Files:**
- `lib/features/chat/conversation_screen.dart` — `_handleViewProfile`

**Change:**
```dart
final memberResult = await widget.chatRepository!.getConversationMember(...);
if (memberResult.isFailure || memberResult.value == null) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load profile')),
    );
  }
  return;
}

final profileResult = await widget.chatRepository!.getProfile(memberResult.value!);
if (profileResult.isFailure || profileResult.value == null) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load profile')),
    );
  }
  return;
}
```

---

### Fix 6 — Mute/Unmute Immediate UI Update

**Problem:** `_handleMute`/`_handleUnmute` call `setState(() {})` but never update `_isMuted`. `_buildMenuActions` reads `_isMuted` to decide whether to show Mute or Unmute. Result: menu doesn't change until screen is reloaded.

**Plan:**
1. In `_handleMute`: on success, `setState(() { _isMuted = true; })`.
2. In `_handleUnmute`: on success, `setState(() { _isMuted = false; })`.

**Files:**
- `lib/features/chat/conversation_screen.dart` — `_handleMute`, `_handleUnmute`

**Change:**
```dart
Future<void> _handleMute() async {
  if (widget.chatRepository == null) return;
  final result = await widget.chatRepository!.muteConversation(widget.conversation.id);
  if (!mounted) return;
  if (result.isSuccess) {
    setState(() { _isMuted = true; });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Failed to mute'), backgroundColor: const Color(0xFFFF4D8D)),
    );
  }
}

Future<void> _handleUnmute() async {
  if (widget.chatRepository == null) return;
  final result = await widget.chatRepository!.unmuteConversation(widget.conversation.id);
  if (!mounted) return;
  if (result.isSuccess) {
    setState(() { _isMuted = false; });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Failed to unmute'), backgroundColor: const Color(0xFFFF4D8D)),
    );
  }
}
```

---

### Fix 7 — Muted Indicator in Connection Chat List

**Problem:** `ConnectionsInboxScreen._load()` builds `ConversationPreview` with `isMuted: false` (default). The mute icon in `_NameAndPreview` never appears because `c.isMuted` is always false.

**Plan:**
1. In `ConnectionsInboxScreen._load()`, after building the initial `_connections` list, fetch mute states for each connection's conversation.
2. Update each `ConversationPreview` with the correct `isMuted` value.
3. Use existing `ChatRepository.isConversationMuted(conversationId)`.

**Implementation approach:**
- After the `connectionModels.map(...)` block, run a `Future.wait` to check mute state for each connection.
- Build a `Map<String, bool>` of `conversationId -> isMuted`.
- Rebuild `_connections` with correct `isMuted` values.
- On returning from conversation screen, `_load()` is called via `RealtimeConnectionsService` listener, so mute state refreshes automatically.

**Files:**
- `lib/features/chat/connections_screen.dart` — `_load()` method

**Pseudocode:**
```dart
// After building _connections with isMuted: false:
final muteChecks = await Future.wait(
  _connections.map((c) async {
    // Need conversationId for each connection
    final convResult = await ChatRepository().getOrCreateConnectionConversation(c.id);
    if (convResult.isFailure || convResult.value == null) return MapEntry(c.id, false);
    final muteResult = await ChatRepository().isConversationMuted(convResult.value!);
    return MapEntry(c.id, muteResult.isSuccess ? (muteResult.value ?? false) : false);
  }),
);
final muteMap = Map.fromEntries(muteChecks);
setState(() {
  _connections = _connections.map((c) => c.copyWith(isMuted: muteMap[c.id] ?? false)).toList();
});
```

---

### Fix 8 — Block Confirmation Clarity

**Problem:** SnackBar says "User blocked" — vague.

**Plan:**
1. Change SnackBar text from `'User blocked'` to `'Blocked'`.
2. Keep existing `Navigator.of(context).pop()` to return to connection list.
3. No other changes.

**Files:**
- `lib/features/chat/conversation_screen.dart` — `_handleBlock`

---

### Fix 9 — Report Flow Verification

**Current state:** Report flow already:
1. Opens reason picker (RadioListTile)
2. Opens optional details dialog
3. Calls `chatRepository.reportUser()`
4. Shows "Report submitted" SnackBar on success
5. Shows error SnackBar on failure

**Assessment:** Flow is functionally complete. No structural changes required. The spec's concern ("Report action does not appear to work") is likely caused by the same silent-failure pattern as View Profile, or by the details dialog always returning empty string.

**Plan:** No code change required. If testing reveals the reason picker doesn't close properly or the submission silently fails, fix in implementation phase.

---

### Fix 10 — Plus Button

**No change.** Already `onTap: () {}`. Leave as-is.

---

### Fix 11 — Notifications

**Out of scope.** No changes.

---

## 3. Files to Modify

| File | Changes |
|------|---------|
| `lib/features/chat/chat_repository.dart` | Add `getLatestMessagePreview(String conversationId)` |
| `lib/features/chat/connections_screen.dart` | Use real message timestamps; load mute state; update `_relativeTime` to handle null/empty |
| `lib/features/chat/conversation_screen.dart` | Fix keyboard gap (MessageComposer no SafeArea); View Profile error SnackBars; mute state update; block SnackBar text |
| `lib/features/chat/conversation_widgets.dart` | Remove `SafeArea(top: false)` from `MessageComposer`; add `CrossAxisAlignment.stretch` to `ChatSegmentedTabs` Row; polish `PremiumSearchBar` padding |
| `lib/features/chat/chat_models.dart` | Possibly add `copyWith` to `ConversationPreview` if not present (for mute state updates) |

---

## 4. Files to Leave Unchanged

| File | Reason |
|------|--------|
| `lib/features/chat/chat_models.dart` | Only `copyWith` addition if missing — no structural change |
| `lib/features/chat/chat_dtos.dart` | Backend DTOs locked |
| `lib/features/chat/chat_widgets.dart` | ConversationAvatar, UnreadBadge, etc. — no change |
| `lib/features/chat/chat_sections.dart` | Layout only |
| `lib/features/chat/message_widgets.dart` | Timestamp fix already done in 9.5.3 |
| `lib/features/chat/realtime_messages_service.dart` | Working realtime — locked |
| `lib/features/chat/demo_chat_data.dart` | Demo data locked |
| `lib/features/profile/connections_view_model.dart` | Connection state locked |
| `lib/features/profile/realtime_connections_service.dart` | Locked |
| `lib/core/supabase/auth_service.dart` | Locked |
| All existing migrations | Locked |
| `pubspec.yaml` | No new dependencies required |

---

## 5. Validation Plan

### Automated
- `flutter analyze` — 0 errors, no new warnings
- `flutter build apk --release` — succeeds

### Manual Two-Device Tests

| Test | Expected |
|------|----------|
| **A — Timestamp** | Each connection shows actual latest-message relative time. Empty conversation shows "No messages yet". |
| **B — Keyboard** | Composer sits directly above keyboard. No large gap. |
| **C — Search** | Single glass field. No nested inner fill. Placeholder vertically centered. |
| **D — Tab labels** | "Connection" and "Plan" text perfectly centered vertically and horizontally. |
| **E — View Profile** | Tapping View Profile opens other user's public profile. Back returns to same conversation. Failure shows SnackBar error. |
| **F — Mute** | Menu changes to Unmute immediately. Connection list shows mute icon. Unmute removes icon. |
| **G — Block** | "Blocked" confirmation. Conversation pops. No false success on failure. |
| **H — Report** | Reason picker → submit → "Report submitted" confirmation. |
| **I — Plus** | Tap does nothing. No error. No media picker. |
| **J — Notifications** | Not tested. Out of scope. |

---

## 6. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| N+1 queries for timestamps + mute state | Medium | Low | Connections list is typically small (< 100). If it grows, batch the queries in a later optimization. |
| `copyWith` missing on `ConversationPreview` | Low | Low | Add it if absent — trivial addition. |
| Keyboard gap fix affects Plans chat | Low | Low | `MessageComposer` is shared. Removing `SafeArea(top: false)` benefits both tabs. |
| Search bar polish changes text vertical position | Low | Low | Verify `contentPadding: EdgeInsets.symmetric(vertical: 14)` centers text visually. |

---

## 7. Explicit Scope Boundary

### IN SCOPE
- Connection chat preview timestamp from `messages.created_at`
- Keyboard/composer positioning
- Tab label vertical alignment
- Search bar visual polish
- View Profile error feedback
- Mute/unmute immediate UI state sync
- Muted indicator in connection list
- Block confirmation clarity
- Report flow verification

### OUT OF SCOPE
- Image/voice/file/location messaging
- Typing indicators
- Read receipts UI
- Calls
- Message editing/forwarding
- Admin dashboard
- Push notifications / FCM / Firebase
- New dependencies
- Plans chat backend changes
- Realtime architecture changes
- Migration changes

---

## Phase 9.5.4 Plan Complete
## No implementation performed
## STOP
