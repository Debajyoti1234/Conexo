# Phase 9.4.1B - Production DOB Hardening (INSPECTION ONLY - NO FILES MODIFIED)

## Live DB evidence (remote project wlfitdzhvfhuqgxwreed)
- date_of_birth: nullable (is_nullable = YES), type date
- profile_completed: NOT NULL boolean
- profiles rows: total=2, null_dob=2, completed=2, completed_but_null_dob=2
- Constraints on profiles: profiles_pkey (PK), profiles_id_fkey (FK). NO CHECK constraints.
- Triggers on profiles: none.
- RLS: profiles_policy FOR ALL USING/ WITH CHECK (auth.uid() = id); plus SELECT policy for public profiles.

## Findings
1. Model completion (validateDraft) includes validateDateOfBirth -> drives UserProfileDraft.isComplete. Creation (_complete gated on isComplete) and Editing (_canSave = isComplete && isDirty) enforce DOB CLIENT-SIDE only.
2. GAP: SupabaseProfileRepository.checkProfileStatus() reads ONLY cached profile_completed boolean; does not re-check date_of_birth. Existing rows completed=true & dob=null -> ProfileStatus.complete -> AuthGate -> MainShell. Confirmed 2/2 rows in this state.
3. Minimum age: NOT enforced anywhere (validateDateOfBirth = non-null + not-future only). Picker year-18 seed is UI-only.
4. Bypass: No DB CHECK/trigger; RLS allows owner to upsert profile_completed=true with date_of_birth=null. Client-only gate is bypassable; 2 legacy rows already bypassed.
5. NOT NULL: cannot be applied now (2 null rows); would need fabricated DOB (prohibited).

## Smallest production-safe changes (future task, not done now)
- Client: SupabaseProfileRepository.checkProfileStatus() select date_of_birth too; return incomplete when null. (LocalProfileRepository already re-derives via isComplete.)
- DB migration (idempotent, in order):
  1) UPDATE profiles SET profile_completed=false WHERE date_of_birth IS NULL AND profile_completed=true;  (non-destructive reconcile of 2 rows)
  2) ALTER TABLE profiles ADD CONSTRAINT profiles_completed_requires_dob CHECK (profile_completed=false OR date_of_birth IS NOT NULL);
- Do NOT SET NOT NULL on date_of_birth yet.

## Adults-only (18+) - only if confirmed, NOT implemented
- Client: profile_validation.dart -> add age>=18 (using ageFromDate) inside validateDateOfBirth or new validateAge; date picker lastDate = now-18y.
- Backend: cannot use CHECK with now() (not immutable) -> BEFORE INSERT/UPDATE trigger or completion RPC rejecting dob > current_date - interval 18 years.

## Recommended order
1. Client checkProfileStatus DOB-aware. 2. Migration reconcile + CHECK. 3. analyze + apply + verify. 4. (if confirmed) 18+ at both layers.

STATUS: INSPECTION COMPLETE - NO FILES MODIFIED.
