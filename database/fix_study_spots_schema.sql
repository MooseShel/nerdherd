-- Comprehensive fix for missing columns in study_spots
-- Ensures all columns required by the App are present.

-- 1. Source (e.g. 'supabase', 'osm', 'business_owner')
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'supabase';

-- 2. Type (e.g. 'cafe', 'library')
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'other';

-- 3. Image URL
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Notify
DO $$
BEGIN
    RAISE NOTICE 'Added source, type, and image_url columns to study_spots.';
END $$;
