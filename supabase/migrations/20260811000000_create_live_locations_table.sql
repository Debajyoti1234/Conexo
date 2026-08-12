CREATE TABLE live_locations (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_live_locations_user_id ON live_locations(user_id);

ALTER TABLE live_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own live location"
  ON live_locations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own live location"
  ON live_locations FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated users can read all live locations"
  ON live_locations FOR SELECT
  USING (auth.role() = 'authenticated');
