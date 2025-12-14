-- Insert a fake request FROM a Bot TO the currently authenticated user
-- Be sure to replace 'YOUR_USER_ID_HERE' with your actual UUID if running manually, 
-- or rely on auth.uid() if running in RLS context.
-- However, running in SQL Editor usually ignores RLS policies for auth.uid() unless you use set_config.
-- A safer way for manual testing:

INSERT INTO public.collab_requests (sender_id, receiver_id, status)
SELECT 
    '00000000-0000-4000-a000-000000000001', -- Bot Tutor A UUID
    auth.users.id,                          -- Your User ID
    'pending'
FROM auth.users
WHERE auth.users.email LIKE '%@%' -- Selects essentially any user, limit 1 to be safe 
LIMIT 1;

-- If you have multiple users, you might want to specify email:
-- WHERE auth.users.email = 'your_email@example.com'
