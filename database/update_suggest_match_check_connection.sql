-- ==============================================================================
-- OPTIMIZE MATCH WORKFLOW & NOTIFICATIONS
-- ==============================================================================

-- 1. UPDATE NOTIFICATION TRIGGER
-- Only notify for 'pending' requests. Auto-accepted ones should be silent (or handled differently).
CREATE OR REPLACE FUNCTION notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
BEGIN
  -- FILTER: Only notify if status is 'pending'
  IF NEW.status != 'pending' THEN
    RETURN NEW;
  END IF;

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


-- 2. UPDATE SUGGEST_MATCH RPC
-- Check for existing connection. If exists, auto-accept.
CREATE OR REPLACE FUNCTION public.suggest_match(
    target_user_id UUID,
    match_type TEXT,
    message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender_id UUID;
    v_match_id UUID;
    v_is_new BOOLEAN := FALSE;
    v_request_count INT;
    v_are_connected BOOLEAN := FALSE;
BEGIN
    v_sender_id := auth.uid();
    
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Auth UID is NULL. Cannot suggest match.';
    END IF;

    -- 0. CHECK FOR EXISTING CONNECTION
    SELECT EXISTS (
       SELECT 1 FROM public.connections
       WHERE (user_id_1 = LEAST(v_sender_id, target_user_id) 
          AND user_id_2 = GREATEST(v_sender_id, target_user_id))
    ) INTO v_are_connected;

    -- 1. Check if a match already exists (any orientation)
    SELECT id INTO v_match_id 
    FROM public.serendipity_matches
    WHERE (user_a = v_sender_id AND user_b = target_user_id)
       OR (user_a = target_user_id AND user_b = v_sender_id);

    IF v_match_id IS NULL THEN
        -- 2. Create New Match (Sender is ALWAYS user_a)
        INSERT INTO public.serendipity_matches (user_a, user_b, match_type, accepted, receiver_interested)
        VALUES (
            v_sender_id, 
            target_user_id, 
            match_type,
            v_are_connected, -- Auto-accept if connected
            v_are_connected  -- Auto-interest if connected
        )
        RETURNING id INTO v_match_id;
        v_is_new := TRUE;
    ELSE
        -- Update existing match if connected
        IF v_are_connected THEN
            UPDATE public.serendipity_matches
            SET accepted = TRUE,
                receiver_interested = TRUE
            WHERE id = v_match_id;
        END IF;
    END IF;

    -- 3. FORCED UPSERT: Ensure Collab Request always exists for this match
    -- If connected, status is 'accepted'. If not, 'pending'.
    INSERT INTO public.collab_requests (sender_id, receiver_id, status)
    VALUES (v_sender_id, target_user_id, CASE WHEN v_are_connected THEN 'accepted' ELSE 'pending' END)
    ON CONFLICT DO NOTHING;

    -- If no unique constraint, we just update existing ones
    UPDATE public.collab_requests 
    SET status = CASE WHEN v_are_connected THEN 'accepted' ELSE 'pending' END
    WHERE (sender_id = v_sender_id AND receiver_id = target_user_id)
       OR (sender_id = target_user_id AND receiver_id = v_sender_id);

    -- 4. DIAGNOSTIC: Count requests for this pair
    SELECT COUNT(*) INTO v_request_count 
    FROM public.collab_requests 
    WHERE (sender_id = v_sender_id AND receiver_id = target_user_id)
       OR (sender_id = target_user_id AND receiver_id = v_sender_id);

    RETURN jsonb_build_object(
        'success', true,
        'match_id', v_match_id,
        'is_new', v_is_new,
        'diag_request_count', v_request_count,
        'sender_id', v_sender_id,
        'receiver_id', target_user_id,
        'is_connected', v_are_connected
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
