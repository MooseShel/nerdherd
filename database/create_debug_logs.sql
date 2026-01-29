-- Migration: Create Debug Logs Table
-- Purpose: Capture application errors and fatals for remote debugging.

CREATE TABLE IF NOT EXISTS public.debug_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    level TEXT NOT NULL, -- e.g., 'error', 'fatal'
    message TEXT NOT NULL,
    error_details TEXT,
    stack_trace TEXT,
    platform TEXT, -- e.g., 'ios', 'android', 'web'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.debug_logs ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert their own logs
CREATE POLICY "Allow individual insert access for debug_logs"
    ON public.debug_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow admins (authenticated with service role or specific IDs if needed) to read logs
-- For now, just keep it restricted or allow read if user_id matches
CREATE POLICY "Allow individual read access for debug_logs"
    ON public.debug_logs FOR SELECT
    USING (auth.uid() = user_id);

-- Enable Realtime
alter publication supabase_realtime add table debug_logs;

COMMENT ON TABLE public.debug_logs IS 'Stores application error logs for remote diagnostic purposes.';
