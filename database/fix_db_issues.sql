
-- 1. Fix FCM Token Function (column name mismatch)
CREATE OR REPLACE FUNCTION public.update_fcm_token(token TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET 
    fcm_token = token,
    last_updated = timezone('utc'::text, now())
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Ensure Collab Requests Policies are Correct (RLS)
-- Drop existing to be safe
DROP POLICY IF EXISTS "Allow individual read access for requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Allow authenticated insert access for requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can view their requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can send requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can delete their requests" ON public.collab_requests;
DROP POLICY IF EXISTS "Users can update their requests" ON public.collab_requests;

-- Enable RLS
ALTER TABLE public.collab_requests ENABLE ROW LEVEL SECURITY;

-- RECREATE POLICIES (Comprehensive)

-- VIEW: Sender OR Receiver
CREATE POLICY "Users can view their requests"
    ON public.collab_requests FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- INSERT: Sender only
CREATE POLICY "Users can send requests"
    ON public.collab_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- UPDATE: Sender OR Receiver (Receiver accepts/rejects)
CREATE POLICY "Users can update their requests"
    ON public.collab_requests FOR UPDATE
    USING (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- DELETE: Sender OR Receiver
CREATE POLICY "Users can delete their requests"
    ON public.collab_requests FOR DELETE
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
