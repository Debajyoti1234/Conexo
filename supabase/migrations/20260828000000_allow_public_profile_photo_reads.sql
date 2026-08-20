-- Phase 9.2B Refinement: Allow reading public profiles' photos from Storage
--
-- Root cause: the `profile-photos` Storage bucket was configured owner-only, so
-- `createSignedUrl` (which requires SELECT on the storage object) succeeds for
-- the owner viewing their OWN photos but is denied when the Discovery/People
-- screen tries to sign ANOTHER user's photo. This left remote photos blank in
-- Discovery even though the DB mapping is correct.
--
-- Fix: add a SELECT policy on storage.objects for the `profile-photos` bucket
-- that lets any authenticated user read objects belonging to a user whose
-- profile is public. Private profiles' photos remain protected. This is purely
-- additive and does not modify existing owner policies.
--
-- Photo object paths are `profiles/{userId}/photos/{photoId}.jpg`, so:
--   (storage.foldername(name))[1] = 'profiles'
--   (storage.foldername(name))[2] = '{userId}'
--   (storage.foldername(name))[3] = 'photos'

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Authenticated can read public profile photos'
  ) THEN
    CREATE POLICY "Authenticated can read public profile photos"
      ON storage.objects FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'profile-photos'
        AND (storage.foldername(name))[1] = 'profiles'
        AND EXISTS (
          SELECT 1 FROM public.profiles
          WHERE profiles.id::text = (storage.foldername(name))[2]
            AND profiles.profile_visibility = 'public'
        )
      );
  END IF;
END $$;
