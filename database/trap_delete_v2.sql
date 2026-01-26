-- ==============================================================================
-- TRAP V2: REVEAL THE KILLER
-- ==============================================================================
-- We update the trap to show us the SQL query that triggered the delete.

CREATE OR REPLACE FUNCTION public.prevent_delete_trap()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION '🚫 TRAP TRIGGERED! Query that caused delete: "%"', current_query();
END;
$$ LANGUAGE plpgsql;

-- Ensure the trigger is still there (it should be, but just in case)
DROP TRIGGER IF EXISTS trap_delete_collab_requests ON public.collab_requests;

CREATE TRIGGER trap_delete_collab_requests
BEFORE DELETE ON public.collab_requests
FOR EACH ROW
EXECUTE FUNCTION public.prevent_delete_trap();
