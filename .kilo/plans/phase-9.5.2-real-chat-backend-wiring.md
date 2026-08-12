# Phase 9.5.2 — Real Chat Backend Wiring: Connections Chat
## PLAN MODE ONLY — NO IMPLEMENTATION

---

## 1. Current Inspected Architecture

### Connections Tab Data Flow (REAL)
```
ConnectionsInboxScreen
  → ConnectionsViewModel.loadAcceptedConnections()
    → ConnectionRepository.getMyConnections()
      → Supabase public.connections (REAL)
  → Maps ConnectionUiModel → ConversationPreview (id = connectionId)
  → _openConversation() navigates to ConversationScreen
```

### ConversationScreen Data Flow (DEMO)
```
ConversationScreen
  → widget.repository.loadMessages(conversationId)
    → LocalChatRepository.loadMessages()
      → demoMessageThreads[conversationId] (DEMO)
  → widget.repository.loadGroupMetadata(conversationId)
    → LocalChatRepository.loadGroupMetadata()
      → demoGroupMetadata[conversationId] (DEMO)
```

### Plans Tab Data Flow (DEMO — MUST PRESERVE)
```
ConnectionsInboxScreen._load()
  → _localChatRepository.loadPlanConversations()
    → demoConversations where type == group (DEMO)
```

### Realtime Infrastructure
- `RealtimeConnectionsService` — singleton, single channel, broadcasts connection changes
- `supabase_realtime` publication includes: `connections`, `conversations`, `conversation_members`, `messages`
- No message realtime subscription exists

### Key Gap
When a user taps an accepted connection in the Connections tab, the app navigates to `ConversationScreen` with the `connectionId` as the conversation ID. There is no real conversation in the database, no real messages, and no realtime. The entire message thread is fake demo data.

---

## 2. Files to Create

| File | Purpose |
|------|---------|
| `lib/features/chat/chat_repository.dart` | **Replace** the demo `LocalChatRepository` with a real `ChatRepository` for connection chat. Keep `LocalChatRepository` for Plans. |
| `lib/features/chat/realtime_messages_service.dart` | Singleton realtime service for active conversation message updates (INSERT/UPDATE/DELETE on `public.messages`). |
| `lib/features/chat/chat_dtos.dart` | Backend DTOs: `ChatConversation`, `ChatMessage`, `ChatMessageEvent`, `ChatEventType`. Minimal, focused on Supabase row mapping. |

### Note on `chat_repository.dart`
The existing `chat_repository.dart` contains the demo `LocalChatRepository`. Phase 9.5.2 will **replace** it with a real `ChatRepository`. The demo class is removed because:
- Plans tab will continue using its own local data path (see Plans-tab protection below)
- `LocalChatRepository` is entirely demo-oriented and will not be needed for connection chat

---

## 3. Files to Modify

| File | Changes |
|------|---------|
| `lib/features/chat/connections_screen.dart` | Wire Connections tab to real chat: resolve conversation on tap, pass real repository to `ConversationScreen`, add realtime subscription for messages |
| `lib/features/chat/conversation_screen.dart` | Accept optional `ChatRepository`, load real messages when repository is provided, enable message sending, subscribe to realtime |
| `lib/features/chat/chat_models.dart` | No structural changes to UI models. Add mapping helpers if needed. |
| `lib/features/chat/conversation_widgets.dart` | Enable `MessageComposer` send action for connection conversations |
| `lib/features/home_connection_dashboard.dart` | Update "Open Room" navigation to use real `ChatRepository` instead of `LocalChatRepository.findConversationForConnection()` |

### Note on `home_connection_dashboard.dart`
The existing "Open Room" button in `NetworkConnectionCard` currently calls:
```dart
final conversation = repository.findConversationForConnection(connection.id);
```
This always returns null for real connections (the demo map only has `'network_002': 'c2'`). Phase 9.5.2 should resolve the real conversation and navigate properly.

---

## 4. Files Intentionally Unchanged

| File | Reason |
|------|--------|
| `lib/features/chat/chat_widgets.dart` | Pure UI primitives — no data dependency |
| `lib/features/chat/chat_sections.dart` | Layout-only — no data dependency |
| `lib/features/chat/chat_models.dart` | UI models preserved as-is |
| `lib/features/chat/message_widgets.dart` | Pure UI — no data dependency |
| `lib/features/chat/demo_chat_data.dart` | Preserved for potential future Plans backend work |
| `lib/features/profile/connection_repository.dart` | Connection CRUD — separate concern |
| `lib/features/profile/connections_view_model.dart` | Connection state — separate concern |
| `lib/features/profile/connection_data.dart` | Connection DTOs — separate concern |
| `lib/features/profile/realtime_connections_service.dart` | Connection realtime — separate concern |
| `lib/core/supabase/supabase_client.dart` | No changes needed |
| `lib/core/supabase/auth_service.dart` | No changes needed |
| All migration files | Locked |

