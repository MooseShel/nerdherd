-- Admin RLS Policies

-- Policy: Admins can update any profile (e.g., to ban users)
CREATE POLICY "Allow admins to update any profile"
ON public.profiles
FOR UPDATE
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);

-- Policy: Admins can delete any profile (optional, but good for moderation)
CREATE POLICY "Allow admins to delete any profile"
ON public.profiles
FOR DELETE
USING (
  (SELECT is_admin FROM public.profiles WHERE user_id = auth.uid()) = TRUE
);

-- Note: Admins can already read everything due to the public read policy.
-- If we had private data, we would add a read policy here too.
