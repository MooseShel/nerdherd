-- Create the storage bucket 'spot_images'
INSERT INTO storage.buckets (id, name, public)
VALUES ('spot_images', 'spot_images', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policy: Authenticated users can upload spot images
DROP POLICY IF EXISTS "Authenticated users can upload spot images" ON storage.objects;
CREATE POLICY "Authenticated users can upload spot images" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'spot_images');

-- RLS Policy: Public View
DROP POLICY IF EXISTS "Spot images are publicly accessible" ON storage.objects;
CREATE POLICY "Spot images are publicly accessible" ON storage.objects
FOR SELECT
USING (bucket_id = 'spot_images');
