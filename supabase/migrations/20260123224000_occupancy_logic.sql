-- MIGRATION: Occupancy Calculation Logic
-- Date: 2026-01-23

-- 1. Function to calculate occupancy for all spots
CREATE OR REPLACE FUNCTION public.refresh_spot_occupancy()
RETURNS void AS $$
DECLARE
    spot_record RECORD;
    active_user_count INTEGER;
    MAX_CAPACITY CONSTANT INTEGER := 20; -- Simplified for MVP
BEGIN
    FOR spot_record IN SELECT id, location FROM public.study_spots LOOP
        -- Count users within 50m who updated in last 5 mins and are NOT ghosts
        -- Note: using ST_Distance on geography type (location column)
        SELECT COUNT(*)
        INTO active_user_count
        FROM public.profiles
        WHERE 
            is_ghost = false
            AND last_updated > (now() - interval '10 minutes')
            AND ST_DWithin(location, spot_record.location, 50);

        -- Update the spot
        UPDATE public.study_spots
        SET occupancy_percent = LEAST(((active_user_count::float / MAX_CAPACITY::float) * 100)::integer, 100)
        WHERE id = spot_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. (Optional) Setup a trigger or just allow RPC call
-- For now, let's make it an RPC that the client can trigger or 
-- we can run periodically if Supabase CRON is enabled.
