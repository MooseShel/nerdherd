-- Enable Storage Extension (usually enabled by default, but good to ensure)
-- create extension if not exists "storage" schema "extensions";

-- 1. Create the 'chat-images' bucket
insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do update set public = true;

-- 2. Enable RLS on objects (it is enabled by default for storage.objects)
-- alter table storage.objects enable row level security;

-- 3. Policy: Allow Public Read Access
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'chat-images' );

-- 4. Policy: Allow Authenticated Uploads
create policy "Authenticated Uploads"
on storage.objects for insert
with check (
  bucket_id = 'chat-images'
  and auth.role() = 'authenticated'
);

-- 5. Policy: Allow Users to Update/Delete their own files (optional depending on requirement)
create policy "Users can update own files"
on storage.objects for update
using (
  bucket_id = 'chat-images'
  and auth.uid() = owner
);

create policy "Users can delete own files"
on storage.objects for delete
using (
  bucket_id = 'chat-images'
  and auth.uid() = owner
);
