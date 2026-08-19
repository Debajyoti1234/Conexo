-- Phase 9.1A: Discovery Preferences — Distance + Age Range
--
-- Adds user-facing discovery preferences to the profiles table. All columns
-- are nullable so existing users load safely with no forced defaults.
-- RLS is already enforced by the existing profiles_policy (auth.uid() = id),
-- so no additional policy is required for these additive columns.

-- Maximum discovery distance in kilometres. NULL = no limit / unset.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS discovery_distance_km INTEGER;

-- Minimum age for People/Discovery results. NULL = unset.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS discovery_min_age INTEGER;

-- Maximum age for People/Discovery results. NULL = unset.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS discovery_max_age INTEGER;
