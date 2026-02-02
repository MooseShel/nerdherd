-- Function to safely delete a spot as admin
-- If sponsored and active, it schedules deletion. Otherwise, deletes immediately.
CREATE OR REPLACE FUNCTION public.admin_delete_spot(
    p_admin_id UUID,
    p_spot_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_admin BOOLEAN;
    v_spot RECORD;
BEGIN
    -- 1. Verify Admin Status
    SELECT is_admin INTO v_is_admin
    FROM public.profiles
    WHERE user_id = p_admin_id;

    IF v_is_admin IS NOT TRUE THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- 2. Get Spot Details
    SELECT * INTO v_spot
    FROM public.study_spots
    WHERE id = p_spot_id;

    IF v_spot IS NULL THEN
        RAISE EXCEPTION 'Spot not found';
    END IF;

    -- 3. Check for Active Sponsorship
    -- Logic: Sponsored AND Expiry in Future
    IF v_spot.is_sponsored = true AND v_spot.sponsorship_expiry > NOW() THEN
        -- Schedule Deletion
        UPDATE public.study_spots
        SET 
            auto_renew = false, -- Disable auto-renew immediately
            admin_deletion_scheduled_at = v_spot.sponsorship_expiry
        WHERE id = p_spot_id;
        
        RETURN jsonb_build_object(
            'success', true, 
            'action', 'scheduled', 
            'message', 'Spot has active sponsorship. Scheduled for deletion on ' || v_spot.sponsorship_expiry,
            'scheduled_at', v_spot.sponsorship_expiry
        );
    ELSE
        -- Delete Immediately
        DELETE FROM public.study_spots
        WHERE id = p_spot_id;

        RETURN jsonb_build_object(
            'success', true, 
            'action', 'deleted', 
            'message', 'Spot deleted successfully.'
        );
    END IF;
END;
$$;
