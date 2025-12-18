-- Reset all user locations to NULL to clear stale data
UPDATE public.profiles
SET 
  lat = NULL, 
  long = NULL, 
  last_updated = NOW() -- Set update time to now so we know when the reset happened
WHERE 
  -- Optional: Don't reset the admin/developer if needed, but 'tutor' check below is just an example
  true;

-- Optional: If you want to delete specific test users you can uncomment:
-- DELETE FROM public.profiles WHERE university_id LIKE '%test%';
