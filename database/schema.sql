-- Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    university_id TEXT, -- e.g., verified email domain or ID
    is_tutor BOOLEAN DEFAULT FALSE,
    current_classes TEXT[] DEFAULT '{}', -- Array of strings, e.g., {'CS101', 'MATH200'}
    intent_tag TEXT, -- e.g., 'Open to Collab', 'Quiet Study Only'
    location_geom GEOMETRY(POINT, 4326), -- PostGIS geometry column for location
    lat FLOAT, -- Added for easier Realtime sync
    long FLOAT, -- Added for easier Realtime sync
    avatar_url TEXT, -- Optional profile picture URL
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (user_id)
);

-- Trigger to sync lat/long -> location_geom
CREATE OR REPLACE FUNCTION public.sync_location_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NOT NULL AND NEW.long IS NOT NULL THEN
        NEW.location_geom := st_point(NEW.long, NEW.lat)::geometry;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_profile_location_change ON public.profiles;
CREATE TRIGGER on_profile_location_change
    BEFORE INSERT OR UPDATE OF lat, long ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_location_geom();

-- Enable Realtime
alter publication supabase_realtime add table profiles;

-- Create GIST index for fast spatial queries (KNN, Box search)
CREATE INDEX IF NOT EXISTS profiles_location_geom_idx ON public.profiles USING GIST (location_geom);

-- RLS Policies (Security)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Allow users to read all profiles (discovery)
CREATE POLICY "Allow public read access for profiles"
    ON public.profiles FOR SELECT
    USING (true);

-- Allow users to update their own profile
CREATE POLICY "Allow individual update access"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Allow users to insert their own profile
CREATE POLICY "Allow individual insert access"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RPC Function to find nearby peers
create or replace function nearby_peers(
  lat float,
  long float,
  radius_meters int default 5000
) returns table (
  user_id uuid,
  university_id text,
  is_tutor boolean,
  current_classes text[],
  intent_tag text,
  dist_meters float
)
language plpgsql
as $$
begin
  return query
  select
    p.user_id,
    p.university_id,
    p.is_tutor,
    p.current_classes,
    p.intent_tag,
    st_distance(
      p.location_geom,
      st_point(long, lat)::geometry
    ) as dist_meters
  from
    public.profiles p
  where
    st_dwithin(
      p.location_geom,
      st_point(long, lat)::geometry,
      radius_meters
    )
  order by
    p.location_geom <-> st_point(long, lat)::geometry;
end;

-- Collab Requests Table
CREATE TABLE IF NOT EXISTS public.collab_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- RLS for Collab Requests
ALTER TABLE public.collab_requests ENABLE ROW LEVEL SECURITY;

-- Allow users to see requests they sent or received
CREATE POLICY "Allow individual read access for requests"
    ON public.collab_requests FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Allow authenticated users to send requests
CREATE POLICY "Allow authenticated insert access for requests"
    ON public.collab_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Update Realtime for requests (so receiver sees it instantly)
alter publication supabase_realtime add table collab_requests;

