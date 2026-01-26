-- ==============================================================================
-- TRAP: BLOCK ALL DELETIONS ON COLLAB_REQUESTS
-- ==============================================================================
-- Since the data keeps vanishing, we will forbid DELETES entirely.
-- This will cause whatever is trying to delete the record to crash with an error.

CREATE OR REPLACE FUNCTION public.prevent_delete_trap()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION '🚫 SYSTEM TRAP: Deletion attempted on collab_request (%)! Blocked.', OLD.id;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trap_delete_collab_requests ON public.collab_requests;

CREATE TRIGGER trap_delete_collab_requests
BEFORE DELETE ON public.collab_requests
FOR EACH ROW
EXECUTE FUNCTION public.prevent_delete_trap();