---

## 5. Supabase Changes

### 5.1 RPC Function: `get_or_create_connection_conversation`

**Purpose:** Atomically find or create a conversation for an accepted connection, and ensure both users are members. This is the only safe way to create conversations from the client because:
- `conversations` has no INSERT RLS policy (intentionally immutable from client in Phase 9.5.1)
- The function runs as `SECURITY DEFINER` to bypass RLS for the controlled creation path
- It validates the connection exists and is `accepted` before creating anything

**Signature:**
```sql
CREATE OR REPLACE FUNCTION public.get_or_create_connection_conversation(
  p_connection_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation_id uuid;
  v_requester_id uuid;
  v_recipient_id uuid;
BEGIN
  -- Validate connection exists and is accepted
  SELECT requester_id, recipient_id INTO v_requester_id, v_recipient_id
  FROM public.connections
  WHERE id = p_connection_id AND status = 'accepted';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Connection not found or not accepted';
  END IF;
  
  -- Derive deterministic conversation UUID from connection ID
  -- Same connection always maps to the same conversation
  v_conversation_id := md5(p_connection_id::text || '-conexo-connection-v1')::uuid;
  
  -- Create conversation if not exists (idempotent)
  INSERT INTO public.conversations (id, type, plan_id)
  VALUES (v_conversation_id, 'connection', NULL)
  ON CONFLICT (id) DO NOTHING;
  
  -- Add both members (idempotent)
  INSERT INTO public.conversation_members (conversation_id, user_id)
  VALUES (v_conversation_id, v_requester_id), (v_conversation_id, v_recipient_id)
  ON CONFLICT (conversation_id, user_id) DO NOTHING;
  
  RETURN v_conversation_id;
END;
$$;
```

**Security properties:**
- Only creates conversations for `accepted` connections
- Deterministic UUID prevents duplicate conversations for the same connection
- `ON CONFLICT DO NOTHING` makes it safe for concurrent calls
- `SECURITY DEFINER` bypasses the missing INSERT policy on `conversations`
- The function validates the connection state, not the client

**Grant:**
```sql
GRANT EXECUTE ON FUNCTION public.get_or_create_connection_conversation(uuid) TO authenticated;
```

### 5.2 Why No Schema Changes to Existing Tables
- `conversations` table already has all required columns (`type`, `plan_id`, timestamps)
- No `connection_id` column needed — the deterministic UUID mapping is sufficient
- No RLS changes needed — Phase 9.5.1 policies are already correct for message CRUD
- The RPC function handles the one gap (no INSERT policy on `conversations`)

---

## 6. RLS Verification

### No RLS Changes Required
Phase 9.5.1 RLS policies are sufficient:

| Operation | Table | Policy | Status |
|-----------|-------|--------|--------|
| Read conversation | `conversations` | Member check via EXISTS | ✅ Sufficient |
| Read messages | `messages` | Member check via EXISTS | ✅ Sufficient |
| Send message | `messages` | `auth.uid() = sender_id` + member check | ✅ Sufficient |
| Update message | `messages` | `auth.uid() = sender_id` | ✅ Sufficient |
| Update last_read_at | `conversation_members` | `auth.uid() = user_id` | ✅ Sufficient |
| Create conversation | `conversations` | **No INSERT policy** — handled by RPC | ✅ Correct |

### Security Properties Preserved
- User A cannot read User B's messages (membership check)
- User A cannot insert as User B (`auth.uid() = sender_id`)
- User A cannot insert into non-member conversations (membership check)
- User A cannot modify User B's membership (`auth.uid() = user_id`)
- User A cannot modify User B's messages (`auth.uid() = sender_id`)
- Conversation creation is gated by accepted connection validation in RPC

---

## 7. Connection → Conversation Creation Flow

