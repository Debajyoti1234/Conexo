# Conexo Connection Tab UI Refinement — Implementation Plan

## Goal
Transform the Connection tab from an expandable-section dashboard into a premium navigation dashboard with 4 glass cards that navigate to dedicated pages, plus an integrated scrollable Activity feed. Preserve every existing backend, notification architecture, and data source.

## Current Architecture Summary

| Component | Location | Role |
|-----------|----------|------|
| `ConnectionsScreen` | `lib/features/secondary_screens.dart:70` | Shell entry, wraps `ConnectionsDashboard` in `_ScreenFrame` |
| `ConnectionsDashboard` | `lib/features/home_connection_dashboard.dart` | Single stateful widget with 4 expandable sections + summary grid |
| `_ExpandableSection` | `home_connection_dashboard.dart:1156` | Expandable shell with `AnimatedSize` + chevron |
| `_SummaryCard` | `home_connection_dashboard.dart:1042` | 2×2 grid cards, currently `onTap` → `_scrollToSection` |
| `NetworkConnectionCard` | `home_connection_dashboard_cards.dart:200` | Full glass card for accepted connection |
| `IncomingRequestCard` | `home_connection_dashboard_cards.dart:391` | Full glass card for incoming request |
| `PendingRequestCard` | `home_connection_dashboard_cards.dart:515` | Full glass card for pending request |
| `Hosted plan card` | `home_connection_dashboard.dart:769` | Independently expandable plan container |
| `NotificationController` | `lib/features/notifications/notification_controller.dart` | Owned by `MainShellState`, exposes `notifications`, `hasUnread`, `pulseTrigger`, `markAllRead()` |
| `ActivityCenterScreen` | `lib/features/notifications/activity_center_screen.dart` | Standalone full-page activity feed with grouping |
| Notification bell | `lib/features/main_shell.dart:101` | Positioned bell icon, shown only when `_selectedIndex == 2` |
| `NotificationNavigation` | `lib/features/notifications/notification_navigation.dart` | Centralized routing for all notification types |
| `AppRouter` | `lib/app/router/app_router.dart` | Only has `slideRoute` and `premiumProfileRoute` |
| `ConnectionsViewModel` | `lib/features/profile/connections_view_model.dart` | Stateless wrapper around `ConnectionRepository` |
| `SupabasePlanRepository` | `lib/features/plans/supabase_plan_repository.dart` | Plan data + member management |

## Constraints
- **NO backend changes** — no migrations, no schema changes, no RLS changes
- **NO new database tables**
- **NO notification architecture changes** — reuse `NotificationController`, `NotificationRepository`, Supabase Realtime
- **NO new icon packages** — use existing Material icons only
- **Reuse existing repositories** — `ConnectionRepository`, `SupabasePlanRepository`, `NotificationRepository`
- Preserve all existing mutation logic: accept/decline/cancel/remove/approve
- Preserve `NotificationNavigation.open()` routing exactly
- Preserve `ActivityCenterScreen` standalone behavior (existing bell still works when on other tabs)
- `flutter analyze` + APK build must pass

## File Changes

### New Files (4)

| File | Purpose |
|------|---------|
| `lib/features/connections/network_page.dart` | Dedicated Network page — list of accepted connections with Message/Remove actions |
| `lib/features/connections/requests_page.dart` | Dedicated Requests page — incoming requests with Accept/Decline |
| `lib/features/connections/pending_page.dart` | Dedicated Pending page — outgoing requests with Cancel |
| `lib/features/connections/hosted_plans_page.dart` | Dedicated Hosted Plans page — hosted plans list with Open Plan |

Each page:
- Is a `StatelessWidget` that accepts data lists + action callbacks via constructor
- Loads its own data independently using existing `ConnectionsViewModel` / `SupabasePlanRepository`
- Reuses existing card widgets (`NetworkConnectionCard`, `IncomingRequestCard`, `PendingRequestCard`) or creates compact list-row variants
- Wraps in existing `_ScreenFrame` for consistent safe-area/background
- Uses `AppRouter.slideRoute` for navigation transition
- Shows premium empty states per spec

### Modified Files (6)

#### 1. `lib/features/home_connection_dashboard.dart` — Core refactor

**Remove:**
- `_sectionExpanded` map, `_planExpanded` map, `_sectionKeys` map
- `_scrollController`, `_prefs`
- `_restorePreferences()`, `_setSectionExpanded()`, `_setPlanExpanded()`, `_scrollToSection()`
- `_buildNetworkSection()`, `_buildRequestsSection()`, `_buildPendingSection()`, `_buildHostedPlansSection()`
- `_ExpandableSection` widget class
- `_buildHostedPlanCard()` and `_buildPlanBody()` (moved to dedicated page)
- `_PlanMetaChip`, `_InlineEmpty` widgets
- `SharedPreferences` import

