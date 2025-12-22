-- Migration to enable Revenue Tracking and Platform Fees

-- 1. Modify Transactions Table
-- Remove NOT NULL constraint from user_id to allow "System" transactions (where user_id is NULL)
ALTER TABLE public.transactions ALTER COLUMN user_id DROP NOT NULL;

-- 2. Update Transaction Type Check Constraint
-- We need to drop the old constraint and add a new updated one
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions 
ADD CONSTRAINT transactions_type_check 
CHECK (type IN ('deposit', 'withdrawal', 'payment', 'refund', 'earnings', 'platform_fee', 'subscription', 'ad_revenue'));

-- 3. Notify Admin
DO $$
BEGIN
    RAISE NOTICE 'Monetization schema updated: user_id allows NULL, new transaction types added.';
END $$;
