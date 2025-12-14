-- Allow users to delete connections where they are one of the parties
CREATE POLICY "Users can delete their connections"
ON public.connections
FOR DELETE
USING (
    auth.uid() = user_id_1 OR auth.uid() = user_id_2
);
