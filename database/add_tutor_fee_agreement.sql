-- Migration: Add Tutor Fee Agreement Tracking
-- Adds a timestamp column to record when a user agreed to the platform fee.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS tutor_fee_agreed_at TIMESTAMPTZ;

-- Notify schema update
DO $$
BEGIN
    RAISE NOTICE 'Added tutor_fee_agreed_at to profiles table';
END $$;
