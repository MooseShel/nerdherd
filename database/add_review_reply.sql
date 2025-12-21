-- Add reply column to reviews table
ALTER TABLE public.reviews
ADD COLUMN IF NOT EXISTS reply TEXT;

-- Update RLS: Users can update their own reviews (as reviewee) to add a reply
CREATE POLICY "Reviewees can reply to reviews"
    ON public.reviews FOR UPDATE
    USING (auth.uid() = reviewee_id)
    WITH CHECK (auth.uid() = reviewee_id);
