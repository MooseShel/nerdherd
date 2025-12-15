-- Allow authenticated users to update study spots (for Summon Feature)
create policy "Study spots are updateable by logged in users"
  on public.study_spots
  for update
  to authenticated
  using (true)
  with check (true);

-- Ensure generated columns don't block updates (Postgres handles this generally)
-- The original table definition: generated always as (...) stored.
-- Postgres allows UPDATE as long as we don't try to set 'location' column explicitly to a value.
-- Our Dart code only sets 'lat' and 'long', so this strictly works.
