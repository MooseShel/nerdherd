-- Create the storage bucket 'verification_docs'
-- We insert into the internal storage.buckets table. 
-- Setting 'public' to true means files can be accessed via their public URL.
INSERT INTO storage.buckets (id, name, public)
VALUES ('verification_docs', 'verification_docs', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policy: Authenticated users can upload files
-- This allows any logged-in user to upload a document.
CREATE POLICY "Authenticated users can upload" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'verification_docs');

-- RLS Policy: Users can update their own files (optional, but good for retrying)
CREATE POLICY "Users can update own files" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'verification_docs' AND owner = auth.uid());

-- RLS Policy: Authenticated users can select (view/download) files
-- Since the bucket is public, the URL is public, but this allows API access (e.g. for the Admin panel to list/load them).
CREATE POLICY "Authenticated users can view" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'verification_docs');
