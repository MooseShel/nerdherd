-- Add admin_reply to support_tickets
ALTER TABLE public.support_tickets
ADD COLUMN IF NOT EXISTS admin_reply TEXT;

-- Create a view for Ledger if not exists (already handled by transactions table usually)
-- But ensuring ledger policies are robust
GRANT SELECT ON public.transactions TO authenticated;
