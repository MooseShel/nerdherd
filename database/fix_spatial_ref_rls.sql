-- Enable RLS on spatial_ref_sys
ALTER TABLE IF EXISTS public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;

-- Allow read access to everyone (essential for PostGIS operations)
CREATE POLICY "Public read access"
ON public.spatial_ref_sys
FOR SELECT
USING (true);

-- No insert/update/delete policies created means default deny for everyone except superusers/service_role
