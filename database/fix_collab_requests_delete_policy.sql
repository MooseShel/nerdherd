-- Step 1: Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'collab_requests';

-- Step 2: View all existing policies
SELECT policyname, cmd, qual::text, with_check::text
FROM pg_policies
WHERE tablename = 'collab_requests';

-- Step 3: Drop ALL existing policies and recreate them properly
DROP POLICY IF EXISTS "Users can view their requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can send requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can delete their requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can update their requests" ON public.collab_requests;

-- Step 4: Create comprehensive policies

-- SELECT: Users can view requests where they are sender OR receiver
CREATE POLICY "Users can view their requests"
    ON public.collab_requests
    FOR SELECT
    USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

-- INSERT: Users can send requests (they must be the sender)
CREATE POLICY "Users can send requests"
    ON public.collab_requests
    FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id
    );

-- UPDATE: Users can update requests where they are receiver (for accepting/rejecting)
CREATE POLICY "Users can update their requests"
    ON public.collab_requests
    FOR UPDATE
    USING (auth.uid() = receiver_id OR auth.uid() = sender_id)
    WITH CHECK (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- DELETE: Users can delete requests where they are sender OR receiver
CREATE POLICY "Users can delete their requests"
    ON public.collab_requests
    FOR DELETE
    USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

-- Step 5: Verify policies were created
SELECT policyname, cmd, qual::text
FROM pg_policies
WHERE tablename = 'collab_requests'
ORDER BY cmd, policyname;
