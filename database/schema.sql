-- Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    university_id TEXT, -- e.g., verified email domain or ID
    full_name TEXT, -- User's display name
    address TEXT, -- Campus or physical address
    is_tutor BOOLEAN DEFAULT FALSE,
    current_classes TEXT[] DEFAULT '{}', -- Array of strings, e.g., {'CS101', 'MATH200'}
    intent_tag TEXT, -- e.g., 'Open to Collab', 'Quiet Study Only'
    location_geom GEOMETRY(POINT, 4326), -- PostGIS geometry column for location
    lat FLOAT, -- Added for easier Realtime sync
    long FLOAT, -- Added for easier Realtime sync
    avatar_url TEXT, -- Optional profile picture URL
    fcm_token TEXT, -- Firebase Cloud Messaging Token
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (user_id)
);

CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);

-- Function to handle new user signup (Auto-create profile)
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name, address, is_tutor, avatar_url)
  VALUES (
    NEW.id, 
    NEW.raw_user_meta_data->>'full_name', 
    NEW.raw_user_meta_data->>'address', 
    (NEW.raw_user_meta_data->>'is_tutor')::boolean,
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call handle_new_user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

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
$$;

-- Function to update FCM Token
CREATE OR REPLACE FUNCTION public.update_fcm_token(token TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = token
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- ==========================================
-- NOTIFICATIONS SYSTEM
-- ==========================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, 
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB, 
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications"
ON public.notifications FOR INSERT WITH CHECK (true);

-- Notification Triggers
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  notification_id UUID;
  user_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO user_exists;
  IF user_exists THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (p_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO notification_id;
    RETURN notification_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  IF receiver_exists THEN
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM public.profiles WHERE user_id = NEW.sender_id;
    PERFORM public.create_notification(
      NEW.receiver_id, 'request', 'New Collaboration Request', sender_name || ' wants to connect!', jsonb_build_object('request_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_new_request ON public.collab_requests;
CREATE TRIGGER trigger_notify_new_request AFTER INSERT ON public.collab_requests FOR EACH ROW EXECUTE FUNCTION public.notify_new_request();

CREATE OR REPLACE FUNCTION public.notify_new_message() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  message_preview TEXT;
  receiver_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  IF receiver_exists THEN
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM public.profiles WHERE user_id = NEW.sender_id;
    message_preview := CASE WHEN NEW.message_type = 'image' THEN '📷 Sent an image' WHEN LENGTH(NEW.content) > 50 THEN SUBSTRING(NEW.content, 1, 50) || '...' ELSE NEW.content END;
    PERFORM public.create_notification(
      NEW.receiver_id, 'message', sender_name, message_preview, jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: messages table must essentially exist for this to work, ensuring schema consistency
-- DROP TRIGGER IF EXISTS trigger_notify_new_message ON public.messages;
-- CREATE TRIGGER trigger_notify_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();

CREATE OR REPLACE FUNCTION public.notify_request_accepted() RETURNS TRIGGER AS $$
DECLARE
  accepter_name TEXT;
  sender_exists BOOLEAN;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.sender_id) INTO sender_exists;
    IF sender_exists THEN
      SELECT COALESCE(full_name, intent_tag, 'Someone') INTO accepter_name FROM public.profiles WHERE user_id = NEW.receiver_id;
      PERFORM public.create_notification(
        NEW.sender_id, 'request_accepted', 'Request Accepted!', accepter_name || ' accepted your request.', jsonb_build_object('request_id', NEW.id, 'accepter_id', NEW.receiver_id)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_request_accepted ON public.collab_requests;
CREATE TRIGGER trigger_notify_request_accepted AFTER UPDATE ON public.collab_requests FOR EACH ROW EXECUTE FUNCTION public.notify_request_accepted();
