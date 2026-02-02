-- Add is_active column to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

DO $$
BEGIN
    RAISE NOTICE 'Added is_active column to profiles.';
END $$;
