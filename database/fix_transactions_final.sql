-- 1. Ensure user_id allows NULL for system transactions
ALTER TABLE public.transactions ALTER COLUMN user_id DROP NOT NULL;

-- 2. Drop old constraint
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

-- 3. Add comprehensive constraint with all used types
ALTER TABLE public.transactions 
ADD CONSTRAINT transactions_type_check 
CHECK (type IN (
    'deposit', 
    'withdrawal', 
    'payment', 
    'refund', 
    'earnings', 
    'platform_fee', 
    'subscription', 
    'ad_revenue',
    'sponsorship_fee',
    'platform_revenue'
));
