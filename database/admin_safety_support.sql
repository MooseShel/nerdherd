-- 1. Add Verification Status to Profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_verified_tutor BOOLEAN DEFAULT FALSE;

-- 2. Create Announcements Table
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read active announcements
CREATE POLICY "Everyone can read announcements" 
ON public.announcements FOR SELECT 
USING (true);

-- Policy: Only Admins can insert/update/delete
CREATE POLICY "Admins can manage announcements"
ON public.announcements FOR ALL
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);

-- 3. Create Reports Table
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id UUID REFERENCES public.profiles(user_id) NOT NULL,
    reported_id UUID REFERENCES public.profiles(user_id) NOT NULL,
    reason TEXT NOT NULL,
    status TEXT CHECK (status IN ('pending', 'resolved', 'dismissed')) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create reports
CREATE POLICY "Users can create reports" 
ON public.reports FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = reporter_id);

-- Policy: Admins can view/update reports
CREATE POLICY "Admins can view reports"
ON public.reports FOR SELECT
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);

CREATE POLICY "Admins can update reports"
ON public.reports FOR UPDATE
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);


-- 4. Create Support Tickets Table
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(user_id) NOT NULL,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT CHECK (status IN ('open', 'in_progress', 'closed')) DEFAULT 'open',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create their own tickets
CREATE POLICY "Users can create support tickets"
ON public.support_tickets FOR INSERT
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own tickets
CREATE POLICY "Users can view own tickets"
ON public.support_tickets FOR SELECT
TO authenticated 
USING (auth.uid() = user_id);

-- Policy: Admins can view/update all tickets
CREATE POLICY "Admins can view all tickets"
ON public.support_tickets FOR SELECT
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);

CREATE POLICY "Admins can update tickets"
ON public.support_tickets FOR UPDATE
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);

-- Enable Realtime for new tables
alter publication supabase_realtime add table public.announcements;
alter publication supabase_realtime add table public.reports;
alter publication supabase_realtime add table public.support_tickets;

-- Admin Policy for Ledger (Transactions)
CREATE POLICY "Admins can view all transactions"
ON public.transactions FOR SELECT
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);
