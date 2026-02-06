-- RPC to delete own account
-- This function deletes the user from auth.users and explicitly cleans up all related data in public tables.

CREATE OR REPLACE FUNCTION delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id uuid;
BEGIN
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete from each table, ignoring errors if table/column doesn't exist
  -- This makes the function resilient to schema differences
  
  BEGIN
    DELETE FROM public.struggle_signals WHERE user_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.user_skills WHERE user_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.spot_reviews WHERE user_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.activation_requests WHERE user_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.notifications WHERE user_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  -- Bi-directional tables (delete if user is EITHER party)
  BEGIN
    DELETE FROM public.connections WHERE user_id_1 = current_user_id OR user_id_2 = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.serendipity_matches WHERE user_id_1 = current_user_id OR user_id_2 = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.collab_requests WHERE sender_id = current_user_id OR receiver_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.messages WHERE sender_id = current_user_id OR receiver_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.appointments WHERE student_id = current_user_id OR tutor_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;
  
  BEGIN
    DELETE FROM public.blocked_users WHERE blocker_id = current_user_id OR blocked_id = current_user_id;
  EXCEPTION WHEN undefined_table OR undefined_column THEN NULL;
  END;

  -- Delete from public.profiles (required)
  DELETE FROM public.profiles WHERE user_id = current_user_id;
  
  -- Delete from auth.users (required)
  DELETE FROM auth.users WHERE id = current_user_id;
END;
$$;
