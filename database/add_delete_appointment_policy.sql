-- Allow users to delete their own appointments
-- This is necessary for the "Remove from list" feature to work.

CREATE POLICY "Delete own appointments"
    ON public.appointments
    FOR DELETE
    USING (auth.uid() = host_id OR auth.uid() = attendee_id);
