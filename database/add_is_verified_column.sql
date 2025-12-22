-- Fix for "Could not find the 'is_verified' column" error
-- This column is required for the Add Spot logic in BusinessDashboard

ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;

-- Notify
DO $$
BEGIN
    RAISE NOTICE 'Added is_verified column to study_spots table.';
END $$;
