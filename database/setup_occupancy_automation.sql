-- Enable pg_cron if available (Supabase supports this)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Refresh occupancy for all study spots every 5 minutes
SELECT cron.schedule(
    'update-all-spot-occupancy',
    '*/5 * * * *',
    $$
    SELECT update_spot_occupancy(id) FROM public.study_spots;
    $$
);

-- For environments where pg_cron is not enabled, we can create an RPC 
-- that the frontend calls occasionally to refresh the data
CREATE OR REPLACE FUNCTION refresh_nearby_occupancy(user_lat double precision, user_long double precision)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Refresh occupancy for spots within 5km of the user
    PERFORM update_spot_occupancy(id)
    FROM public.study_spots
    WHERE st_dwithin(location, st_point(user_long, user_lat)::geography, 5000);
END;
$$;
