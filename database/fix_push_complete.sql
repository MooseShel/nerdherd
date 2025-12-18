-- =================================================================
-- COMPLETE PUSH NOTIFICATION FIX
-- Run this script in Supabase SQL Editor to fix all DB-side issues.
-- =================================================================

-- 1. Add FCM Token Column to Profiles (if missing)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);

-- 2. Create RPC to update FCM Token (Client calls this)
CREATE OR REPLACE FUNCTION public.update_fcm_token(token TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = token
  WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Ensure Notifications Table Exists
-- (Based on create_notifications.sql)
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, 
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB, 
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for Notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Policies for Notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications"
ON public.notifications FOR INSERT WITH CHECK (true);

-- 4. Create Triggers to Populated Notifications Table
-- (These generate the rows in 'notifications' table when events happen)

-- Helper: Create Notification Function
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  notification_id UUID;
  user_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO user_exists;
  IF user_exists THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (p_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO notification_id;
    RETURN notification_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: New Collab Request
CREATE OR REPLACE FUNCTION public.notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  IF receiver_exists THEN
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM public.profiles WHERE user_id = NEW.sender_id;
    PERFORM public.create_notification(
      NEW.receiver_id, 'request', 'New Collaboration Request', sender_name || ' wants to connect!', jsonb_build_object('request_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_new_request ON public.collab_requests;
CREATE TRIGGER trigger_notify_new_request AFTER INSERT ON public.collab_requests FOR EACH ROW EXECUTE FUNCTION public.notify_new_request();

-- Trigger: New Message
CREATE OR REPLACE FUNCTION public.notify_new_message() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  message_preview TEXT;
  receiver_exists BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  IF receiver_exists THEN
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM public.profiles WHERE user_id = NEW.sender_id;
    message_preview := CASE WHEN NEW.message_type = 'image' THEN '📷 Sent an image' WHEN LENGTH(NEW.content) > 50 THEN SUBSTRING(NEW.content, 1, 50) || '...' ELSE NEW.content END;
    PERFORM public.create_notification(
      NEW.receiver_id, 'message', sender_name, message_preview, jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_new_message ON public.messages;
CREATE TRIGGER trigger_notify_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();

-- Trigger: Request Accepted
CREATE OR REPLACE FUNCTION public.notify_request_accepted() RETURNS TRIGGER AS $$
DECLARE
  accepter_name TEXT;
  sender_exists BOOLEAN;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.sender_id) INTO sender_exists;
    IF sender_exists THEN
      SELECT COALESCE(full_name, intent_tag, 'Someone') INTO accepter_name FROM public.profiles WHERE user_id = NEW.receiver_id;
      PERFORM public.create_notification(
        NEW.sender_id, 'request_accepted', 'Request Accepted!', accepter_name || ' accepted your request.', jsonb_build_object('request_id', NEW.id, 'accepter_id', NEW.receiver_id)
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_request_accepted ON public.collab_requests;
CREATE TRIGGER trigger_notify_request_accepted AFTER UPDATE ON public.collab_requests FOR EACH ROW EXECUTE FUNCTION public.notify_request_accepted();


-- =================================================================
-- 5. TRIGGER FOR EDGE FUNCTION (WEBHOOK)
-- =================================================================
-- INSTRUCTIONS FOR USER:
-- We will NOT create a 'pg_net' trigger here because it requires hardcoding secrets in SQL.
-- Instead, use the Supabase Dashboard:
-- 1. Go to Database -> Webhooks.
-- 2. Create a new Webhook:
--    - Name: "Send Push Notification"
--    - Table: "notifications"
--    - Events: "INSERT"
--    - Type: "HTTP Request" (Edge Function)
--    - Method: POST
--    - URL: https://[YOUR-PROJECT-ID].supabase.co/functions/v1/push
--    - Headers: 
--       Authorization: Bearer [YOUR-SERVICE-ROLE-KEY]
-- =================================================================
