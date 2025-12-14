-- Fix for collab_requests foreign key constraints
-- This allows collaboration requests with simulated bot users

-- Drop existing table and recreate without strict foreign keys
DROP TABLE IF EXISTS public.collab_requests CASCADE;

CREATE TABLE IF NOT EXISTS public.collab_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- RLS for Collab Requests
ALTER TABLE public.collab_requests ENABLE ROW LEVEL SECURITY;

-- Allow users to see requests they sent or received
CREATE POLICY "Allow individual read access for requests"
    ON public.collab_requests FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Allow authenticated users to send requests
CREATE POLICY "Allow authenticated insert access for requests"
    ON public.collab_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Allow users to update requests they received (accept/reject)
CREATE POLICY "Allow receiver to update requests"
    ON public.collab_requests FOR UPDATE
    USING (auth.uid() = receiver_id);

-- Allow users to delete their own requests
CREATE POLICY "Allow sender to delete requests"
    ON public.collab_requests FOR DELETE
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Update Realtime for requests (so receiver sees it instantly)
ALTER PUBLICATION supabase_realtime ADD TABLE collab_requests;
