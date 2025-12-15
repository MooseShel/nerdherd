-- Update Appointments Status Constraint
-- We need to add 'completion_pending' and 'disputed' to the allowed statuses.

DO $$
BEGIN
    -- 1. Drop existing check constraint
    -- Note: We need to know the name. Usually postgres names it 'appointments_status_check'.
    -- We'll try to drop it if it exists.
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'appointments_status_check') THEN
        ALTER TABLE public.appointments DROP CONSTRAINT appointments_status_check;
    END IF;

    -- 2. Add new constraint with updated values
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_status_check 
    CHECK (status IN ('pending', 'confirmed', 'declined', 'cancelled', 'completion_pending', 'completed', 'disputed'));

END $$;