```
User taps accepted connection in ConnectionsInboxScreen
  ↓
_openConversation(connectionId)
  ↓
Look up ConnectionUiModel from _connectionModels
  ↓
Call ChatRepository.getOrCreateConnectionConversation(connectionId)
  ↓
RPC: get_or_create_connection_conversation
  ↓ validates connection is accepted
  ↓ derives deterministic conversation UUID
  ↓ INSERT conversation (idempotent)
  ↓ INSERT both members (idempotent)
  ↓ returns conversation UUID
  ↓
Create ConversationPreview with real conversation UUID
  ↓
Navigate to ConversationScreen(conversation: realPreview, chatRepository: ChatRepository())
```

**Deterministic UUID mapping:**
```sql
md5(connection_id::text || '-conexo-connection-v1')::uuid
```
- Same connection ID always produces the same conversation UUID
- No duplicate conversations possible
- No race conditions (concurrent calls insert same UUID, one wins, others get existing)

---

## 8. Message Send Flow

```
User types text in MessageComposer
  ↓ taps send
  ↓
ChatRepository.sendMessage(conversationId, content)
  ↓
INSERT INTO public.messages (conversation_id, sender_id, type, content)
  ↓ RLS: auth.uid() = sender_id AND membership check
  ↓
On success: message appears in UI immediately (optimistic or confirmed)
  ↓
Realtime broadcasts INSERT to recipient
  ↓
Recipient's ConversationScreen appends new message
```

---

## 9. Message Receive Flow (Realtime)

```
ConversationScreen subscribes to messages for active conversation
  ↓
RealtimeMessagesService creates channel:
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'messages',
    filter: 'conversation_id=eq.<conversationId>',
    callback: (payload) => stream.add(event)
  )
  ↓
INSERT event → append new message to list
  UPDATE event → update message in place (soft delete)
  DELETE event → remove message from list
  ↓
UI rebuilds with new message
```

### Subscription Lifecycle
- `ConversationScreen.initState()` → `RealtimeMessagesService.instance.start(conversationId)`
- `ConversationScreen.dispose()` → `RealtimeMessagesService.instance.stop()`
- Reference counting prevents premature channel removal if multiple listeners exist

---

## 10. Read-State Flow

```
User opens ConversationScreen
  ↓
ChatRepository.updateLastReadAt(conversationId)
  ↓
UPDATE conversation_members SET last_read_at = now()
  WHERE conversation_id = :id AND user_id = auth.uid()
  ↓
Unread count in ConnectionsInboxScreen:
  SELECT count(*) FROM messages
  WHERE conversation_id = :id
    AND created_at > (SELECT last_read_at FROM conversation_members WHERE conversation_id = :id AND user_id = auth.uid())
    AND deleted_at IS NULL
```

**Note:** Unread count recalculation in `ConnectionsInboxScreen` is deferred to a future phase. Phase 9.5.2 only establishes the `last_read_at` update mechanism.

---

## 11. Error Handling

| Scenario | Behavior |
|----------|----------|
| Conversation creation fails | Show SnackBar error, keep user in inbox, allow retry |
| Message load fails | Show error state with retry button (existing `_ErrorState` pattern) |
| Message send fails | Show SnackBar error, restore message to composer for retry |
| Realtime subscription fails | Log error, fall back to manual pull-to-refresh |
| Auth session lost | `_load()` returns empty/failure, existing error UI handles it |
| Network interruption | Supabase client handles reconnection automatically |

All error handling uses the project's existing patterns:
- `ConnectionResult<T>`-style result wrappers (new `ChatResult<T>` follows same pattern)
- SnackBar for transient errors
- `_ErrorState` widget for screen-level failures
- Loading spinners during async operations

---

## 12. Plans-Tab Protection

### Explicit Guarantee
Phase 9.5.2 will **NOT** modify the Plans tab behavior:

| Component | Phase 9.5.2 Change? |
|-----------|---------------------|
| `ConnectionsInboxScreen._tabIndex == 1` (Plans) | **NO CHANGE** |
| `_localChatRepository.loadPlanConversations()` | **PRESERVED** |
| `_plans` list source | **PRESERVED** — still `LocalChatRepository` |
| Plans tab `_openConversation` | **PRESERVED** — still navigates to demo `ConversationScreen` |
| `LocalChatRepository` class | **REMOVED** but only because it's replaced by `ChatRepository` for connections; Plans data path remains local |

### Implementation Detail
The `_openConversation` method in `ConnectionsInboxScreen` will distinguish:
```dart
void _openConversation(ConversationPreview c) async {
  final isConnectionChat = _connectionModels.containsKey(c.id);
  if (isConnectionChat) {
    // Real connection chat — resolve conversation and use ChatRepository
    ...
  } else {
    // Plan chat — preserve existing demo behavior
    Navigator.of(context).push(conversationRoute(c));
  }
}
```

