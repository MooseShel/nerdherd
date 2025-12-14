-- 1. Ensure the column exists (Safe to run multiple times)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2. Force refresh the Realtime publication for the profiles table
-- This ensures that new columns are treated correctly by the Realtime stream
ALTER PUBLICATION supabase_realtime DROP TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- 3. Confirm the column is present
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'avatar_url';
