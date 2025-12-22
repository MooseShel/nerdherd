DO $$
DECLARE
    target_user_id UUID;
BEGIN
    -- 1. Get the user_id for 'Moose Business'
    SELECT user_id INTO target_user_id
    FROM public.profiles
    WHERE full_name = 'Moose Business'
    LIMIT 1;

    -- Check if user was found
    IF target_user_id IS NOT NULL THEN
        -- 2. Update all study spots to be owned by this user
        UPDATE public.study_spots
        SET owner_id = target_user_id;
        
        RAISE NOTICE 'Assigned all study spots to Moose Business (%)', target_user_id;
    ELSE
        RAISE WARNING 'User "Moose Business" not found.';
    END IF;
END $$;
