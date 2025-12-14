-- 1. Drop Foreign Key Constraint to allow fake User IDs (Bots)
ALTER TABLE public.profiles 
DROP CONSTRAINT IF EXISTS profiles_user_id_fkey;

-- 2. Allow INSERTS/UPDATES to profiles from authenticated users (for simulation)
-- First, drop existing restrictive insert policies if any (usually none by default or "users can insert their own")
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.profiles;

-- Create permissive insert policy (WARNING: prototype only)
CREATE POLICY "Allow simulation inserts"
ON public.profiles
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Permit Updates as well (to move bots)
CREATE POLICY "Allow simulation updates"
ON public.profiles
FOR UPDATE
USING (auth.role() = 'authenticated');
