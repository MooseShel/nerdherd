-- MIGRATION: Vibe Check Schema Additions
-- Date: 2026-01-23

-- 1. Add vibe-related columns to study_spots
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS occupancy_percent INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS vibe_summary TEXT,
ADD COLUMN IF NOT EXISTS ai_tags TEXT[] DEFAULT '{}';

-- 2. Create spot_reviews table
CREATE TABLE IF NOT EXISTS public.spot_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Add RLS Policies for spot_reviews
ALTER TABLE public.spot_reviews ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Spot reviews are public') THEN
        CREATE POLICY "Spot reviews are public"
            ON public.spot_reviews FOR SELECT
            USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert their own spot reviews') THEN
        CREATE POLICY "Users can insert their own spot reviews"
            ON public.spot_reviews FOR INSERT
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;
