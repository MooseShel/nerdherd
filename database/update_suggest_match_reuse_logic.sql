-- ==============================================================================
-- FIX SEQUENTIAL SOS MATCHES (RESET LOGIC)
-- ==============================================================================

-- Problem: If users matched before (but are NOT currently connected), a new SOS 
-- reuses the old 'accepted' match record without resetting it. 
-- The UI sees 'accepted=true' and prevents the handshake.

-- Fix: Explicitly RESET the match state if it exists and we are not connected.

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
        -- 2. Create New Match
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
        -- 2b. Existing Match Logic
        IF v_are_connected THEN
            -- If connected, ensure it looks accepted
            UPDATE public.serendipity_matches
            SET accepted = TRUE,
                receiver_interested = TRUE,
                match_type = match_type -- Update type to latest
            WHERE id = v_match_id;
        ELSE
            -- CRITICAL FIX: If NOT connected, RESET the match state to allow a new handshake.
            -- This handles the case where users matched before, disconnected (or session ended),
            -- and are now matching again.
            UPDATE public.serendipity_matches
            SET accepted = FALSE,
                receiver_interested = FALSE,
                match_type = match_type,
                created_at = NOW() -- Bump timestamp to show as new
            WHERE id = v_match_id;
        END IF;
    END IF;

    -- 3. FORCED UPSERT: Ensure Collab Request state matches our intent
    INSERT INTO public.collab_requests (sender_id, receiver_id, status)
    VALUES (v_sender_id, target_user_id, CASE WHEN v_are_connected THEN 'accepted' ELSE 'pending' END)
    ON CONFLICT DO NOTHING;

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
