# Phase 9.1F — Profile Final Polish + Moderation Foundation + Navigation Refinement

## 1. Current State Audit

### Already working
- `safety_reports` table + RLS (migration `20260824000000_create_safety_tables.sql`)
- `blocked_users` table + RLS
- `report-screenshots` private bucket (manual Supabase config)
- `SafetyRepository.submitReport()` — stores report, uploads screenshot, invokes Edge Function
- `notify-safety-report` Edge Function — sends email via Resend
- Block enforcement in Discovery, Connections, Chat
- Help & Support screen (FAQ + Contact Support CTA + Safety CTA)
- About Conexo screen (branding + principles + app version via `package_info_plus`)
- Profile 3-dot menu wired to all screens
- 59 tests passing (13 discovery preference + 8 safety repository + 38 existing)
- `flutter analyze`: 0 errors, 0 warnings (11 pre-existing info lints)

### Gaps identified
1. Edge Function returns 200 even when `RESEND_API_KEY` is missing, making failure non-observable
2. No moderation aggregation view for future admin dashboard
3. Profile sub-screen transitions are duplicated inline (4+ copies of identical `PageRouteBuilder`)
4. Minor UI consistency opportunities across Profile screens

---

## 2. PART 1 — Report → Support Email

### Problem
When `RESEND_API_KEY` is missing, the Edge Function returns HTTP 200 with `email_sent: false`. The Flutter client swallows the error silently. This makes email delivery failures invisible.

### Fix
**Edge Function (`supabase/functions/notify-safety-report/index.ts`):**
- When `RESEND_API_KEY` is missing: return HTTP 503 with structured JSON error + console.error with report_id
- When Resend API call fails: return HTTP 502 + console.error with status + response body
- Success: return HTTP 200 with `ok: true`, `email_sent: true`, `email_id`
- Subject format: `[Conexo Safety Report] ${report.report_type} — Report ${report.id}`
- Email body includes: report ID, reporter name/ID, reported name/ID, report type, description, created_at, screenshot reference

**Flutter client (`lib/features/profile/safety_repository.dart`):**
- Keep `try/catch` around `functions.invoke` — report success is independent of email
- Add `debugPrint` for email failure observability during development
- Do NOT surface email failure to user as a report failure

### Deploy prerequisite (document, do not implement)
- Deploy Edge Function: `supabase functions deploy notify-safety-report`
- Configure secret: `supabase secrets set RESEND_API_KEY=<key>`
- Without this, email is skipped with observable 503 log entry

---

## 3. PART 2 — Moderation Report Overview

### New migration: `supabase/migrations/20260825000000_create_safety_report_summary.sql`

```sql
CREATE OR REPLACE VIEW public.safety_report_summary AS
SELECT
  reported_user_id,
  MAX(reported_name_snapshot) AS reported_name_snapshot,
  COUNT(*) AS total_reports,
  MAX(created_at) AS latest_report_at,
  COUNT(*) FILTER (WHERE status = 'pending') AS pending_reports,
  COUNT(*) FILTER (WHERE status = 'reviewing') AS reviewed_reports,
  COUNT(*) FILTER (WHERE status = 'resolved') AS resolved_reports,
  COUNT(*) FILTER (WHERE status = 'dismissed') AS dismissed_reports,
  COUNT(*) FILTER (WHERE status = 'action_taken') AS action_taken_reports,
  COUNT(*) FILTER (WHERE report_type = 'Sexual harassment') AS sexual_harassment_count,
  COUNT(*) FILTER (WHERE report_type = 'Fake identity / impersonation') AS fake_identity_count,
  COUNT(*) FILTER (WHERE report_type = 'Spam or scam') AS spam_scam_count,
  COUNT(*) FILTER (WHERE report_type = 'Abusive behavior') AS abusive_behavior_count,
  COUNT(*) FILTER (WHERE report_type = 'Inappropriate content') AS inappropriate_content_count,
  COUNT(*) FILTER (WHERE report_type = 'Hate or discrimination') AS hate_discrimination_count,
  COUNT(*) FILTER (WHERE report_type = 'Unwanted messages') AS unwanted_messages_count,
  COUNT(*) FILTER (WHERE report_type = 'Suspicious activity') AS suspicious_activity_count,
  COUNT(*) FILTER (WHERE report_type = 'Other') AS other_count
FROM public.safety_reports
GROUP BY reported_user_id;
```

### Security
- No RLS SELECT policy for `authenticated` or `public`
- Only `service_role` / future admin role can query
- Normal users cannot access this view through the Flutter client
- No new Flutter code needed — view exists for future admin tools only

---

## 4. PART 3 — Report Data Quality

