DO $$
DECLARE
    v_user_id UUID;
    v_token TEXT;
BEGIN
    -- 1. Find a user with a token
    SELECT user_id, fcm_token INTO v_user_id, v_token
    FROM public.profiles
    WHERE fcm_token IS NOT NULL
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '❌ No users found with login/FCM Token. Please Open the App and Login first to save your token!';
    ELSE
        RAISE NOTICE '✅ Found User: %', v_user_id;
        RAISE NOTICE 'ℹ️ Token starts with: %...', substring(v_token, 1, 15);
        
        -- 2. Insert Notification to trigger the Webhook
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (v_user_id, 'system_test', '🚀 Verification Test', 'If you see this, Push Notifications are working!', '{"test": "true"}');
        
        RAISE NOTICE '✅ Test Notification Inserted! Check your device now.';
    END IF;
END $$;
