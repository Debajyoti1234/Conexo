-- Phase 1E.4F-B: Admin Verification Document Storage Access
--
-- Creates a single narrowly-scoped SELECT policy on storage.objects
-- allowing authenticated Admins to read verification documents.
--
-- This is the minimum authorization required for the Admin UI to
-- generate short-lived signed URLs for document review.
--
-- Security model:
--   * Only authenticated admins can use this policy.
--   * Public.is_admin() is verified server-side inside the policy.
--   * Only SELECT is granted; no INSERT/UPDATE/DELETE.
--   * Restricted to bucket_id = 'verification-documents' only.
--   * Does NOT modify user policies, RLS, consumer verification,
--     or any other Storage bucket.
--   * Does NOT make the bucket public.
--   * Does NOT grant service-role access.

CREATE POLICY "Admins can read verification documents"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'verification-documents'
    AND public.is_admin()
  );
