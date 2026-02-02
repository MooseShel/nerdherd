-- Function to physically delete spots that are scheduled for deletion and past due
CREATE OR REPLACE FUNCTION public.process_scheduled_deletions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT id, name 
        FROM public.study_spots 
        WHERE admin_deletion_scheduled_at IS NOT NULL 
          AND admin_deletion_scheduled_at <= NOW()
    LOOP
        DELETE FROM public.study_spots WHERE id = r.id;
        RAISE NOTICE 'Deleted scheduled spot: % (%)', r.name, r.id;
    END LOOP;
END;
$$;
