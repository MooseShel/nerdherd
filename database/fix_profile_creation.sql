-- 1. Add missing columns to 'profiles' table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS address TEXT;

-- 2. Create a function to handle new user signup
-- This function will run whenever a new user is added to auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name, address, is_tutor, avatar_url)
  VALUES (
    NEW.id, 
    NEW.raw_user_meta_data->>'full_name', 
    NEW.raw_user_meta_data->>'address', 
    (NEW.raw_user_meta_data->>'is_tutor')::boolean,
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create the trigger
-- Ensure we drop it first to avoid duplicates if re-running
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 4. (Optional) Backfill existing users who might have metadata but no column data
-- Only run this if you have existing users with missing names in profiles
UPDATE public.profiles p
SET 
  full_name = u.raw_user_meta_data->>'full_name',
  address = u.raw_user_meta_data->>'address'
FROM auth.users u
WHERE p.user_id = u.id 
  AND (p.full_name IS NULL OR p.address IS NULL);
