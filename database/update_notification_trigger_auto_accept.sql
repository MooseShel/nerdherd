-- ==============================================================================
-- UPDATE NOTIFICATION TRIGGER (HANDLE AUTO-ACCEPT)
-- ==============================================================================

CREATE OR REPLACE FUNCTION notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
  v_type TEXT;
  v_title TEXT;
  v_body TEXT;
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

    -- Determine Notification Content based on Status
    IF NEW.status = 'accepted' THEN
        -- Auto-Accepted (Friend SOS) case
        v_type := 'friend_sos';
        v_title := 'SOS from Friend! 🚨';
        v_body := sender_name || ' needs help! (Auto-Connected)';
    ELSIF NEW.status = 'pending' THEN
        -- Standard Request case
        v_type := 'request';
        v_title := 'New Collaboration Request';
        v_body := sender_name || ' wants to connect with you!';
    ELSE
        -- Ignore other statuses (rejected, etc)
        RETURN NEW;
    END IF;

    -- Create notification for receiver
    PERFORM create_notification(
      NEW.receiver_id,
      v_type,
      v_title,
      v_body,
      jsonb_build_object('request_id', NEW.id, 'sender_id', NEW.sender_id)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
