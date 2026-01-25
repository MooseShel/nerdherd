-- Drop the trigger that causes automatic AI invocation on every review insert.
-- This prevents double-charging (App + DB) and 429 errors.

DROP TRIGGER IF EXISTS on_review_submitted ON public.spot_reviews;
