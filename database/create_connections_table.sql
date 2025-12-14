-- Create connections table
CREATE TABLE IF NOT EXISTS public.connections (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id_1 uuid REFERENCES public.profiles(user_id) NOT NULL,
    user_id_2 uuid REFERENCES public.profiles(user_id) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id_1, user_id_2)
);

-- RLS Policies
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own connections (as either party)
CREATE POLICY "Users can view their own connections"
ON public.connections FOR SELECT
USING (auth.uid() = user_id_1 OR auth.uid() = user_id_2);

-- Allow users to insert connections (usually handled by server function, but for client-side accept:)
-- We only allow insertion if the user is one of the parties (usually the one accepting, i.e. user_id_2 is me, or I'm creating it)
CREATE POLICY "Users can insert connections involving themselves"
ON public.connections FOR INSERT
WITH CHECK (auth.uid() = user_id_1 OR auth.uid() = user_id_2);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
