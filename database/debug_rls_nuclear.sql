-- ==============================================================================
-- NUCLEAR OPTION: ALLOW ALL READ ACCESS FOR COLLAB REQUESTS
-- ==============================================================================
-- This is a temporary debugging measure to prove if RLS is hiding your data.

-- 1. Drop the restrictive policy
DROP POLICY IF EXISTS "Users can view their requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Allow individual read access for requests" ON public.collab_requests;

-- 2. Create a permissible policy (Allow ANY authenticated user to see ANY request)
CREATE POLICY "Allow global read access (DEBUG)"
    ON public.collab_requests FOR SELECT
    USING (true);

-- 3. Verify polices
SELECT * FROM pg_policies WHERE tablename = 'collab_requests';
