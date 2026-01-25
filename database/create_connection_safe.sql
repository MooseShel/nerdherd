-- Create a database function that safely creates connections without throwing duplicate key errors
CREATE OR REPLACE FUNCTION public.create_connection_safe(
  uid1 uuid,
  uid2 uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Use ON CONFLICT DO NOTHING to silently handle duplicates
  INSERT INTO public.connections (user_id_1, user_id_2)
  VALUES (uid1, uid2)
  ON CONFLICT (user_id_1, user_id_2) DO NOTHING;
  
  -- Always return true since either it was inserted or already exists
  RETURN true;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't throw
    RAISE WARNING 'Error in create_connection_safe: %', SQLERRM;
    RETURN false;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_connection_safe(uuid, uuid) TO authenticated;
