-- P1.2B.13: Plan Location Foundation
--
-- Adds readable location fields to `plans` so a creator's selected place
-- (name + formatted address) persists and can be displayed in Plan Details.
--
-- Rationale: `plans` already has `latitude` and `longitude` (DOUBLE PRECISION,
-- nullable), but there is NO column for the human-readable place name/address.
-- The P1.2B.12 audit confirmed the typed location was never persisted. These
-- two nullable TEXT columns are the smallest change needed to persist and
-- display the selected place. Coordinates continue to use the existing
-- latitude/longitude columns.
--
-- SCOPE: additive only. No RLS change, no change to unrelated columns, no
-- change to membership/chat/invitation architecture. Existing plans keep
-- NULL for these columns and must continue loading safely.

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS location_name TEXT;

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS location_address TEXT;
