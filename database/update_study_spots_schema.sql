-- Add occupancy and AI tag columns to study_spots
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS occupancy_percent int DEFAULT 0,
ADD COLUMN IF NOT EXISTS vibe_summary text,
ADD COLUMN IF NOT EXISTS ai_tags text[] DEFAULT '{}';

-- Function to update spot occupancy based on nearby users
-- This counts users within 50 meters of the spot
CREATE OR REPLACE FUNCTION update_spot_occupancy(target_spot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    spot_location geography;
    user_count int;
    capacity int := 20; -- Default capacity per spot, can be adjusted or added to schema
BEGIN
    -- Get spot location
    SELECT location INTO spot_location FROM public.study_spots WHERE id = target_spot_id;

    -- Count active profiles within 50 meters
    -- NOTE: This assumes 'profiles' table has 'location_geom' and 'last_updated' (which it does)
    -- and we consider 'active' as updated in the last 15 minutes
    SELECT count(*) INTO user_count
    FROM public.profiles
    WHERE st_dwithin(location_geom, spot_location, 50)
    AND last_updated > (now() - interval '15 minutes');

    -- Update occupancy_percent (capped at 100%)
    UPDATE public.study_spots
    SET occupancy_percent = LEAST((user_count * 100) / capacity, 100)
    WHERE id = target_spot_id;
END;
$$;
