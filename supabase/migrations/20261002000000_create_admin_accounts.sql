-- ============================================================================
-- Admin Authorization Layer (Phase 1A)
-- ============================================================================
--
-- Creates a dedicated, server-side authorization table for the Conexo Admin
-- Dashboard. The admin identity is a separate Supabase Auth account — NOT the
-- existing consumer user. This table is the single source of truth for
-- "Is this authenticated user an authorized admin?"
--
-- Design constraints:
--   • No coupling to the consumer `profiles` table.
--   • RLS ensures only the admin can read/write their own row.
--   • The admin cannot modify their own role/authorization via client SQL.
--   • Consumer users cannot read, insert, update, or delete admin records.
--   • Initial owner row is inserted via migration (server-side), not Flutter.
-- ============================================================================

-- 1. TABLE
--    admin_user_id is a hard FK to auth.users — this is what separates the
--    admin identity from ordinary Conexo consumer accounts.
CREATE TABLE IF NOT EXISTS public.admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL,
  role TEXT NOT NULL DEFAULT 'owner'
    CHECK (role IN ('owner')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (admin_user_id)
);

-- 2. INDEX for fast lookup by admin_user_id
CREATE INDEX IF NOT EXISTS idx_admin_accounts_admin_user_id
  ON public.admin_accounts(admin_user_id);

-- 3. ROW LEVEL SECURITY
ALTER TABLE public.admin_accounts ENABLE ROW LEVEL SECURITY;

-- 3a. SELECT: only the admin can read their own authorization row.
DROP POLICY IF EXISTS "Admin can read own admin record" ON public.admin_accounts;
CREATE POLICY "Admin can read own admin record"
  ON public.admin_accounts
  FOR SELECT
  TO authenticated
  USING (auth.uid() = admin_user_id);

-- 3b. INSERT: blocked for now. The initial owner row is inserted via this
--     migration (server-side). No client INSERT policy exists so consumers
--     and even the admin cannot create new admin records from the app.
--     (No INSERT policy = no inserts from authenticated role.)

-- 3c. UPDATE: blocked. Admin cannot modify their own role or authorization.
--     (No UPDATE policy = no updates from authenticated role.)

-- 3d. DELETE: blocked. Admin cannot delete their own authorization.
--     (No DELETE policy = no deletes from authenticated role.)

-- 4. is_admin() HELPER
--    Secure, server-side check used by future RLS policies and edge functions.
--    SECURITY DEFINER ensures the function runs with the privileges of the
--    creator (not the caller), preventing privilege escalation.
--    search_path is pinned to 'public' to prevent schema search-path attacks.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_accounts
    WHERE admin_user_id = auth.uid()
  );
$$;

-- 5. INITIAL OWNER RECORD
--    Insert the dedicated admin Supabase Auth user as the initial owner.
--    Replace the placeholder UUID below with the actual admin auth user ID.
INSERT INTO public.admin_accounts (admin_user_id, role)
VALUES (
  '416e188c-bf28-401f-883c-e74830d3e6f0'::UUID,
  'owner'
)
ON CONFLICT (admin_user_id) DO NOTHING;