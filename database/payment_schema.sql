-- Payment / Wallet Integration Schema

-- Add wallet_balance to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC(10, 2) DEFAULT 0.00;

-- Create Transactions Table
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL, -- Positive for deposit, Negative for withdrawal/payment
    type TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal', 'payment', 'refund')),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- RLS Policies for Transactions
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own transactions
CREATE POLICY "Allow individual read access for transactions"
    ON public.transactions FOR SELECT
    USING (auth.uid() = user_id);

-- Allow users to insert their own transactions (for MVP simulation only)
-- In a real app, this would be server-side only to prevent fraud.
CREATE POLICY "Allow individual insert access for simulated transactions"
    ON public.transactions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Notify schema update
DO $$
BEGIN
    RAISE NOTICE 'Added wallet_balance and transactions table';
END $$;