### Current schema review
- `reporter_user_id`: set from `AuthService.currentUser.id` — correct
- `reported_user_id`: validated against `profiles` table via `maybeSingle` — correct
- `reporter_user_id != reported_user_id`: enforced by CHECK constraint + Flutter guard — correct
- `report_type`: required, no default — correct
- `description`: optional, trimmed — correct
- `screenshot_path`: optional, uploaded after report insert — correct
- `status`: defaults to `pending` — correct
- `created_at`/`updated_at`: set client-side in current code

### Change required
Move `created_at` and `updated_at` to server-side defaults:
- Change migration to use `DEFAULT now()` (already present)
- Remove `created_at` and `updated_at` from Flutter insert payload so Postgres generates them
- This prevents client clock manipulation

### Flutter change
In `SafetyRepository.submitReport()`:
- Remove `'created_at': now` and `'updated_at': now` from `reportPayload`
- Postgres will generate timestamps via `DEFAULT now()`

---

## 5. PART 4 — Navigation Animation Polish

### Problem
7 Profile sub-screens each contain an identical inline `PageRouteBuilder` with copy-pasted transition code. This is inconsistent with the rest of the app which uses shared route factories.

### Fix
**Extract shared helper in `lib/app/router/app_router.dart`:**

```dart
static Route<T> premiumProfileRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 420),
  reverseTransitionDuration: const Duration(milliseconds: 320),
  pageBuilder: (context, animation, secondaryAnimation) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);
```

**Update all Profile sub-screens to use `AppRouter.premiumProfileRoute`:**
- `safety_screen.dart` — replace 4 inline `PageRouteBuilder` with `AppRouter.premiumProfileRoute`
- `help_support_screen.dart` — replace `_premiumRoute` helper with `AppRouter.premiumProfileRoute`
- Remove route factories from individual screens where they only wrap the same pattern
- Keep `premiumSafetyRoute`, `premiumHelpSupportRoute`, `premiumAboutConexoRoute` as public API but delegate to `AppRouter.premiumProfileRoute`

**Screens affected:**
- Safety (4 sub-routes)
- Help & Support (2 sub-routes)
- Contact Support (navigated from Safety)
- Report Problem (navigated from Safety)
- Blocked Users (navigated from Safety)
- Safety Tips (navigated from Safety)

---

## 6. PART 5 — Profile UI Polish

### Scope
Visual refinement only. No feature changes. No backend changes.

### Areas to polish

#### 1. Card consistency
- Standardize `GlassCard` padding to `EdgeInsets.all(18)` across all Profile screens
- Standardize card border radius to `BorderRadius.circular(18)` for tiles, `BorderRadius.circular(16)` for cards
- Standardize border color: `Colors.white.withValues(alpha: .08)` everywhere

#### 2. Vertical spacing
- Standardize section gaps: `SizedBox(height: 12)` between tiles, `SizedBox(height: 16)` between cards, `SizedBox(height: 24)` between major sections
- Remove inconsistent double-spacing

#### 3. Typography hierarchy
- Screen titles: `headlineSmall?.copyWith(fontWeight: FontWeight.w800)`
- Section headers: `fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFEAEEF9)`
- Body text: `fontSize: 14, color: Color(0xFFB9C3DC), height: 1.5`
- Subtle text: `fontSize: 12.5, color: Color(0xFFB9C3DC)`

#### 4. Icon consistency
- Tile icons: 40x40 container, `BorderRadius.circular(14)`, icon size 22
- Card icons: 40x40 container, `BorderRadius.circular(12)`, icon size 20
- Principle icons: 36x36 container, `BorderRadius.circular(10)`, icon size 18

#### 5. Button consistency
- Primary: `ConexoButton` — height 56, radius 16
- Secondary: `OutlinedButton` — consistent padding `EdgeInsets.symmetric(horizontal: 18, vertical: 14)`
- Text buttons: consistent foreground `Color(0xFF8B5CF6)`

#### 6. Empty states
- Standardize empty state pattern: icon (56px, opacity 0.35) + title (16px, w600) + subtitle (13px)
- Already consistent in BlockedUsers, SafetyTips

#### 7. Loading states
- Standardize `CircularProgressIndicator(color: Color(0xFF8B5CF6))`
- Already consistent

#### 8. Back navigation
- All screens use `Icons.arrow_back_rounded` with `IconButton` — consistent
- Remove `Stack` wrapper where `SafeArea` + `ListView` is sufficient

### Specific file changes

#### `safety_screen.dart`
- Remove 4 duplicated inline `PageRouteBuilder` → use `AppRouter.premiumProfileRoute`
- Keep `premiumSafetyRoute` as public API (delegates to `AppRouter.premiumProfileRoute`)

#### `help_support_screen.dart`
- Remove `_premiumRoute` helper → use `AppRouter.premiumProfileRoute`
- Standardize FAQ card padding/margins

#### `about_conexo_screen.dart`
- Standardize principle card spacing
- Ensure version text uses consistent muted color

