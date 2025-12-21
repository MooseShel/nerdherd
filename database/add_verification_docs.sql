-- Add verification fields to profiles table
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status') THEN
        CREATE TYPE public.verification_status AS ENUM ('pending', 'verified', 'rejected');
    END IF;
END $$;

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS verification_document_url TEXT,
ADD COLUMN IF NOT EXISTS verification_status public.verification_status DEFAULT 'pending';

-- Create storage bucket for verification documents if not exists
-- (Note: Bucket creation usually happens via Supabase Dashboard or API, 
-- but we can document the intent here. Admin users will need access to this bucket.)
