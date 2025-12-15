-- Fix for Message Notifications
-- 1. Ensure message_type column exists (idempotent)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';

-- 2. Drop existing trigger and function to ensure clean slate
DROP TRIGGER IF EXISTS trigger_notify_new_message ON public.messages;
DROP FUNCTION IF EXISTS notify_new_message();

-- 3. Re-create the function with robust handling
CREATE OR REPLACE FUNCTION notify_new_message() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  message_preview TEXT;
  receiver_exists BOOLEAN;
  msg_type TEXT;
BEGIN
  -- Check if receiver exists
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  
  IF receiver_exists THEN
    -- Get sender name
    SELECT COALESCE(full_name, intent_tag, 'Someone')
    INTO sender_name
    FROM profiles
    WHERE user_id = NEW.sender_id;

    -- Safely access message_type if it exists in the record (PL/pgSQL handles this via NEW.column)
    -- We default to 'text' if null
    msg_type := COALESCE(NEW.message_type, 'text');

    -- Create preview
    message_preview := CASE
      WHEN msg_type = 'image' THEN '📷 Sent an image'
      WHEN LENGTH(NEW.content) > 50 THEN SUBSTRING(NEW.content, 1, 50) || '...'
      ELSE NEW.content
    END;

    -- Create notification
    PERFORM create_notification(
      NEW.receiver_id,
      'message',
      sender_name,
      message_preview,
      jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Swallow errors to prevent blocking message sending
  -- But log/raise notice could be useful for debugging
  RAISE WARNING 'Notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Re-attach trigger
CREATE TRIGGER trigger_notify_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();
