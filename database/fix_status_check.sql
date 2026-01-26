-- ==============================================================================
-- CHECK CONSTRAINT FIX FOR COLLAB_REQUESTS
-- ==============================================================================

-- 1. Drop the existing check constraint on 'status'
ALTER TABLE public.collab_requests 
DROP CONSTRAINT IF EXISTS collab_requests_status_check;

-- 2. Add the new check constraint including 'interested'
ALTER TABLE public.collab_requests 
ADD CONSTRAINT collab_requests_status_check 
CHECK (status IN ('pending', 'interested', 'accepted', 'rejected'));

-- 3. Verification
SELECT 
    conname as constraint_name, 
    pg_get_constraintdef(c.oid) as definition
FROM pg_constraint c 
JOIN pg_namespace n ON n.oid = c.connamespace 
WHERE conrelid = 'public.collab_requests'::regclass 
AND contype = 'c';