**Modify:**
- `ConnectionsDashboard` constructor: accept `NotificationController? notifications`
- `initState`: keep `_load()` + `RealtimeConnectionsService` subscription; remove preference restore
- `dispose`: remove `_prefs` dispose
- `_load()`: keep loading network/requests/pending for counts; keep hosted plans loading for count
- `build()`: new structure
  - Header: `Connections` (32sp, w800) + subtitle `Your network, requests & plans`
  - `_buildSummaryGrid()` — cards now navigate to dedicated pages
  - Activity section: `_ActivitySection(controller: _notifications)` with "Your Activity" header + "Mark all read" + grouped scrollable feed
- `_SummaryCard`: change `onTap` from `ValueChanged<String>` to `VoidCallback`; remove `sectionId` parameter; update icon set
- Summary card icons:
  - Network → `Icons.people_rounded`
  - Requests → `Icons.person_add_rounded`
  - Pending → `Icons.schedule_rounded`
  - Hosted Plans → `Icons.star_rounded`

**Add:**
- `_ActivitySection` widget — compact activity feed using `NotificationController`
  - Header row: "Your Activity" + `TextButton("Mark all read", onTap: controller?.markAllRead)`
  - Uses `ValueListenableBuilder` on `controller.notifications` + `controller.pulseTrigger` to rebuild only the feed
  - Groups via existing `groupNotifications()`
  - Renders compact `_ActivityCompactRow` per notification (small 28dp icon chip, title, subtitle, timestamp, subtle unread dot)
  - Tap routes via `NotificationNavigation.open()`
  - Premium empty state when no notifications
  - Subtle separator between items
- `_ActivityCompactRow` — lightweight row widget for the feed
- Route navigation methods: `_openNetwork()`, `_openRequests()`, `_openPending()`, `_openHostedPlans()` using `AppRouter.slideRoute`

#### 2. `lib/features/secondary_screens.dart` — Pass notification controller

- `ConnectionsScreen` constructor: accept `NotificationController? notifications`
- Pass to `ConnectionsDashboard(notifications: notifications)`
- Remove `const` from `ConnectionsScreen` usage

#### 3. `lib/features/main_shell.dart` — Remove bell, expose controller

- Remove the entire notification bell block (lines 99-126)
- Add `static NotificationController? get notifications => mainShellKey.currentState?._notifications;` — but `_notifications` is private in `MainShellState`. Add a public getter on `MainShellState`:
  ```dart
  NotificationController get notifications => _notifications;
  ```
- Update `_screens` list: change `const ConnectionsScreen()` to `ConnectionsScreen(notifications: _notifications)` — requires making `_screens` a getter or rebuilding it when `_notifications` is available
  - Since `_screens` is `static final` and created once, change to a non-static getter on `MainShellState` that returns the list with the injected controller
  - Or simpler: keep `_screens` static but make `ConnectionsScreen` read notifications via `MainShell.notifications` static accessor, keeping `ConnectionsScreen` const
- **Decision: Keep `ConnectionsScreen` const.** Use `MainShell.notifications` static getter. `ConnectionsDashboard` reads notifications via this accessor. This avoids touching the `IndexedStack` children list and preserves tab state.

#### 4. `lib/features/notifications/notification_widgets.dart` — Add compact row

- Add `_ActivityCompactRow` widget (or keep it in `home_connection_dashboard.dart` as a private widget)
- Decision: Keep `_ActivityCompactRow` private in `home_connection_dashboard.dart` to avoid cross-feature coupling. The Activity Center keeps its full `NotificationCard`; the Connection tab gets its own compact variant.

#### 5. `lib/app/router/app_router.dart` — Add routes

Add 4 new route helpers:
- `networkPageRoute()` → `NetworkPage`
- `requestsPageRoute()` → `RequestsPage`  
- `pendingPageRoute()` → `PendingPage`
- `hostedPlansPageRoute()` → `HostedPlansPage`

All use `PageRouteBuilder` with the existing premium fade+slide transition (200-250ms).

#### 6. `lib/features/home_connection_dashboard_cards.dart` — Minor adjustments

- No structural changes needed; existing cards (`NetworkConnectionCard`, `IncomingRequestCard`, `PendingRequestCard`) are reused as-is inside dedicated pages
- `_ActionPill` is already package-private (`_ActionPill`) — dedicated pages in `features/connections/` cannot use it. **Decision: Make `_ActionPill` public (`ActionPill`) or duplicate the small widget.** Since it's only ~30 lines and used in 3 places, make it public by removing the underscore. This is a minimal visibility change.

## Data Flow

### Dashboard counts (no behavior change)
```
MainShell init
  → _notifications.start()
  → ConnectionsDashboard._load()
    → ConnectionsViewModel.loadAcceptedConnections()
    → ConnectionsViewModel.loadIncomingRequests()
    → ConnectionsViewModel.loadOutgoingRequests()
    → widget.repository.getPublishedExperiences() + members
  → setState updates counts
  → RealtimeConnectionsService triggers _load() on changes
```

