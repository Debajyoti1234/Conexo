-- P1.2B.5.1: Fix infinite RLS recursion between plans and plan_members
--
-- Root cause:
--   plan_members SELECT policy "Creators can read plan memberships" contains
--   a subquery on public.plans. The plans SELECT policy "Members can read
--   joined plans" contains a subquery on plan_members. This creates infinite
--   recursion when PostgreSQL evaluates RLS:
--
--     plan_members
--       → EXISTS (SELECT 1 FROM plans WHERE plans.id = plan_members.plan_id)
--         → plans RLS "Members can read joined plans"
--           → EXISTS (SELECT 1 FROM plan_members WHERE plan_members.plan_id = plans.id)
--             → plan_members RLS "Creators can read plan memberships"
--               → EXISTS (SELECT 1 FROM plans ...) → repeat
--
--   Additionally, "Members can read plan participants" self-references
--   plan_members via the pm2 alias, causing self-recursion on plan_members.
--
-- Fix:
--   Replace direct subqueries with SECURITY DEFINER helper functions.
--   SECURITY DEFINER bypasses RLS for the function's internal queries,
--   breaking the recursion while preserving server-side authorization.

-- Helper: check if the current authenticated user is the creator of a plan.
CREATE OR REPLACE FUNCTION public.is_plan_creator(p_plan_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.plans
    WHERE id = p_plan_id AND creator_id = auth.uid()
  );
END;
$$;

-- Helper: check if the current authenticated user is a joined member of a plan.
CREATE OR REPLACE FUNCTION public.is_plan_member(p_plan_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.plan_members
    WHERE plan_id = p_plan_id AND user_id = auth.uid() AND status = 'joined'
  );
END;
$$;

-- Grant execute to authenticated users so the RLS policies can call them.
GRANT EXECUTE ON FUNCTION public.is_plan_creator(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_plan_member(UUID) TO authenticated;

-- Drop the recursive policies on plan_members.
DROP POLICY IF EXISTS "Creators can read plan memberships" ON public.plan_members;
DROP POLICY IF EXISTS "Members can read plan participants" ON public.plan_members;

-- Recreate using the non-recursive helper functions.
CREATE POLICY "Creators can read plan memberships"
  ON public.plan_members FOR SELECT
  TO authenticated
  USING (public.is_plan_creator(plan_members.plan_id));

CREATE POLICY "Members can read plan participants"
  ON public.plan_members FOR SELECT
  TO authenticated
  USING (
    status = 'joined'
    AND public.is_plan_member(plan_members.plan_id)
  );
