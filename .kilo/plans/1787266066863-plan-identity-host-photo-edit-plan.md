# P1.2B.8.3 — Plan Identity, Profile Data & Hosted-Plan Management

## Goal
Fix Plan identity/profile presentation, move request management to Connections → Hosted Plans, and implement Edit Plan.

## Implementation Checklist

### 1. Fix `getPublishedExperiences` cover signed URL
**File:** `lib/features/plans/supabase_plan_repository.dart`
**Change:** Add `getCoverSignedUrls` call and pass `signedUrls[i]` instead of `null`.

### 2. Fix generic "Host" fallback
**File:** `lib/features/plans/supabase_plan_repository.dart`
**Change:** In `_planToExperience`, replace `'Host'` fallback with `'User ${plan.hostId.substring(0, 8)}'`.

### 3. Fix pending-requester label fallback
**File:** `lib/features/plans/plan_details_screen.dart`
**Change:** Remove ellipsis from `'User ${membership.userId.substring(0, 8)}...'`.

### 4. Remove Plan Detail approve/decline UI
**Files:** `lib/features/plans/plan_details_screen.dart`
**Change:** Remove `_loadPendingRequests`, `_approve`, `_decline`, `_PendingRequestsSection`, `_PendingRequestTile`. Keep `PlanJoinController` approve/decline for Connections reuse.

### 5. Fix Connections → Hosted Plans
**Files:** `lib/features/home_connection_dashboard.dart`, `lib/features/home_connection_dashboard_data.dart`
**Change:** Replace `demoHostedPlans` with real `SupabasePlanRepository.getPublishedExperiences()`. Wire approve/decline to real RPCs. Load real join requests and participants from `plan_members`.

### 6. Implement Edit Plan
**Files:** `lib/features/plans/plan_repository.dart`, `lib/features/plans/supabase_plan_repository.dart`, `lib/features/plans/create_plan_screen.dart`, `lib/features/plans/my_plans_screen.dart`, `lib/features/plans/create_plan_data.dart`
**Change:** Add `updatePublished` to repository, add edit mode to `CreatePlanScreen`, wire Edit button.

### 7. Fix own Plan Detail context
**File:** `lib/features/plans/plan_details_sections.dart`
**Change:** Add conditional management card for own plans vs social host card for others.

---

## Validation
1. `flutter analyze` — 0 errors
2. `.\tool\build_apk.ps1` — success
3. Manual validation with two real users

---

**Ready to execute?** Switch to an implementation-capable agent to apply the source-code changes above.
