-- Phase 1A: Admin Authorization Layer (consolidated)
-- Creates admin_accounts table, inserts initial owner, then enables RLS.
-- The migration runner executes with elevated privileges, so the INSERT
-- succeeds before RLS is enabled.

-- 1. TABLE
CREATE TABLE IF NOT EXISTS public.admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL,
  role TEXT NOT NULL DEFAULT 'owner'
    CHECK (role IN ('owner')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (admin_user_id)
);

-- 2. INDEX
CREATE INDEX IF NOT EXISTS idx_admin_accounts_admin_user_id
  ON public.admin_accounts(admin_user_id);

-- 3. INITIAL OWNER RECORD (before RLS is enabled)
INSERT INTO public.admin_accounts (admin_user_id, role)
VALUES (
  '416e188c-bf28-401f-883c-e74830d3e6f0'::UUID,
  'owner'
)
ON CONFLICT (admin_user_id) DO NOTHING;

-- 4. ROW LEVEL SECURITY (after data is inserted)
ALTER TABLE public.admin_accounts ENABLE ROW LEVEL SECURITY;

-- 4a. SELECT: only the admin can read their own authorization row.
DROP POLICY IF EXISTS "Admin can read own admin record" ON public.admin_accounts;
CREATE POLICY "Admin can read own admin record"
  ON public.admin_accounts
  FOR SELECT
  TO authenticated
  USING (auth.uid() = admin_user_id);

-- 5. is_admin() HELPER
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