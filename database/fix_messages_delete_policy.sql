-- Enable deletion of messages
-- Current implementation attempts to delete messages where user is sender OR receiver.
-- RLS default is deny, so we must explicitly allow it.

DROP POLICY IF EXISTS "Users can delete their own messages" ON public.messages;

CREATE POLICY "Users can delete their own messages"
    ON public.messages
    FOR DELETE
    USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );
