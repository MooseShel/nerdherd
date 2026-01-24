-- MIGRATION: Add Noise Level to Study Spots
-- Date: 2026-01-24

ALTER TABLE public.study_spots
ADD COLUMN noise_level INTEGER DEFAULT 1;

-- Add comment for documentation
COMMENT ON COLUMN public.study_spots.noise_level IS 'Noise level from 1 (Silent) to 5 (Loud), inferred from AI analysis of reviews.';
