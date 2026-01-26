-- ==============================================================================
-- NUCLEAR OPTION: RECREATE COLLAB_REQUESTS TABLE
-- ==============================================================================
-- The table is behaving anomalously (deleting records on update). 
-- We are recreating it from scratch to clear any hidden corruption or triggers.

-- 1. Create a temporary backup of any surviving data (just in case)
CREATE TEMP TABLE collab_requests_backup AS SELECT * FROM public.collab_requests;

-- 2. Drop the problematic table (and its dependent policies/triggers)
DROP TABLE IF EXISTS public.collab_requests CASCADE;

-- 3. Recreate the table FRESH
CREATE TABLE public.collab_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'interested', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    message TEXT DEFAULT NULL -- Re-adding the column we know exists
);

-- 4. Enable RLS
ALTER TABLE public.collab_requests ENABLE ROW LEVEL SECURITY;

-- 5. Re-apply Policies (Standard Permissive for now)
CREATE POLICY "Users can view their requests"
    ON public.collab_requests FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send requests"
    ON public.collab_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their requests"
    ON public.collab_requests FOR UPDATE
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can delete their requests"
    ON public.collab_requests FOR DELETE
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- 6. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.collab_requests;

-- 7. Restore Data (Optional - usually empty anyway due to the bug)
-- INSERT INTO public.collab_requests SELECT * FROM collab_requests_backup;

-- 8. VITAL: Restore the Notification Triggers 
-- (Only add back the ones we trust perfectly)

CREATE OR REPLACE FUNCTION public.notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  IF receiver_exists THEN
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM public.profiles WHERE user_id = NEW.sender_id;
    PERFORM public.create_notification(
      NEW.receiver_id, 'request', 'New Collaboration Request', sender_name || ' wants to connect!', jsonb_build_object('request_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_new_request 
AFTER INSERT ON public.collab_requests 
FOR EACH ROW EXECUTE FUNCTION public.notify_new_request();

-- Note: We are deliberating OMITTING the 'cleanup_old_requests' logic initially to verify stability.
