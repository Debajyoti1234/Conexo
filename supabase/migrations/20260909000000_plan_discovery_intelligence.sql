-- P1.2B.15: Plan Discovery Intelligence (Featured + Friends Joined signals)
--
-- Smallest safe backend additions to power two discovery rails with REAL data.
-- Trending needs no schema change (it reuses the existing joined-member counts
-- + plan recency). No demo data, no fabricated engagement.
--
-- 1. plans.is_featured — a real curated flag. Defaults false, so no plan is
--    featured until it is genuinely curated (the Featured rail is simply empty
--    until then; it is never populated with fabricated/random plans). Featured
--    plans still obey the existing visibility + RLS rules.
--
-- 2. get_friends_joined_plan_ids(uuid[]) — a SECURITY DEFINER helper that, for
--    the calling user, returns which of the supplied (already RLS-authorized)
--    plan ids have at least one ACCEPTED CONNECTION joined as a member
--    (status = 'joined' only). Needed because the viewer is not a member of
--    discovery plans and therefore cannot read their plan_members rows under
--    the existing RLS. The function only returns plan ids from the caller's
--    supplied set, never member identities, and excludes the caller.
--
-- SCOPE: additive only. No RLS weakened, no existing column/policy/table/RPC
-- changed, no membership/chat/invitation change.

-- ============================================================================
-- 1. FEATURED FLAG
-- ============================================================================

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;

-- ============================================================================
-- 2. FRIENDS-JOINED HELPER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_friends_joined_plan_ids(
  p_plan_ids uuid[]
)
RETURNS TABLE(plan_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT pm.plan_id
  FROM public.plan_members pm
  JOIN public.plans p ON p.id = pm.plan_id AND p.status = 'active'
  WHERE pm.status = 'joined'
    AND pm.plan_id = ANY(p_plan_ids)
    AND pm.user_id <> auth.uid()
    AND pm.user_id IN (
      SELECT CASE
               WHEN c.requester_id = auth.uid() THEN c.recipient_id
               ELSE c.requester_id
             END
      FROM public.connections c
      WHERE c.status = 'accepted'
        AND (c.requester_id = auth.uid() OR c.recipient_id = auth.uid())
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_friends_joined_plan_ids(uuid[]) TO authenticated;
