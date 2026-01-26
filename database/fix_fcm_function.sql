-- Fix for update_fcm_token referencing non-existent 'updated_at' column
-- Replaces it with 'last_updated' which exists in the schema

CREATE OR REPLACE FUNCTION public.update_fcm_token(token TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET 
    fcm_token = token,
    last_updated = timezone('utc'::text, now()) -- Use correct column name
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
