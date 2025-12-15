-- FIX ALL NOTIFICATIONS
-- Run this to ensure Appointment and Message notifications work!

-- 1. Helper: Create Notification Function
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
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = p_user_id) INTO user_exists;
  
  IF user_exists THEN
    INSERT INTO notifications (user_id, type, title, body, data)
    VALUES (p_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO notification_id;
    RETURN notification_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Trigger for NEW MESSAGES (Chat)
DROP TRIGGER IF EXISTS trigger_notify_new_message ON messages;
DROP FUNCTION IF EXISTS notify_new_message();

CREATE OR REPLACE FUNCTION notify_new_message() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  message_preview TEXT;
  receiver_exists BOOLEAN;
BEGIN
  -- Check if receiver exists
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  
  IF receiver_exists THEN
    -- Get sender name
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM profiles WHERE user_id = NEW.sender_id;

    -- Preview
    message_preview := NEW.content;
    IF LENGTH(message_preview) > 50 THEN
        message_preview := SUBSTRING(message_preview, 1, 50) || '...';
    END IF;

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


-- 3. Trigger for APPOINTMENT EVENTS (Request, Accept, Cancel, Reschedule)
DROP TRIGGER IF EXISTS trigger_notify_appt_request ON appointments;
DROP TRIGGER IF EXISTS trigger_notify_appt_update ON appointments;
DROP TRIGGER IF EXISTS trigger_notify_appt_event ON appointments;
DROP FUNCTION IF EXISTS notify_appointment_event();

CREATE OR REPLACE FUNCTION notify_appointment_event() RETURNS TRIGGER AS $$
DECLARE
  host_name TEXT;
  attendee_name TEXT;
  sender_name TEXT;
BEGIN
  -- Get Names
  SELECT COALESCE(full_name, intent_tag, 'Tutor') INTO host_name FROM profiles WHERE user_id = NEW.host_id;
  SELECT COALESCE(full_name, intent_tag, 'Student') INTO attendee_name FROM profiles WHERE user_id = NEW.attendee_id;

  -- A) INSERT (New Request)
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
     -- Notify Host
     PERFORM create_notification(
       NEW.host_id,
       'appointment_request',
       'New Session Request',
       attendee_name || ' requested a session with you.',
       jsonb_build_object('appointment_id', NEW.id)
     );
  END IF;

  -- B) UPDATE
  IF TG_OP = 'UPDATE' THEN
     -- 1. Confirmed
     IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
       PERFORM create_notification(
         NEW.attendee_id,
         'appointment_confirmed',
         'Session Confirmed',
         host_name || ' accepted your request!',
         jsonb_build_object('appointment_id', NEW.id)
       );
     END IF;

     -- 2. Declined
     IF NEW.status = 'declined' AND OLD.status = 'pending' THEN
       PERFORM create_notification(
         NEW.attendee_id,
         'appointment_declined',
         'Session Declined',
         host_name || ' declined your request.',
         jsonb_build_object('appointment_id', NEW.id)
       );
     END IF;

     -- 3. Cancelled (Notify Both to be safe, filtering out "me" is hard in trigger w/o context, so we notify both)
     IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
       -- Notify Host
       PERFORM create_notification(
         NEW.host_id,
         'appointment_cancelled',
         'Session Cancelled',
         'Session with ' || attendee_name || ' was cancelled.',
         jsonb_build_object('appointment_id', NEW.id)
       );
       -- Notify Attendee
       PERFORM create_notification(
         NEW.attendee_id,
         'appointment_cancelled',
         'Session Cancelled',
         'Session with ' || host_name || ' was cancelled.',
         jsonb_build_object('appointment_id', NEW.id)
       );
     END IF;
     
     -- 4. Rescheduled (Confirmed -> Pending with time change)
     IF NEW.status = 'pending' AND OLD.status = 'confirmed' THEN
         PERFORM create_notification(
           NEW.host_id,
           'appointment_rescheduled',
           'Session Rescheduled',
           'Session with ' || attendee_name || ' details changed. Please review.',
           jsonb_build_object('appointment_id', NEW.id)
         );
         PERFORM create_notification(
           NEW.attendee_id,
           'appointment_rescheduled',
           'Session Rescheduled',
           'Session with ' || host_name || ' details changed. Please review.',
           jsonb_build_object('appointment_id', NEW.id)
         );
     END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_appt_event
AFTER INSERT OR UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION notify_appointment_event();
