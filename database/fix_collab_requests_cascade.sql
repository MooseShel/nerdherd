-- ==============================================================================
-- FIX: REMOVE CASCADE DELETE FROM COLLAB_REQUESTS (AGAIN)
-- ==============================================================================
-- I previously inadvertently re-added 'ON DELETE CASCADE' when recreating the table.
-- This script changes it to 'ON DELETE NO ACTION' to protect data from bot cleanups.

-- 1. Drop existing FK constraints
ALTER TABLE public.collab_requests 
DROP CONSTRAINT IF EXISTS collab_requests_sender_id_fkey;

ALTER TABLE public.collab_requests 
DROP CONSTRAINT IF EXISTS collab_requests_receiver_id_fkey;

-- 2. Re-add FK constraints WITHOUT CASCADE (use NO ACTION)
ALTER TABLE public.collab_requests 
ADD CONSTRAINT collab_requests_sender_id_fkey 
FOREIGN KEY (sender_id) REFERENCES public.profiles(user_id) ON DELETE NO ACTION;

ALTER TABLE public.collab_requests 
ADD CONSTRAINT collab_requests_receiver_id_fkey 
FOREIGN KEY (receiver_id) REFERENCES public.profiles(user_id) ON DELETE NO ACTION;

-- 3. Verify the change (should verify delete_rule is 'NO ACTION')
SELECT
    tc.table_name, 
    kcu.column_name, 
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'collab_requests';