### Activity feed (new integration)
```
MainShell._notifications (singleton-like)
  → watchNotifications() → Supabase Realtime channel
  → _onRealtime() updates _notifications list + syncs hasUnread + pulseTrigger
  → ConnectionsDashboard ValueListenableBuilder rebuilds _ActivitySection
  → groupNotifications() → compact rows
  → User taps row → NotificationNavigation.open()
  → "Mark all read" → controller.markAllRead()
```

### Dedicated pages (independent loading)
```
User taps SummaryCard
  → Navigator.push(AppRouter.networkPageRoute())
    → NetworkPage loads via ConnectionsViewModel.loadAcceptedConnections()
    → Reuses NetworkConnectionCard with Message/Remove actions
    → Mutations via ConnectionRepository (same as dashboard)
```

## Empty States (per spec)

| Page | Icon | Message |
|------|------|---------|
| Network | `Icons.group_add_outlined` | "Your network is just getting started." |
| Requests | `Icons.person_add_alt_1_outlined` | "No new requests. You're all caught up." |
| Pending | `Icons.hourglass_empty_rounded` | "No pending requests." |
| Hosted Plans | `Icons.event_available_outlined` | "No hosted plans yet. Your plans will appear here." |
| Activity | `Icons.notifications_off_outlined` | "You're all caught up." |

## Animation Spec

- Page transitions: `FadeTransition` + `SlideTransition(Offset(0.08, 0) → zero)`, 200ms, `easeOutCubic`
- Activity insertion: only newly inserted row animates (via `AnimatedSwitcher` or `AnimatedOpacity` on list item)
- No bounce, no spring, no glow on activity rows
- Summary card entrance: preserve existing `EntranceFade` stagger

## Performance Plan

- Activity feed uses `ListView.builder` for long lists
- `ValueListenableBuilder` scopes rebuilds to the activity section only
- Profile photos reuse existing `ProfilePhotoResolver` cache
- No nested scroll conflicts — activity is inside the dashboard's main scroll
- No duplicate realtime listeners — single `NotificationController` owned by `MainShell`
- Dedicated pages dispose controllers in `dispose()` if they create any

## Open Questions / Decisions

**Q: Should the dedicated pages load data independently or receive it from the dashboard?**
→ **Decision: Load independently.** Pushed routes must be self-contained. Reusing the same repositories (`ConnectionsViewModel`, `SupabasePlanRepository`) satisfies "reuse existing data sources." The minor initial-load duplication is acceptable for route independence.

**Q: How does `ConnectionsDashboard` access `NotificationController`?**
→ **Decision: Static accessor via `MainShell.notifications`.** `MainShell` already exposes `switchToTab` via `mainShellKey`. Add a public getter on `MainShellState` + static accessor. This keeps `ConnectionsScreen` const and avoids rebuilding `IndexedStack` children.

**Q: Where does the compact activity row widget live?**
→ **Decision: Private widget in `home_connection_dashboard.dart`.** Keeps the Activity Center's full `NotificationCard` untouched. No cross-feature coupling.

**Q: Should the bell icon be completely removed or hidden?**
→ **Decision: Completely removed from the Connection header.** The Activity Center still exists and is accessible if needed (requirement says "do not remove the notification system itself"). The activity feed is now directly visible in the Connection tab.

**Q: What about the existing `ActivityCenterScreen` standalone page?**
→ **Decision: Preserve exactly as-is.** It can still be opened if navigation logic elsewhere calls it. The new inline feed is additive, not a replacement.

## Implementation Order

1. Add `notifications` getter to `MainShellState` + static accessor
2. Create `lib/features/connections/` directory
3. Create `network_page.dart`, `requests_page.dart`, `pending_page.dart`, `hosted_plans_page.dart`
4. Make `_ActionPill` public in `home_connection_dashboard_cards.dart`
5. Add 4 route helpers to `app_router.dart`
6. Refactor `ConnectionsDashboard`:
   - Remove expandable sections
   - Update summary cards to navigate
   - Add activity section
   - Add compact activity row
7. Update `ConnectionsScreen` to accept and pass notifications
8. Remove bell from `MainShell`
9. Run `flutter analyze`
10. Run `.\tool\build_apk.ps1`
11. Manual testing per spec

## Validation

```powershell
flutter analyze
.\tool\build_apk.ps1
```

Manual test checklist:
- [ ] Connection home: 4 glass cards visible, Activity visible, bell removed, Activity scrolls
- [ ] Network: dedicated page, connections visible, photo → Public Profile, Message → Chat, Remove → confirm flow
- [ ] Requests: Accept/Decline work
- [ ] Pending: Cancel works
- [ ] Hosted Plans: Open Plan works
- [ ] Activity: realtime updates, unread state, mark all read, routing correct
- [ ] Navigation: back from each page returns to dashboard with correct state
- [ ] Bottom nav preserved
- [ ] Web build valid
