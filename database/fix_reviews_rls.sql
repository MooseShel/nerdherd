-- Drop the old overly restrictive policy
DROP POLICY IF EXISTS "Users can create reviews" ON public.reviews;

-- Create the fixed policy allowing 'completed' status
CREATE POLICY "Users can create reviews"
    ON public.reviews FOR INSERT
    WITH CHECK (
        auth.uid() = reviewer_id AND
        EXISTS (
            SELECT 1 FROM public.appointments a
            WHERE a.id = appointment_id
            AND (a.host_id = reviewer_id OR a.attendee_id = reviewer_id)
            AND a.status IN ('confirmed', 'completed') -- Allow completed sessions to be reviewed
        )
    );
