-- Add payment fields to appointments table
ALTER TABLE public.appointments 
ADD COLUMN IF NOT EXISTS price DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT FALSE;

-- We don't strictly need a transaction_id FK if we just log it in the description, 
-- but keeping a reference could be useful. For MVP, we'll skip the strict FK constraint 
-- to keep it simple and just rely on the 'transactions' log.
