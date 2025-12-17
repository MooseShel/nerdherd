CREATE OR REPLACE FUNCTION get_available_subjects()
RETURNS TABLE (subject text)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    substring(code FROM '^[A-Za-z]+') AS subject
  FROM
    courses
  WHERE
    code ~ '^[A-Za-z]+'
  ORDER BY
    subject;
END;
$$;
