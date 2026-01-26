-- ==============================================================================
-- FIX SUGGEST_MATCH: ALWAYS NEW HANDSHAKE
-- ==============================================================================

-- Requirement: "New SOS broadcast = Completely new request. Go through handshake workflow normally whether connected or not."
-- Logic: ALWAYS reset the match state to 'Pending' to force a fresh handshake.

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
        -- 2. Create Totally New Match
        INSERT INTO public.serendipity_matches (user_a, user_b, match_type, accepted, receiver_interested)
        VALUES (
            v_sender_id, 
            target_user_id, 
            match_type,
            FALSE, -- Always pending
            FALSE  -- Always pending
        )
        RETURNING id INTO v_match_id;
        v_is_new := TRUE;
    ELSE
        -- 2b. Existing Match Logic: FORCE RESET
        -- We treat this as a "Re-Match". We must clear the previous accepted state
        -- to allow the handshake (Interest -> Confirm) to happen again.
        UPDATE public.serendipity_matches
        SET accepted = FALSE,
            receiver_interested = FALSE,
            match_type = match_type,
            created_at = NOW() -- Bump timestamp to appear recent
        WHERE id = v_match_id;
    END IF;

    -- 3. FORCED UPDATE: Status is ALWAYS 'pending' for a new SOS
    INSERT INTO public.collab_requests (sender_id, receiver_id, status)
    VALUES (v_sender_id, target_user_id, 'pending')
    ON CONFLICT DO NOTHING;

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
