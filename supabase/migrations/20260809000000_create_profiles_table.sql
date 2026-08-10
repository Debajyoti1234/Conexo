CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  photos JSONB NOT NULL DEFAULT '[]'::jsonb,
  bio TEXT NOT NULL DEFAULT '',
  interests TEXT[] NOT NULL DEFAULT '{}',
  languages TEXT[] NOT NULL DEFAULT '{}',
  gender TEXT NOT NULL DEFAULT '',
  location TEXT NOT NULL DEFAULT '',
  social_links JSONB NOT NULL DEFAULT '[]'::jsonb,
  occupation TEXT NOT NULL DEFAULT '',
  education TEXT NOT NULL DEFAULT '',
  company TEXT NOT NULL DEFAULT '',
  college TEXT NOT NULL DEFAULT '',
  hometown TEXT NOT NULL DEFAULT '',
  website TEXT NOT NULL DEFAULT '',
  about_me TEXT NOT NULL DEFAULT '',
  favorite_activities TEXT[] NOT NULL DEFAULT '{}',
  verification_status TEXT NOT NULL DEFAULT 'notVerified',
  profile_visibility TEXT NOT NULL DEFAULT 'public',
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  profile_completed BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_policy ON profiles
FOR ALL
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
