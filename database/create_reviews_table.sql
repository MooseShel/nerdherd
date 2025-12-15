-- Create Reviews Table for Two-Way Ratings
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reviewer_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    reviewee_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    appointment_id UUID NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
    
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    
    -- Prevent duplicate reviews for the same appointment by the same person
    UNIQUE(reviewer_id, appointment_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON public.reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_reviews_appointment ON public.reviews(appointment_id);

-- RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read reviews
CREATE POLICY "Reviews are public"
    ON public.reviews FOR SELECT
    USING (true);

-- Policy: Users can insert their own reviews
-- (Ideally, we'd check if they participated in the appointment, but basic auth check is start)
CREATE POLICY "Users can create reviews"
    ON public.reviews FOR INSERT
    WITH CHECK (
        auth.uid() = reviewer_id AND
        EXISTS (
            SELECT 1 FROM public.appointments a
            WHERE a.id = appointment_id
            AND (a.host_id = reviewer_id OR a.attendee_id = reviewer_id)
            AND a.status = 'confirmed' -- Ensure appointment was at least confirmed
        )
    );

-- Notification Trigger for New Review
CREATE OR REPLACE FUNCTION notify_new_review() RETURNS TRIGGER AS $$
DECLARE
  reviewer_name TEXT;
BEGIN
  SELECT COALESCE(full_name, intent_tag, 'Someone') INTO reviewer_name 
  FROM profiles WHERE user_id = NEW.reviewer_id;

  PERFORM create_notification(
    NEW.reviewee_id,
    'new_review',
    'New Rating Received',
    reviewer_name || ' gave you a ' || NEW.rating || '-star rating!',
    jsonb_build_object('review_id', NEW.id, 'appointment_id', NEW.appointment_id)
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_new_review
AFTER INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION notify_new_review();
