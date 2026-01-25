-- Trigger function to call summarize-spot-reviews Edge Function
CREATE OR REPLACE FUNCTION public.trigger_spot_summary()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM
    net.http_post(
      url := 'https://' || current_setting('request.headers')::json->>'host' || '/functions/v1/summarize-spot-reviews',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('request.headers')::json->>'apikey'
      ),
      body := jsonb_build_object('record', row_to_json(NEW))
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on every new review
DROP TRIGGER IF EXISTS on_review_submitted ON public.spot_reviews;
-- TRIGGER DISABLED to prevent 429 errors (Double Invocation with Client)
-- CREATE TRIGGER on_review_submitted
--   AFTER INSERT ON public.spot_reviews
--   FOR EACH ROW
--   EXECUTE FUNCTION public.trigger_spot_summary();
