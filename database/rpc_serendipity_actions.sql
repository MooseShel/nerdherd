-- ==============================================================================
-- SERENDIPITY ENGINE: TWO-STEP HANDSHAKE (RPCs)
-- ==============================================================================

-- 0. SCHEMA UPDATE (Run this first if not already done)
-- ALTER TABLE public.serendipity_matches ADD COLUMN IF NOT EXISTS receiver_interested BOOLEAN DEFAULT FALSE;

-- 0.1 SUGGEST MATCH (Stage 0: System or User finds a buddy)
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
BEGIN
    v_sender_id := auth.uid();
    
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Auth UID is NULL. Cannot suggest match.';
    END IF;

    -- 1. Check if a match already exists (any orientation)
    SELECT id INTO v_match_id 
    FROM public.serendipity_matches
    WHERE (user_a = v_sender_id AND user_b = target_user_id)
       OR (user_a = target_user_id AND user_b = v_sender_id);

    IF v_match_id IS NULL THEN
        -- 2. Create New Match (Sender is ALWAYS user_a)
        INSERT INTO public.serendipity_matches (user_a, user_b, match_type)
        VALUES (v_sender_id, target_user_id, match_type)
        RETURNING id INTO v_match_id;
        v_is_new := TRUE;
    END IF;

    -- 3. FORCED UPSERT: Ensure Collab Request always exists for this match
    -- We'll use a more surgical approach than DELETE/INSERT to be extra safe
    INSERT INTO public.collab_requests (sender_id, receiver_id, status)
    VALUES (v_sender_id, target_user_id, 'pending')
    ON CONFLICT DO NOTHING; -- Assuming there might be a unique constraint we don't know about

    -- If no unique constraint, we just update existing ones to 'pending' to be sure
    UPDATE public.collab_requests 
    SET status = 'pending'
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
        'receiver_id', target_user_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 1. EXPRESS INTEREST (Stage 1: Receiver clicks "Accept" -> Now "I'm Interested")
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
    -- 1. Get Match Details
    SELECT * INTO match_record FROM public.serendipity_matches WHERE id = target_match_id;
    
    IF match_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- 2. Update Match to Interested
    UPDATE public.serendipity_matches 
    SET receiver_interested = TRUE 
    WHERE id = target_match_id;

    -- 3. Update Collab Request
    UPDATE public.collab_requests cr
    SET status = 'interested'
    WHERE 
        ((cr.sender_id = match_record.user_a AND cr.receiver_id = match_record.user_b) OR
         (cr.sender_id = match_record.user_b AND cr.receiver_id = match_record.user_a))
        AND cr.status = 'pending';

    -- 4. Notify the Sender (The person who created the SOS)
    -- The sender is ALWAYS user_a in our current suggest_match logic
    v_sender_id := match_record.user_a;

    PERFORM public.create_notification(
        v_sender_id,
        'buddy_interested',
        'Someone is interested! 🤩',
        'Review your study buddy requests to start chatting.',
        jsonb_build_object('match_id', target_match_id, 'interested_id', auth.uid())
    );

    RETURN jsonb_build_object(
        'success', true, 
        'match_id', target_match_id,
        'receiver_interested', true
    );

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
    updated_match_row RECORD;
    v_receiver_id UUID;
    rows_updated INT;
BEGIN
    -- 1. Get Match Details
    SELECT * INTO match_record FROM public.serendipity_matches WHERE id = target_match_id;
    
    IF match_record IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    -- SECURITY: Only the sender (user_a) can confirm the match
    IF auth.uid() != match_record.user_a THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the sender can confirm this match');
    END IF;

    -- 2. Update Match to Accepted
    UPDATE public.serendipity_matches 
    SET accepted = TRUE 
    WHERE id = target_match_id
    RETURNING * INTO updated_match_row;

    GET DIAGNOSTICS rows_updated = ROW_COUNT;

    -- 3. Update Collab Request (Robust Upsert)
    -- Even if it was deleted, we recreate it as accepted for history
    UPDATE public.collab_requests cr
    SET status = 'accepted'
    WHERE 
        ((cr.sender_id = match_record.user_a AND cr.receiver_id = match_record.user_b) OR
         (cr.sender_id = match_record.user_b AND cr.receiver_id = match_record.user_a));
         
    IF NOT FOUND THEN
        INSERT INTO public.collab_requests (sender_id, receiver_id, status)
        VALUES (match_record.user_a, match_record.user_b, 'accepted');
    END IF;

    -- 4. Create Connection (Atomic)
    IF match_record.user_a < match_record.user_b THEN
        INSERT INTO public.connections (user_id_1, user_id_2)
        VALUES (match_record.user_a, match_record.user_b)
        ON CONFLICT DO NOTHING;
    ELSE
        INSERT INTO public.connections (user_id_1, user_id_2)
        VALUES (match_record.user_b, match_record.user_a)
        ON CONFLICT DO NOTHING;
    END IF;

    -- 5. EXPIRE STRUGGLE SIGNALS (SOS) for the sender
    UPDATE public.struggle_signals
    SET is_active = FALSE, expires_at = NOW()
    WHERE user_id = match_record.user_a AND is_active = TRUE;

    -- 6. Notify the Receiver
    v_receiver_id := match_record.user_b;

    PERFORM public.create_notification(
        v_receiver_id,
        'match_confirmed',
        'Match Confirmed! 🎉',
        'Your study buddy accepted! Start chatting now.',
        jsonb_build_object('match_id', target_match_id, 'confirmer_id', auth.uid())
    );

    -- 7. CLEANUP: Clear notifications for the sender regarding "interested"
    DELETE FROM public.notifications 
    WHERE user_id = auth.uid() 
    AND type = 'buddy_interested'
    AND (data->>'match_id')::uuid = target_match_id;

    RETURN jsonb_build_object(
        'success', true, 
        'match_id', updated_match_row.id, 
        'final_accepted_status', updated_match_row.accepted
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
