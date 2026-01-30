-- RPC for finding classmates (enrolled in the same courses)
CREATE OR REPLACE FUNCTION match_classmates(
  target_user_id UUID,
  target_university_id UUID,
  match_count INT DEFAULT 10
) RETURNS TABLE (
  u_user_id UUID,
  u_full_name TEXT,
  u_avatar_url TEXT,
  u_intent_tag TEXT,
  u_is_tutor BOOLEAN,
  matching_course_code TEXT,
  matching_course_title TEXT,
  dist_meters FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH my_courses AS (
    SELECT course_id FROM user_courses WHERE user_id = target_user_id
  ),
  classmates AS (
    SELECT DISTINCT uc.user_id, c.course_code, c.title
    FROM user_courses uc
    JOIN courses c ON uc.course_id = c.id
    WHERE uc.course_id IN (SELECT course_id FROM my_courses)
      AND uc.user_id != target_user_id
      AND c.university_id = target_university_id
  )
  SELECT 
    p.user_id,
    p.full_name,
    p.avatar_url,
    p.intent_tag,
    p.is_tutor,
    cl.course_code,
    cl.title,
    ST_Distance(p.location_geom, qp.location_geom) as dist_meters
  FROM profiles p
  JOIN classmates cl ON p.user_id = cl.user_id
  JOIN profiles qp ON qp.user_id = target_user_id
  WHERE p.university_id = target_university_id::text -- university_id is TEXT in profiles
  ORDER BY dist_meters ASC NULLS LAST
  LIMIT match_count;
END;
$$;
