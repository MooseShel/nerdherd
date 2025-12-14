-- Create ratings table
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rater_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    rated_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(rater_id, rated_id) -- One rating per pair
);

-- Enable RLS
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access for ratings"
    ON public.ratings FOR SELECT
    USING (true);

-- Allow authenticated insert (users rate others)
CREATE POLICY "Allow authenticated insert for ratings"
    ON public.ratings FOR INSERT
    WITH CHECK (auth.uid() = rater_id);

-- Helper to get average rating for a user
CREATE OR REPLACE FUNCTION public.get_user_average_rating(target_user_id UUID)
RETURNS FLOAT AS $$
DECLARE
    avg_rating FLOAT;
BEGIN
    SELECT AVG(rating) INTO avg_rating
    FROM public.ratings
    WHERE rated_id = target_user_id;
    
    RETURN COALESCE(avg_rating, 0.0);
END;
$$ LANGUAGE plpgsql;

-- Realtime
alter publication supabase_realtime add table ratings;