#### `contact_support_screen.dart`
- Remove unnecessary `Stack` wrapper

#### `report_problem_screen.dart`
- Standardize dropdown field styling to match other inputs

#### `blocked_users_screen.dart`
- Standardize tile padding to match `_SafetyTile`

---

## 7. Files Expected to Change

### Modified files
| File | Change |
|------|--------|
| `supabase/functions/notify-safety-report/index.ts` | Fix email failure handling + subject format |
| `lib/features/profile/safety_repository.dart` | Remove client-side timestamps; add email failure logging |
| `lib/app/router/app_router.dart` | Add `premiumProfileRoute` helper |
| `lib/features/profile/safety_screen.dart` | Use shared route helper |
| `lib/features/profile/help_support_screen.dart` | Use shared route helper |
| `lib/features/profile/my_profile_screen.dart` | Update route factories to use shared helper |
| `lib/features/profile/about_conexo_screen.dart` | Minor spacing/typography polish |
| `lib/features/profile/contact_support_screen.dart` | Remove Stack wrapper |
| `lib/features/profile/report_problem_screen.dart` | Standardize input styling |
| `lib/features/profile/blocked_users_screen.dart` | Standardize tile padding |

### New files
| File | Purpose |
|------|---------|
| `supabase/migrations/20260825000000_create_safety_report_summary.sql` | Moderation aggregation view |

---

## 8. Dependencies

No new dependencies. Reuse existing:
- `url_launcher: ^6.3.0`
- `package_info_plus: ^10.2.1`
- `image_picker: ^1.1.2`
- `supabase_flutter: ^2.17.1`

---

## 9. Security

### Edge Function
- No credentials in Flutter
- `RESEND_API_KEY` remains Supabase secret
- Function returns 503 when secret missing (observable failure)
- Function returns 502 when Resend API fails (observable failure)

### Moderation view
- No RLS policy for normal users
- Only `service_role` / future admin can query
- No reporter identity exposure in view (only reported_user_id + aggregated counts)

### Report data
- `created_at`/`updated_at` now server-side (Postgres `DEFAULT now()`)
- Prevents client clock manipulation

---

## 10. Testing

### Existing tests (must pass)
- All 59 existing tests
- `safety_repository_test.dart` — model parsing, result wrappers, block invariants
- `discovery_preference_filter_test.dart` — age/distance filters
- `owner_profile_header_test.dart` — profile header states
- `verification_flow_test.dart` — verification flow
- `widget_test.dart` — app startup

### Manual verification
1. **Report flow**: Profile → Safety → Report a Problem → submit → verify report in Supabase → check Edge Function logs for email status
2. **Moderation view**: In Supabase SQL Editor, query `SELECT * FROM safety_report_summary` with service_role — verify aggregation
3. **Navigation**: Profile → 3-dot → Safety/Help/About — verify smooth transitions, back navigation
4. **Profile polish**: Review all Profile screens for consistent spacing, typography, cards

---

## 11. Validation

### Mandatory
```powershell
flutter analyze
.\tool\build_apk.ps1
```

### Runtime
```powershell
.\tool\run_prod.ps1
```
Only if authorized device available.

---

## 12. Implementation Order

1. Fix Edge Function (`notify-safety-report/index.ts`)
2. Fix Flutter timestamps (`safety_repository.dart`)
3. Create moderation view migration
4. Add `AppRouter.premiumProfileRoute`
5. Update all Profile sub-screen routes
6. Polish UI consistency in affected screens
7. Run `flutter analyze`
8. Run tests
9. Build APK

---

## 13. Scope Protection

### DO NOT modify
- Plans feature
- People/Discovery logic
- Discovery filtering
- Discovery preferences
- Chat logic
- Connections logic
- Authentication
- Profile creation
- Profile completion (9.1C)
- Localization

### DO NOT add
- Admin dashboard
- Ban/suspend functionality
- New backend tables
- New email infrastructure
- New dependencies

---

## 14. Deployment Prerequisites

### Required for email delivery
1. Deploy Edge Function: `supabase functions deploy notify-safety-report`
2. Set secret: `supabase secrets set RESEND_API_KEY=<resend-api-key>`
3. Verify Resend sender domain `conexo.app` is configured in Resend dashboard

### Required for moderation view
1. Apply migration: `supabase db push` or apply manually
2. No additional configuration needed

---

## 15. Final Report Template

After implementation, report:
1. Files changed (exact list)
2. Edge Function status (deployed? secret configured?)
3. Email delivery verification status
4. Moderation view created and verified
5. Navigation animation changes
6. UI polish summary
7. Test count and result
8. `flutter analyze` result
9. `run_prod` result
10. APK path and size
11. Remaining issues (if any)
12. Phase status: COMPLETE or what remains
