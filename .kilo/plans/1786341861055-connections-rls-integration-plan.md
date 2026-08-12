# Phase 9.4.6 — Production Connections Integration & RLS Hardening: Implementation Plan

## 1. Current State (from inspection)

### Screens & Data Flow
- **Connections tab** → `ConnectionsDashboard` (home_connection_dashboard.dart) — uses local demo lists: `demoNetwork`, `demoRequests`, `demoPending`, `demoHostedPlans`
- **Chats tab** → `ConnectionsInboxScreen` (connections_screen.dart) — uses `LocalChatRepository` → `demoConversations` (hardcoded)
- **People tab** → `HomeScreen` (home_screen.dart) — already wired to `ConnectionRepository` for Connect button

### Existing Repository
- `ConnectionRepository` (lib/features/profile/connection_repository.dart) — fully functional, all CRUD methods exist:
  - `sendRequest`, `acceptRequest`, `rejectRequest`, `cancelRequest`
  - `getConnectionBetween`, `getMyConnections`, `getIncomingRequests`, `getOutgoingRequests`

### Existing Data Models
- `Connection` (connection_data.dart) — id, requesterId, recipientId, status, createdAt, updatedAt
- `ConnectionStatus` — pending, accepted, rejected, cancelled
- `ConnectionDirection` — sent, received
- `ConversationPreview` (chat_models.dart) — used by ConnectionsInboxScreen

### Current RLS Policies (insecure)
| Policy | Command | Rule |
|--------|---------|------|
| Users can view own connections | SELECT | auth.uid() = requester_id OR auth.uid() = recipient_id |
| Users can send connection requests | INSERT | auth.uid() = requester_id |
| Users can update own connections | UPDATE | auth.uid() = requester_id OR auth.uid() = recipient_id **← TOO BROAD** |
| Users can delete own requests | DELETE | auth.uid() = requester_id |

### Security Issues Found
1. **Broad UPDATE policy**: Either party can update ANY column, allowing:
   - Requester to change `pending → accepted` (should be recipient-only)
   - Recipient to change `accepted → pending` (should be immutable)
   - Either party to change `requester_id` or `recipient_id` (should be immutable)
2. **No state transition enforcement**: Database allows arbitrary status changes
3. **No column-level immutability**: `requester_id`, `recipient_id`, `created_at` can be modified post-creation

## 2. Plan

### Step 1: Create RLS Hardening Migration
**File**: `supabase/migrations/20260818000000_harden_connections_rls.sql`

Actions:
1. Drop the broad `Users can update own connections` policy
2. Add narrow UPDATE policies (defense-in-depth row filtering):
   - `Requester can cancel own pending request` — ALLOW UPDATE WHERE `auth.uid() = requester_id AND status = 'pending'`
   - `Recipient can accept/reject pending requests` — ALLOW UPDATE WHERE `auth.uid() = recipient_id AND status = 'pending'`
3. Create a trigger function `enforce_connection_transitions()` as the final enforcement layer:
   - Checks `NEW.requester_id = OLD.requester_id` and `NEW.recipient_id = OLD.recipient_id` (immutable IDs)
   - Checks `NEW.created_at = OLD.created_at` (immutable creation timestamp)
   - Validates state transitions:
     - `pending → cancelled` — only if `auth.uid() = requester_id`
     - `pending → accepted` — only if `auth.uid() = recipient_id`
     - `pending → rejected` — only if `auth.uid() = recipient_id`
     - All other transitions → raise exception
4. Create trigger `trg_enforce_connection_transitions` on `connections` BEFORE UPDATE
5. Keep SELECT, INSERT, DELETE policies unchanged

This provides defense-in-depth: RLS policies filter which rows a user can attempt to update; the trigger validates the specific allowed transitions and enforces immutability regardless of which UPDATE path was used.

### Step 2: Create Connections View Model
**File**: `lib/features/profile/connections_view_model.dart`

Purpose: Bridge `Connection` + user profile data to UI models used by both `ConnectionsDashboard` and `ConnectionsInboxScreen`.

Components:
- `ConnectionUiModel` — unified model with:
  - `connectionId`, `otherUserId`, `otherUserName`, `otherUserAge`, `otherUserOccupation`, `otherUserCity`
  - `otherUserPortrait`, `otherUserColor`, `mutualInterests`
  - `status`, `direction`, `createdAt`, `updatedAt`
- `ConnectionsViewModel` class with methods:
  - `loadAcceptedConnections()` → `Future<List<ConnectionUiModel>>` (for Network section)
  - `loadIncomingRequests()` → `Future<List<ConnectionUiModel>>` (for Requests section)
  - `loadOutgoingRequests()` → `Future<List<ConnectionUiModel>>` (for Pending section)
  - `acceptRequest(String connectionId)` → `Future<ConnectionResult<void>>`
  - `rejectRequest(String connectionId)` → `Future<ConnectionResult<void>>`
  - `cancelRequest(String connectionId)` → `Future<ConnectionResult<void>>`
  - `refresh()` — reloads all data

Profile fetching: Query `profiles` table by `otherUserId` for display fields. If profile is missing, use graceful fallback (name from auth metadata or "Unknown").

### Step 3: Update ConnectionsDashboard (home_connection_dashboard.dart)
Replace local demo data with `ConnectionsViewModel`.

