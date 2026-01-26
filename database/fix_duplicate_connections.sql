-- ==============================================================================
-- FIX DUPLICATE CONNECTIONS
-- ==============================================================================

-- 1. Normalize Order: Ensure user_id_1 < user_id_2 for all rows
-- We use a temporary table approach to avoid constraint violations during the swap
BEGIN;

-- Update rows where order is wrong
UPDATE public.connections
SET 
  user_id_1 = LEAST(user_id_1, user_id_2),
  user_id_2 = GREATEST(user_id_1, user_id_2)
WHERE user_id_1 > user_id_2;

-- 2. Delete Duplicates (Keep the oldest one)
DELETE FROM public.connections a
USING public.connections b
WHERE a.id > b.id 
  AND a.user_id_1 = b.user_id_1 
  AND a.user_id_2 = b.user_id_2;

-- 3. Add Constraint to prevent future disorder
-- This ensures that (A, B) and (B, A) cannot both exist because (B, A) is invalid.
ALTER TABLE public.connections
DROP CONSTRAINT IF EXISTS check_users_ordered;

ALTER TABLE public.connections
ADD CONSTRAINT check_users_ordered CHECK (user_id_1 < user_id_2);

COMMIT;
