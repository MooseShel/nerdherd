-- ==============================================================================
-- SERENDIPITY ENGINE: TWO-STEP HANDSHAKE (FINAL STAGE)
-- ==============================================================================

-- 0. SCHEMA UPDATE
ALTER TABLE public.serendipity_matches ADD COLUMN IF NOT EXISTS receiver_interested BOOLEAN DEFAULT FALSE;

-- 0.1 SUGGEST MATCH (Stage 0: System or User finds a buddy)
-- LOGIC: 
-- - If Connected: Auto-Accept (Straight to Chat)
-- - If NOT Connected: Force Handshake (Reset to Pending)
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

    -- 1. Check if a match already exists
    SELECT id INTO v_match_id 
    FROM public.serendipity_matches
    WHERE (user_a = v_sender_id AND user_b = target_user_id)
       OR (user_a = target_user_id AND user_b = v_sender_id);

    IF v_match_id IS NULL THEN
        -- 2. Create New Match
        INSERT INTO public.serendipity_matches (user_a, user_b, match_type, accepted, receiver_interested)
        VALUES (
            v_sender_id, 
            target_user_id, 
            match_type,
            v_are_connected,
            v_are_connected
        )
        RETURNING id INTO v_match_id;
        v_is_new := TRUE;
    ELSE
        -- 2b. Existing Match Logic: SYNC STATE WITH CONNECTION
        UPDATE public.serendipity_matches
        SET accepted = v_are_connected,
            receiver_interested = v_are_connected,
            match_type = match_type,
            created_at = NOW() 
        WHERE id = v_match_id;
    END IF;

    -- 3. Sync Collab Request
    INSERT INTO public.collab_requests (sender_id, receiver_id, status)
    VALUES (v_sender_id, target_user_id, CASE WHEN v_are_connected THEN 'accepted' ELSE 'pending' END)
    ON CONFLICT DO NOTHING;

    UPDATE public.collab_requests 
    SET status = CASE WHEN v_are_connected THEN 'accepted' ELSE 'pending' END
    WHERE (sender_id = v_sender_id AND receiver_id = target_user_id)
       OR (sender_id = target_user_id AND receiver_id = v_sender_id);

    -- 4. DIAGNOSTIC
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


-- 1. EXPRESS INTEREST (Stage 1: Receiver clicks "Accept" -> I'm Interested)
CREATE OR REPLACE FUNCTION public.express_interest(
    target_match_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    match_record RECORD;
    v_sender_id UUID;
BEGIN
    SELECT * INTO match_record FROM public.serendipity_matches WHERE id = target_match_id;
    
    IF match_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- Update Match
    UPDATE public.serendipity_matches 
    SET receiver_interested = TRUE 
    WHERE id = target_match_id;

    -- Update Collab Request
    UPDATE public.collab_requests cr
    SET status = 'interested'
    WHERE 
        ((cr.sender_id = match_record.user_a AND cr.receiver_id = match_record.user_b) OR
         (cr.sender_id = match_record.user_b AND cr.receiver_id = match_record.user_a))
        AND cr.status = 'pending';

    -- Notify the Sender
    v_sender_id := match_record.user_a;
    PERFORM public.create_notification(
        v_sender_id,
        'buddy_interested',
        'Someone is interested! 🤩',
        'Review your study buddy requests to start chatting.',
        jsonb_build_object('match_id', target_match_id, 'interested_id', auth.uid())
    );

    RETURN jsonb_build_object('success', true, 'match_id', target_match_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 2. CONFIRM MATCH (Stage 2: Sender clicks "Confirm" -> Creates Connection & Chat)
CREATE OR REPLACE FUNCTION public.confirm_match(
    target_match_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    match_record RECORD;
BEGIN
    SELECT * INTO match_record FROM public.serendipity_matches WHERE id = target_match_id;
    
    IF match_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    IF auth.uid() != match_record.user_a THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the sender can confirm');
    END IF;

    -- Update Match
    UPDATE public.serendipity_matches SET accepted = TRUE WHERE id = target_match_id;

    -- Update Collab Request
    UPDATE public.collab_requests cr
    SET status = 'accepted'
    WHERE ((cr.sender_id = match_record.user_a AND cr.receiver_id = match_record.user_b) OR
           (cr.sender_id = match_record.user_b AND cr.receiver_id = match_record.user_a));
         
    IF NOT FOUND THEN
        INSERT INTO public.collab_requests (sender_id, receiver_id, status)
        VALUES (match_record.user_a, match_record.user_b, 'accepted');
    END IF;

    -- Create Connection
    INSERT INTO public.connections (user_id_1, user_id_2)
    VALUES (LEAST(match_record.user_a, match_record.user_b), GREATEST(match_record.user_a, match_record.user_b))
    ON CONFLICT DO NOTHING;

    -- Expire SOS
    UPDATE public.struggle_signals
    SET is_active = FALSE, expires_at = NOW()
    WHERE user_id = match_record.user_a AND is_active = TRUE;

    -- Notify Receiver
    PERFORM public.create_notification(
        match_record.user_b,
        'match_confirmed',
        'Match Confirmed! 🎉',
        'Your study buddy accepted! Start chatting now.',
        jsonb_build_object('match_id', target_match_id, 'confirmer_id', auth.uid())
    );

    RETURN jsonb_build_object('success', true, 'match_id', target_match_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 3. NOTIFICATION TRIGGER (For Collab Requests)
CREATE OR REPLACE FUNCTION notify_new_request() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  receiver_exists BOOLEAN;
  v_type TEXT;
  v_title TEXT;
  v_body TEXT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.receiver_id) INTO receiver_exists;
  
  IF receiver_exists THEN
    SELECT COALESCE(full_name, intent_tag, 'Someone') INTO sender_name FROM profiles WHERE user_id = NEW.sender_id;

    IF NEW.status = 'accepted' THEN
        v_type := 'friend_sos';
        v_title := 'SOS from Friend! 🚨';
        v_body := sender_name || ' needs help! (Auto-Connected)';
    ELSIF NEW.status = 'pending' THEN
        v_type := 'request';
        v_title := 'New Collaboration Request';
        v_body := sender_name || ' wants to connect with you!';
    ELSE
        RETURN NEW;
    END IF;

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
