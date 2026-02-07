-- Add reply_to_id to messages
ALTER TABLE messages 
ADD COLUMN reply_to_id UUID REFERENCES messages(id);

-- Create message_reactions table
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

-- Enable RLS for message_reactions
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

-- Policies for message_reactions
CREATE POLICY "Users can view reactions for messages they can see"
    ON message_reactions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM messages m
            WHERE m.id = message_reactions.message_id
            AND (m.sender_id = auth.uid() OR m.receiver_id = auth.uid())
        )
    );

CREATE POLICY "Users can add reactions to messages they can see"
    ON message_reactions FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM messages m
            WHERE m.id = message_reactions.message_id
            AND (m.sender_id = auth.uid() OR m.receiver_id = auth.uid())
        )
    );

CREATE POLICY "Users can remove their own reactions"
    ON message_reactions FOR DELETE
    USING (user_id = auth.uid());

-- Typing Status Table (if not exists) & Realtime
CREATE TABLE IF NOT EXISTS typing_status (
    user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
    conversation_id UUID NOT NULL, -- Logical ID (e.g., hash of sorted user IDs) or just track per pair
    is_typing BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- Simple policy: Anyone can read typing status (or refine to friends)
CREATE POLICY "Anyone can view typing status"
    ON typing_status FOR SELECT
    USING (true);

CREATE POLICY "Users can update their own typing status"
    ON typing_status FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Add to Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE typing_status;
ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;
