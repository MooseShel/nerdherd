-- Step 1: Add Missing Columns to Universities Table
-- Run this FIRST before the main migration

-- Add short_name column
ALTER TABLE universities ADD COLUMN IF NOT EXISTS short_name TEXT;

-- Add location column  
ALTER TABLE universities ADD COLUMN IF NOT EXISTS location TEXT;

-- Add website_url column
ALTER TABLE universities ADD COLUMN IF NOT EXISTS website_url TEXT;

-- Add logo_url column
ALTER TABLE universities ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- Add is_active column
ALTER TABLE universities ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add unique constraint on short_name (will fail if duplicates exist, which is fine)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'universities_short_name_key'
  ) THEN
    ALTER TABLE universities ADD CONSTRAINT universities_short_name_key UNIQUE (short_name);
  END IF;
END $$;

-- Verify columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'universities'
ORDER BY ordinal_position;
