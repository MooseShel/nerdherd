-- ==========================================
-- PART 1: Schema Updates
-- ==========================================

-- Add FCM Token column to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);

-- ==========================================
-- PART 2: Security Functions
-- ==========================================

-- Function to update the FCM token for the current user safely
-- This is called by the Flutter app
CREATE OR REPLACE FUNCTION public.update_fcm_token(token TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = token
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- INSTRUCTIONS
-- ==========================================
-- Run this script in your Supabase SQL Editor.
-- After running this, go to:
-- Database -> Webhooks -> Create Webhook
-- Name: "Push Notification"
-- Table: "notifications"
-- Events: "INSERT"
-- Type: "HTTP Request"
-- URL: "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/push"
-- HTTP Method: POST
-- HTTP Headers: 
--    Authorization: Bearer <YOUR_SERVICE_ROLE_KEY>
