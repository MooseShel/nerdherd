-- Notifications System - Clean Migration (Idempotent)
-- This script can be run multiple times safely

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_notify_new_request ON collab_requests;
DROP TRIGGER IF EXISTS trigger_notify_new_message ON messages;
DROP TRIGGER IF EXISTS trigger_notify_request_accepted ON collab_requests;

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS notify_new_request();
DROP FUNCTION IF EXISTS notify_new_message();
DROP FUNCTION IF EXISTS notify_request_accepted();
DROP FUNCTION IF EXISTS create_notification(UUID, TEXT, TEXT, TEXT, JSONB);

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;

-- 1. Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL, -- 'request', 'message', 'request_accepted', 'request_rejected'
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB, -- Additional data (e.g., sender_id, request_id, etc.)
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only view their own notifications
CREATE POLICY "Users can view own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
ON notifications FOR UPDATE
USING (auth.uid() = user_id);

-- System can insert notifications (via triggers)
CREATE POLICY "System can insert notifications"
ON notifications FOR INSERT
WITH CHECK (true);

-- 2. Function to create notification (with user existence check)
CREATE OR REPLACE FUNCTION create_notification(
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
  -- Check if user exists in auth.users
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO user_exists;
  
  -- Only create notification if user exists
  IF user_exists THEN
    INSERT INTO notifications (user_id, type, title, body, data)
    VALUES (p_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
  ELSE
    -- User doesn't exist, skip notification creation
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger for new collaboration requests
CREATE OR REPLACE FUNCTION notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
BEGIN
  -- Check if receiver exists in auth.users
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  
  -- Only create notification if receiver is a real user
  IF receiver_exists THEN
    -- Get sender's name
    SELECT COALESCE(full_name, intent_tag, 'Someone')
    INTO sender_name
    FROM profiles
    WHERE user_id = NEW.sender_id;

    -- Create notification for receiver
    PERFORM create_notification(
      NEW.receiver_id,
      'request',
      'New Collaboration Request',
      sender_name || ' wants to connect with you!',
      jsonb_build_object('request_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_new_request
AFTER INSERT ON collab_requests
FOR EACH ROW
EXECUTE FUNCTION notify_new_request();

-- 4. Trigger for new messages
CREATE OR REPLACE FUNCTION notify_new_message() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  message_preview TEXT;
  receiver_exists BOOLEAN;
BEGIN
  -- Check if receiver exists in auth.users
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  
  -- Only create notification if receiver is a real user
  IF receiver_exists THEN
    -- Get sender's name
    SELECT COALESCE(full_name, intent_tag, 'Someone')
    INTO sender_name
    FROM profiles
    WHERE user_id = NEW.sender_id;

    -- Create message preview
    message_preview := CASE
      WHEN NEW.message_type = 'image' THEN '📷 Sent an image'
      WHEN LENGTH(NEW.content) > 50 THEN SUBSTRING(NEW.content, 1, 50) || '...'
      ELSE NEW.content
    END;

    -- Create notification for receiver
    PERFORM create_notification(
      NEW.receiver_id,
      'message',
      sender_name,
      message_preview,
      jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_new_message
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION notify_new_message();

-- 5. Trigger for request accepted
CREATE OR REPLACE FUNCTION notify_request_accepted() RETURNS TRIGGER AS $$
DECLARE
  accepter_name TEXT;
  sender_exists BOOLEAN;
BEGIN
  -- Only notify on status change to accepted
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    -- Check if sender exists in auth.users
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.sender_id) INTO sender_exists;
    
    -- Only create notification if sender is a real user
    IF sender_exists THEN
      -- Get the person who accepted (receiver)
      SELECT COALESCE(full_name, intent_tag, 'Someone')
      INTO accepter_name
      FROM profiles
      WHERE user_id = NEW.receiver_id;

      -- Notify the original sender
      PERFORM create_notification(
        NEW.sender_id,
        'request_accepted',
        'Request Accepted!',
        accepter_name || ' accepted your collaboration request',
        jsonb_build_object('request_id', NEW.id, 'accepter_id', NEW.receiver_id)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_request_accepted
AFTER UPDATE ON collab_requests
FOR EACH ROW
EXECUTE FUNCTION notify_request_accepted();

-- 6. Index for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read) WHERE read = false;
