-- Add auto_renew column to study_spots
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT false;

DO $$
BEGIN
    RAISE NOTICE 'Added auto_renew column to study_spots.';
END $$;
