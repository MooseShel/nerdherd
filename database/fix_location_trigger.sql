-- Fix sync_location_geom to handle NULLs correctly
CREATE OR REPLACE FUNCTION public.sync_location_geom()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NOT NULL AND NEW.long IS NOT NULL THEN
        NEW.location_geom := st_point(NEW.long, NEW.lat)::geometry;
    ELSE
        -- Essential: Clear the geometry if coordinates are removed (Ghost Mode)
        NEW.location_geom := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Force update all existing profiles to ensure consistency
-- This "cleans" any ghost users who might have stale geometry but null coords
UPDATE public.profiles
SET location_geom = NULL
WHERE lat IS NULL OR long IS NULL;
