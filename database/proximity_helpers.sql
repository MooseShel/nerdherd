-- ============================================
-- SERENDIPITY PROXIMITY EXTENSIONS
-- ============================================

-- 1. Get Nearby Users (Optimized for Maching)
-- Returns users who are online/recent and nearby
CREATE OR REPLACE FUNCTION get_nearby_users_for_matching(
  p_lat FLOAT,
  p_long FLOAT,
  p_radius_meters FLOAT,
  p_exclude_user_id UUID
)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  distance_meters FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_point GEOGRAPHY;
BEGIN
  v_point := ST_SetSRID(ST_MakePoint(p_long, p_lat), 4326)::geography;

  RETURN QUERY
  SELECT
    p.user_id as id,
    p.full_name,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(p.long, p.lat), 4326)::geography,
      v_point
    ) as distance_meters
  FROM profiles p
  WHERE 
    p.user_id != p_exclude_user_id
    AND p.lat IS NOT NULL 
    AND p.long IS NOT NULL
    -- Only active users (updated recently, e.g. last hour) to avoid ghost matching
    AND p.last_updated > NOW() - INTERVAL '1 hour'
    -- Spatial Index Check
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(p.long, p.lat), 4326)::geography,
      v_point,
      p_radius_meters
    )
  ORDER BY distance_meters ASC
  LIMIT 5;
END;
$$;


-- 2. System Propose Match (Safe Wrapper)
-- Creates a match without requiring specific auth.uid() context
CREATE OR REPLACE FUNCTION system_propose_match(
  p_struggler_id UUID,
  p_helper_id UUID,
  p_reason TEXT,
  p_signal_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match_id UUID;
  v_exists BOOLEAN;
BEGIN
  -- Check if match already exists (recent)
  SELECT EXISTS (
    SELECT 1 FROM serendipity_matches
    WHERE 
      (user_a = p_struggler_id AND user_b = p_helper_id) OR 
      (user_a = p_helper_id AND user_b = p_struggler_id)
  ) INTO v_exists;

  IF v_exists THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_matched');
  END IF;

  -- Create Match
  INSERT INTO serendipity_matches (
    user_a, 
    user_b, 
    match_type, 
    accepted, 
    receiver_interested
  ) VALUES (
    p_struggler_id,
    p_helper_id,
    'proximity', -- System type
    FALSE,
    FALSE
  ) RETURNING id INTO v_match_id;

  -- Send Notification to HELPER (Standard Notification Flow)
  PERFORM create_notification(
    p_helper_id,
    'buddy_nearby', -- New Type
    'Someone nearby needs help! 🆘', 
    p_reason,
    jsonb_build_object(
       'match_id', v_match_id, 
       'struggler_id', p_struggler_id,
       'signal_id', p_signal_id
    )
  );
  
  -- Send Notification to STRUGGLER (Optional: "We found someone!")
  -- Maybe wait until helper accepts? Let's wait.

  RETURN jsonb_build_object('success', true, 'match_id', v_match_id);
END;
$$;
