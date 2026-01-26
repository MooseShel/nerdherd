-- DIAGNOSIS SCRIPT
-- Run this in Supabase SQL Editor to see what records exist for a specific user.
-- Replace 'USER_ID_HERE' with the actual UUID if testing for others, 
-- or just run it as-is if using the dashboard's "user impersonation" feature (if available).
-- Otherwise, just select ALL to see global state (for debugging dev database).

SELECT 
    'MATCH' as type,
    id, 
    user_a, 
    user_b, 
    accepted, 
    created_at,
    match_type
FROM public.serendipity_matches
ORDER BY created_at DESC
LIMIT 10;

SELECT 
    'REQUEST' as type,
    id, 
    sender_id, 
    receiver_id, 
    status, 
    created_at
FROM public.collab_requests
ORDER BY created_at DESC
LIMIT 10;
