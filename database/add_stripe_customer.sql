-- Add stripe_customer_id to profiles table to link App User -> Stripe Customer
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS stripe_customer_id text;

-- Add index for performance (lookup by stripe id)
CREATE INDEX IF NOT EXISTS idx_profiles_stripe_customer_id 
ON public.profiles(stripe_customer_id);

-- Comment
COMMENT ON COLUMN public.profiles.stripe_customer_id IS 'Linking ID for Stripe Customer object (cus_...)';
