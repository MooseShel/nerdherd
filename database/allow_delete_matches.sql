-- Allow users to delete their own matches (Decline/Cancel)
CREATE POLICY "Users can delete their matches"
  ON public.serendipity_matches FOR DELETE
  USING (auth.uid() = user_a OR auth.uid() = user_b);
