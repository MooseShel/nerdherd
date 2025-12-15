-- Add admin and banned columns to profiles table

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;

-- Notify that columns were added
DO $$
BEGIN
    RAISE NOTICE 'Added is_admin and is_banned columns to profiles table';
END $$;
