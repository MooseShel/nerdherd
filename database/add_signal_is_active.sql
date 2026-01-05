-- Migration: Add is_active column to struggle_signals
-- This enables proper signal lifecycle management for always-on Serendipity

-- Add is_active column with default true
ALTER TABLE struggle_signals 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_struggle_signals_is_active 
ON struggle_signals(is_active);

-- Mark all expired signals as inactive
UPDATE struggle_signals 
SET is_active = false 
WHERE expires_at < NOW();

-- Add UPDATE policy for struggle_signals
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE tablename = 'struggle_signals' 
    AND policyname = 'Users can update own struggle signals'
  ) THEN
    CREATE POLICY "Users can update own struggle signals" 
    ON struggle_signals FOR UPDATE 
    USING (auth.uid() = user_id);
  END IF;
END $$;
