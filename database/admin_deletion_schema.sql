-- Add admin_deletion_scheduled_at column to study_spots
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS admin_deletion_scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

DO $$
BEGIN
    RAISE NOTICE 'Added admin_deletion_scheduled_at column to study_spots.';
END $$;
