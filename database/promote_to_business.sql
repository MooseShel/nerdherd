-- Promote 'Moose Business' to Business Owner
UPDATE public.profiles
SET is_business_owner = true
WHERE full_name = 'Moose Business';