Plans conversations never have entries in `_connectionModels`, so they always take the demo path.

---

## 13. Model Strategy

### Existing UI Models (Preserved)
- `ConversationPreview` — unchanged, used by both real and demo paths
- `Message` — unchanged, used by `ConversationScreen` UI
- `ConversationType` — unchanged (`private` for connections, `group` for plans)
- `MessageType` — unchanged (UI enum)

### New Backend DTOs (`chat_dtos.dart`)
```dart
class ChatConversation {
  final String id;
  final String type;
  final String? planId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String content;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? deletedAt;
}

class ChatMessageEvent {
  final String messageId;
  final ChatEventType type;
  final ChatMessage? message;
  
  const ChatMessageEvent({
    required this.messageId,
    required this.type,
    this.message,
  });
}

enum ChatEventType { inserted, updated, deleted }
```

### Mapping
- `ChatRepository` maps Supabase rows → UI models internally
- `ConversationScreen` receives UI `Message` objects (no DTOs exposed to widgets)
- `chat_dtos.dart` is the only new model file; existing models are untouched

---

## 14. Realtime Subscription Design

### `RealtimeMessagesService` (New Singleton)

```dart
class RealtimeMessagesService {
  RealtimeMessagesService._();
  static final RealtimeMessagesService instance = RealtimeMessagesService._();
  
  RealtimeChannel? _channel;
  final _controller = StreamController<ChatMessageEvent>.broadcast();
  int _listenerCount = 0;
  String? _lastConversationId;
  
  Stream<ChatMessageEvent> get onMessageChanged => _controller.stream;
  
  void start(String conversationId) {
    _listenerCount++;
    if (_channel != null) {
      if (conversationId == _lastConversationId) return;
      stop();
    }
    _lastConversationId = conversationId;
    _channel = Supabase.instance.client.channel('messages-realtime-$conversationId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: 'conversation_id=eq.$conversationId',
      callback: _handleEvent,
    ).subscribe();
  }
  
  void stop() {
    _listenerCount--;
    if (_listenerCount <= 0) {
      _listenerCount = 0;
      if (_channel != null) {
        Supabase.instance.client.removeChannel(_channel!);
        _channel = null;
        _lastConversationId = null;
      }
    }
  }
  
  void dispose() {
    _controller.close();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _listenerCount = 0;
    _lastConversationId = null;
  }
}
```

### Design Properties
- Single channel per active conversation
- Filtered by `conversation_id` at the PostgREST level
- Reference counted (multiple listeners share one channel)
- Clean subscribe/unsubscribe lifecycle tied to `ConversationScreen`

---

## 15. Exact Implementation Sequence

### Step 1: Create `chat_dtos.dart`
- Define `ChatConversation`, `ChatMessage`, `ChatMessageEvent`, `ChatEventType`
- Add mapping helpers from Supabase rows to DTOs

### Step 2: Create `realtime_messages_service.dart`
- Implement singleton with reference counting
- `start(conversationId)` creates filtered channel
- `stop()` removes channel when count reaches 0
- Stream emits `ChatMessageEvent` for INSERT/UPDATE/DELETE

### Step 3: Create new `chat_repository.dart`
- Replace `LocalChatRepository` with `ChatRepository`
- Implement:
  - `getOrCreateConnectionConversation(String connectionId)` → calls RPC
  - `loadMessages(String conversationId)` → queries `public.messages` with soft-delete filter
  - `sendMessage(String conversationId, String content)` → INSERT into `public.messages`
  - `updateLastReadAt(String conversationId)` → UPDATE `conversation_members`
  - `subscribeToMessages(String conversationId)` → delegates to `RealtimeMessagesService`
- All methods return `ChatResult<T>` (same pattern as `ConnectionResult<T>`)

### Step 4: Modify `connections_screen.dart`
- In `_openConversation()`:
  - Check if `_connectionModels.containsKey(c.id)` → connection chat
  - If connection chat: call `ChatRepository.getOrCreateConnectionConversation(c.id)`, create real `ConversationPreview`, navigate with `chatRepository` parameter
  - If plan chat: preserve existing behavior
- Update `conversationRoute` call to pass `chatRepository` for connection conversations
- Add realtime subscription in `initState` if needed for inbox preview updates (deferred — not strictly required for Phase 9.5.2)

