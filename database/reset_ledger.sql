-- DANGER: This script resets the financial ledger!

-- 1. Clear Transactions (Table: 'transactions')
TRUNCATE TABLE public.transactions;

-- 2. Reset Wallet Balances to 0
UPDATE public.profiles
SET wallet_balance = 0.0;

-- 3. Enforce Non-Negative Balance Constraint
ALTER TABLE public.profiles 
  DROP CONSTRAINT IF EXISTS wallet_balance_non_negative;

ALTER TABLE public.profiles
  ADD CONSTRAINT wallet_balance_non_negative 
  CHECK (wallet_balance >= 0);
