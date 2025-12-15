-- FIX REALTIME PAYLOADS
-- Issue: Update events might be missing context columns (sender_id, etc.) if not changed.
-- Fix: Set REPLICA IDENTITY FULL to ensure complete notification payloads.

ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.collab_requests REPLICA IDENTITY FULL; -- Good measure

-- Verify Publication again
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.collab_requests;
