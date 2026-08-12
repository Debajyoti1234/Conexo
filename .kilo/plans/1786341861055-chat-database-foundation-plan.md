# Phase 9.5.1 — Production Chat Database Foundation & RLS: Implementation Plan

## 1. Current Inspected State

### Existing Supabase Tables
- `profiles` — user profiles with public/private fields
- `live_locations` — GPS coordinates per user
- `connections` — connection requests with state machine (pending/accepted/rejected/cancelled)

### Existing Migrations
- `20260809000000_create_profiles_table.sql`
- `20260811000000_create_live_locations_table.sql`
- `20260812000000_add_discovery_prerequisites.sql`
- `20260813000000_harden_dob_requirement.sql`
- `20260814000000_enforce_minimum_age.sql`
- `20260815000000_add_discovery_fields.sql`
- `20260817000000_create_connections_table.sql`
- `20260818000000_harden_connections_rls.sql`
- `20260819000000_fix_connections_update_rls.sql`
- `20260820000000_enable_connections_realtime.sql`

### Existing Realtime
- `supabase_realtime` publication includes `public.connections` only
- `RealtimeConnectionsService` in Flutter subscribes to connection changes
- No message/conversation realtime exists

### Migration History Status
- Both `20260818000000` and `20260819000000` are recorded in `supabase_migrations.schema_migrations`
- `20260820000000` is also recorded
- Fresh checkouts can run `supabase migration up` safely

## 2. Existing Chat Architecture

### REAL (Supabase-backed)
- **Connection CRUD**: `ConnectionRepository` → `public.connections` table
- **Connection list loading**: `ConnectionsViewModel.loadAcceptedConnections()`, `loadIncomingRequests()`, `loadOutgoingRequests()`
- **Profile enrichment**: `_fetchProfiles()` queries `public.profiles`
- **Connection realtime**: `RealtimeConnectionsService` broadcasts changes to `ConnectionsInboxScreen`

### DEMO (Local/In-Memory)
- `LocalChatRepository` — all methods return static demo data after artificial delay
- `demo_chat_data.dart` — static lists of conversations, message threads, group metadata
- `ConversationScreen` — loads from `LocalChatRepository`, composer is decorative/inert
- `message_models.dart` — pure UI models, no persistence
- `chat_widgets.dart`, `conversation_widgets.dart`, `message_widgets.dart` — pure UI
- Plans tab in `ConnectionsInboxScreen` uses `LocalChatRepository.loadPlanConversations()`

### Data Flow
```
ConnectionsInboxScreen
├── Connections tab → ConnectionsViewModel → ConnectionRepository → Supabase connections + profiles → REAL
└── Plans tab → LocalChatRepository → demo_chat_data.dart → DEMO

ConversationScreen
└── LocalChatRepository → demo_chat_data.dart → DEMO
```

## 3. Database Gaps

The following tables **do not exist** and must be created:

| Table | Status |
|-------|--------|
| `conversations` | ❌ Missing |
| `conversation_members` | ❌ Missing |
| `messages` | ❌ Missing |
| `message_reads` | ❌ Missing |

## 4. Proposed Schema

### 4.1 `conversations`
```sql
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('connection', 'plan')),
  plan_id UUID NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Rationale:**
- `type` is restricted to `'connection'` or `'plan'` via CHECK constraint
- `plan_id` is nullable because connection conversations don't have a plan
- `plan_id` should eventually have a foreign key to a `plans` table (not created in this phase)
- `updated_at` tracks last message time for ordering

### 4.2 `conversation_members`
```sql
CREATE TABLE public.conversation_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_read_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);
```

**Rationale:**
- Composite unique constraint prevents duplicate membership
- Foreign keys ensure referential integrity
- `last_read_at` enables unread count calculation without a separate `message_reads` table
- `joined_at` tracks when the user entered the conversation

### 4.3 `messages`
```sql
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'voice', 'image', 'call_event', 'system')),
  content TEXT NOT NULL DEFAULT '',
  media_url TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ NULL
);
```

**Rationale:**
- `type` supports future message kinds via CHECK constraint
- `content` is required but defaults to empty string for system messages
- `media_url` is nullable for text-only messages
- `deleted_at` enables soft deletion — null means active, non-null means deleted
- Foreign key to `conversations` with CASCADE delete ensures messages are removed if conversation is deleted

### 4.4 `message_reads` — NOT CREATED
**Decision:** Do NOT create `message_reads` table.

**Rationale:** `conversation_members.last_read_at` is sufficient for unread count calculation:
```sql
SELECT count(*) FROM messages
WHERE conversation_id = :cid
  AND created_at > (SELECT last_read_at FROM conversation_members WHERE conversation_id = :cid AND user_id = :uid)
  AND deleted_at IS NULL;
