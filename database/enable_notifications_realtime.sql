-- Enable Realtime for Notifications table
-- This was missing from previous scripts!
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Verify it worked
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications';
