-- ==============================================================================
-- ENABLE REAL-TIME FOR SERENDIPITY MATCHES (FIXED)
-- ==============================================================================

-- 1. Ensure the matches table is in the realtime publication
-- Note: If you get "already member" error, it means the table is already tracked.
-- You can ignore that error or uncomment the 'SET' line below if you want to reset it.
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.serendipity_matches;

-- 2. CRITICAL STEP: Ensure all columns are part of the replica identity
-- This ensures 'receiver_interested' is included in EVERY broadcast message,
-- even when it's the only thing that changes.
ALTER TABLE public.serendipity_matches REPLICA IDENTITY FULL;

-- 3. Verification
-- SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'serendipity_matches';
