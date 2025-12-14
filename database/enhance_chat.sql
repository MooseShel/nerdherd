-- Phase 3: Enhanced Chat Experience - Database Migration (Fixed)

-- Drop existing typing_status table if it exists to recreate with fixed constraints
DROP TABLE IF EXISTS typing_status;

-- 1. Typing Status Table (without strict foreign key constraints to allow simulated users)
CREATE TABLE IF NOT EXISTS typing_status (
  user_id UUID NOT NULL,
  chat_with UUID NOT NULL,
  is_typing BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, chat_with)
);

-- Enable RLS
ALTER TABLE typing_status ENABLE ROW LEVEL SECURITY;

-- Users can update their own typing status
CREATE POLICY "Users can update own typing status"
ON typing_status FOR ALL
USING (auth.uid() = user_id);

-- Users can view typing status of people they chat with
CREATE POLICY "Users can view chat partner typing status"
ON typing_status FOR SELECT
USING (auth.uid() = chat_with OR auth.uid() = user_id);

-- 2. Add columns to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';
ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_url TEXT;

-- 3. Create storage bucket for chat images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('chat-images', 'chat-images', false)
ON CONFLICT (id) DO NOTHING;

-- 4. Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Users can upload chat images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view chat images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own chat images" ON storage.objects;

-- 5. Storage policies for chat images
CREATE POLICY "Users can upload chat images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'chat-images' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view chat images"
ON storage.objects FOR SELECT
USING (bucket_id = 'chat-images');

CREATE POLICY "Users can delete own chat images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'chat-images' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);
