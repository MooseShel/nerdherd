-- ==============================================================================
-- FIX MISSING COLUMNS
-- ==============================================================================

-- The 'express_interest' RPC relies on this column to track the handshake state.
ALTER TABLE public.serendipity_matches 
ADD COLUMN IF NOT EXISTS receiver_interested BOOLEAN DEFAULT FALSE;

-- Ensure RLS allows updates to this column if needed (usually implicit if update policy exists)
-- Just in case, grant update if not already
-- (Assuming standard policies interact with this)
