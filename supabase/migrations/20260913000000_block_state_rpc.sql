-- Chat + Blocking refinement: directional block-state helper.
--
-- Uses the canonical public.blocks table (blocker_id, blocked_id). RLS on
-- public.blocks only exposes rows where the caller is the blocker, so a client
-- cannot tell whether "the other user blocked me". This SECURITY DEFINER helper
-- returns ONLY the two booleans describing the relationship between the caller
-- and one specific other user, so the chat can render the correct directional
-- blocked state without leaking any other block rows or metadata.
--
-- No new tables. Complements the existing public.blocked_profile_ids() helper
-- (bidirectional id set for discovery filtering).

CREATE OR REPLACE FUNCTION public.block_state(p_other UUID)
RETURNS TABLE (i_blocked BOOLEAN, they_blocked BOOLEAN)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    EXISTS (
      SELECT 1 FROM public.blocks
      WHERE blocker_id = auth.uid() AND blocked_id = p_other
    ) AS i_blocked,
    EXISTS (
      SELECT 1 FROM public.blocks
      WHERE blocker_id = p_other AND blocked_id = auth.uid()
    ) AS they_blocked
$$;

REVOKE ALL ON FUNCTION public.block_state(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.block_state(UUID) TO authenticated;
