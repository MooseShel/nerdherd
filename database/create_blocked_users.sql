-- Create blocked_users table
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    blocker_id uuid REFERENCES public.profiles(user_id) NOT NULL,
    blocked_id uuid REFERENCES public.profiles(user_id) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(blocker_id, blocked_id)
);

-- RLS Policies
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own blocks
CREATE POLICY "Users can view their own blocks"
ON public.blocked_users FOR SELECT
USING (auth.uid() = blocker_id);

-- Allow users to insert their own blocks
CREATE POLICY "Users can insert their own blocks"
ON public.blocked_users FOR INSERT
WITH CHECK (auth.uid() = blocker_id);

-- Allow users to delete their own blocks
CREATE POLICY "Users can delete their own blocks"
ON public.blocked_users FOR DELETE
USING (auth.uid() = blocker_id);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.blocked_users;