Changes:
- Remove `List<NetworkConnection> _network = List.of(demoNetwork)` etc.
- Add `final _viewModel = ConnectionsViewModel()` and state: `_loading`, `_error`
- `_load()` calls `_viewModel.loadAcceptedConnections()`, `loadIncomingRequests()`, `loadOutgoingRequests()`
- Map `ConnectionUiModel` → `NetworkConnection`, `IncomingRequest`, `PendingRequest` for existing card widgets
- Wire `_acceptRequest`, `_declineRequest`, `_cancelPending` to `_viewModel` real methods
- After successful mutation: call `_load()` to refresh
- Add `RefreshIndicator` wrapping the ListView
- Keep `Hosted Plans` section as demo (not connections)
- Keep `_openConnectionRoom` using `LocalChatRepository.findConversationForConnection` (demo chat data stays local)

### Step 4: Update ConnectionsInboxScreen (connections_screen.dart)
Replace `LocalChatRepository` for Connections tab with `ConnectionsViewModel`.

Changes:
- Replace `_repository = const LocalChatRepository()` with `_viewModel = ConnectionsViewModel()`
- For Connections tab (index 0):
  - Load from `_viewModel.loadAcceptedConnections()`
  - Map `ConnectionUiModel` → `ConversationPreview`
  - Accept/decline/cancel actions wired to `_viewModel`
- For Plans tab (index 1): Keep `LocalChatRepository` (demo data is fine for now)
- Add `RefreshIndicator` wrapping the ListView
- After mutation: refresh Connections tab data

Mapping `ConnectionUiModel` → `ConversationPreview`:
- `id`: connection.id
- `name`: otherUserName
- `avatarAsset`: otherUserPortrait (empty string if none)
- `lastMessage`: 'Connected' or formatted timestamp
- `timestamp`: relative time from `updatedAt`
- `type`: ConversationType.private
- `status`: ConversationStatus.recentlyConnected
- `lastMessageType`: LastMessageType.connectionAccepted
- `isVerified`: from profile verification status

### Step 5: Keep LocalChatRepository Boundary Clear
- `LocalChatRepository` remains for demo chat/message/conversation data
- It is used ONLY by:
  - `ConnectionsInboxScreen` Plans tab
  - `ConversationScreen` (demo message threads)
  - `ConnectionsDashboard._openConnectionRoom` (demo conversation lookup)
- It is NOT used for connection relationship state
- Connection relationships come exclusively from `ConnectionRepository`

### Step 6: Wire Profile Navigation
- Tapping a connection in either screen opens `PublicProfileScreen` via `premiumPublicProfileRoute()`
- Reuse existing `mapNetworkConnectionToProfile` or create new mapper for `ConnectionUiModel`
- Add `mapConnectionToProfile(ConnectionUiModel model)` to `profile_navigation_mapper.dart`

### Step 7: Handle Error/Loading/Empty States
- Loading: Show existing `LoadingSkeleton`
- Empty: Show existing `EmptyInbox` (Connections tab) or `_EmptyState` (Dashboard sections)
- Error: Show existing premium error/retry pattern (or add simple retry button)
- After mutation failure: Do NOT update local state; show error; user can retry

### Step 8: Apply Migration & Verify
- Apply migration to linked Supabase project
- Verify RLS policies, trigger, constraints remotely
- Run `flutter analyze`
- Build `flutter build apk --release`

## 3. Files to Create
1. `supabase/migrations/20260818000000_harden_connections_rls.sql`
2. `lib/features/profile/connections_view_model.dart`

## 4. Files to Modify
1. `lib/features/home_connection_dashboard.dart`
2. `lib/features/chat/connections_screen.dart`
3. `lib/features/profile/profile_navigation_mapper.dart`

## 5. Files to Leave Unchanged
- `lib/features/chat/chat_repository.dart` (LocalChatRepository stays)
- `lib/features/chat/chat_models.dart` (ConversationPreview stays)
- `lib/features/chat/chat_widgets.dart` (premium UI stays)
- `lib/features/profile/connection_repository.dart` (already correct)
- `lib/features/profile/connection_data.dart` (already correct)
- Demo data files (home_connection_dashboard_data.dart, demo_chat_data.dart)

## 6. Security Validation Plan

After implementation, verify:
1. **RLS policies**: `SELECT`, `INSERT`, `DELETE` unchanged; broad `UPDATE` replaced by two narrow policies:
   - Requester can update only their own `pending` rows
   - Recipient can update only their incoming `pending` rows
2. **Trigger**: Final enforcement layer — tests each allowed transition and rejects forbidden ones
3. **Self-connection**: Still blocked by `connections_no_self` CHECK constraint
4. **Duplicate protection**: `idx_connections_unique_pair` unique index still active
5. **Unauthorized read**: User C cannot read A/B's connection
6. **Unauthorized mutation**: User C cannot modify A/B's connection (blocked by both RLS and trigger)
7. **Requester cannot accept own request**: Fails (RLS blocks; trigger additionally checks `auth.uid() = recipient_id`)
8. **Recipient cannot impersonate requester**: Fails (RLS blocks; trigger additionally checks `auth.uid() = requester_id` for cancel)
9. **ID immutability**: Trigger blocks changes to `requester_id`, `recipient_id`, `created_at` even if RLS row filter were bypassed

## 7. Open Questions (None — implementation-ready)

All key decisions are resolved:
- RLS hardening via trigger (smallest, safest design)
- Reuse existing ConnectionRepository
- Create one new view model (connections_view_model.dart)
- Keep LocalChatRepository for demo chat data only
- ConnectionsDashboard and ConnectionsInboxScreen both wired to real data
- Profile navigation reuses existing PublicProfileScreen
