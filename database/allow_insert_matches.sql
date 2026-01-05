-- Allow authenticated users to insert matches (they are suggesting the match)
CREATE POLICY "Enable insert for authenticated users" ON "public"."serendipity_matches"
AS PERMISSIVE FOR INSERT
TO "authenticated"
WITH CHECK (true);

-- Allow users to view matches they are part of
CREATE POLICY "Enable select for users involved in match" ON "public"."serendipity_matches"
AS PERMISSIVE FOR SELECT
TO "authenticated"
USING ((auth.uid() = user_a) OR (auth.uid() = user_b));
