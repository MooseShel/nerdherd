-- Add university_id to profiles unique linkage
alter table public.profiles 
add column if not exists university_id uuid references public.universities(id) on delete set null;

-- Update RLS if needed (already covered by public profiles policy usually)
-- But ensuring it's updateable by user
create policy "Users can update own university" on public.profiles
  for update using (auth.uid() = user_id);
