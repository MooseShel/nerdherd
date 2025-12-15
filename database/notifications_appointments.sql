-- Notifications for Appointments

-- 1. Trigger for New Appointment Request
CREATE OR REPLACE FUNCTION notify_appointment_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
BEGIN
  -- Notify Host (Tutor)
  IF NEW.status = 'pending' AND (OLD.status IS NULL OR OLD.status != 'pending') THEN
    SELECT COALESCE(full_name, intent_tag, 'A Student') INTO sender_name FROM profiles WHERE user_id = NEW.attendee_id;
    
    PERFORM create_notification(
      NEW.host_id,
      'appointment_request',
      'New Session Request',
      sender_name || ' requested a session with you.',
      jsonb_build_object('appointment_id', NEW.id, 'role', 'host')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_appt_request
AFTER INSERT ON appointments
FOR EACH ROW
EXECUTE FUNCTION notify_appointment_request();


-- 2. Trigger for Appointment Updates (Accept, Decline, Cancel, Reschedule)
CREATE OR REPLACE FUNCTION notify_appointment_update() RETURNS TRIGGER AS $$
DECLARE
  host_name TEXT;
  attendee_name TEXT;
  actor_name TEXT; -- logic to guess who did it? Not easy in trigger without current_setting('request.jwt.claim.sub') or assuming status flow.
  -- Simplified logic based on status transition
BEGIN
  -- Get names
  SELECT COALESCE(full_name, intent_tag, 'Tutor') INTO host_name FROM profiles WHERE user_id = NEW.host_id;
  SELECT COALESCE(full_name, intent_tag, 'Student') INTO attendee_name FROM profiles WHERE user_id = NEW.attendee_id;

  -- Case 1: Confirmed (Accepted) -> Notify Attendee
  IF NEW.status = 'confirmed' AND OLD.status = 'pending' THEN
    PERFORM create_notification(
      NEW.attendee_id,
      'appointment_confirmed',
      'Session Confirmed!',
      host_name || ' accepted your session request.',
      jsonb_build_object('appointment_id', NEW.id)
    );
  END IF;

  -- Case 2: Declined -> Notify Attendee
  IF NEW.status = 'declined' AND OLD.status = 'pending' THEN
    PERFORM create_notification(
      NEW.attendee_id,
      'appointment_declined',
      'Session Declined',
      host_name || ' declined your session request.',
      jsonb_build_object('appointment_id', NEW.id)
    );
  END IF;

  -- Case 3: Cancelled -> Notify the *other* party?
  -- Hard to know who cancelled without context, usually the one who ISN'T the trigger user.
  -- But in a trigger we don't always know who the auth user is reliably if service role used.
  -- However, assumes standard flow:
  -- We'll just notify BOTH (except the one acting, if we can imply. If not, safe to notify both or just the 'victim').
  -- Actually, let's look at the implementation. Tutors Only Cancel Confirmed. Students Cancel Pending/Confirmed.
  -- We'll simply notify both "Session Cancelled" to be safe, or just relying on "User seeing status".
  -- For better UX, let's try to notify the 'other' party.
  -- We will rely on the app to send specific notifications? NO, user asked for "enabled for all actions".
  -- Let's try to infer or just generic notification.
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
     -- Generic message to Host
     PERFORM create_notification(
       NEW.host_id,
       'appointment_cancelled',
       'Session Cancelled',
       'A session with ' || attendee_name || ' was cancelled.',
       jsonb_build_object('appointment_id', NEW.id)
     );
     -- Generic message to Attendee
     PERFORM create_notification(
       NEW.attendee_id,
       'appointment_cancelled',
       'Session Cancelled',
       'A session with ' || host_name || ' was cancelled.',
       jsonb_build_object('appointment_id', NEW.id)
     );
  END IF;

  -- Case 4: Rescheduled (Pending again) -> Notify the OTHER party. 
  -- We assume the *Actor* is the one who updated it. The *Other* needs to know.
  -- But Trigger doesn't know who Actor is. 
  -- We'll check if START TIME changed.
  IF NEW.start_time != OLD.start_time AND NEW.status = 'pending' AND OLD.status = 'confirmed' THEN
     -- Reschedule happened. Assuming Initiator is the one who triggered update.
     -- We can't distinguish easily. 
     -- We will send a generic "Session Rescheduled" to both? No that's noisy.
     -- Let's assume for now the App handles the UX, but for "Notifications enabled", we can just notify "Session Details Changed".
     -- Actually, in our current UI, only "Reschedule" button does this transition (Confirmed -> Pending + New Time).
     -- And currently only Tutors (Host) or Students? Checked code: Both have Reschedule button.
     -- We will notify BOTH to be safe: "Session Rescheduled: Please review."
     PERFORM create_notification(
       NEW.host_id,
       'appointment_rescheduled',
       'Session Rescheduled',
       'Session with ' || attendee_name || ' was rescheduled. Please review.',
       jsonb_build_object('appointment_id', NEW.id)
     );
      PERFORM create_notification(
       NEW.attendee_id,
       'appointment_rescheduled',
       'Session Rescheduled',
       'Session with ' || host_name || ' was rescheduled. Please review.',
       jsonb_build_object('appointment_id', NEW.id)
     );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_appt_update
AFTER UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION notify_appointment_update();
