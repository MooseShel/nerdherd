-- RPC Function to find semantic matches
CREATE OR REPLACE FUNCTION match_nerds(
  query_embedding vector(1536),
  match_threshold float,
  match_count int,
  min_social float DEFAULT 0.0,
  max_social float DEFAULT 1.0,
  min_temporal float DEFAULT 0.0,
  max_temporal float DEFAULT 1.0,
  target_university_id text DEFAULT NULL
) RETURNS TABLE (
  user_id uuid,
  full_name text,
  avatar_url text,
  bio text,
  similarity float,
  study_style_social float,
  study_style_temporal float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.full_name,
    p.avatar_url,
    p.bio,
    1 - (p.bio_embedding <=> query_embedding) AS similarity,
    p.study_style_social,
    p.study_style_temporal
  FROM public.profiles p
  WHERE 
    1 - (p.bio_embedding <=> query_embedding) > match_threshold
    AND p.study_style_social BETWEEN min_social AND max_social
    AND p.study_style_temporal BETWEEN min_temporal AND max_temporal
    AND (target_university_id IS NULL OR p.university_id = target_university_id)
    AND p.user_id != auth.uid() -- Exclude current user
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;
