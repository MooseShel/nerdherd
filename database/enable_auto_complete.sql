-- 1. Ensure updated_at is actually updated
create extension if not exists moddatetime schema extensions;

-- Assuming stats/extensions schema, but trying standard public or extensions
-- If moddatetime is not available, we write a manual function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_appointments_updated_at ON public.appointments;

CREATE TRIGGER update_appointments_updated_at
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();


-- 2. Create the Auto-Complete Function
CREATE OR REPLACE FUNCTION auto_complete_stale_appointments()
RETURNS void AS $$
BEGIN
    -- Update appointments that have been pending completion for > 24 hours
    UPDATE public.appointments
    SET status = 'completed',
        updated_at = now() -- Explicitly set updated_at (though trigger handles it too)
    WHERE status = 'completion_pending'
    AND updated_at < (now() - INTERVAL '24 hours');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Schedule with pg_cron
-- Note: Requires pg_cron extension to be enabled in Supabase Dashboard -> Database -> Extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule to run every hour
-- Syntax: schedule(job_name, cron_schedule, command)
SELECT cron.schedule(
    'auto_complete_appointments', -- Job name
    '0 * * * *',                  -- Every hour
    'SELECT auto_complete_stale_appointments()'
);
