-- MIGRATION: Occupancy Calculation Logic (FIXED)
-- Date: 2026-01-23

-- 1. Function to calculate occupancy for all spots
CREATE OR REPLACE FUNCTION public.refresh_spot_occupancy()
RETURNS void AS $$
DECLARE
    spot_record RECORD;
    active_user_count INTEGER;
    MAX_CAPACITY CONSTANT INTEGER := 20; 
BEGIN
    FOR spot_record IN SELECT id, location FROM public.study_spots WHERE location IS NOT NULL LOOP
        -- Count users within 50m who updated in last 10 mins and are NOT ghosts
        SELECT COUNT(*)
        INTO active_user_count
        FROM public.profiles
        WHERE 
            is_ghost = false
            AND last_updated > (now() - interval '10 minutes')
            AND location IS NOT NULL
            AND ST_DWithin(location, spot_record.location, 50);

        -- Update the spot
        UPDATE public.study_spots
        SET occupancy_percent = LEAST(((active_user_count::float / MAX_CAPACITY::float) * 100)::integer, 100)
        WHERE id = spot_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