### Step 5: Modify `conversation_screen.dart`
- Add `ChatRepository? chatRepository` parameter
- In `_load()`:
  - If `chatRepository != null` and `conversation.type == private`:
    - Call `chatRepository.loadMessages(conversation.id)`
    - Call `chatRepository.updateLastReadAt(conversation.id)`
  - Else:
    - Preserve existing `LocalChatRepository` path (Plans)
- In `initState()` / `dispose()`:
  - Start/stop `RealtimeMessagesService` when using real chat
- In `MessageComposer`:
  - Wire send action to `chatRepository.sendMessage()` when real chat is active

### Step 6: Modify `conversation_widgets.dart`
- Wire `MessageComposer` send callback
- Add error state for send failures
- Show sending indicator

### Step 7: Modify `home_connection_dashboard.dart`
- Update "Open Room" button in `NetworkConnectionCard`:
  - Call `ChatRepository.getOrCreateConnectionConversation(connection.connectionId)`
  - Navigate to `ConversationScreen` with real repository

### Step 8: Apply Supabase migration
- Create `supabase/migrations/20260822000000_create_connection_chat_rpc.sql`
- Contains `get_or_create_connection_conversation` RPC function
- Grant EXECUTE to authenticated

### Step 9: Verify
- `flutter analyze` — no new issues
- Manual testing matrix (see below)
- Database verification

---

## 16. Manual Testing Matrix

| Test | Expected Result |
|------|-----------------|
| Open accepted connection → ConversationScreen | Real conversation created, real messages load |
| Open same accepted connection again | Same conversation reused (deterministic UUID) |
| Open different accepted connection | Different conversation created |
| Send text message | Message appears in UI, saved to database |
| Receive message (second user) | Message appears via realtime |
| Open conversation with no messages | Empty thread state shown |
| Message send failure | SnackBar error, message stays in composer |
| Plans tab → tap plan conversation | Demo data, unchanged behavior |
| Network connection → Open Room | Real conversation opens |
| Pull-to-refresh in inbox | Reloads connections from Supabase |
| Auth logout → login as different user | Sees only own conversations/messages |

---

## 17. Security Verification

| Threat | Prevention |
|--------|------------|
| User A reads User B's private conversation | RLS: `messages` SELECT requires membership EXISTS check |
| User A inserts message as User B | RLS: `messages` INSERT WITH CHECK `auth.uid() = sender_id` |
| User A inserts into unrelated conversation | RLS: `messages` INSERT WITH CHECK membership EXISTS |
| User A impersonates User B | Database enforces `auth.uid() = sender_id`, client cannot override |
| User A modifies User B's membership | RLS: `conversation_members` UPDATE/DELETE `auth.uid() = user_id` |
| User A modifies User B's message | RLS: `messages` UPDATE `auth.uid() = sender_id` |
| User A creates conversation with non-connected user | RPC validates `status = 'accepted'` before creating |
| User A creates duplicate conversations | Deterministic UUID + `ON CONFLICT DO NOTHING` |

---

## 18. Flutter Verification

- `flutter analyze` — must pass with no new errors/warnings
- No new dependencies added
- No existing UI behavior broken

---

## 19. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Deterministic UUID collision | Negligible | Low | `md5(...)::uuid` has 2^122 space; collision probability is astronomically low |
| RPC function not found by Flutter | Low | Medium | Test RPC call from Flutter during implementation; grant EXECUTE to authenticated |
| Realtime filter syntax mismatch | Low | Medium | Verify Supabase Flutter SDK filter format during implementation |
| `conversation_members` table growth | Low | Low | CASCADE delete cleans up when conversations/users are removed |
| Message soft-delete edge cases | Low | Low | `deleted_at IS NULL` filter in all message queries |

---

## 20. Explicit Scope Boundary

### IN SCOPE for Phase 9.5.2
- Real connection conversation creation via RPC
- Real message loading from `public.messages`
- Real text message sending
- Real-time message updates via Supabase Realtime
- `last_read_at` updates
- Wiring `ConversationScreen` to real data for connection conversations
- "Open Room" navigation from Connections Dashboard

### OUT OF SCOPE for Phase 9.5.2
- Plan chat backend (Plans remains demo)
- Image/voice/call messages
- Typing indicators
- Active status / last seen
- Read receipts UI (unread counts in inbox)
- Notifications / push notifications
- Message deletion UI
- Message editing
- Message forwarding
- Blocking / reporting
- Premium restrictions
- Conversation creation from client-side (RPC only)
- Connection acceptance hooks (conversation not auto-created on accept)

---

## PHASE 9.5.2 PLAN COMPLETE
## NO IMPLEMENTATION PERFORMED
## STOP
