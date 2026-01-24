-- Enable the pg_net extension to allow HTTP requests from Postgres
CREATE EXTENSION IF NOT EXISTS "net";

-- Function to call the Edge Function for embedding generation
CREATE OR REPLACE FUNCTION public.trigger_profile_embedding()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger if bio or current_classes changed
  IF (TG_OP = 'INSERT') OR 
     (OLD.bio IS DISTINCT FROM NEW.bio) OR 
     (OLD.current_classes IS DISTINCT FROM NEW.current_classes) THEN
    
    PERFORM
      net.http_post(
        url := 'https://' || current_setting('request.headers')::json->>'host' || '/functions/v1/generate-profile-embedding',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('request.headers')::json->>'apikey'
        ),
        body := jsonb_build_object('record', row_to_json(NEW))
      );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automate embedding generation
DROP TRIGGER IF EXISTS on_profile_embedding_update ON public.profiles;
CREATE TRIGGER on_profile_embedding_update
  AFTER INSERT OR UPDATE OF bio, current_classes ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_profile_embedding();
