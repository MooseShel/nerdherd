-- Create activation_requests table
CREATE TABLE IF NOT EXISTS public.activation_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.activation_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own requests (even if not active)
CREATE POLICY "Users can create activation requests" 
ON public.activation_requests 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own requests
CREATE POLICY "Users can view own activation requests" 
ON public.activation_requests 
FOR SELECT 
USING (auth.uid() = user_id);

-- Policy: Admins can view/update all
CREATE POLICY "Admins can view/update activation requests" 
ON public.activation_requests 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE user_id = auth.uid() AND is_admin = true
  )
);

DO $$
BEGIN
    RAISE NOTICE 'Created activation_requests table and policies.';
END $$;
