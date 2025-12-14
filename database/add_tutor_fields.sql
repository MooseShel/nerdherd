-- Add Tutor specific fields to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS hourly_rate INTEGER, -- Hourly rate in whole currency units (e.g. USD)
ADD COLUMN IF NOT EXISTS bio TEXT; -- Short bio for tutors
