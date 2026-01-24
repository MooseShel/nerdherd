-- Create Spot Reviews Table
CREATE TABLE IF NOT EXISTS public.spot_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spot_id UUID NOT NULL REFERENCES public.study_spots(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    
    -- Prevent duplicate reviews for the same spot by the same person
    UNIQUE(spot_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_spot_reviews_spot ON public.spot_reviews(spot_id);

-- RLS Policies
ALTER TABLE public.spot_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Everyone can view spot reviews"
    ON public.spot_reviews FOR SELECT
    USING (true);

CREATE POLICY "Users can create spot reviews"
    ON public.spot_reviews FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own spot reviews"
    ON public.spot_reviews FOR UPDATE
    USING (auth.uid() = user_id);
