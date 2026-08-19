-- Phase 9.1F: Moderation Report Summary Foundation
--
-- Creates an aggregation VIEW over public.safety_reports so a future admin /
-- moderation system can identify accounts with repeated reports without
-- changing the existing report architecture.
--
-- Additive only. Does NOT modify or delete any safety_reports data.
--
-- SECURITY MODEL
--   * security_invoker = true  → the view executes with the querying role's
--     permissions and therefore respects the RLS on public.safety_reports.
--   * All access is REVOKED from anon + authenticated so ordinary app users
--     can never read the moderation summary through the Flutter client.
--   * SELECT is granted only to service_role (and postgres), which is the
--     access path a future admin/moderation backend will use.
--
-- The report_type strings below MUST match the exact values submitted by the
-- Flutter report UI (lib/features/profile/report_problem_screen.dart).

CREATE OR REPLACE VIEW public.safety_report_summary
WITH (security_invoker = true) AS
SELECT
  reported_user_id,
  MAX(reported_name_snapshot) AS reported_name_snapshot,
  COUNT(*) AS total_reports,
  MAX(created_at) AS latest_report_at,

  -- Status breakdown
  COUNT(*) FILTER (WHERE status = 'pending')      AS pending_reports,
  COUNT(*) FILTER (WHERE status = 'reviewing')    AS reviewing_reports,
  COUNT(*) FILTER (WHERE status = 'resolved')     AS resolved_reports,
  COUNT(*) FILTER (WHERE status = 'dismissed')    AS dismissed_reports,
  COUNT(*) FILTER (WHERE status = 'action_taken') AS action_taken_reports,

  -- Report-type breakdown (exact Flutter report_type strings)
  COUNT(*) FILTER (WHERE report_type = 'Sexual harassment')              AS sexual_harassment_count,
  COUNT(*) FILTER (WHERE report_type = 'Fake identity / impersonation')  AS fake_identity_count,
  COUNT(*) FILTER (WHERE report_type = 'Spam or scam')                   AS spam_scam_count,
  COUNT(*) FILTER (WHERE report_type = 'Abusive behavior')               AS abusive_behavior_count,
  COUNT(*) FILTER (WHERE report_type = 'Inappropriate content')          AS inappropriate_content_count,
  COUNT(*) FILTER (WHERE report_type = 'Hate or discrimination')         AS hate_discrimination_count,
  COUNT(*) FILTER (WHERE report_type = 'Unwanted messages')              AS unwanted_messages_count,
  COUNT(*) FILTER (WHERE report_type = 'Suspicious activity')            AS suspicious_activity_count,
  COUNT(*) FILTER (WHERE report_type = 'Safety concern')                 AS safety_concern_count,
  COUNT(*) FILTER (WHERE report_type = 'Other')                          AS other_count
FROM public.safety_reports
GROUP BY reported_user_id;

-- ============================================================================
-- ACCESS CONTROL — admin/service-role only
-- ============================================================================

-- Ordinary app roles must never read the moderation summary.
REVOKE ALL ON public.safety_report_summary FROM anon;
REVOKE ALL ON public.safety_report_summary FROM authenticated;

-- Only the service role (future admin/moderation backend) may query it.
GRANT SELECT ON public.safety_report_summary TO service_role;
