-- Phase 13: Sponsored Spots & Business Portal Logic

-- 1. Update Profiles Table (Business Owner Role)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_business_owner BOOLEAN DEFAULT false;

-- 2. Update Study Spots Table (Sponsorship & Ownership)
ALTER TABLE public.study_spots 
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES public.profiles(user_id),
ADD COLUMN IF NOT EXISTS is_sponsored BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS promotional_text TEXT,
ADD COLUMN IF NOT EXISTS sponsorship_expiry TIMESTAMP WITH TIME ZONE;

-- 3. RLS Policies for Study Spots (Ownership)
-- Allow "Business Owners" to INSERT new spots
DROP POLICY IF EXISTS "Business Owners can insert spots" ON public.study_spots;
CREATE POLICY "Business Owners can insert spots"
ON public.study_spots FOR INSERT
WITH CHECK (
  auth.uid() = owner_id 
  OR 
  (SELECT is_business_owner FROM public.profiles WHERE user_id = auth.uid()) = true
);

-- Allow Owners to UPDATE their own spots
DROP POLICY IF EXISTS "Owners can update their spots" ON public.study_spots;
CREATE POLICY "Owners can update their spots"
ON public.study_spots FOR UPDATE
USING (auth.uid() = owner_id);

-- Notify
DO $$
BEGIN
    RAISE NOTICE 'Added Business Owner role and Sponsored Spots columns.';
END $$;
