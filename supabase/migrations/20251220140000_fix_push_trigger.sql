-- Enable the pg_net extension to make HTTP requests
create extension if not exists "pg_net";

-- Function to handle new notification and call Edge Function
create or replace function public.handle_new_notification()
returns trigger as $$
declare
  PROJECT_REF text := 'PROJECT_REF_PLACEHOLDER'; -- Replace with your project ref (e.g. 'zzdasdmceaykwjsozums')
  ANON_KEY text := 'ANON_KEY_PLACEHOLDER'; -- Replace with your Anon Key
begin
  -- Call the Edge Function 'push'
  perform
    net.http_post(
      url := 'https://' || PROJECT_REF || '.supabase.co/functions/v1/push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || ANON_KEY
      ),
      body := jsonb_build_object(
        'record', row_to_json(new)
      )
    );
  
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to fire on INSERT to notifications table
drop trigger if exists on_new_notification on public.notifications;
create trigger on_new_notification
  after insert on public.notifications
  for each row execute procedure public.handle_new_notification();
