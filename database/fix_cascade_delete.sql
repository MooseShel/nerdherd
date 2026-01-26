-- ==============================================================================
-- FIX: REMOVE CASCADE DELETE FROM SERENDIPITY_MATCHES
-- ==============================================================================
-- This prevents match records from being deleted when profiles are updated/touched

-- 1. Drop existing FK constraints
ALTER TABLE public.serendipity_matches 
DROP CONSTRAINT IF EXISTS serendipity_matches_user_a_fkey;

ALTER TABLE public.serendipity_matches 
DROP CONSTRAINT IF EXISTS serendipity_matches_user_b_fkey;

-- 2. Re-add FK constraints WITHOUT CASCADE (use NO ACTION instead)
ALTER TABLE public.serendipity_matches 
ADD CONSTRAINT serendipity_matches_user_a_fkey 
FOREIGN KEY (user_a) REFERENCES public.profiles(user_id) ON DELETE NO ACTION;

ALTER TABLE public.serendipity_matches 
ADD CONSTRAINT serendipity_matches_user_b_fkey 
FOREIGN KEY (user_b) REFERENCES public.profiles(user_id) ON DELETE NO ACTION;

-- 3. Verify the change
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
  AND tc.table_name = 'serendipity_matches';