```

This is simpler, requires fewer writes, and aligns with the "smallest production-safe design" principle. `message_reads` can be added later if per-message read tracking becomes necessary.

## 5. RLS Design

### 5.1 `conversations`

| Policy | Command | USING | WITH CHECK |
|--------|---------|-------|------------|
| Members can read conversations | SELECT | `auth.uid() IN (SELECT user_id FROM conversation_members WHERE conversation_id = id)` | — |
| Authenticated users can create conversations | INSERT | — | `auth.uid() IN (SELECT user_id FROM conversation_members WHERE conversation_id = id)` (enforced after member insertion) |

**Note:** Conversation creation requires the creator to also be a member. This is enforced by requiring the INSERTing user to already exist in `conversation_members` for that conversation. In practice, a service/RPC will insert both atomically.

### 5.2 `conversation_members`

| Policy | Command | USING | WITH CHECK |
|--------|---------|-------|------------|
| Members can read membership | SELECT | `auth.uid() = user_id` | — |
| Users can insert themselves | INSERT | — | `auth.uid() = user_id` |
| Users can update own last_read_at | UPDATE | `auth.uid() = user_id` | `auth.uid() = user_id` |
| Users can remove themselves | DELETE | `auth.uid() = user_id` | — |

**Rationale:** Users control their own membership record only. They cannot add/remove other users. `last_read_at` updates are user-initiated.

### 5.3 `messages`

| Policy | Command | USING | WITH CHECK |
|--------|---------|-------|------------|
| Members can read messages | SELECT | `auth.uid() IN (SELECT user_id FROM conversation_members WHERE conversation_id = conversation_id)` | — |
| Members can insert messages | INSERT | — | `auth.uid() = sender_id AND auth.uid() IN (SELECT user_id FROM conversation_members WHERE conversation_id = conversation_id)` |
| Senders can update own messages | UPDATE | `auth.uid() = sender_id` | `auth.uid() = sender_id` |
| Senders can soft-delete own messages | UPDATE | `auth.uid() = sender_id` | `auth.uid() = sender_id` (deleted_at only) |

**Critical security rules enforced:**
1. A user can only read messages in conversations they belong to
2. A user can only insert messages as themselves (`auth.uid() = sender_id`)
3. A user can only insert messages into conversations they belong to
4. A user can only update/delete their own messages

### 5.4 `message_reads` — NOT CREATED
No policies needed.

## 6. Realtime Recommendation

### Tables to Add to `supabase_realtime`
| Table | Reason |
|-------|--------|
| `messages` | New messages must appear instantly in conversation UI |
| `conversation_members` | Membership changes affect access |
| `conversations` | Conversation metadata changes (e.g., plan updates) |

### Tables NOT to Add
| Table | Reason |
|-------|--------|
| `message_reads` | Table not created |
| `profiles` | Already handled separately if needed |
| `connections` | Already in publication |

**Minimum viable realtime for Phase 9.5.2+:** Only `messages` is strictly required for chat UI. `conversation_members` and `conversations` can be added later if needed.

## 7. Indexes and Constraints

### `conversations`
```sql
CREATE INDEX idx_conversations_type ON public.conversations(type);
CREATE INDEX idx_conversations_plan_id ON public.conversations(plan_id) WHERE plan_id IS NOT NULL;
```

### `conversation_members`
```sql
CREATE INDEX idx_conversation_members_conversation_id ON public.conversation_members(conversation_id);
CREATE INDEX idx_conversation_members_user_id ON public.conversation_members(user_id);
```

### `messages`
```sql
CREATE INDEX idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX idx_messages_conversation_created_at ON public.messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX idx_messages_deleted_at ON public.messages(deleted_at) WHERE deleted_at IS NULL;
```

**Rationale:**
- Messages are queried by `conversation_id` ordered by `created_at DESC` — composite index covers this
- `deleted_at` partial index ensures soft-deleted messages are excluded from default queries
- Member lookups by `conversation_id` and `user_id` are frequent for RLS checks

## 8. Migration Strategy

### Migration File
```
supabase/migrations/20260821000000_create_chat_foundation.sql
```

### Safety Considerations
- This migration only creates new tables — no modifications to existing tables
- All existing migrations remain untouched
- The new migration will be recorded in `supabase_migrations.schema_migrations` on first run
- Fresh checkouts will apply all 11 migrations in order without conflicts

### Migration Contents
1. CREATE TABLE `conversations`
2. CREATE TABLE `conversation_members`
3. CREATE TABLE `messages`
4. ALTER TABLE ... ENABLE ROW LEVEL SECURITY on all three tables
5. CREATE INDEX on all three tables
6. CREATE RLS policies for all three tables
7. ALTER PUBLICATION supabase_realtime ADD TABLE public.messages
8. ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_members
9. ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations

## 9. Files to Create

| File | Purpose |
|------|---------|
| `supabase/migrations/20260821000000_create_chat_foundation.sql` | Database schema, indexes, RLS, realtime |
| `lib/features/chat/chat_models.dart` | Add real chat models (Conversation, Message, etc.) if needed by later phases — **defer to 9.5.2** |
| `lib/features/chat/chat_repository.dart` | Add real chat repository methods — **defer to 9.5.2** |

**Note:** Phase 9.5.1 should be database-only. Flutter model/repository changes belong to Phase 9.5.2.

## 10. Files to Modify

| File | Change |
|------|--------|
| None | Phase 9.5.1 is database-only |

**Rationale:** The existing Flutter code uses `LocalChatRepository` for demo data. Real chat UI, models, and repositories are Phase 9.5.2+. No Flutter changes are required for the database foundation.

## 11. Files to Leave Unchanged

| File | Reason |
|------|--------|
| `lib/features/chat/chat_models.dart` | Demo models — will be replaced in 9.5.2 |
| `lib/features/chat/chat_repository.dart` | Demo repository — will be replaced in 9.5.2 |
| `lib/features/chat/connections_screen.dart` | UI only — will be wired to real data in 9.5.2 |
| `lib/features/chat/conversation_screen.dart` | Demo UI — will be updated in 9.5.2 |
| `lib/features/chat/chat_widgets.dart` | UI primitives — no changes needed |
| `lib/features/chat/conversation_widgets.dart` | UI primitives — no changes needed |
| `lib/features/chat/message_widgets.dart` | UI primitives — no changes needed |
| `lib/features/chat/chat_sections.dart` | Layout only — no changes needed |
| `lib/features/chat/demo_chat_data.dart` | Demo data — will be removed in 9.5.2 |
| `lib/features/profile/connection_repository.dart` | No changes needed |
| `lib/features/profile/connections_view_model.dart` | No changes needed |
| `lib/features/profile/realtime_connections_service.dart` | No changes needed |
| `supabase/migrations/20260818000000_harden_connections_rls.sql` | Locked |
| `supabase/migrations/20260819000000_fix_connections_update_rls.sql` | Locked |
| `supabase/migrations/20260820000000_enable_connections_realtime.sql` | Locked |

## 12. Security Verification

### How the Database Prevents Each Threat

| Threat | Prevention Mechanism |
|--------|---------------------|
| **User A reads User B's messages** | RLS: `messages` SELECT requires membership in `conversation_members`. User A is not a member of User B's private conversation, so query returns empty. |
| **User A inserts into User B's conversation** | RLS: `messages` INSERT requires `auth.uid() = sender_id` AND membership check. Even if User A knows the conversation ID, they cannot insert as User B (sender impersonation blocked) and cannot insert as themselves (membership check fails). |
| **User A impersonates User B** | RLS: `messages` INSERT/UPDATE WITH CHECK requires `auth.uid() = sender_id`. The database uses the authenticated user ID, not a client-provided value. |
| **User A modifies another user's membership** | RLS: `conversation_members` UPDATE/DELETE requires `auth.uid() = user_id`. User A can only modify their own membership row. |
| **User A deletes another user's messages** | RLS: `messages` UPDATE requires `auth.uid() = sender_id`. Only the message author can soft-delete their own messages. |
| **User A modifies conversation ownership/metadata** | RLS: `conversations` has no UPDATE policy in Phase 9.5.1. Conversations are immutable at the database level until a future phase adds controlled update mechanisms (e.g., RPC). |
| **User A accesses read state for unrelated conversations** | RLS: `conversation_members` SELECT requires `auth.uid() = user_id`. A user can only see their own membership rows, which include `last_read_at`. |

### Enforcement Layers

| Layer | Purpose |
|-------|---------|
| **Foreign Keys** | Ensure `conversation_id` references valid conversations, `sender_id` references valid users, `user_id` references valid users |
| **CHECK Constraints** | Enforce valid `type` values on conversations and messages |
| **UNIQUE Constraints** | Prevent duplicate memberships (`conversation_id, user_id`) |
| **RLS Policies** | Enforce user-level access control at the database level |
| **ON DELETE CASCADE** | Ensure orphaned data is cleaned up when conversations or users are deleted |

**No triggers required for Phase 9.5.1.** The RLS policies and constraints are sufficient. Triggers can be added later if business logic requires it (e.g., automatic `updated_at` on conversations when new messages arrive).

## 13. Flutter Verification

### Required
- `flutter analyze` — must pass with no new errors/warnings

### Not Required
- `flutter build apk --release` — Phase 9.5.1 is database-only, no Flutter code changes

### Future Flutter Work (Phase 9.5.2+)
- Add real chat models to `chat_models.dart`
- Create `ChatRepository` with Supabase-backed methods
- Wire `ConversationScreen` to real data
- Implement message sending/receiving UI
- Add realtime subscription for new messages

## 14. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| **Soft deletion confusion** | Medium | Medium | Document that `deleted_at IS NULL` is the canonical "active" filter. All queries must include this filter. |
| **last_read_at race conditions** | Low | Low | Multiple concurrent updates to `last_read_at` are harmless — the latest value wins. |
| **Conversation creation without membership** | Low | Medium | RLS INSERT policy requires membership. Service layer must insert member row first or use RPC for atomic creation. |
| **Realtime volume** | Low | Low | Messages are small payloads. Realtime is only active when screens are mounted. |
| **Migration ordering** | Low | High | Migration timestamp `20260821000000` is after all existing migrations. No conflicts. |

## 15. Exact Implementation Sequence

1. **Create migration file** `supabase/migrations/20260821000000_create_chat_foundation.sql`
   - Create `conversations` table with CHECK constraint on `type`
   - Create `conversation_members` table with UNIQUE constraint and foreign keys
   - Create `messages` table with CHECK constraint on `type` and soft deletion via `deleted_at`
   - Enable RLS on all three tables
   - Create indexes on all three tables
   - Create RLS policies for all three tables
   - Add all three tables to `supabase_realtime` publication

2. **Apply migration to remote database**
   - Run `npx supabase migration up --linked`
   - Verify tables exist with `\dt public.conversations` etc.
   - Verify indexes exist
   - Verify RLS policies exist
   - Verify realtime publication includes new tables

3. **Record migration in schema_migrations** (if CLI doesn't do it automatically)

4. **Run flutter analyze** — verify no new issues

5. **Stop** — do not implement Phase 9.5.2

## 16. Explicit Scope Boundary

### IN SCOPE for Phase 9.5.1
- Creating `conversations`, `conversation_members`, `messages` tables
- Enabling RLS on all three tables with production-safe policies
- Creating indexes for query performance
- Adding tables to `supabase_realtime` publication
- Database-level security enforcement

### OUT OF SCOPE for Phase 9.5.1
- Automatic conversation creation on connection acceptance
- Connection → conversation hooks/triggers
- Plan → conversation hooks/triggers
- Flutter model changes
- Flutter repository changes
- Flutter UI changes
- Message sending/receiving UI
- Message realtime UI
- Image/voice/call message types
- Read receipts implementation
- Typing indicators
- Active status / last seen
- Notifications / push notifications
- Plan backend migration
- Plan chat backend migration
- Conversation deletion logic
- Moderation / blocking
- Premium entitlements

---

## PHASE 9.5.1 PLAN COMPLETE
## NO IMPLEMENTATION PERFORMED
## STOP
