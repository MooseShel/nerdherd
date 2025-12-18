-- Trigger to call Edge Function on new Notification
-- Requires 'pg_net' extension to be enabled in Supabase

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.handle_new_notification_push()
RETURNS TRIGGER AS $$
DECLARE
    payload JSONB;
BEGIN
    -- Construct payload
    payload := jsonb_build_object(
        'record', row_to_json(NEW)
    );

    -- We will call the Edge Function 'push'

    
    -- EXECUTING PUSH NOTIFICATION
    -- IMPORTANT: Replace 'SUPABASE_SERVICE_ROLE_KEY' with your actual service role key securely.
    -- Ideally, use a transformation or a Vault for the key, but for this SQL script:
    
    PERFORM net.http_post(
        url := 'https://zzdasdmceaykwjsozums.supabase.co/functions/v1/push',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer SUPABASE_SERVICE_ROLE_KEY'
        ),
        body := payload
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger
DROP TRIGGER IF EXISTS trigger_push_on_notification ON public.notifications;

CREATE TRIGGER trigger_push_on_notification
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_notification_push();
