-- ==============================================================================
-- DEPLOY ENHANCED RPC FUNCTIONS FOR DEBUGGING
-- ==============================================================================
-- Run this in Supabase SQL Editor to deploy the debug versions

-- First, ensure the receiver_interested column exists
ALTER TABLE public.serendipity_matches 
ADD COLUMN IF NOT EXISTS receiver_interested BOOLEAN DEFAULT FALSE;

-- Now deploy the enhanced functions (copy from rpc_serendipity_actions_debug.sql)
-- This is a deployment wrapper that includes all necessary setup

\i rpc_serendipity_actions_debug.sql

-- Verify deployment
SELECT 
    routine_name,
    routine_type,
    security_type,
    obj_description(oid, 'pg_proc') as description
FROM information_schema.routines r
JOIN pg_proc p ON p.proname = r.routine_name
WHERE routine_schema = 'public'
  AND routine_name IN ('suggest_match', 'express_interest', 'confirm_match')
ORDER BY routine_name;

-- Show current RLS policies
SELECT 
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'serendipity_matches'
ORDER BY policyname;
